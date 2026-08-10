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
local Enemies = require("src.data.enemies")
local Combat = require("src.rules.combat")
local Deck = require("src.rules.deck")
local Encounter = require("src.rules.encounter")
local Rng = require("src.util.rng")

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
    hp = def.max_hp, energy = 0, defense = 0, esquive = 0, camoufle = 0,
    incapacite = 0, vulnerabilite = 0, puissance = 0, saignements = 0, has_acted = false,
  }
end

local function carried_hero(h)
  -- Entre deux combats d'un même run, seuls les PV persistent (blessures non
  -- soignées) ; tout le reste repart à zéro.
  local n = shallow_copy(h)
  n.energy = 0; n.defense = 0; n.esquive = 0; n.camoufle = 0
  n.incapacite = 0; n.vulnerabilite = 0; n.puissance = 0; n.saignements = 0; n.has_acted = false
  return n
end

--- Crée un état de partie vide (avant le premier resetGame/reset_run).
function Game.new_state()
  return {
    heroes = {}, enemies = {}, deck = {}, hand = {}, discard = {},
    pending = nil, turn = 1, over = false,
    run = { combat_index = 1 }, draft_picks = nil,
    combat_snapshot = nil, turn_snapshot = nil, uid_counter = 0, log = {},
    rng = nil, -- créés par Game.reset_run (voir Game.new_rng_streams)
  }
end

-- Un flux indépendant par système à seed reproductible (2026-08-10, demande
-- explicite -- pour un run donné, mêmes tirages même après un redémarrage de combat
-- ou de tour) : "encounter" (composition + PV/bouclier des ennemis tirés à chaque
-- combat), "deck" (ordre de mélange du deck), "enemy_turn" (cible + coup choisi par
-- chaque ennemi, et la variance de ses montants, à chaque tour), "draft" (les 3
-- cartes proposées en fin de combat), "feu_de_camp" (égalité entre aventuriers
-- également blessés + tirage des 2 cartes à améliorer, voir src/rules/feu_de_camp.lua).
-- Seeds dérivées d'une seed maîtresse par de simples décalages -- pas un besoin
-- d'indépendance statistique forte, juste que rejouer un flux ne consomme jamais
-- les tirages d'un AUTRE flux.
function Game.new_rng_streams(master_seed)
  master_seed = master_seed or os.time()
  return {
    master_seed = master_seed,
    encounter = Rng.new(master_seed),
    deck = Rng.new(master_seed + 1),
    enemy_turn = Rng.new(master_seed + 2),
    draft = Rng.new(master_seed + 3),
    feu_de_camp = Rng.new(master_seed + 4),
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
    combat_index = state.run.combat_index,
    -- État du flux "enemy_turn" à cet instant précis (2026-08-10, demande explicite
    -- -- tirages reproductibles même après un redémarrage de combat) : ce snapshot
    -- est toujours pris juste avant le premier Game.start_turn du combat (voir
    -- reset_run/start_next_combat), donc juste avant le premier
    -- Encounter.roll_telegraphs -- le restaurer avant de relancer start_turn fait
    -- retomber les mêmes cibles/coups ennemis au tour 1, pas un nouveau tirage.
    enemy_turn_rng_state = state.rng.enemy_turn.state,
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
  local deck = {}
  for i, c in ipairs(snap.deck) do deck[i] = c end
  state.deck = deck
  state.run.combat_index = snap.combat_index
  state.rng.enemy_turn.state = snap.enemy_turn_rng_state
  state.hand = {}; state.discard = {}; state.pending = nil
  state.turn = 1; state.over = false
  state.log = {}
  Combat.log(state, "Combat " .. state.run.combat_index .. " relancé depuis le début.", "sys")
  Game.start_turn(state)
end

--- Photo de l'état juste avant la pioche du tour (2026-08-10, demande explicite --
-- bouton "Recommencer ce tour"), prise dans Game.start_turn APRÈS l'énergie/les
-- statuts qui décroissent et le tirage des télégraphes ennemis (déjà fixés à cet
-- instant, donc reproductibles à l'identique) mais AVANT Deck.fill_hand -- restaurer
-- puis repiocher redonne exactement la même main, puisque le deck n'est qu'une liste
-- dépilée dans l'ordre (jamais rebattue tant qu'elle n'est pas vide, voir
-- Deck.fill_hand) : aucun hasard supplémentaire à rejouer. Même principe que
-- Game.snapshot_combat ci-dessus, à l'échelle du tour plutôt que du combat.
function Game.snapshot_turn(state)
  local heroes, enemies = {}, {}
  for i, h in ipairs(state.heroes) do heroes[i] = shallow_copy(h) end
  for i, e in ipairs(state.enemies) do enemies[i] = shallow_copy(e) end
  local deck, hand, discard = {}, {}, {}
  for i, c in ipairs(state.deck) do deck[i] = c end
  for i, c in ipairs(state.hand) do hand[i] = c end
  for i, c in ipairs(state.discard) do discard[i] = c end
  state.turn_snapshot = {
    heroes = heroes, enemies = enemies, deck = deck, hand = hand, discard = discard,
    turn = state.turn,
  }
end

--- Recommence le tour en cours depuis la dernière photo (voir Game.snapshot_turn) --
-- pas tout le combat. Ne rejoue PAS Game.start_turn au complet (ça redonnerait +1
-- énergie et re-tirerait de nouveaux télégraphes au hasard) : seule la pioche est
-- refaite, depuis le deck restauré.
function Game.restore_turn_snapshot(state)
  local snap = state.turn_snapshot
  if not snap then Game.restore_combat_snapshot(state); return end
  local heroes, enemies = {}, {}
  for i, h in ipairs(snap.heroes) do heroes[i] = shallow_copy(h) end
  for i, e in ipairs(snap.enemies) do enemies[i] = shallow_copy(e) end
  state.heroes = heroes
  state.enemies = enemies
  local deck, hand, discard = {}, {}, {}
  for i, c in ipairs(snap.deck) do deck[i] = c end
  for i, c in ipairs(snap.hand) do hand[i] = c end
  for i, c in ipairs(snap.discard) do discard[i] = c end
  state.deck = deck; state.hand = hand; state.discard = discard
  state.turn = snap.turn
  state.pending = nil; state.over = false
  state.log = {}
  Combat.log(state, "Tour " .. state.turn .. " relancé depuis le début.", "sys")
  Deck.fill_hand(state)
end

--- Nouvelle run complète (équivalent resetGame). `seed` (optionnel, 2026-08-10,
-- demande explicite) : fixe la seed maîtresse des 4 flux aléatoires de la run
-- (voir Game.new_rng_streams) -- même run rejouée à l'identique si redonnée ;
-- par défaut une seed dérivée de l'horloge, comme avant.
function Game.reset_run(state, seed)
  local heroes = {}
  for i, def in ipairs(Heroes.defs) do heroes[i] = fresh_hero(def) end
  state.heroes = heroes
  state.run = { combat_index = 1 }
  state.rng = Game.new_rng_streams(seed)
  local budget = Encounter.budget_for_combat(1)
  local instances = Encounter.generate_encounter(budget, state.rng.encounter)
  local enemies = {}
  for i, inst in ipairs(instances) do
    enemies[i] = Encounter.instantiate_enemy(inst.template, inst.level, function() return Game.next_uid(state) end, state.rng.encounter)
  end
  state.enemies = enemies
  state.deck = Deck.build_starting_deck(function() return Game.next_uid(state) end, state.rng.deck)
  state.hand = {}; state.discard = {}; state.pending = nil
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
  local instances = Encounter.generate_encounter(budget, state.rng.encounter)
  local enemies = {}
  for i, inst in ipairs(instances) do
    enemies[i] = Encounter.instantiate_enemy(inst.template, inst.level, function() return Game.next_uid(state) end, state.rng.encounter)
  end
  state.enemies = enemies
  local reclaimed = {}
  for _, c in ipairs(state.deck) do reclaimed[#reclaimed + 1] = c end
  for _, c in ipairs(state.hand) do reclaimed[#reclaimed + 1] = c end
  for _, c in ipairs(state.discard) do reclaimed[#reclaimed + 1] = c end
  state.deck = Deck.shuffle(reclaimed, state.rng.deck)
  state.hand = {}; state.discard = {}; state.pending = nil
  state.turn = 1
  state.log = {}
  Combat.log(state, "Combat " .. state.run.combat_index .. " (budget " .. budget .. ") : " .. Encounter.summary(state.enemies), "sys")
  Game.snapshot_combat(state)
  Game.start_turn(state)
end

-- ---------- début de tour ----------

--- Équivalent startTurn : +1 énergie, statuts qui décroissent, télégraphie
-- ennemie, pioche à HAND_SIZE.
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

  Encounter.roll_telegraphs(state)
  Game.snapshot_turn(state)
  local drawn = Deck.fill_hand(state)

  return drawn
end

-- ---------- jouer une carte ----------

--- `Game.assign_hero` verrouille le héros (`has_acted = true`) dès l'assignation,
-- avant même la résolution de cible (enemy/ally en attente d'un clic) -- une
-- carte abandonnée à ce stade (le joueur change d'avis, reclique la carte ou
-- annule) ne l'a donc jamais réellement joué et doit rendre le verrou.
local function revert_pending_hero_lock(state)
  local pending = state.pending
  if pending and pending.hero_id then
    local hero = Combat.hero_by_id(state, pending.hero_id)
    if hero then hero.has_acted = false end
  end
end

--- Sélectionne/désélectionne une carte de la main (équivalent onHandCardClicked).
function Game.select_card(state, uid)
  if state.pending and state.pending.uid == uid then
    revert_pending_hero_lock(state)
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
  revert_pending_hero_lock(state)
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
  if def.requires_camouflage and (hero.camoufle or 0) <= 0 then return false end

  pending.hero_id = hero_id
  hero.has_acted = true

  if pending.mode == "concentrate" then
    hero.energy = hero.energy + 1
    Combat.log(state, hero.name .. " se concentre avec " .. def.name .. " (+1 énergie).", "you")
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

-- ---------- fin de tour ----------

--- Retourne true si la main a bien été défaussée (rien à faire si la partie
-- est déjà terminée).
function Game.end_turn_requested(state)
  if state.over then return false end
  state.pending = nil
  if #state.hand > 0 then
    Combat.log(state, #state.hand .. " carte(s) non jouée(s) défaussée(s).", "sys")
  end
  Game.discard_cards(state, Game.shallow_copy(state.hand))
  return true
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

local function resolve_enemy_attack(state, e, amount, brut)
  local target = Combat.hero_by_id(state, e.target_hero_id)
  if not target or target.hp <= 0 then return end
  if (target.esquive or 0) > 0 then
    target.esquive = target.esquive - 1
    Combat.log(state, e.name .. " utilise " .. e.next_move.name .. " sur " .. target.name .. "… esquivé !", "sys")
    return
  end
  -- source_unit = e (pas source_hero, qui reste nil pour garder le texte/la
  -- couleur "foe" du journal) : la propre Incapacité de l'ennemi qui frappe
  -- doit réduire SES dégâts -- jusqu'ici jamais lue nulle part (bug signalé,
  -- 2026-08-09 -- Lâcheté pose bien Incapacité sur un ennemi, mais rien n'en
  -- tenait compte à la résolution).
  Combat.deal_damage(state, nil, target, amount, "physique", nil, { brut = brut, source_unit = e })
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
