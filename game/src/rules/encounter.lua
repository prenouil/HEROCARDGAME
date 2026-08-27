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

-- Pool des templates réellement tirables au hasard (2026-08-21, demande
-- explicite) : exclut les `boss_only` (Homme Arbre, Pousse d'Arbre) -- jamais
-- mêlés à une rencontre normale du mode Infini, réservés à
-- Encounter.boss_encounter ci-dessous. Recalculé à chaque appel plutôt que
-- mis en cache : la liste Enemies.templates ne change jamais en cours de
-- partie, le coût est négligeable (une douzaine d'entrées).
local function random_pool()
  local pool = {}
  for _, t in ipairs(Enemies.templates) do
    if not t.boss_only then pool[#pool + 1] = t end
  end
  return pool
end

-- 40 tentatives, garde la composition dont le coût total colle le mieux au budget.
-- `rng` (2026-08-10, demande explicite -- tirages reproductibles) : voir Game.reset_run.
function Encounter.generate_encounter(budget, rng)
  local pool = random_pool()
  local best = nil
  for _ = 1, 40 do
    local count = rng:random(1, Encounter.MAX_ENEMIES_PER_COMBAT)
    local picks = {}
    for i = 1, count do
      picks[i] = pool[rng:random(#pool)]
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

--- Rencontre fixe du boss (2026-08-21, demande explicite) : 1 Homme Arbre +
-- 4 Pousses d'Arbre, jamais tirée par le budget aléatoire (voir "boss_only"
-- sur ces 2 templates dans enemies.lua, filtré hors du pool de
-- Encounter.generate_encounter par random_pool ci-dessus) -- toujours niveau
-- 1, que le combat soit lancé depuis "Tester le boss" ou en fin d'un run
-- borné à 5 combats (voir Game.start_boss_test/Game.start_boss_combat).
function Encounter.boss_encounter(uid_gen, rng)
  local homme_arbre = Enemies.by_id("homme-arbre")
  local pousse = Enemies.by_id("pousse")
  -- Ordre [pousse, pousse, homme-arbre, pousse, pousse] (2026-08-21, demande
  -- explicite) : View.enemy_rects place les ennemis dans l'ordre de cette
  -- liste sur une rangée centrée, donc l'Homme Arbre (position 3/5) tombe
  -- pile au centre avec 2 Pousses de chaque côté, sans logique de layout dédiée.
  local instances = {}
  for _ = 1, 2 do
    instances[#instances + 1] = Encounter.instantiate_enemy(pousse, 1, uid_gen, rng)
  end
  instances[#instances + 1] = Encounter.instantiate_enemy(homme_arbre, 1, uid_gen, rng)
  for _ = 1, 2 do
    instances[#instances + 1] = Encounter.instantiate_enemy(pousse, 1, uid_gen, rng)
  end
  return instances
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

  -- Règle tacite du Nécromancien Novice (2026-08-21, demande explicite --
  -- volontairement absente de tout texte affiché au joueur, voir moves_info
  -- dans enemies.lua qui ne la mentionne pas) : si AUCUN ennemi vivant
  -- n'inflige de dégâts directs ce tour (kind == "dmg", une fois tous les
  -- télégraphes déjà tirés ci-dessus), chaque Nécromancien Novice présent
  -- échange sa Malédiction contre Toucher Nécrotique -- jamais un tour
  -- entièrement inoffensif côté monstres. `e.target_hero_id` reste celui déjà
  -- tiré : Malédiction et Toucher Nécrotique partagent le même target_mode
  -- ("random"), pas besoin de retirer une cible.
  local any_damage = false
  for _, e in ipairs(state.enemies) do
    if e.hp > 0 and e.next_move and e.next_move.kind == "dmg" then
      any_damage = true
      break
    end
  end
  if not any_damage then
    for _, e in ipairs(state.enemies) do
      if e.hp > 0 and e.template_id == "necromancien" and e.next_move and e.next_move.kind ~= "dmg" then
        e.next_move = { kind = "dmg", name = "Toucher Nécrotique", icon = "\u{1F480}", amount = Enemies.roll_scaled(3, e.level, rng) }
      end
    end
  end
end

return Encounter
