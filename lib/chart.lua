-- What the chart says about each battler on the field: its name and level,
-- its types, and every attacking type that does not deal it normal damage,
-- grouped by how much damage it does deal.
--
-- The multipliers are the engine's own damage calculation
-- (src/core/game3/battle/types.lua Types.typeCalc), with the defender's types
-- taken as the damage code takes them (src/core/game3/battle/damage.lua):
-- a Transformed battler's copied types, and Foresight letting Normal and
-- Fighting hit a Ghost.

return function(Engine)
  local Types, State = Engine.Types, Engine.State
  local Chart = {}

  -- The order the groups are listed in; normal damage (1x) is left out.
  local GROUPS = {
    { multiplier = 4, label = "4×" },
    { multiplier = 2, label = "2×" },
    { multiplier = 0.5, label = "1/2×" },
    { multiplier = 0.25, label = "1/4×" },
    { multiplier = 0, label = "0×" },
  }

  -- Attacking types in the order of the game's type ids, which its Pokédex
  -- search lists them in; the ??? type has no moves.
  local ATTACKING_TYPES = {}
  for _, id in pairs(Types.ID) do
    if id ~= Types.ID.MYSTERY then ATTACKING_TYPES[#ATTACKING_TYPES + 1] = id end
  end
  table.sort(ATTACKING_TYPES)
  Chart.ATTACKING_TYPES = ATTACKING_TYPES

  -- Battler ids in page order: foes first, left before right.
  local PAGE_ORDER = { 1, 3, 0, 2 }

  -- The groups holding at least one type: { { label, types = { id, ... } }, ... }.
  function Chart.matchups(defendingTypes, foresight)
    local groups = {}
    for _, group in ipairs(GROUPS) do
      local types = {}
      for _, attacking in ipairs(ATTACKING_TYPES) do
        local _, _, multiplier = Types.typeCalc(attacking, defendingTypes[1], defendingTypes[2], nil, foresight)
        if multiplier == group.multiplier then types[#types + 1] = attacking end
      end
      if #types > 0 then groups[#groups + 1] = { label = group.label, types = types } end
    end
    return groups
  end

  -- One type or two, never the same one twice.
  local function defendingTypes(battler)
    local copied = battler.expTransform or {}
    local type1, type2 = copied.type1 or battler.type1, copied.type2 or battler.type2
    if type2 == nil or type2 == type1 then return { type1 } end
    return { type1, type2 }
  end

  -- One page per battler standing on the field, in PAGE_ORDER.
  function Chart.pages(st)
    local pages = {}
    for _, id in ipairs(PAGE_ORDER) do
      local battler = id < st.battlersCount and st.battlers[id] or nil
      if battler and not State.isAbsent(st, id) and not State.isFainted(battler) then
        local types = defendingTypes(battler)
        pages[#pages + 1] = {
          name = State.prefixedName(st, battler),
          level = battler.mon.level,
          types = types,
          groups = Chart.matchups(types, battler.expIdentified),
        }
      end
    end
    return pages
  end

  return Chart
end
