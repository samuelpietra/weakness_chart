-- The mod against the real engine, with no ROM, so CI runs it: every module
-- and function the mod reaches is still there (resolveEngine would otherwise
-- switch the chart off with only a log line), the sounds and the type chart
-- it reads, the engine source still behaving as main.lua's comments say, and
-- the three wraps going in on the real modules.
local MOD = os.getenv("WCH_MOD") .. "/"
local ENGINE = os.getenv("WCH_ENGINE") .. "/"
local function slurp(p) local f = io.open(p, "rb"); if not f then return nil end local s = f:read("*a"); f:close(); return s end

local failures = 0
local function check(cond, what)
  print((cond and "PASS " or "FAIL ") .. what)
  if not cond then failures = failures + 1 end
end

-- What main.lua and lib/ call on each module, by its name in main.lua's ENGINE.
local CALLED = {
  Audio = { "playSe" },
  Battle = { "draw", "getState" },
  BattleUi = { "handleInput" },
  FrlgFont = { "draw", "measure" },
  Help = { "isOpen", "update" },
  Kit = { "image", "manifest" },
  ListMenu = { "drawScrollArrows" },
  Profile = { "family" },
  RomText = { "plain" },
  State = { "isAbsent", "isFainted", "prefixedName" },
  SummaryChrome = { "drawTypeBadge" },
  Types = { "typeCalc" },
  Window = { "stdFrame" },
}
local SOUNDS = { "SE_PC_LOGIN", "SE_SELECT", "SE_PC_OFF" }

local function has(source, text) return source ~= nil and source:find(text, 1, true) ~= nil end

function love.load()
  local ok, err = pcall(function()
    package.path = ENGINE .. "?.lua;" .. ENGINE .. "?/init.lua;" .. package.path
    local source = slurp(MOD .. "main.lua")

    -- the modules, read from main.lua's own ENGINE table
    local modules = {}
    for name, path in source:match("local ENGINE = (%b{})"):gmatch('(%w+)%s*=%s*"([%w%._]+)"') do
      local loaded, module = pcall(require, path)
      modules[name] = loaded and type(module) == "table" and module or nil
      check(modules[name] ~= nil, "module " .. path)
    end
    for name, functions in pairs(CALLED) do
      for _, fn in ipairs(functions) do
        check(modules[name] and type(modules[name][fn]) == "function", "function " .. name .. "." .. fn)
      end
    end
    for _, sound in ipairs(SOUNDS) do
      check(modules.SeIds and modules.SeIds[sound] ~= nil, "sound " .. sound)
    end

    -- the type chart: the multiplier is typeCalc's third result, ??? is a type id
    local Types = modules.Types
    local ID = Types.ID
    check(type(ID) == "table" and ID.MYSTERY ~= nil, "Types.ID, with MYSTERY")
    local function multiplier(attacking, ...) return select(3, Types.typeCalc(attacking, ...)) end
    check(multiplier(ID.ELECTRIC, ID.WATER, ID.FLYING) == 4, "ELECTRIC on WATER/FLYING is 4x")
    check(multiplier(ID.GRASS, ID.ROCK) == 2, "GRASS on ROCK is 2x")
    check(multiplier(ID.FIRE, ID.WATER, ID.ROCK) == 0.25, "FIRE on WATER/ROCK is 1/4x")
    check(multiplier(ID.GROUND, ID.FLYING) == 0, "GROUND on FLYING is 0x")
    check(multiplier(ID.NORMAL, ID.GHOST, nil, nil, true) == 1, "Foresight lets NORMAL hit a GHOST")

    -- what the engine does that main.lua and lib/chart.lua rely on, read from its source
    local ui = slurp(ENGINE .. "src/core/game3/battle/ui.lua")
    for _, mode in ipairs({ "menu", "moves", "target" }) do
      check(has(ui, 'Ui._mode = "' .. mode .. '"'), "the battle's command screen Ui._mode " .. mode)
    end
    check(not has(ui, 'wasPressed("r")') and not has(ui, "wasPressed('r')"), "the battle's command keys leave R free")
    check(has(ui, "Ui._wally"), "Wally's tutorial sets Ui._wally")
    local help = slurp(ENGINE .. "src/ui/game3/help_system.lua")
    check(has(help, "wasPressed('l')") and has(help, "wasPressed('r')"), "the Help System opens on L and R")
    local damage = slurp(ENGINE .. "src/core/game3/battle/damage.lua")
    check(has(damage, "expTransform.type1") and has(damage, "expIdentified"),
      "the damage code takes Transform's copied types and Foresight")
    local bridge = slurp(ENGINE .. "src/core/game3/battle_bridge.lua")
    check(has(bridge, 'ModRuntime.emit("battle.started"') and has(bridge, 'ModRuntime.emit("battle.ended"'),
      "battles emit battle.started and battle.ended")

    -- the entry on the real modules: every wrap in place
    local events = {}
    local entry = assert(loadstring(source, "main.lua"))()
    entry({ path = "mods/weakness_chart", read = function(_, rel) return slurp(MOD .. rel) end,
      events = { on = function(_, name) events[name] = true end } })
    local originals = "__weakness_chart_originals"
    for _, wrap in ipairs({ { "Battle", "draw" }, { "BattleUi", "handleInput" }, { "Help", "update" } }) do
      local module = modules[wrap[1]]
      local saved = rawget(module, originals)
      check(saved ~= nil and saved[wrap[2]] ~= nil and module[wrap[2]] ~= saved[wrap[2]],
        wrap[1] .. "." .. wrap[2] .. " wrapped")
    end
    check(events["battle.started"] and events["battle.ended"], "the chart closes on battle.started and battle.ended")
  end)
  if not ok then print("FAIL " .. tostring(err)); failures = failures + 1 end
  print(failures == 0 and "ALL PASS" or (failures .. " FAILED"))
  love.event.quit()
end
