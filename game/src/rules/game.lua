-- Orchestrateur de partie : état, tours, flux de jeu (jouer une carte, fin de
-- tour, résolution ennemie, victoire/défaite, run infini avec draft de carte).
-- Pur — aucune dépendance LÖVE. La UI pilote le rythme (pauses, animations) en
-- appelant ces fonctions ; le rythme lui-même n'est jamais une règle de jeu.
--
-- Port fidèle de la logique portée par le grand IIFE de proto-cartes-completes/
-- index.html (state, startTurn, assignHero, resolvePending, finishCard,
-- endTurnClicked, advanceAfterDiscard, resetGame, startNextCombat, etc.),
-- moins tout ce qui est rendu DOM/animation (déplacé en src/ui).

local Heroes = require("src.data.heroes")
local Glossary = require("src.data.glossary")
local Enemies = require("src.data.enemies")
local Combat = require("src.rules.combat")
local Deck = require("src.rules.deck")
local Encounter = require("src.rules.encounter")

local Game = {}

local function shallow_copy(t)
  local out = {}
  for k, v in pairs(t) do out[k] = v end
  return out
end
Game.shallow_copy = shallow_copy

function Game.next_uid(state)
  state.uid_counter = state.uid_counter + 1
  return state.uid_counter
end

local function fresh_hero(def)
  return {
    id = def.id, class_id = def.class_id, name = def.name, icon = def.icon, label = def.label, max_hp = def.max_hp,
    hp = def.max_hp, energy = 0, defense = 0, esquive = 0, camoufle = false,
    incapacite = 0, vulnerabilite = 0, puissance = 0, saignements = 0, has_acted = false,
  }
end

local function carried_hero(h)
  -- Entre deux combats d'un même run, seuls les PV persistent (blessures non
  -- soignées) ; tout le reste repart à zéro.
  local n = shallow_copy(h)
  n.energy = 0; n.defense = 0; n.esquive = 0; n.camoufle = false
  n.incapacite = 0; n.vulnerabilite = 0; n.puissance = 0; n.saignements = 0; n.has_acted = false
  return n
end

--- Crée un état de partie vide (avant le premier resetGame/reset_run).
function Game.new_state()
  return {
    heroes = {}, enemies = {}, deck = {}, hand = {}, discard = {},
    pending = nil, turn = 1, over = false, mage_keep_pending = false,
    paladin_revive_used = false, run = { combat_index = 1 }, draft_picks = nil,
    combat_snapshot = nil, uid_counter = 0, log = {},
  }
end

-- ---------- cycle de vie du run ----------

function Game.snapshot_combat(state)
  local heroes, enemies = {}, {}
  for i, h in ipairs(state.heroes) do heroes[i] = shallow_copy(h) end
  for i, e in ipairs(state.enemies) do enemies[i] = shallow_copy(e) end
  local deck = {}
  for i, c in ipairs(state.deck) do deck[i] = c end
  state.combat_snapshot = {
    heroes = heroes, enemies = enemies, deck = deck,
    combat_index = state.run.combat_index, paladin_revive_used = state.paladin_revive_used,
  }
end

--- Recommence le combat en cours (mêmes ennemis/mêmes PV déjà tirés, même
-- deck, héros à neuf) — pas toute la run.
function Game.restore_combat_snapshot(state)
  local snap = state.combat_snapshot
  if not snap then Game.reset_run(state); return end
  local heroes, enemies = {}, {}
  for i, h in ipairs(snap.heroes) do heroes[i] = shallow_copy(h) end
  for i, e in ipairs(snap.enemies) do enemies[i] = shallow_copy(e) end
  state.heroes = heroes
  state.enemies = enemies
  state.deck = { table.unpack(snap.deck) }
  state.run.combat_index = snap.combat_index
  state.paladin_revive_used = snap.paladin_revive_used
  state.hand = {}; state.discard = {}; state.pending = nil; state.mage_keep_pending = false
  state.turn = 1; state.over = false
  state.log = {}
  Combat.log(state, "Combat " .. state.run.combat_index .. " relancé depuis le début.", "sys")
  Game.start_turn(state)
end

--- Nouvelle run complète (équivalent resetGame).
function Game.reset_run(state)
  local heroes = {}
  for i, def in ipairs(Heroes.defs) do heroes[i] = fresh_hero(def) end
  state.heroes = heroes
  state.paladin_revive_used = false
  state.run = { combat_index = 1 }
  local budget = Encounter.budget_for_combat(1)
  local instances = Encounter.generate_encounter(budget)
  local enemies = {}
  for i, inst in ipairs(instances) do
    enemies[i] = Encounter.instantiate_enemy(inst.template, inst.level, function() return Game.next_uid(state) end)
  end
  state.enemies = enemies
  state.deck = Deck.build_starting_deck(function() return Game.next_uid(state) end)
  state.hand = {}; state.discard = {}; state.pending = nil; state.mage_keep_pending = false
  state.turn = 1; state.over = false
  state.log = {}
  Combat.log(state, "Run Infini — Combat 1 (budget " .. budget .. ") : " .. Encounter.summary(state.enemies), "sys")
  Game.snapshot_combat(state)
  Game.start_turn(state)
end

--- Combat suivant dans la même run, après un draft de carte (équivalent startNextCombat).
function Game.start_next_combat(state)
  state.run.combat_index = state.run.combat_index + 1
  local budget = Encounter.budget_for_combat(state.run.combat_index)
  local heroes = {}
  for i, h in ipairs(state.heroes) do heroes[i] = carried_hero(h) end
  state.heroes = heroes
  state.paladin_revive_used = false
  local instances = Encounter.generate_encounter(budget)
  local enemies = {}
  for i, inst in ipairs(instances) do
    enemies[i] = Encounter.instantiate_enemy(inst.template, inst.level, function() return Game.next_uid(state) end)
  end
  state.enemies = enemies
  local reclaimed = {}
  for _, c in ipairs(state.deck) do reclaimed[#reclaimed + 1] = c end
  for _, c in ipairs(state.hand) do reclaimed[#reclaimed + 1] = c end
  for _, c in ipairs(state.discard) do reclaimed[#reclaimed + 1] = c end
  state.deck = Deck.shuffle(reclaimed)
  state.hand = {}; state.discard = {}; state.pending = nil; state.mage_keep_pending = false
  state.turn = 1
  state.log = {}
  Combat.log(state, "Combat " .. state.run.combat_index .. " (budget " .. budget .. ") : " .. Encounter.summary(state.enemies), "sys")
  Game.snapshot_combat(state)
  Game.start_turn(state)
end

-- ---------- début de tour ----------

--- Équivalent startTurn : +1 énergie, statuts qui décroissent, télégraphie
-- ennemie, pioche à HAND_SIZE, coups gratuits du Pouvoir de Classe Guerrier.
-- Retourne la liste des uids piochés (pour que la UI puisse les animer).
function Game.start_turn(state)
  if state.over then return {} end
  for _, h in ipairs(state.heroes) do
    if h.hp > 0 then
      h.energy = h.energy + 1
      h.defense = 0
      h.has_acted = false
      if h.puissance > 0 then h.puissance = h.puissance - 1 end
    end
  end
  Combat.log(state, "— Tour " .. state.turn .. " : +1 énergie, pioche à " .. Deck.HAND_SIZE .. " —", "sys")

  local guerrier = Combat.hero_by_id(state, "guerrier")
  Encounter.roll_telegraphs(state)
  local drawn = Deck.fill_hand(state)

  if guerrier and guerrier.hp > 0 then
    local melee_count = 0
    for _, c in ipairs(state.hand) do
      if Glossary.has_keyword(c.def.desc, "epee") then melee_count = melee_count + 1 end
    end
    for _ = 1, melee_count do
      local targets = Combat.living_enemies(state)
      if #targets == 0 then break end
      local t = targets[math.random(#targets)]
      Combat.log(state, "Pouvoir de Classe du Guerrier : coup gratuit sur " .. t.name .. ".", "power")
      Combat.deal_damage(state, guerrier, t, Heroes.GUERRIER_FREE_HIT_DMG, "physique", nil)
    end
  end

  return drawn
end

-- ---------- jouer une carte ----------

--- Sélectionne/désélectionne une carte de la main (équivalent onHandCardClicked,
-- moins la branche "Pouvoir de Classe du Mage" traitée séparément par la UI).
function Game.select_card(state, uid)
  if state.pending and state.pending.uid == uid then
    state.pending = nil
    return
  end
  for _, c in ipairs(state.hand) do
    if c.uid == uid then
      state.pending = { uid = uid, def = c.def, mode = nil, hero_id = nil }
      return
    end
  end
end

function Game.set_pending_mode(state, mode)
  if state.pending then state.pending.mode = mode end
end

function Game.cancel_pending(state)
  state.pending = nil
end

--- Équivalent assignHero — sans les animations. Retourne true si la carte a
-- fini de se résoudre au sein de cet appel (concentration), false si on
-- attend encore un clic de cible (jeu normal avec cible ennemie/alliée).
function Game.assign_hero(state, hero_id)
  local pending = state.pending
  if not pending then return false end
  local hero = Combat.hero_by_id(state, hero_id)
  local def = pending.def
  if not hero or hero.hp <= 0 then return false end
  if hero.has_acted then return false end
  if hero.energy < Combat.required_cost(hero, pending) then return false end
  if def.requires_camouflage and not hero.camoufle then return false end

  pending.hero_id = hero_id
  hero.has_acted = true

  if pending.mode == "concentrate" then
    hero.energy = hero.energy + 1
    Combat.log(state, hero.name .. " se concentre avec " .. def.name .. " (+1 énergie).", "you")
    if hero.class_id == "assassin" then
      hero.camoufle = true
      hero.puissance = (hero.puissance or 0) + 2
      Combat.log(state, hero.name .. " devient Camouflé et gagne Puissance 2 !", "power")
    end
    Game.finish_card(state, pending)
    return true
  end

  -- mode "play"
  if def.target == "self" then Game.resolve_pending(state, "self", hero_id); return true end
  if def.target == "all-enemies" then Game.resolve_pending(state, "all-enemies", nil); return true end
  if def.target == "conditional" and Combat.enemy_targeting(state, hero) then
    Game.resolve_pending(state, "self", hero_id)
    return true
  end
  return false -- en attente d'un clic de cible
end

--- Équivalent resolvePending.
function Game.resolve_pending(state, kind, target_id)
  local pending = state.pending
  if not pending or not pending.hero_id then return end
  local hero = Combat.hero_by_id(state, pending.hero_id)
  local def = pending.def
  local cost = Combat.effective_cost(hero, def)
  if not hero or hero.energy < cost then state.pending = nil; return end

  local target = nil
  if def.target == "enemy" or (def.target == "conditional" and kind == "enemy") then
    if kind ~= "enemy" then return end
    target = Combat.enemy_by_id(state, target_id)
    if not target or target.hp <= 0 then return end
  elseif def.target == "ally" then
    if kind ~= "ally" then return end
    target = Combat.hero_by_id(state, target_id)
    if not target or target.hp <= 0 then return end
  elseif def.target == "self" or (def.target == "conditional" and kind == "self") then
    target = hero
  end
  -- def.target == "all-enemies" : target reste nil, l'effet itère living_enemies() lui-même.

  hero.energy = hero.energy - cost
  local ctx = { state = state, hero = hero, target = target, card_def = def }
  def.effect(ctx)
  Game.check_victory(state)
  Game.finish_card(state, pending, ctx)
end

--- Équivalent finishCard : retire la carte de la main vers défausse/main/dessus
-- du deck selon ce que l'effet a demandé (ctx.return_to_hand / return_to_deck_top).
function Game.finish_card(state, pending, ctx)
  local idx
  for i, c in ipairs(state.hand) do
    if c.uid == pending.uid then idx = i break end
  end
  if idx then
    local card = table.remove(state.hand, idx)
    if ctx and ctx.return_to_hand then
      state.hand[#state.hand + 1] = card
    elseif ctx and ctx.return_to_deck_top then
      state.deck[#state.deck + 1] = card -- fin du tableau = dessus du deck (prochaine carte piochée)
    else
      state.discard[#state.discard + 1] = card
    end
  end
  state.pending = nil
end

-- ---------- fin de tour / pouvoir de classe du Mage ----------

function Game.end_turn_requested(state)
  -- Retourne "mage-keep" si la UI doit demander au joueur quelle carte garder,
  -- sinon défausse tout de suite et renvoie "discarded".
  if state.over or state.mage_keep_pending then return nil end
  state.pending = nil
  local mage = Combat.hero_by_id(state, "mage")
  if mage and mage.hp > 0 and #state.hand > 0 then
    state.mage_keep_pending = true
    return "mage-keep"
  end
  if #state.hand > 0 then
    Combat.log(state, #state.hand .. " carte(s) non jouée(s) défaussée(s).", "sys")
  end
  Game.discard_cards(state, Game.shallow_copy(state.hand))
  return "discarded"
end

function Game.resolve_mage_keep(state, uid)
  local rest = {}
  for _, c in ipairs(state.hand) do
    if c.uid ~= uid then rest[#rest + 1] = c end
  end
  state.mage_keep_pending = false
  if #rest > 0 then Combat.log(state, #rest .. " carte(s) défaussée(s) (le Mage en garde 1).", "sys") end
  Game.discard_cards(state, rest)
end

-- Le Pouvoir de Classe du Mage est une option, pas une obligation.
function Game.resolve_mage_keep_none(state)
  state.mage_keep_pending = false
  if #state.hand > 0 then Combat.log(state, #state.hand .. " carte(s) défaussée(s) (le Mage ne garde rien).", "sys") end
  Game.discard_cards(state, Game.shallow_copy(state.hand))
end

--- Déplace les cartes données de la main vers la défausse (pure — la UI gère
-- l'animation de vol séparément si elle le souhaite).
function Game.discard_cards(state, cards_to_discard)
  local discard_uids = {}
  for _, c in ipairs(cards_to_discard) do discard_uids[c.uid] = true end
  local kept = {}
  for _, c in ipairs(state.hand) do
    if not discard_uids[c.uid] then kept[#kept + 1] = c end
  end
  for _, c in ipairs(cards_to_discard) do state.discard[#state.discard + 1] = c end
  state.hand = kept
end

-- ---------- résolution de fin de tour (saignements, ennemis, décroissance) ----------

function Game.tick_bleed(state)
  for _, e in ipairs(state.enemies) do
    if e.hp > 0 and (e.saignements or 0) > 0 then
      local dmg = e.saignements
      e.hp = e.hp - dmg
      Combat.log(state, e.name .. " saigne : " .. dmg .. " dégâts.", "sys")
      e.saignements = e.saignements - 1
    end
  end
  for _, h in ipairs(state.heroes) do
    if h.hp > 0 and (h.saignements or 0) > 0 then
      local dmg = h.saignements
      h.hp = h.hp - dmg
      Combat.log(state, h.name .. " saigne : " .. dmg .. " dégâts.", "foe")
      h.saignements = h.saignements - 1
    end
  end
end

local function try_paladin_revive(state, hero)
  if state.paladin_revive_used then return end
  local paladin = Combat.hero_by_id(state, "paladin")
  if not paladin or paladin.hp <= 0 then return end
  hero.hp = 1
  state.paladin_revive_used = true
  Combat.log(state, "Pouvoir de Classe du Paladin : " .. hero.name .. " se relève avec 1 PV !", "power")
end

local function resolve_enemy_attack(state, e, amount, brut)
  local target = Combat.hero_by_id(state, e.target_hero_id)
  if not target or target.hp <= 0 then return end
  if (target.esquive or 0) > 0 then
    target.esquive = target.esquive - 1
    Combat.log(state, e.name .. " utilise " .. e.next_move.name .. " sur " .. target.name .. "… esquivé !", "sys")
    return
  end
  Combat.deal_damage(state, nil, target, amount, "physique", nil, { brut = brut })
  if target.hp <= 0 then try_paladin_revive(state, target) end
end

--- Résout l'action télégraphiée d'un seul ennemi (équivalent d'une itération
-- de la boucle dans advanceAfterDiscard). Ne fait rien si l'ennemi est mort
-- ou n'a pas d'action prévue. Fonction pure/déterministe une fois next_move
-- déjà tiré — c'est le point d'accroche pour paceer la résolution dans la UI.
function Game.resolve_enemy_action(state, e)
  if e.hp <= 0 or not e.next_move then return end
  local move = e.next_move

  if e.template_id == "troll" and move.kind == "heal-self" and e.took_fire_damage_this_turn then
    Combat.log(state, e.name .. " tente de se régénérer, mais les flammes empêchent la guérison !", "sys")
  elseif e.template_id == "golem" then
    if e.took_damage_this_turn then
      resolve_enemy_attack(state, e, move.amount, false)
    else
      Combat.log(state, e.name .. " reste immobile, intact.", "sys")
    end
  elseif move.kind == "heal-self" then
    e.hp = math.min(e.max_hp, e.hp + move.amount)
    Combat.log(state, e.name .. " se régénère de " .. move.amount .. " PV.", "heal")
  elseif move.kind == "heal-ally" then
    local ally = Combat.enemy_by_id(state, move.heal_target_id)
    if ally and ally.hp > 0 then
      ally.hp = math.min(ally.max_hp, ally.hp + move.amount)
      Combat.log(state, e.name .. " soigne " .. ally.name .. " de " .. move.amount .. " PV.", "heal")
    end
  elseif move.kind == "debuff" then
    local target = Combat.hero_by_id(state, e.target_hero_id)
    if target and target.hp > 0 then
      target[move.status_key] = (target[move.status_key] or 0) + move.amount
      local label = Enemies.status_labels[move.status_key] or move.status_key
      Combat.log(state, e.name .. " inflige " .. label .. " " .. move.amount .. " à " .. target.name .. ".", "foe")
    end
  elseif move.kind == "dmg" then
    resolve_enemy_attack(state, e, move.amount, move.brut)
    if move.bleed then
      local target = Combat.hero_by_id(state, e.target_hero_id)
      if target and target.hp > 0 then target.saignements = (target.saignements or 0) + move.bleed end
    end
  end
end

--- Décroissance de fin de tour (après résolution ennemie) : Incapacité côté
-- héros, Incapacité + Vulnérabilité côté ennemis.
function Game.decay_end_of_turn_statuses(state)
  for _, h in ipairs(state.heroes) do
    if (h.incapacite or 0) > 0 then h.incapacite = math.max(0, h.incapacite - 1) end
  end
  for _, e in ipairs(state.enemies) do
    if (e.incapacite or 0) > 0 then e.incapacite = math.max(0, e.incapacite - 1) end
    if (e.vulnerabilite or 0) > 0 then e.vulnerabilite = math.max(0, e.vulnerabilite - 1) end
  end
end

-- ---------- victoire / défaite ----------

--- Retourne true si la victoire vient d'être déclenchée par cet appel.
function Game.check_victory(state)
  if not state.over and #Combat.living_enemies(state) == 0 then
    state.over = true
    return true
  end
  return false
end

--- Retourne true si la défaite vient d'être déclenchée par cet appel.
function Game.check_defeat(state)
  if not state.over and #Combat.living_heroes(state) == 0 then
    state.over = true
    return true
  end
  return false
end

function Game.combats_won(state)
  return math.max(0, state.run.combat_index - 1)
end

return Game
