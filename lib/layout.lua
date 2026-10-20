-- The chart window, drawn over the battle with the game's own pieces: the
-- standard window frame of the player's choice (Window.stdFrame), the text
-- font (FrlgFont), the summary screen's move type badges and the list menu's
-- scroll arrows.  A header window names the battler, with its level and
-- types; the window below lists its matchups, one group per row, five badges
-- to a row, over a footer naming the buttons.
--
-- Positions are pixels of the 240x160 screen, windows in 8px tiles.

return function(Engine)
  local Layout = {}

  local HEADER = { left = 1, top = 1, w = 28, h = 2 }
  local BODY = { left = 1, top = 5, w = 28, h = 14 }
  Layout.HEADER, Layout.BODY = HEADER, BODY

  local TEXT_X = 10
  local RIGHT = 230
  local HEADER_Y = 8
  local LEVEL_GAP = 8

  local BADGE_W, BADGE_H = 32, 16
  local BADGE_STEP = 34
  local BADGES_PER_ROW = 5
  local BADGES_X = 48
  local ROWS_Y = 45
  local ROW_PITCH = 17
  local GROUP_GAP = 1
  local FOOTER_Y = 136
  Layout.BADGE_W, Layout.BADGE_H, Layout.RIGHT, Layout.FOOTER_Y = BADGE_W, BADGE_H, RIGHT, FOOTER_Y
  Layout.BODY_BOTTOM = (BODY.top + BODY.h) * 8

  -- The footer joins the words of two of the game's button hints:
  -- gText_PickOk ("{DPAD_UPDOWN}PICK {A_BUTTON}OK") and gText_AButtonExit
  -- ("{A_BUTTON}EXIT"), the exit on R.  The R icon is twice as wide as the A
  -- one the hints were drawn with, so a space follows each icon.
  function Layout.footer()
    local pick = Engine.RomText.plain("gText_PickOk"):match("{DPAD_UPDOWN}(%S+)")
    local exit = Engine.RomText.plain("gText_AButtonExit"):match("{A_BUTTON}(%S+)")
    if not (pick and exit) then error("the ROM's PICK and EXIT button hints are not as expected", 0) end
    return ("{DPAD_UPDOWN} %s  {R_BUTTON} %s"):format(pick, exit)
  end

  -- Where each group's label and badges go:
  -- { { label, y, badges = { { type, x, y }, ... } }, ... }.
  function Layout.rows(page)
    local rows, y = {}, ROWS_Y
    for _, group in ipairs(page.groups) do
      local row = { label = group.label, y = y, badges = {} }
      for i, typeId in ipairs(group.types) do
        local column, line = (i - 1) % BADGES_PER_ROW, math.floor((i - 1) / BADGES_PER_ROW)
        row.badges[i] = { type = typeId, x = BADGES_X + column * BADGE_STEP, y = y + line * ROW_PITCH }
      end
      rows[#rows + 1] = row
      y = y + ROW_PITCH * math.ceil(#group.types / BADGES_PER_ROW) + GROUP_GAP
    end
    return rows
  end

  local badgeImage, badgeQuads

  local function drawBadge(typeId, x, y)
    if not badgeImage then
      local entry = assert(Engine.Kit.manifest("rse/summary"), "the summary screen graphics are not in the cache").moveTypes
      badgeImage = assert(entry and Engine.Kit.image(entry.png), "the move type badges are not in the cache")
      badgeQuads = {}
    end
    local quad = badgeQuads[typeId]
    if not quad then
      quad = love.graphics.newQuad(0, typeId * BADGE_H, BADGE_W, BADGE_H, badgeImage:getDimensions())
      badgeQuads[typeId] = quad
    end
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(badgeImage, quad, x, y)
  end

  -- frame counts the frames the chart has been open, for the arrows' bounce.
  function Layout.draw(page, index, count, frame, footer)
    local Font = Engine.FrlgFont
    Engine.Window.stdFrame(HEADER)
    Engine.Window.stdFrame(BODY)

    Font.draw(page.name, TEXT_X, HEADER_Y)
    if page.level then Font.draw("{LV}" .. page.level, TEXT_X + Font.measure(page.name) + LEVEL_GAP, HEADER_Y) end
    local type1, type2 = page.types[1], page.types[2]
    if type2 then
      drawBadge(type1, RIGHT - BADGE_W - BADGE_STEP, HEADER_Y)
      drawBadge(type2, RIGHT - BADGE_W, HEADER_Y)
    else
      drawBadge(type1, RIGHT - BADGE_W, HEADER_Y)
    end

    for _, row in ipairs(Layout.rows(page)) do
      Font.draw(row.label, TEXT_X, row.y)
      for _, badge in ipairs(row.badges) do drawBadge(badge.type, badge.x, badge.y) end
    end

    Font.draw(footer, RIGHT - Font.measure(footer), FOOTER_Y)
    Engine.ListMenu.drawScrollArrows(BODY, index > 1, index < count, frame)
  end

  return Layout
end
