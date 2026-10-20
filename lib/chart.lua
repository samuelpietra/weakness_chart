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
  local Chart = {}

  -- The order the groups are listed in; normal damage (1x) is left out.
  Chart.GROUPS = {
    { multiplier = 4, label = "4×" },
    { multiplier = 2, label = "2×" },
    { multiplier = 0.5, label = "1/2×" },
    { multiplier = 0.25, label = "1/4×" },
    { multiplier = 0, label = "0×" },
  }

  local TYPE_IDS_END = 17

  -- Attacking types in the game's own order of type ids, which its Pokédex
  -- search lists them in; the ??? type has no moves.
  local ATTACKING_TYPES = {}
  for id = 0, TYPE_IDS_END do
    if id ~= Engine.Types.ID.MYSTERY then ATTACKING_TYPES[#ATTACKING_TYPES + 1] = id end
  end
  Chart.ATTACKING_TYPES = ATTACKING_TYPES

  -- Ids of the battlers the chart shows, foes first, left before right.
  local PAGE_ORDER = { 1, 3, 0, 2 }

  -- The groups that hold at least one type: { { label, types = { id, ... } }, ... }.
  function Chart.matchups(type1, type2, foresight)
    local groups = {}
    for _, group in ipairs(Chart.GROUPS) do
      local types = {}
      for _, attacking in ipairs(ATTACKING_TYPES) do
        local _, _, multiplier = Engine.Types.typeCalc(attacking, type1, type2, nil, foresight)
        if multiplier == group.multiplier then types[#types + 1] = attacking end
      end
      if #types > 0 then groups[#groups + 1] = { label = group.label, types = types } end
    end
    return groups
  end

  local function defendingTypes(battler)
    local type1, type2 = battler.type1, battler.type2
    if battler.expTransform then
      type1 = battler.expTransform.type1 or type1
      type2 = battler.expTransform.type2 or type2
    end
    if type2 == type1 then type2 = nil end
    return type1, type2
  end

  -- One page per battler standing on the field, in PAGE_ORDER.
  function Chart.pages(st)
    local State = Engine.State
    local pages = {}
    for _, id in ipairs(PAGE_ORDER) do
      local battler = id < (st.battlersCount or 2) and st.battlers[id] or nil
      if battler and not State.isAbsent(st, id) and not State.isFainted(battler) then
        local type1, type2 = defendingTypes(battler)
        pages[#pages + 1] = {
          name = State.prefixedName(st, battler),
          level = battler.mon and battler.mon.level,
          types = { type1, type2 },
          groups = Chart.matchups(type1, type2, battler.expIdentified and true or false),
        }
      end
    end
    return pages
  end

  return Chart
end
