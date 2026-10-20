-- Weakness Chart (id: weakness_chart)
--
-- In a battle, while the game waits for a command (the action menu, the move
-- list or the target choice), R opens a chart of the battlers on the field,
-- one page each, foes first: name, level and types, and every attacking type
-- that deals 4x, 2x, 1/2x, 1/4x or no damage to it (lib/chart.lua).  Up and
-- down turn the pages; R closes it.  While it is open, the battle gets no
-- input.  It sounds like the PC's storage screens do, which the Pokédex's
-- entry pages share: SE_PC_LOGIN opening, SE_SELECT turning a page,
-- SE_PC_OFF closing.
--
-- The window is the game's own (lib/layout.lua), drawn over the battle after
-- the engine has drawn it (Battle.draw).  The keys are read where the battle
-- reads its command keys (Ui.handleInput), which neither L nor R is used in.

return function(mod)
  local MOD_ID = "weakness_chart"

  local ENGINE = {
    Audio     = "src.core.game3.audio",
    Battle    = "src.core.game3.battle",
    BattleUi  = "src.core.game3.battle.ui",
    FrlgFont  = "src.ui.game3.frlg_font",
    Kit       = "src.ui.game3.rse.scene_kit",
    ListMenu  = "src.ui.game3.list_menu",
    RomText   = "src.core.game3.rom_text",
    SE        = "src.core.game3.se_ids",
    State     = "src.core.game3.battle.state",
    Types     = "src.core.game3.battle.types",
    Window    = "src.ui.game3.window",
  }

  local function engineModule(path)
    local loaded, module = pcall(require, path)
    if not loaded or type(module) ~= "table" then return nil end
    return module
  end

  local function log(fmt, ...)
    print(("[%s] " .. fmt):format(MOD_ID, ...))
  end

  local Engine, missing = {}, {}
  for name, path in pairs(ENGINE) do
    Engine[name] = engineModule(path)
    if not Engine[name] then missing[#missing + 1] = path end
  end
  if #missing > 0 then
    table.sort(missing)
    log("this engine version lacks %s; the chart is off", table.concat(missing, ", "))
    return
  end

  local function libChunk(name)
    local rel = "lib/" .. name .. ".lua"
    local source = mod:read(rel)
    if not source then error(("%s: %s is missing"):format(MOD_ID, rel), 0) end
    local chunk, err = load(source, "@" .. mod.path .. "/" .. rel)
    if not chunk then error(("%s: %s did not compile: %s"):format(MOD_ID, rel, tostring(err)), 0) end
    return chunk()(Engine)
  end
  local Chart = libChunk("chart")
  local Layout = libChunk("layout")

  local Battle, Ui = Engine.Battle, Engine.BattleUi

  -- The command screens the chart opens over.
  local COMMAND_MODES = { menu = true, moves = true, target = true }

  local function choosingCommand()
    local st = Battle.getState()
    return st ~= nil and COMMAND_MODES[Ui._mode] and not st.oldManTutorial and not Ui._wally
  end

  -- { pages, index, frame, footer } while the chart is open.
  local chart = nil

  local function playSe(name)
    Engine.Audio.playSe(assert(Engine.SE[name], name))
  end

  local function open()
    local pages = Chart.pages(Battle.getState())
    if #pages == 0 then return false end
    chart = { pages = pages, index = 1, frame = 0, footer = Layout.footer() }
    playSe("SE_PC_LOGIN")
    return true
  end

  -- At the first or last page the page stays, silently, as a list's cursor does.
  local function turnPage(input)
    chart.frame = chart.frame + 1
    if input:wasPressed("r") then
      chart = nil
      playSe("SE_PC_OFF")
      return
    end
    local step = (input:wasPressed("up") and -1) or (input:wasPressed("down") and 1) or 0
    local index = math.max(1, math.min(#chart.pages, chart.index + step))
    if index ~= chart.index then
      chart.index = index
      playSe("SE_SELECT")
    end
  end

  -- ------- engine wraps
  --
  -- Each original is kept on the engine module under ORIGINALS, so loading
  -- this mod twice (a hot reload) wraps the engine's function, not our own.

  local ORIGINALS = "__" .. MOD_ID .. "_originals"

  local function wrap(module, name, make)
    if type(module[name]) ~= "function" then
      log("this engine version lacks %s; the chart is off", name)
      return false
    end
    local saved = rawget(module, ORIGINALS)
    if not saved then
      saved = {}
      module[ORIGINALS] = saved
    end
    saved[name] = saved[name] or module[name]
    module[name] = make(saved[name])
    return true
  end

  -- An error in the chart closes it and is logged, instead of stopping the battle.
  local function guarded(what, fn, ...)
    local done, err = pcall(fn, ...)
    if not done then
      chart = nil
      log("chart closed: %s failed: %s", what, tostring(err))
    end
    return done and err
  end

  if not (type(Battle.getState) == "function" and type(Engine.Types.typeCalc) == "function") then
    log("this engine version lacks Battle.getState or Types.typeCalc; the chart is off")
    return
  end

  wrap(Ui, "handleInput", function(original)
    return function(input, ...)
      if chart and not choosingCommand() then chart = nil end
      if chart then
        guarded("turning a page", turnPage, input)
        return true
      end
      if input and input:wasPressed("r") and choosingCommand() and guarded("opening", open) then
        return true
      end
      return original(input, ...)
    end
  end)

  wrap(Battle, "draw", function(original)
    return function(...)
      original(...)
      if chart and not choosingCommand() then chart = nil end
      if chart then
        guarded("drawing", Layout.draw, chart.pages[chart.index], chart.index, #chart.pages, chart.frame, chart.footer)
      end
    end
  end)

  mod.events:on("battle.started", function() chart = nil end)
  mod.events:on("battle.ended", function() chart = nil end)
end
