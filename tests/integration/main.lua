-- The battle paths of the mod on stand-ins for the engine modules it wraps:
-- when R opens the chart and closes it, what the pages hold, that the battle
-- gets no input while the chart is open, and that the chart never outlives
-- the command screen it was opened over.  The type chart is the engine's own.
local MOD = os.getenv("WCH_MOD") .. "/"
local ENGINE = os.getenv("WCH_ENGINE") .. "/"
local function slurp(p) local f = io.open(p, "rb"); if not f then return nil end local s = f:read("*a"); f:close(); return s end

local failures = 0
local function check(cond, what)
  print((cond and "PASS " or "FAIL ") .. what)
  if not cond then failures = failures + 1 end
end

-- ------- stand-ins

local ROM = { gText_PickOk = "{DPAD_UPDOWN}PICK {A_BUTTON}OK", gText_AButtonExit = "{A_BUTTON}EXIT" }
local RomText = { plain = function(key) return ROM[key] or "" end,
  key = function(name, i) return name .. "[" .. i .. "]" end, lazy = function() return {} end }

local st
local Battle = { getState = function() return st end, draw = function() end }
local inputCalls = 0
local Ui = { _mode = "menu", handleInput = function() inputCalls = inputCalls + 1; return false end }
local State = {
  isAbsent = function(s, id) return s.absent[id] and true or false end,
  isFainted = function(b) return b.fainted end,
  prefixedName = function(s, b)
    if b.side == "player" then return b.name end
    return (s.wild and "Wild " or "Foe ") .. b.name
  end,
}

local drawn
local fontBroken = false
local Font = {
  draw = function(text) if fontBroken then error("no font") end drawn.texts[#drawn.texts + 1] = text end,
  measure = function(text) return 6 * #text end,
}
local Window = { stdFrame = function(tpl) drawn.frames[#drawn.frames + 1] = tpl end }
local ListMenu = { drawScrollArrows = function(_, up, down) drawn.up, drawn.down = up, down end }
local Kit = {
  manifest = function() return { moveTypes = { png = "move_types.png" } } end,
  image = function() return { getDimensions = function() return 32, 368 end } end,
}
love.graphics = { newQuad = function(_, y) return { y = y } end, setColor = function() end,
  draw = function(_, quad) drawn.badges[#drawn.badges + 1] = quad.y / 16 end }

local function resetDrawn() drawn = { texts = {}, frames = {}, badges = {} } end

local sounds = {}
local SE = { SE_PC_LOGIN = 2, SE_PC_OFF = 3, SE_SELECT = 5 }
local SE_NAME = { [2] = "LOGIN", [3] = "OFF", [5] = "SELECT" }
local Audio = { playSe = function(id) sounds[#sounds + 1] = SE_NAME[id] end }
local function heard() local all = table.concat(sounds, ","); sounds = {}; return all end

local events = {}
local fakeMod = { path = "mods/weakness_chart", read = function(_, rel) return slurp(MOD .. rel) end,
  events = { on = function(_, name, fn) events[name] = fn end } }

-- a frame: the battle reads its keys, then draws
local function frame(pressed)
  local input = { wasPressed = function(_, key) return key == pressed end }
  local before = inputCalls
  local consumed = Ui.handleInput(input)
  resetDrawn()
  Battle.draw()
  return consumed, inputCalls > before
end

local function texts() return table.concat(drawn.texts, " | ") end

function love.load()
  local ok, err = pcall(function()
    package.path = ENGINE .. "?.lua;" .. ENGINE .. "?/init.lua;" .. package.path
    package.loaded["src.core.game3.rom_text"] = RomText
    local Types = require("src.core.game3.battle.types")
    local ID = Types.ID
    for path, module in pairs({
      ["src.core.game3.battle"] = Battle, ["src.core.game3.battle.ui"] = Ui,
      ["src.ui.game3.frlg_font"] = Font, ["src.ui.game3.rse.scene_kit"] = Kit,
      ["src.ui.game3.list_menu"] = ListMenu, ["src.core.game3.battle.state"] = State,
      ["src.ui.game3.window"] = Window, ["src.core.game3.audio"] = Audio, ["src.core.game3.se_ids"] = SE,
    }) do package.loaded[path] = module end

    local entry = assert(loadstring(slurp(MOD .. "main.lua"), "main.lua"))()
    entry(fakeMod)
    entry(fakeMod) -- a hot reload wraps the engine's functions, not the mod's

    local function battler(side, name, level, t1, t2, extra)
      local b = { side = side, name = name, mon = { level = level }, type1 = t1, type2 = t2 }
      for k, v in pairs(extra or {}) do b[k] = v end
      return b
    end

    -- --- a single battle
    st = { battlersCount = 2, absent = {}, battlers = {
      [0] = battler("player", "TORCHIC", 13, ID.FIRE),
      [1] = battler("enemy", "GEODUDE", 12, ID.ROCK, ID.GROUND),
    } }
    Ui._mode = "menu"

    local consumed, reached = frame(nil)
    check(not consumed and reached and #drawn.frames == 0, "closed: the battle gets its input, nothing is drawn")
    consumed, reached = frame("a")
    check(reached and #drawn.frames == 0, "closed: A reaches the battle once despite the reload")

    consumed, reached = frame("r")
    check(consumed and not reached, "R in the action menu opens the chart and the battle never sees it")
    check(#drawn.frames == 2, "two windows: header and matchups")
    check(texts():find("Foe GEODUDE", 1, true) and texts():find("{LV}12", 1, true), "page 1 is the foe, with its level")
    check(drawn.badges[1] == ID.ROCK and drawn.badges[2] == ID.GROUND, "header badges are the foe's types")
    check(texts():find("{DPAD_UPDOWN} PICK  {R_BUTTON} EXIT", 1, true), "footer from the ROM's PICK and EXIT")
    check(texts():find("4× | 2× | 1/2× | 1/4× | 0×", 1, true), "ROCK/GROUND lists all five groups, in order")
    check(drawn.badges[3] == ID.WATER and drawn.badges[4] == ID.GRASS, "4×: WATER, GRASS")
    check(drawn.up == false and drawn.down == true, "page 1 of 2: only the down arrow")
    check(heard() == "LOGIN", "opening sounds like a PC storage screen: SE_PC_LOGIN")

    for _, key in ipairs({ "a", "b", "left", "start" }) do
      consumed, reached = frame(key)
      check(consumed and not reached, "open: " .. key .. " never reaches the battle")
    end
    check(heard() == "", "other keys make no sound")
    frame("up")
    check(texts():find("Foe GEODUDE", 1, true), "up on the first page stays there")
    check(heard() == "", "and makes no sound")
    frame("down")
    check(heard() == "SELECT", "turning a page: SE_SELECT")
    check(texts():find("TORCHIC", 1, true) and not texts():find("Foe", 1, true), "down: the player's own POKéMON, no prefix")
    check(drawn.up == true and drawn.down == false, "page 2 of 2: only the up arrow")
    frame("down")
    check(texts():find("TORCHIC", 1, true), "down on the last page stays there")
    check(heard() == "", "and makes no sound")
    check(not texts():find("4×", 1, true) and texts():find("2× | 1/2×", 1, true), "FIRE: 2× and 1/2× only")

    consumed, reached = frame("r")
    check(consumed and not reached and #drawn.frames == 0, "R closes the chart, and is not passed on")
    check(heard() == "OFF", "closing: SE_PC_OFF")
    consumed, reached = frame("down")
    check(reached and not consumed, "closed again: the battle gets its input")

    -- --- where R does not open it
    for _, mode in ipairs({ "selmsg", "bag", "party", "none" }) do
      Ui._mode = mode
      consumed, reached = frame("r")
      check(reached and #drawn.frames == 0, "R in mode " .. mode .. " goes to the battle")
    end
    Ui._mode = "moves"
    frame("r")
    check(#drawn.frames == 2, "R in the move list opens it")
    Ui._mode = "selmsg"
    consumed, reached = frame(nil)
    check(#drawn.frames == 0 and reached, "the command screen ending closes it")
    check(heard() == "LOGIN", "silently: only the opening was heard")
    Ui._mode = "target"
    frame("r")
    check(#drawn.frames == 2, "R in the target choice opens it")
    events["battle.ended"]()
    frame(nil)
    check(#drawn.frames == 0, "the battle ending closes it")
    Ui._mode = "menu"
    st.oldManTutorial = true
    consumed, reached = frame("r")
    check(reached and #drawn.frames == 0, "not during a scripted tutorial")
    st.oldManTutorial = nil
    Ui._wally = true
    consumed, reached = frame("r")
    check(reached and #drawn.frames == 0, "not while Wally catches")
    Ui._wally = nil

    -- --- a double battle
    st = { battlersCount = 4, wild = true, absent = { [3] = true }, battlers = {
      [0] = battler("player", "LOMBRE", 15, ID.WATER, ID.GRASS),
      [1] = battler("enemy", "GASTLY", 14, ID.GHOST, ID.POISON),
      [2] = battler("player", "SHEDINJA", 20, ID.BUG, ID.GHOST, { fainted = true }),
      [3] = battler("enemy", "NOSEPASS", 15, ID.ROCK),
    } }
    frame("r")
    local seen = { texts():match("^(.-) |") }
    frame("down"); seen[#seen + 1] = texts():match("^(.-) |")
    frame("down"); seen[#seen + 1] = texts():match("^(.-) |")
    check(table.concat(seen, ",") == "Wild GASTLY,LOMBRE,LOMBRE",
      "doubles: foes first, absent and fainted battlers skipped, wild prefix (" .. table.concat(seen, ",") .. ")")
    frame("r")

    -- --- Foresight and Transform, as the damage code takes them
    st = { battlersCount = 2, absent = {}, battlers = {
      [0] = battler("player", "DITTO", 30, ID.NORMAL, nil, { expTransform = { type1 = ID.WATER, type2 = ID.GROUND } }),
      [1] = battler("enemy", "GASTLY", 14, ID.GHOST, ID.POISON),
    } }
    frame("r")
    check(texts():find("0×", 1, true), "GHOST/POISON: Normal and Fighting deal it no damage")
    frame("r")
    st.battlers[1].expIdentified = true
    frame("r")
    check(not texts():find("0×", 1, true) and texts():find("1/2×", 1, true), "after Foresight they do: no 0× row left")
    frame("down")
    check(drawn.badges[1] == ID.WATER and drawn.badges[2] == ID.GROUND, "a Transformed battler shows the copied types")
    frame("r")

    -- --- a failure closes the chart instead of stopping the battle
    fontBroken = true
    frame("r")
    fontBroken = false
    consumed, reached = frame("a")
    check(reached, "a drawing error closes the chart and gives the battle its input back")
  end)
  if not ok then print("FAIL " .. tostring(err)); failures = failures + 1 end
  print(failures == 0 and "ALL PASS" or (failures .. " FAILED"))
  love.event.quit()
end
