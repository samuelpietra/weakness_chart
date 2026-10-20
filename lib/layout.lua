-- The chart window, drawn over the battle with the game's own pieces: the
-- window frame the player chose in OPTIONS, the text font, the summary
-- screen's type badges and the list menu's scroll arrows.  A header
-- window names the battler, with its level and types; the window below lists
-- its matchups, one group per row, five badges to a row, over a footer naming
-- the buttons.
--
-- Positions are pixels of the 240x160 screen, windows are in 8px tiles.

return function(Engine)
  local Font, Window = Engine.FrlgFont, Engine.Window
  local Layout = {}

  local TILE = 8
  local HEADER_WINDOW = { left = 1, top = 1, w = 28, h = 2 }
  local MATCHUPS_WINDOW = { left = 1, top = 5, w = 28, h = 14 }
  local MATCHUPS_BOTTOM = (MATCHUPS_WINDOW.top + MATCHUPS_WINDOW.h) * TILE

  local TEXT_X = 10
  local RIGHT = 230
  local HEADER_Y = 8
  local LEVEL_GAP = 8

  -- Every badge takes a 32x16 slot: Emerald's badges fill it, FireRed's and
  -- LeafGreen's are 32x12 and sit in its middle.
  local BADGE_W, BADGE_H = 32, 16
  local BADGE_STEP = 34
  local BADGES_PER_ROW = 5
  local BADGES_X = 48
  local ROWS_Y = 45
  local ROW_STEP = 17
  -- The tightest gap that keeps six rows (Steel/Rock, Electric/Steel) in the window.
  local GROUP_GAP = 1
  local FOOTER_Y = 136

  -- Each group's label and badges, placed: { { label, y, badges = { { type, x, y }, ... } }, ... }.
  local function matchupRows(groups)
    local rows, y = {}, ROWS_Y
    for _, group in ipairs(groups) do
      local row = { label = group.label, y = y, badges = {} }
      for i, typeId in ipairs(group.types) do
        local column, line = (i - 1) % BADGES_PER_ROW, math.floor((i - 1) / BADGES_PER_ROW)
        row.badges[i] = { type = typeId, x = BADGES_X + column * BADGE_STEP, y = y + line * ROW_STEP }
      end
      rows[#rows + 1] = row
      y = y + ROW_STEP * math.ceil(#group.types / BADGES_PER_ROW) + GROUP_GAP
    end
    return rows
  end

  -- How many badges of these groups would leave the window or run into the footer.
  function Layout.misplacedBadges(groups, footer)
    local footerLeft = RIGHT - Font.measure(footer)
    local misplaced = 0
    for _, row in ipairs(matchupRows(groups)) do
      for _, badge in ipairs(row.badges) do
        local right, bottom = badge.x + BADGE_W, badge.y + BADGE_H
        if right > RIGHT or bottom > MATCHUPS_BOTTOM or (bottom > FOOTER_Y and right > footerLeft) then
          misplaced = misplaced + 1
        end
      end
    end
    return misplaced
  end

  local emeraldBadges, emeraldQuads

  local function drawEmeraldBadge(typeId, x, y)
    if not emeraldBadges then
      local summary = assert(Engine.Kit.manifest("rse/summary"), "the summary screen graphics are not in the cache")
      emeraldBadges = assert(Engine.Kit.image(summary.moveTypes.png), "the move type badges are not in the cache")
      emeraldQuads = {}
    end
    emeraldQuads[typeId] = emeraldQuads[typeId]
      or love.graphics.newQuad(0, typeId * BADGE_H, BADGE_W, BADGE_H, emeraldBadges:getDimensions())
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(emeraldBadges, emeraldQuads[typeId], x, y)
  end

  local FIRERED_BADGE_H = 12

  local function drawFireRedBadge(typeId, x, y)
    Engine.SummaryChrome.drawTypeBadge(typeId, x, y + (BADGE_H - FIRERED_BADGE_H) / 2)
  end

  -- What differs between the games, by the engine's game family: Emerald
  -- ("rse") or FireRed and LeafGreen ("frlg").  The button hints are the same
  -- text under other names; the badges are each summary screen's own.
  local GAMES = {
    rse = { pickHint = "gText_PickOk", exitHint = "gText_AButtonExit", drawBadge = drawEmeraldBadge },
    frlg = { pickHint = "gText_PickOK", exitHint = "gText_ABUTTONExit", drawBadge = drawFireRedBadge },
  }

  local function game()
    local family = Engine.Profile.family()
    return GAMES[family] or error(("game family %s is not supported"):format(tostring(family)), 0)
  end

  -- The footer joins the words of two of the game's button hints:
  -- "{DPAD_UPDOWN}PICK {A_BUTTON}OK" and "{A_BUTTON}EXIT", the exit on R.  The
  -- R icon is twice as wide as the A one the hints were drawn with, so a space
  -- follows each icon.
  function Layout.footer()
    local hints = game()
    local pick = Engine.RomText.plain(hints.pickHint):match("{DPAD_UPDOWN}(%S+)")
    local exit = Engine.RomText.plain(hints.exitHint):match("{A_BUTTON}(%S+)")
    if not (pick and exit) then error("the ROM's PICK and EXIT button hints are not as expected", 0) end
    return ("{DPAD_UPDOWN} %s  {R_BUTTON} %s"):format(pick, exit)
  end

  -- openFrames, the frames the chart has been open, sets the arrows' bounce.
  function Layout.draw(page, index, count, openFrames, footer)
    local drawBadge = game().drawBadge
    Window.stdFrame(HEADER_WINDOW)
    Window.stdFrame(MATCHUPS_WINDOW)

    Font.draw(page.name, TEXT_X, HEADER_Y)
    Font.draw("{LV}" .. page.level, TEXT_X + Font.measure(page.name) + LEVEL_GAP, HEADER_Y)
    for i, typeId in ipairs(page.types) do
      drawBadge(typeId, RIGHT - BADGE_W - (#page.types - i) * BADGE_STEP, HEADER_Y)
    end

    for _, row in ipairs(matchupRows(page.groups)) do
      Font.draw(row.label, TEXT_X, row.y)
      for _, badge in ipairs(row.badges) do drawBadge(badge.type, badge.x, badge.y) end
    end

    Font.draw(footer, RIGHT - Font.measure(footer), FOOTER_Y)
    Engine.ListMenu.drawScrollArrows(MATCHUPS_WINDOW, index > 1, index < count, openFrames)
  end

  return Layout
end
