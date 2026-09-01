-- Génération de rencontre par budget de difficulté croissant, et télégraphie
-- ennemie en début de tour. Port fidèle de MAX_ENEMIES_PER_COMBAT/BUDGET_BASE/
-- BUDGET_GROWTH/budgetForCombat/generateEncounter/instantiateEnemy/
-- encounterSummary/pickHeroTarget/rollEnemyTelegraphs.

local Enemies = require("src.data.enemies")
local Combat = require("src.rules.combat")

local Encounter = {}

Encounter.MAX_ENEMIES_PER_COMBAT = 4 -- lisibilité, à confirmer en playtest (surtout tactile)
Encounter.BUDGET_BASE = 20 -- inchangé (2026-08-28, demande explicite -- "ne pas changer le départ")
-- Ralentie de 0.22 à 0.12 (2026-08-28, demande explicite -- "la montée moins
-- forte, moins exponentielle") : reste une croissance exponentielle (même
-- formule), mais un taux nettement plus faible aplatit beaucoup la courbe sur
-- la durée d'un run -- ex. budget du combat 10 : ~120 avant, ~55 maintenant,
-- pour un même budget de départ (combat 1 = 20 dans les deux cas). Toujours
-- un placeholder à ajuster en playtest.
Encounter.BUDGET_GROWTH = 0.12

function Encounter.budget_for_combat(n)
  return Enemies.round(Encounter.BUDGET_BASE * (1 + Encounter.BUDGET_GROWTH) ^ (n - 1))
end

-- Pool des templates réellement tirables au hasard (2026-08-21, demande
-- explicite) : exclut les `boss_only` (Homme Arbre, Pousse d'Arbre) -- jamais
-- mêlés à une rencontre normale du mode Infini, réservés à
-- Encounter.boss_encounter ci-dessous. Recalculé à chaque appel plutôt que
-- mis en cache : la liste Enemies.templates ne change jamais en cours de
-- partie, le coût est négligeable (une vingtaine d'entrées).
-- `biome` (optionnel, 2026-09-01, demande explicite -- 4 biomes, un combat
-- confiné à un seul) : si fourni, filtre en plus sur `t.biome == biome` --
-- nil garde l'ancien comportement (pool complet), utilisé par le mode
-- "Infini" (qui ne reçoit PAS la mécanique de biomes, bientôt retiré du jeu)
-- et par "Tester le boss" (qui ne passe même pas par ce pool).
local function random_pool(biome)
  local pool = {}
  for _, t in ipairs(Enemies.templates) do
    if not t.boss_only and (not biome or t.biome == biome) then pool[#pool + 1] = t end
  end
  return pool
end

-- 40 tentatives, garde la composition dont le coût total colle le mieux au budget.
-- `rng` (2026-08-10, demande explicite -- tirages reproductibles) : voir Game.reset_run.
function Encounter.generate_encounter(budget, rng, biome)
  local pool = random_pool(biome)
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
    -- Brûlure (2026-09-01, nouveau statut, Volcan) : même convention que les
    -- champs de statut ci-dessus, jamais décrémentée automatiquement (voir
    -- Game.tick_burn) contrairement à saignements.
    brulure = 0,
    -- "Vol" (2026-08-30, second boss -- l'Aigle Géant, voir enemies.lua) :
    -- 0/absent pour tout le monde par défaut, comme les autres champs de
    -- statut ci-dessus -- seul l'Aigle le fait réellement varier (voir
    -- Game.resolve_enemy_action, kind == "buff-self"/"dmg" avec `move.lands`).
    vol = 0,
    -- Élite (2026-09-01) : false par défaut, voir Encounter.promote_to_elite
    -- ci-dessous -- jamais posé ici directement (l'appelant décide APRÈS
    -- l'instanciation normale, une fois l'ennemi déjà tiré).
    elite = false,
    -- fire_touched_ever (2026-09-01, Troll des Marais) : jamais réinitialisé,
    -- contrairement à took_fire_damage_this_turn -- voir Combat.deal_damage.
    fire_touched_ever = false,
    defending = false, defend_cycle = false, took_damage_this_turn = false, took_fire_damage_this_turn = false,
    next_move = nil, target_hero_id = nil,
  }
end

-- Élite (2026-09-01, demande explicite -- "chaque ennemi peut être décliné
-- sous forme d'élite... l'élite ne coûte pas plus cher") : mutation posée sur
-- une instance DÉJÀ créée par Encounter.instantiate_enemy ci-dessus -- jamais
-- en touchant `level`/`cost`, qui resteraient lus par Enemies.cost_at_level
-- (le budget de rencontre, déjà calculé bien avant cet appel) et rendraient
-- l'Élite payante malgré la règle explicite. ×1.6 sur PV/bouclier ; les
-- montants portés par les COUPS (dégâts/soin/statuts) sont, eux, boostés
-- séparément à chaque tirage -- voir apply_elite dans Encounter.roll_telegraphs
-- plus bas, pas ici (un coup n'existe pas encore à l'instanciation).
function Encounter.promote_to_elite(e)
  e.elite = true
  e.max_hp = Enemies.round(e.max_hp * 1.6)
  e.hp = e.max_hp
  e.shield_rolled = Enemies.round((e.shield_rolled or 0) * 1.6)
end

--- Rencontre fixe du boss (2026-08-21, demande explicite -- ÉTENDUE le
-- 2026-08-30, "il faudrait un deuxième boss : un aigle géant") : tire au sort
-- ENTRE les 2 boss disponibles à chaque appel (même `rng` que le reste de la
-- rencontre, state.rng.encounter -- voir Game.start_boss_test/
-- start_boss_combat, donc reproductible à l'identique pour un seed de run
-- donné, comme tout le reste ici) -- jamais mêlée à la génération normale du
-- mode Infini (voir "boss_only" sur ces templates dans enemies.lua, filtré
-- hors du pool de Encounter.generate_encounter par random_pool ci-dessus).
function Encounter.boss_encounter(uid_gen, rng)
  if rng:random() < 0.5 then
    return Encounter.homme_arbre_encounter(uid_gen, rng)
  end
  return Encounter.aigle_encounter(uid_gen, rng)
end

--- 1 Homme Arbre + 4 Pousses d'Arbre, toujours niveau 1 -- voir le
-- commentaire de Encounter.boss_encounter ci-dessus.
function Encounter.homme_arbre_encounter(uid_gen, rng)
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

--- L'Aigle Géant, seul (2026-08-30, demande explicite -- "il faudrait un
-- deuxième boss : un aigle géant") : contrairement à l'Homme Arbre, aucun
-- sbire -- tout son budget de PV/tours est porté par lui seul (voir
-- enemies.lua, hp_base plus haut que celui de l'Homme Arbre pour compenser
-- l'absence de sbires à abattre séparément).
function Encounter.aigle_encounter(uid_gen, rng)
  local aigle = Enemies.by_id("aigle")
  return { Encounter.instantiate_enemy(aigle, 1, uid_gen, rng) }
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
--
-- Provocation (2026-08-28, statut du Paladin, clarifié après coup -- "+50% de
-- chances d'être ciblé par les ennemis") : bonus FIXE de +50% (×1.5) tant que
-- `provocation > 0`, quel que soit le nombre de stacks -- ceux-ci ne pilotent
-- QUE la durée (1 stack perdu par tour, voir Game.start_turn), pas l'ampleur
-- du bonus. Comme Discrétion, ne joue qu'en mode "random", après le filtre
-- Camouflé (un héros Camouflé reste intouchable même en pleine Provocation).
--
-- "Le Martyr" (2026-08-29, malédiction du Temple -- hero.targeting_bonus) :
-- même formule et même bonus (+50%) que Provocation, mais PERMANENT (pas de
-- décroissance -- copié une seule fois depuis Temple.effects à l'entrée en
-- combat, voir Game.apply_combat_start_temple_effects) et cumulable AVEC
-- Provocation si jamais le même héros porte les deux (×1.5 ×1.5, jamais
-- plafonné -- pas de raison de les rendre exclusifs l'un de l'autre).
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
    if (h.provocation or 0) > 0 then w = w * 1.5 end
    if h.targeting_bonus then w = w * (1 + h.targeting_bonus) end
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
-- Élite, 2ᵉ volet (2026-09-01, voir Encounter.promote_to_elite ci-dessus pour
-- le 1ᵉʳ) : ×1.3 sur tout montant PORTÉ PAR UN COUP déjà télégraphié/roulé --
-- amount/bleed/burn/dmg_all_amount (variantes "à qui ce coup fait combien de
-- dégâts/statut"), amount2 (2ᵉ statut, voir Malédiction/Souffle Étouffant) et
-- defense_bonus_this_turn (gain de bouclier ponctuel du Gobelourd). Chaque
-- champ est optionnel sur un move donné -- ne touche que ceux réellement
-- présents. Appelé à CHAQUE endroit où un move final est construit (2 dans ce
-- fichier : le tirage normal ci-dessous, et le repli du Nécromancien plus
-- bas), jamais une seule fois -- un Nécromancien Élite forcé sur son repli
-- doit garder son bonus.
local function apply_elite(move, e)
  if not e.elite then return move end
  if move.amount then move.amount = Enemies.round(move.amount * 1.3) end
  if move.bleed then move.bleed = Enemies.round(move.bleed * 1.3) end
  if move.burn then move.burn = Enemies.round(move.burn * 1.3) end
  if move.dmg_all_amount then move.dmg_all_amount = Enemies.round(move.dmg_all_amount * 1.3) end
  if move.amount2 then move.amount2 = Enemies.round(move.amount2 * 1.3) end
  if move.defense_bonus_this_turn then move.defense_bonus_this_turn = Enemies.round(move.defense_bonus_this_turn * 1.3) end
  return move
end

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
      local move = apply_elite(template.choose_move(e, state.enemies, rng), e)
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
        e.next_move = apply_elite({ kind = "dmg", name = "Toucher Nécrotique", icon = "\u{1F480}", amount = Enemies.roll_scaled(3, e.level, rng) }, e)
      end
    end
  end
end

return Encounter
