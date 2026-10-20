-- Weakness Chart (id: weakness_chart)
--
-- In a battle, while the game waits for a command (the action menu, the move
-- list or the target choice), R opens a chart of the battlers on the field,
-- one page each (lib/chart.lua), in the game's own windows (lib/layout.lua).
-- Up and down turn the pages; R closes it.  While it is open, the battle
-- gets no input.  It sounds like the PC's storage screens, which the
-- Pokédex's entry pages share: SE_PC_LOGIN opening, SE_SELECT turning a page,
-- SE_PC_OFF closing.
--
-- The chart is drawn after the battle (Battle.draw), and its keys are read
-- where the battle reads its command keys (Ui.handleInput), none of which is R.
-- In FireRed and LeafGreen, L and R also open the Help System, which reads
-- them first (Help.update); in the command screens R is left to the chart,
-- and L still opens the help, except over the open chart.

return function(mod)
  local MOD_ID = "weakness_chart"

  local ENGINE = {
    Audio         = "src.core.game3.audio",
    Battle        = "src.core.game3.battle",
    BattleUi      = "src.core.game3.battle.ui",
    FrlgFont      = "src.ui.game3.frlg_font",
    Help          = "src.ui.game3.help_system",
    Kit           = "src.ui.game3.rse.scene_kit",
    ListMenu      = "src.ui.game3.list_menu",
    Profile       = "src.core.game3.profile",
    RomText       = "src.core.game3.rom_text",
    SeIds         = "src.core.game3.se_ids",
    State         = "src.core.game3.battle.state",
    SummaryChrome = "src.ui.game3.summary_chrome",
    Types         = "src.core.game3.battle.types",
    Window        = "src.ui.game3.window",
  }

  local function log(fmt, ...)
    print(("[%s] " .. fmt):format(MOD_ID, ...))
  end

  local function engineModule(path)
    local loaded, module = pcall(require, path)
    if loaded and type(module) == "table" then return module end
  end

  -- Every engine piece the chart needs, or the names of those missing.  The
  -- wraps go in together or not at all: a chart that takes the keys but is
  -- never drawn would leave the battle stuck behind nothing.
  local function resolveEngine()
    local Engine, missing = {}, {}
    for name, path in pairs(ENGINE) do
      Engine[name] = engineModule(path)
      if not Engine[name] then missing[#missing + 1] = path end
    end
    if #missing == 0 then
      for _, fn in ipairs({ { "Battle", "draw" }, { "Battle", "getState" }, { "BattleUi", "handleInput" },
        { "Help", "isOpen" }, { "Help", "update" }, { "Profile", "family" }, { "SummaryChrome", "drawTypeBadge" }, { "Types", "typeCalc" } }) do
        if type(Engine[fn[1]][fn[2]]) ~= "function" then missing[#missing + 1] = fn[1] .. "." .. fn[2] end
      end
    end
    table.sort(missing)
    return Engine, missing
  end

  local Engine, missing = resolveEngine()
  if #missing > 0 then
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

  local Battle, Ui, Help = Engine.Battle, Engine.BattleUi, Engine.Help

  local COMMAND_SCREENS = { menu = true, moves = true, target = true }

  -- Not while the game itself plays a battle out: the old man's and Wally's
  -- catching tutorials, and the Pokédude's lessons.
  local function choosingCommand()
    local st = Battle.getState()
    return st ~= nil and COMMAND_SCREENS[Ui._mode] and not st.oldManTutorial and not st.pokedude and not Ui._wally
  end

  -- { pages, index, openFrames, footer } while the chart is open.
  local chart = nil

  -- The chart, unless the command screen it was opened over is gone.
  local function openChart()
    if chart and not choosingCommand() then chart = nil end
    return chart
  end

  local function playSe(name)
    Engine.Audio.playSe(assert(Engine.SeIds[name], name))
  end

  local function open()
    local pages = Chart.pages(Battle.getState())
    if #pages == 0 then return false end
    chart = { pages = pages, index = 1, openFrames = 0, footer = Layout.footer() }
    playSe("SE_PC_LOGIN")
    return true
  end

  -- At the first or last page the page stays, silently, as a list's cursor does.
  local function handleKeys(input)
    chart.openFrames = chart.openFrames + 1
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

  local function draw()
    Layout.draw(chart.pages[chart.index], chart.index, #chart.pages, chart.openFrames, chart.footer)
  end

  -- An error in the chart closes it and is logged, instead of stopping the battle.
  local function guarded(what, fn)
    local done, result = pcall(fn)
    if not done then
      chart = nil
      log("chart closed: %s failed: %s", what, tostring(result))
    end
    return done and result
  end

  -- ------- engine wraps
  --
  -- Each original is kept on the engine module under ORIGINALS, so loading
  -- this mod twice (a hot reload) wraps the engine's function, not our own.

  local ORIGINALS = "__" .. MOD_ID .. "_originals"

  local function wrap(module, name, make)
    local saved = rawget(module, ORIGINALS)
    if not saved then
      saved = {}
      module[ORIGINALS] = saved
    end
    saved[name] = saved[name] or module[name]
    module[name] = make(saved[name])
  end

  wrap(Ui, "handleInput", function(original)
    return function(input, ...)
      if not input then return original(input, ...) end
      if openChart() then
        guarded("reading the keys", function() handleKeys(input) end)
        return true
      end
      if input:wasPressed("r") and choosingCommand() and guarded("opening", open) then return true end
      return original(input, ...)
    end
  end)

  wrap(Battle, "draw", function(original)
    return function(...)
      original(...)
      if openChart() then guarded("drawing", draw) end
    end
  end)

  wrap(Help, "update", function(original)
    return function(game, ...)
      local input = game and game.input
      if input and not Help.isOpen() and (openChart() or (input:wasPressed("r") and choosingCommand())) then
        return false
      end
      return original(game, ...)
    end
  end)

  local function close() chart = nil end
  mod.events:on("battle.started", close)
  mod.events:on("battle.ended", close)
end
