-- Draws chart pages with the real engine modules and the imported ROM, and
-- checks every type combination a battler can have fits the window.
local MOD = os.getenv("WCH_MOD") .. "/"
local ENGINE = os.getenv("WCH_ENGINE") .. "/"
local EM = os.getenv("WCH_INSTALL") .. "/emerald/"
local OUT = os.getenv("WCH_WORK") .. "/"
local function slurp(p) local f = io.open(p, "rb"); if not f then return nil end local s = f:read("*a"); f:close(); return s end

-- The engine reads its cache through CacheFs and the scene kit; both are
-- pointed at the imported ROM data here, decoded as the engine decodes it.
local function useCache()
  local CacheBlob = require("src.import.CacheBlob")
  local CacheFs = require("src.import.CacheFs")
  local function read(rel)
    rel = rel:gsub("^red/", "")
    for _, path in ipairs({ EM .. rel, EM .. "data/generated/gba/" .. rel }) do
      local bytes = slurp(path)
      if bytes then return CacheBlob.decode(rel, bytes) end
    end
  end
  CacheFs.read, CacheFs.readAt, CacheFs.readActive = read, read, read
  local Kit = require("src.ui.game3.rse.scene_kit")
  local images = {}
  Kit.image = function(path)
    if images[path] == nil then
      local bytes = slurp(EM .. path)
      images[path] = bytes and love.graphics.newImage(love.image.newImageData(love.filesystem.newFileData(bytes, path))) or false
      if images[path] then images[path]:setFilter("nearest", "nearest") end
    end
    return images[path] or nil
  end
  Kit.loadLua = function(path)
    local source = slurp(EM .. path)
    return source and assert(load(source, "@" .. path, "t", {}))()
  end
end

local function lib(name, Engine)
  return assert(loadstring(slurp(MOD .. "lib/" .. name .. ".lua"), name))()(Engine)
end

function love.load()
  local ok, err = pcall(function()
    package.path = ENGINE .. "?.lua;" .. ENGINE .. "?/init.lua;" .. package.path
    useCache()
    local Engine = {
      FrlgFont = require("src.ui.game3.frlg_font"),
      Kit = require("src.ui.game3.rse.scene_kit"),
      ListMenu = require("src.ui.game3.list_menu"),
      RomText = require("src.core.game3.rom_text"),
      Types = require("src.core.game3.battle.types"),
      Window = require("src.ui.game3.window"),
    }
    local Chart, Layout = lib("chart", Engine), lib("layout", Engine)
    local ID = Engine.Types.ID
    local footer = Layout.footer()

    local failures = 0
    local function check(cond, what)
      print((cond and "PASS " or "FAIL ") .. what)
      if not cond then failures = failures + 1 end
    end

    check(footer == "{DPAD_UPDOWN} PICK  {R_BUTTON} EXIT", "footer from the ROM's button hints: " .. footer)

    -- every type combination: each species' pair, and each single type
    -- (Color Change, Conversion and Camouflage leave a battler one type)
    local combos, seen = {}, {}
    local function add(t1, t2)
      local key = t1 .. "/" .. tostring(t2 ~= t1 and t2 or nil)
      if not seen[key] then seen[key] = true; combos[#combos + 1] = { t1, t2 ~= t1 and t2 or nil } end
    end
    for _, t in ipairs(Chart.ATTACKING_TYPES) do add(t) end
    for _, pair in pairs(assert(loadstring(slurp(EM .. "data/generated/gba/pokemon/types.lua")))()) do add(pair[1], pair[2]) end
    local misfits = {}
    for _, types in ipairs(combos) do
      for _, foresight in ipairs({ false, true }) do
        if Layout.misplacedBadges(Chart.matchups(types, foresight), footer) > 0 then
          misfits[#misfits + 1] = Engine.Types.name(types[1]) .. "/" .. (types[2] and Engine.Types.name(types[2]) or "-")
        end
      end
    end
    check(#misfits == 0, #combos .. " type combinations fit the window " .. table.concat(misfits, " "))

    -- known matchups, read back as the badges' type names
    local function says(types, foresight)
      local parts = {}
      for _, g in ipairs(Chart.matchups(types, foresight)) do
        local names = {}
        for _, t in ipairs(g.types) do names[#names + 1] = Engine.Types.name(t) end
        parts[#parts + 1] = g.label .. " " .. table.concat(names, ",")
      end
      return table.concat(parts, " | ")
    end
    check(says({ ID.ROCK, ID.GROUND }) == "4× WATER,GRASS | 2× FIGHT,GROUND,STEEL,ICE | 1/2× NORMAL,FLYING,ROCK,FIRE | 1/4× POISON | 0× ELECTR",
      "ROCK/GROUND: " .. says({ ID.ROCK, ID.GROUND }))
    check(says({ ID.GHOST }) == "2× GHOST,DARK | 1/2× POISON,BUG | 0× NORMAL,FIGHT", "GHOST: " .. says({ ID.GHOST }))
    check(says({ ID.GHOST }, true) == "2× GHOST,DARK | 1/2× POISON,BUG", "GHOST after Foresight: " .. says({ ID.GHOST }, true))
    -- the engine's other type chart (Types.effectiveness) lacks this one
    check(says({ ID.ROCK }):find("2× [%u,]*GRASS") ~= nil, "GRASS is 2× on ROCK")

    local samples = {
      { "Foe AGGRON", 42, ID.STEEL, ID.ROCK },
      { "Wild MAGNETON", 34, ID.ELECTRIC, ID.STEEL },
      { "SKARMORY", 32, ID.STEEL, ID.FLYING },
      { "TORCHIC", 13, ID.FIRE },
    }
    local sheet = love.graphics.newCanvas(2 * 240 + 8, 2 * 160 + 8)
    local screen = love.graphics.newCanvas(240, 160)
    for i, s in ipairs(samples) do
      love.graphics.setCanvas(screen)
      love.graphics.clear(0.35, 0.45, 0.4, 1)
      local types = { s[3], s[4] }
      Layout.draw({ name = s[1], level = s[2], types = types, groups = Chart.matchups(types) }, i, #samples, 0, footer)
      love.graphics.setCanvas(sheet)
      love.graphics.setColor(1, 1, 1, 1)
      love.graphics.draw(screen, ((i - 1) % 2) * 248, math.floor((i - 1) / 2) * 168)
    end
    love.graphics.setCanvas()
    local small = sheet:newImageData()
    local w, h = small:getDimensions()
    local big = love.image.newImageData(w * 3, h * 3)
    big:mapPixel(function(x, y) return small:getPixel(math.floor(x / 3), math.floor(y / 3)) end)
    local file = io.open(OUT .. "render.png", "wb"); file:write(big:encode("png"):getString()); file:close()
    print("render.png: " .. #samples .. " pages")

    -- the entry on the real engine modules: both wraps in place, once
    local entry = assert(loadstring(slurp(MOD .. "main.lua"), "main.lua"))()
    local fakeMod = { path = "mods/weakness_chart", read = function(_, rel) return slurp(MOD .. rel) end,
      events = { on = function() end } }
    entry(fakeMod)
    local Battle, Ui = require("src.core.game3.battle"), require("src.core.game3.battle.ui")
    local originals = "__weakness_chart_originals"
    local drawWrapped = rawget(Battle, originals) and Battle.draw ~= Battle[originals].draw
    local inputWrapped = rawget(Ui, originals) and Ui.handleInput ~= Ui[originals].handleInput
    entry(fakeMod)
    check(drawWrapped and inputWrapped, "Battle.draw and Ui.handleInput wrapped on the real engine")
    print(failures == 0 and "ALL PASS" or (failures .. " FAILED"))
  end)
  if not ok then print("FAIL " .. tostring(err)) end
  love.event.quit()
end
