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
-- `rng` (2026-08-10, demande explicite -- tirages reproductibles) : voir Game.reset_run.
function Encounter.generate_encounter(budget, rng)
  local best = nil
  for _ = 1, 40 do
    local count = rng:random(1, Encounter.MAX_ENEMIES_PER_COMBAT)
    local picks = {}
    for i = 1, count do
      picks[i] = Enemies.templates[rng:random(#Enemies.templates)]
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

function Encounter.instantiate_enemy(template, level, uid_gen, rng)
  local max_hp = Enemies.roll_scaled(template.hp_base, level, rng)
  return {
    id = template.id .. "-" .. uid_gen(), template_id = template.id, name = template.name, icon = template.icon, label = template.label, level = level,
    max_hp = max_hp, hp = max_hp,
    shield_rolled = template.shield_base and Enemies.roll_scaled(template.shield_base, level, rng) or 0,
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

-- Camouflé (2026-08-24, demande explicite -- jamais câblé jusqu'ici, voir
-- glossary.lua : "ne peut pas être ciblé par un ennemi") : exclu du pool de
-- cibles tant qu'un AUTRE héros vivant ne l'est pas -- s'il ne reste plus que
-- des héros Camouflés (ou un seul héros vivant, Camouflé), on retombe sur le
-- pool complet plutôt que de ne jamais pouvoir désigner de cible ("tant qu'un
-- allié est en vie", voir la même entrée du glossaire). Filet de sécurité
-- seulement : le nettoyage RÉEL du champ (retirer Camouflé à tout le monde dès
-- qu'il ne reste plus d'allié non-Camouflé vivant) vit dans
-- Game.sync_camoufle_visibility, appelé après tout événement qui peut faire
-- mourir un héros ou en rendre un Camouflé -- ce filtre ici ne devrait donc en
-- pratique jamais avoir besoin de retomber sur le pool complet.
--
-- Discrétion (2026-08-24, demande explicite) : en mode "random" (le seul
-- réellement probabiliste -- "lowest-hp" reste un choix déterministe, pas
-- concerné), chaque point de Discrétion du CANDIDAT retire 10% de chance
-- RELATIVE d'être choisi (poids 1 - 0.1*discretion, jamais négatif) -- pas une
-- exclusion binaire comme Camouflé (déjà géré par le filtre `visible`
-- ci-dessus), juste moins probable. Sans effet sur les héros sans Discrétion
-- (poids 1, `discretion` nil traité comme 0).
function Encounter.pick_hero_target(state, mode, rng)
  local alive = Combat.living_heroes(state)
  if #alive == 0 then return nil end
  local visible = {}
  for _, h in ipairs(alive) do
    if (h.camoufle or 0) <= 0 then visible[#visible + 1] = h end
  end
  if #visible > 0 then alive = visible end
  if mode == "lowest-hp" then
    local best = alive[1]
    for _, h in ipairs(alive) do if h.hp < best.hp then best = h end end
    return best
  end

  local weights, total_weight = {}, 0
  for i, h in ipairs(alive) do
    local w = math.max(0, 1 - 0.1 * (h.discretion or 0))
    weights[i] = w
    total_weight = total_weight + w
  end
  if total_weight <= 0 then return alive[rng:random(#alive)] end -- filet : tout le monde à poids nul
  local roll = rng:random() * total_weight
  local cumulative = 0
  for i, w in ipairs(weights) do
    cumulative = cumulative + w
    if roll < cumulative then return alive[i] end
  end
  return alive[#alive] -- filet : arrondi flottant
end

-- `state.rng.enemy_turn` (2026-08-10, demande explicite -- cibles/coups ennemis
-- reproductibles à l'identique pour un run donné) : un seul flux, jamais math.random
-- directement -- voir Game.reset_run. `state` porte déjà `rng`, pas besoin d'un
-- paramètre séparé ici (contrairement à generate_encounter/instantiate_enemy, qui
-- ne reçoivent pas `state`).
function Encounter.roll_telegraphs(state)
  local rng = state.rng.enemy_turn
  for _, e in ipairs(state.enemies) do
    e.took_damage_this_turn = false
    e.took_fire_damage_this_turn = false
    if e.hp <= 0 then
      e.next_move = nil
      e.target_hero_id = nil
      e.defense = 0
    else
      local template = Enemies.by_id(e.template_id)
      local move = template.choose_move(e, state.enemies, rng)
      e.next_move = move
      e.defense = (e.shield_rolled or 0) + (move.defense_bonus_this_turn or 0)
      if Combat.TARGETABLE_MOVE_KINDS[move.kind] then
        local t = Encounter.pick_hero_target(state, template.target_mode, rng)
        e.target_hero_id = t and t.id or nil
      else
        e.target_hero_id = nil
      end
    end
  end
end

return Encounter
