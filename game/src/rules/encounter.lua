-- Génération de rencontre par budget de difficulté croissant, et télégraphie
-- ennemie en début de tour. Port fidèle de MAX_ENEMIES_PER_COMBAT/BUDGET_BASE/
-- BUDGET_GROWTH/budgetForCombat/generateEncounter/instantiateEnemy/
-- encounterSummary/pickHeroTarget/rollEnemyTelegraphs.

local Enemies = require("src.data.enemies")
local Combat = require("src.rules.combat")

local Encounter = {}

Encounter.MAX_ENEMIES_PER_COMBAT = 4 -- lisibilité, à confirmer en playtest (surtout tactile)
Encounter.BUDGET_BASE = 20
Encounter.BUDGET_GROWTH = 0.22 -- +22%/combat, exponentiel, valeur placeholder à tester

function Encounter.budget_for_combat(n)
  return Enemies.round(Encounter.BUDGET_BASE * (1 + Encounter.BUDGET_GROWTH) ^ (n - 1))
end

-- 40 tentatives, garde la composition dont le coût total colle le mieux au budget.
function Encounter.generate_encounter(budget)
  local best = nil
  for _ = 1, 40 do
    local count = math.random(1, Encounter.MAX_ENEMIES_PER_COMBAT)
    local picks = {}
    for i = 1, count do
      picks[i] = Enemies.templates[math.random(#Enemies.templates)]
    end
    local per_slot = budget / count
    local instances = {}
    local total = 0
    for i, t in ipairs(picks) do
      local level = math.max(1, Enemies.round(per_slot / t.cost))
      instances[i] = { template = t, level = level }
      total = total + Enemies.cost_at_level(t, level)
    end
    if not best or math.abs(total - budget) < math.abs(best.total - budget) then
      best = { instances = instances, total = total }
    end
  end
  return best.instances
end

function Encounter.instantiate_enemy(template, level, uid_gen)
  local max_hp = Enemies.roll_scaled(template.hp_base, level)
  return {
    id = template.id .. "-" .. uid_gen(), template_id = template.id, name = template.name, icon = template.icon, label = template.label, level = level,
    max_hp = max_hp, hp = max_hp,
    shield_rolled = template.shield_base and Enemies.roll_scaled(template.shield_base, level) or 0,
    defense = 0, saignements = 0, incapacite = 0, vulnerabilite = 0,
    defending = false, defend_cycle = false, took_damage_this_turn = false, took_fire_damage_this_turn = false,
    next_move = nil, target_hero_id = nil,
  }
end

function Encounter.summary(enemies)
  local parts = {}
  for i, e in ipairs(enemies) do parts[i] = e.name .. " (Nv." .. e.level .. ")" end
  return table.concat(parts, ", ")
end

function Encounter.pick_hero_target(state, mode)
  local alive = Combat.living_heroes(state)
  if #alive == 0 then return nil end
  if mode == "lowest-hp" then
    local best = alive[1]
    for _, h in ipairs(alive) do if h.hp < best.hp then best = h end end
    return best
  end
  return alive[math.random(#alive)]
end

function Encounter.roll_telegraphs(state)
  for _, e in ipairs(state.enemies) do
    e.took_damage_this_turn = false
    e.took_fire_damage_this_turn = false
    if e.hp <= 0 then
      e.next_move = nil
      e.target_hero_id = nil
      e.defense = 0
    else
      local template = Enemies.by_id(e.template_id)
      local move = template.choose_move(e, state.enemies)
      e.next_move = move
      e.defense = (e.shield_rolled or 0) + (move.defense_bonus_this_turn or 0)
      if Combat.TARGETABLE_MOVE_KINDS[move.kind] then
        local t = Encounter.pick_hero_target(state, template.target_mode)
        e.target_hero_id = t and t.id or nil
      else
        e.target_hero_id = nil
      end
    end
  end
end

return Encounter
