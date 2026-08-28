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
local Temple = require("src.rules.temple")

local Game = {}

--- Vrai si `def` porte la catégorie `cat` (même idiome que la détection "feu"
-- dans Combat.deal_damage -- def.cats reste un simple tableau de tags, jamais
-- un champ booléen dédié par tag).
local function def_has_cat(def, cat)
  if not def or not def.cats then return false end
  for _, c in ipairs(def.cats) do
    if c == cat then return true end
  end
  return false
end

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

-- `mana` (2026-08-20, ressource propre au Mage) : nil pour les 3 autres classes
-- -- jamais 0, pour que `Theme`/l'affichage puissent distinguer "n'a pas cette
-- ressource" de "l'a épuisée". Valeur de départ 2, voir def du Mage dans
-- src/data/heroes.lua ; ne remonte JAMAIS toute seule (pas de régénération de
-- tour ni de combat, contrairement à l'énergie globale) -- seules des cartes
-- peuvent l'augmenter (Combat.apply_status n'y touche pas, c'est un champ
-- dédié, pas un statut de combat classique).
-- `discretion` (2026-08-24, ressource propre à l'Assassin, DISTINCTE de
-- Camouflé -- voir Game.gain_discretion) : nil pour les 3 autres classes,
-- même convention que `mana`. Départ à 0, max 10 -- à 10, l'Assassin devient
-- Camouflé (voir Game.gain_discretion). `played_card_this_turn` (tous les
-- héros) : pur suivi interne pour la Discrétion (Game.tick_discretion_end_of_turn,
-- "+5 si un allié passe son tour sans agir") -- PAS une réintroduction de
-- l'ancien has_acted (retiré 2026-08-20, un héros agit toujours librement
-- plusieurs fois par tour), jamais lu pour gater une action.
local function fresh_hero(def)
  return {
    id = def.id, class_id = def.class_id, name = def.name, icon = def.icon, label = def.label, max_hp = def.max_hp,
    hp = def.max_hp, defense = 0, esquive = 0, camoufle = 0,
    incapacite = 0, vulnerabilite = 0, puissance = 0, saignements = 0,
    played_card_this_turn = false,
    mana = def.class_id == "mage" and 2 or nil,
    discretion = def.class_id == "assassin" and 0 or nil,
    -- Bénédiction du Temple (2026-08-28, demande explicite) : nil tant qu'aucune
    -- n'a été accordée -- voir src/rules/temple.lua (Temple.bless) pour
    -- l'attribution, et son application ci-dessous dans carried_hero.
    blessing = nil,
  }
end

--- `combat_start_heal` (2026-08-28, demande explicite) : montant EFFECTIVEMENT
-- rendu par la bénédiction de soin de cet aventurier à cette entrée en combat
-- précise (peut être < Temple.by_id(...).combat_start_heal si déjà proche du
-- plafond, ou nil si pas de bénédiction/déjà mort/déjà à PV pleins) -- lu et
-- remis à nil par Controller:play_hero_ready_hops (view.lua affiche le flottant
-- vert exact, synchronisé avec le petit saut de CET aventurier). La RÈGLE (le
-- soin lui-même) vit ici, pas dans le contrôleur -- lui ne fait que le retour
-- visuel, jamais recalculé indépendamment.
local function apply_combat_start_blessing(n)
  n.combat_start_heal = nil
  if not n.blessing or n.hp <= 0 then return end
  local blessing = Temple.by_id(n.blessing)
  if not blessing or not blessing.combat_start_heal then return end
  local before = n.hp
  n.hp = math.min(n.max_hp, n.hp + blessing.combat_start_heal)
  local healed = n.hp - before
  if healed > 0 then n.combat_start_heal = healed end
end

local function carried_hero(h)
  -- Entre deux combats d'un même run, seuls les PV persistent (blessures non
  -- soignées) ; tout le reste repart à zéro -- SAUF `blessing` (2026-08-28),
  -- qui dure tout le run une fois accordée par le Temple (voir
  -- src/rules/temple.lua) : `shallow_copy` la propage déjà telle quelle, rien
  -- à faire de spécial ici pour ce champ.
  local n = shallow_copy(h)
  n.defense = 0; n.esquive = 0; n.camoufle = 0
  n.incapacite = 0; n.vulnerabilite = 0; n.puissance = 0; n.saignements = 0
  n.played_card_this_turn = false
  apply_combat_start_blessing(n)
  return n
end

--- Énergie de la réserve GLOBALE remise à ce niveau EXACT à chaque début de
-- tour (2026-08-11, précisé par le porteur de projet -- remplace l'énergie
-- individuelle par héros) : une REMISE À NIVEAU FIXE, pas un plancher --
-- qu'il en reste plus ou moins que 3 à la fin du tour précédent (via une
-- carte comme Préparation/Clairvoyance, voir Game.gain_energy, jamais
-- plafonnée EN COURS DE TOUR), le tour suivant retombe toujours exactement
-- sur cette valeur. Voir Game.start_turn, seul endroit qui l'applique.
Game.TURN_START_ENERGY = 3

--- Ajoute `amount` à la réserve d'énergie globale, sans plafond EN COURS DE
-- TOUR (2026-08-11, confirmé explicitement par le porteur de projet) -- seul
-- point d'entrée pour un gain de carte (Clairvoyance/Préparation dans
-- cards.lua) : ne jamais écrire `state.energy = state.energy + n` ailleurs.
-- Le montant gagné ici ne survit jamais au tour : Game.start_turn remet la
-- réserve à Game.TURN_START_ENERGY au tour suivant, quel que soit ce total.
function Game.gain_energy(state, amount)
  state.energy = state.energy + amount
end

--- Ressource propre à l'Assassin (2026-08-24, DISTINCTE de Camouflé -- voir
-- fresh_hero) : plafonnée à 10 (contrairement à l'énergie/la mana, jamais
-- plafonnées) -- au-delà, l'Assassin devient Camouflé (`hero.camoufle = 1`) --
-- c'est le SEUL chemin vers Camouflé désormais, aucune carte ne l'accorde
-- plus directement. Seul point d'entrée pour un gain de Discrétion (cartes
-- Assassinat/En traître/Préparation dans cards.lua, et le passif "un allié agit/ne
-- joue aucune carte ce tour" -- voir Game.on_card_played/
-- Game.tick_discretion_end_of_turn) : ne jamais écrire `hero.discretion = ...`
-- directement ailleurs.
function Game.gain_discretion(state, hero, amount)
  local was_camoufle = (hero.camoufle or 0) > 0
  hero.discretion = math.min(10, (hero.discretion or 0) + amount)
  if hero.discretion >= 10 then
    hero.camoufle = 1
    if not was_camoufle then Combat.log(state, hero.name .. " atteint 10 Discrétion : Camouflé.", "power") end
    Game.sync_camoufle_visibility(state)
  end
end

--- Camouflé "reste tant qu'un allié [non-Camouflé] est en vie" (2026-08-24,
-- demande explicite -- correction d'un premier jet qui ne le vérifiait qu'au
-- ciblage, voir Encounter.pick_hero_target) : retire Camouflé à TOUS les
-- héros dès qu'il ne reste plus aucun allié non-Camouflé vivant pour
-- "couvrir" les autres. À appeler après tout événement qui peut faire mourir
-- un héros ou en rendre un Camouflé -- voir call sites : Game.gain_discretion,
-- Game.tick_bleed, Game.resolve_enemy_action.
function Game.sync_camoufle_visibility(state)
  for _, h in ipairs(state.heroes) do
    if h.hp > 0 and (h.camoufle or 0) <= 0 then return end -- au moins un allié visible : rien à faire
  end
  for _, h in ipairs(state.heroes) do h.camoufle = 0 end
end

--- Crée un état de partie vide (avant le premier resetGame/reset_run).
function Game.new_state()
  return {
    heroes = {}, enemies = {}, deck = {}, hand = {}, discard = {},
    pending = nil, turn = 1, over = false, energy = 0,
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
-- cartes proposées en fin de combat), "forge" (tirage des cartes proposées à
-- l'amélioration, voir src/rules/forge.lua), "temple" (tirage de la bénédiction
-- proposée, voir src/rules/temple.lua), "post_combat" (2026-08-28 -- décide SI la
-- Forge et/ou le Temple apparaissent après un combat donné, voir
-- src/ui/controller.lua : un flux séparé du reste, pour que ces tirages "coup de
-- dé" n'interfèrent jamais avec ceux, déterministes pour un contenu donné, de
-- Forge/Temple eux-mêmes). Seeds dérivées d'une seed maîtresse par de simples
-- décalages -- pas un besoin d'indépendance statistique forte, juste que rejouer
-- un flux ne consomme jamais les tirages d'un AUTRE flux.
function Game.new_rng_streams(master_seed)
  master_seed = master_seed or os.time()
  return {
    master_seed = master_seed,
    encounter = Rng.new(master_seed),
    deck = Rng.new(master_seed + 1),
    enemy_turn = Rng.new(master_seed + 2),
    draft = Rng.new(master_seed + 3),
    forge = Rng.new(master_seed + 4),
    temple = Rng.new(master_seed + 5),
    post_combat = Rng.new(master_seed + 6),
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
    combat_index = state.run.combat_index, energy = state.energy,
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
  state.energy = snap.energy
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
    turn = state.turn, energy = state.energy,
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
  state.energy = snap.energy
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
  state.run = { combat_index = 1, is_boss = false }
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
  state.turn = 1; state.over = false; state.energy = 0
  state.log = {}
  Combat.log(state, "Run Infini — Combat 1 (budget " .. budget .. ") : " .. Encounter.summary(state.enemies), "sys")
  Game.snapshot_combat(state)
  Game.start_turn(state)
end

--- Combat suivant dans la même run, après un draft de carte (équivalent startNextCombat).
function Game.start_next_combat(state)
  state.run.combat_index = state.run.combat_index + 1
  state.run.is_boss = false
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
  state.turn = 1; state.energy = 0
  state.log = {}
  Combat.log(state, "Combat " .. state.run.combat_index .. " (budget " .. budget .. ") : " .. Encounter.summary(state.enemies), "sys")
  Game.snapshot_combat(state)
  Game.start_turn(state)
end

--- Combat de boss autonome (2026-08-21, demande explicite) : bouton "Tester
-- le boss" au menu -- mêmes fondations qu'un run normal (nouveaux héros
-- pleine vie, nouveau deck, nouveaux flux aléatoires) mais rencontre FIXE
-- (Encounter.boss_encounter) plutôt que tirée par le budget. Ne touche jamais
-- `state.run.combat_index`/le mode de run -- ce n'est pas un run normal, voir
-- Controller:start_boss_test (self.run_mode reste nil).
function Game.start_boss_test(state, seed)
  local heroes = {}
  for i, def in ipairs(Heroes.defs) do heroes[i] = fresh_hero(def) end
  state.heroes = heroes
  state.run = { combat_index = 1, is_boss = true }
  state.rng = Game.new_rng_streams(seed)
  state.enemies = Encounter.boss_encounter(function() return Game.next_uid(state) end, state.rng.encounter)
  state.deck = Deck.build_starting_deck(function() return Game.next_uid(state) end, state.rng.deck)
  state.hand = {}; state.discard = {}; state.pending = nil
  state.turn = 1; state.over = false; state.energy = 0
  state.log = {}
  Combat.log(state, "Test du boss : " .. Encounter.summary(state.enemies), "sys")
  Game.snapshot_combat(state)
  Game.start_turn(state)
end

--- Le boss d'un run borné à 5 combats (2026-08-21, demande explicite) :
-- mêmes fondations que Game.start_next_combat (héros/deck reportés du combat
-- précédent) mais rencontre FIXE (Encounter.boss_encounter) plutôt que tirée
-- par le budget -- `combat_index` incrémenté quand même (6, pour l'affichage
-- "Combat 6"), même si le budget de difficulté n'a pas de sens ici.
function Game.start_boss_combat(state)
  state.run.combat_index = state.run.combat_index + 1
  state.run.is_boss = true
  local heroes = {}
  for i, h in ipairs(state.heroes) do heroes[i] = carried_hero(h) end
  state.heroes = heroes
  state.enemies = Encounter.boss_encounter(function() return Game.next_uid(state) end, state.rng.encounter)
  local reclaimed = {}
  for _, c in ipairs(state.deck) do reclaimed[#reclaimed + 1] = c end
  for _, c in ipairs(state.hand) do reclaimed[#reclaimed + 1] = c end
  for _, c in ipairs(state.discard) do reclaimed[#reclaimed + 1] = c end
  state.deck = Deck.shuffle(reclaimed, state.rng.deck)
  state.hand = {}; state.discard = {}; state.pending = nil
  state.turn = 1; state.energy = 0
  state.log = {}
  Combat.log(state, "Le Boss : " .. Encounter.summary(state.enemies), "sys")
  Game.snapshot_combat(state)
  Game.start_turn(state)
end

-- ---------- début de tour ----------

--- Équivalent startTurn : énergie globale remise à Game.TURN_START_ENERGY
-- PILE (2026-08-11, précisé par le porteur de projet -- ni un plancher ni un
-- plafond, une remise à niveau fixe qu'il en reste plus ou moins avant),
-- statuts qui décroissent, télégraphie ennemie, pioche à HAND_SIZE.
-- Retourne la liste des uids piochés (pour que la UI puisse les animer).
function Game.start_turn(state)
  if state.over then return {} end
  state.energy = Game.TURN_START_ENERGY
  for _, h in ipairs(state.heroes) do
    if h.hp > 0 then
      h.defense = 0
      h.played_card_this_turn = false
      if h.puissance > 0 then h.puissance = h.puissance - 1 end
    end
  end
  Combat.log(state, "— Tour " .. state.turn .. " : énergie à " .. state.energy .. ", pioche à " .. Deck.HAND_SIZE .. " —", "sys")

  Encounter.roll_telegraphs(state)
  Game.snapshot_turn(state)
  local drawn = Deck.fill_hand(state)

  return drawn
end

-- ---------- jouer une carte ----------

--- Sélectionne/désélectionne une carte de la main (équivalent onHandCardClicked).
-- Chaque carte appartient à un héros précis (`def.class_id`, voir Cards.by_code/
-- Heroes.class_name -- 2026-08-20, une classe = un seul héros) : la sélection
-- l'assigne DIRECTEMENT à ce héros via Game.assign_hero, sans jamais laisser
-- le joueur choisir. Ne fait rien si son propriétaire ne peut pas la jouer là
-- maintenant (mort, énergie/mana insuffisants) -- pas de sélection "en attente"
-- pour un héros indisponible. Un héros peut agir plusieurs fois par tour
-- (2026-08-20, demande explicite -- plus de notion de "a déjà agi") : le seul
-- verrou est `state.pending` lui-même (une seule carte en attente à la fois),
-- rien à relâcher côté héros quand la sélection change ou s'annule.
-- Retourne "deselected" | "refused" | "assigned" -- lu par Controller:select_card
-- pour savoir quelle animation déclencher, sans jamais comparer un état héros
-- avant/après (2026-08-20, ancien mécanisme via has_acted, devenu impossible
-- sans ce champ). Plus de "resolved" depuis que même les cartes "sans cible"
-- (soi/tous les ennemis) attendent une confirmation avant de se résoudre
-- (2026-08-27, voir Game.assign_hero) -- une sélection n'aboutit donc plus
-- jamais à une résolution synchrone.
function Game.select_card(state, uid)
  if state.pending then
    if state.pending.uid == uid then
      state.pending = nil
      return "deselected"
    end
    state.pending = nil
  end
  for _, c in ipairs(state.hand) do
    if c.uid == uid then
      local owner = Combat.hero_by_id(state, c.def.class_id)
      if not owner or not Combat.can_play(state, owner, { def = c.def }) then return "refused" end
      state.pending = { uid = uid, def = c.def, hero_id = nil }
      Game.assign_hero(state, owner.id)
      return "assigned"
    end
  end
  return "refused"
end

function Game.cancel_pending(state)
  state.pending = nil
end

--- Équivalent assignHero — sans les animations. Retourne toujours false
-- désormais (2026-08-27) : une carte "sans cible" (soi/tous les ennemis) pose
-- `pending.awaiting_confirm_kind` au lieu de se résoudre immédiatement (voir
-- Controller:confirm_pending), au même titre qu'une carte à cible ennemie/
-- alliée attend un clic -- il n'y a donc plus de résolution synchrone possible
-- au sein de cet appel.
function Game.assign_hero(state, hero_id)
  local pending = state.pending
  if not pending then return false end
  local hero = Combat.hero_by_id(state, hero_id)
  local def = pending.def
  if not hero or hero.hp <= 0 then return false end
  if state.energy < def.cost then return false end
  if def.mana_cost and (hero.mana or 0) < def.mana_cost then return false end
  if def.requires_camouflage and (hero.camoufle or 0) <= 0 then return false end

  pending.hero_id = hero_id

  -- Cartes "sans cible" (soi/tous les ennemis) : n'auto-résolvent plus dès
  -- l'assignation (2026-08-27, demande explicite -- "laisser l'opportunité au
  -- joueur de changer d'avis"). `awaiting_confirm_kind` mémorise le kind déjà
  -- déterminé ici (rien à redemander au joueur) ; Controller:confirm_pending
  -- le résout au clic suivant, exactement comme resolve_target le fait pour
  -- une carte à cible. Retourne false ("assigned", pas "resolved") comme le
  -- cas ennemi/allié -- Controller:select_card ne déclenche donc le pulse
  -- qu'à la confirmation réelle, jamais à la simple sélection.
  if def.target == "self" then pending.awaiting_confirm_kind = "self"; return false end
  if def.target == "all-enemies" then pending.awaiting_confirm_kind = "all-enemies"; return false end
  if def.target == "conditional" and Combat.enemy_targeting(state, hero) then
    pending.awaiting_confirm_kind = "self"
    return false
  end
  return false -- en attente d'un clic de cible (ennemi/allié) ou de confirmation (ci-dessus)
end

--- Équivalent resolvePending.
function Game.resolve_pending(state, kind, target_id)
  local pending = state.pending
  if not pending or not pending.hero_id then return end
  local hero = Combat.hero_by_id(state, pending.hero_id)
  local def = pending.def
  local cost = def.cost
  if not hero or state.energy < cost or (def.mana_cost and (hero.mana or 0) < def.mana_cost) then
    state.pending = nil; return
  end

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

  state.energy = state.energy - cost
  if def.mana_cost then hero.mana = hero.mana - def.mana_cost end
  local ctx = { state = state, hero = hero, target = target, card_def = def }
  def.effect(ctx)
  Game.on_card_played(state, hero, def)
  Game.check_victory(state)
  Game.finish_card(state, pending, ctx)
end

--- Effets de bord communs à TOUTE carte jouée, quel que soit son effet propre
-- (2026-08-24, demande explicite) : Camouflé se termine dès qu'un héros joue
-- une carte -- quelle qu'elle soit, même sans rapport avec la discrétion --
-- voir glossary.lua. L'Assassin gagne 1 Discrétion à chaque carte jouée par
-- un AUTRE héros (jamais lui-même, jamais les ennemis -- confirmé
-- explicitement) ; sa propre Discrétion repart à 0 dès qu'IL joue une carte
-- (cohérent avec la fin de Camouflé ci-dessus : jouer une carte = se
-- dévoiler) -- SAUF carte "Furtif" (2026-08-28, clarification explicite du
-- mot-clé : "Ne fait pas perdre de Discrétion") : ce cas ne touche ni
-- discretion ni camoufle, l'action elle-même étant trop discrète pour se
-- trahir. Marque aussi `played_card_this_turn` inconditionnellement (même une
-- carte Furtif compte comme "avoir agi" pour Game.tick_discretion_end_of_turn
-- -- seule la perte de Discrétion/Camouflé est exemptée, pas le fait d'avoir
-- joué).
function Game.on_card_played(state, hero, def)
  hero.played_card_this_turn = true
  local furtif = def_has_cat(def, "furtif")
  if hero.discretion ~= nil then
    if not furtif then
      hero.camoufle = 0
      hero.discretion = 0
    end
  else
    hero.camoufle = 0
    for _, h in ipairs(state.heroes) do
      if h.discretion ~= nil and h.hp > 0 then
        Game.gain_discretion(state, h, 1)
      end
    end
  end
end

--- "+5 Discrétion pour l'Assassin s'IL termine le tour SANS avoir joué de
-- carte lui-même" (2026-08-24, corrigé -- pas par allié inactif, seulement sa
-- propre inaction ; complète Game.on_card_played qui gère le "+1 quand un
-- AUTRE héros joue une carte") : à appeler en fin de tour, AVANT que
-- Game.start_turn ne remette `played_card_this_turn` à false pour le tour
-- suivant -- voir Controller:advance_after_discard_sequenced, même point que
-- Game.decay_end_of_turn_statuses.
function Game.tick_discretion_end_of_turn(state)
  for _, h in ipairs(state.heroes) do
    if h.discretion ~= nil and h.hp > 0 and not h.played_card_this_turn then
      Game.gain_discretion(state, h, 5)
    end
  end
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
    -- Toujours au pluriel, jamais "(s)" (2026-08-21, demande explicite --
    -- accord fautif accepté à 1 carte plutôt que la parenthèse).
    Combat.log(state, #state.hand .. " cartes non jouées défaussées.", "sys")
  end
  Game.grant_furtif_discard_discretion(state, state.hand)
  Game.discard_cards(state, Game.shallow_copy(state.hand))
  return true
end

--- "Furtif" (2026-08-28, clarification explicite du mot-clé) : +2 Discrétion
-- pour CHAQUE carte "Furtif" restée en main -- donc défaussée ci-dessous,
-- jamais jouée ce tour -- à son propriétaire (retrouvé via `def.class_id`,
-- même idiome que Game.select_card, plutôt que suppose "assassin" en dur).
-- Distinct des 2 autres gains de Discrétion (+1 quand un allié agit, +5 en
-- fin de tour sans agir soi-même -- voir Game.on_card_played/
-- Game.tick_discretion_end_of_turn) : celui-ci porte sur la MAIN, pas sur
-- l'action, donc évalué ICI, avant que Game.discard_cards (pure, sans règle
-- de jeu) ne vide réellement la main.
function Game.grant_furtif_discard_discretion(state, hand)
  for _, c in ipairs(hand) do
    if def_has_cat(c.def, "furtif") then
      local owner = Combat.hero_by_id(state, c.def.class_id)
      if owner and owner.hp > 0 and owner.discretion ~= nil then
        Game.gain_discretion(state, owner, 2)
      end
    end
  end
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
  Game.sync_camoufle_visibility(state) -- un héros peut mourir du saignement
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

--- Attaque ennemie qui touche TOUS les héros vivants (2026-08-21, demande
-- explicite -- Homme Arbre, "Onde Sylvestre") : même traitement Esquive que
-- resolve_enemy_attack, héros par héros, jamais un seul jet groupé.
local function resolve_enemy_attack_all(state, e, amount)
  for _, h in ipairs(Combat.living_heroes(state)) do
    if (h.esquive or 0) > 0 then
      h.esquive = h.esquive - 1
      Combat.log(state, e.name .. " utilise " .. e.next_move.name .. " sur " .. h.name .. "… esquivé !", "sys")
    else
      Combat.deal_damage(state, nil, h, amount, "physique", nil, { source_unit = e })
    end
  end
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
  elseif move.kind == "dmg-all" then
    resolve_enemy_attack_all(state, e, move.amount)
  elseif move.kind == "revive" then
    -- Homme Arbre, "Renaissance Sylvestre" (2026-08-21, demande explicite) :
    -- ramène à pleine vie les Pousses d'Arbre DÉJÀ existantes et tombées à 0
    -- -- jamais une nouvelle instance créée, voir enemies.lua. Toujours au
    -- pluriel dans le journal, jamais "(s)" (préférence actée le 2026-08-21).
    local revived = 0
    for _, o in ipairs(state.enemies) do
      if o.template_id == "pousse" and o.hp <= 0 then
        o.hp = o.max_hp
        revived = revived + 1
      end
    end
    if revived > 0 then
      Combat.log(state, e.name .. " ramène " .. revived .. " Pousses d'Arbre à la vie.", "foe")
    end
  end
  Game.sync_camoufle_visibility(state) -- un héros peut mourir de cette attaque
end

--- Décroissance de fin de tour (après résolution ennemie) : Incapacité +
-- Vulnérabilité, héros ET ennemis (bug signalé, 2026-08-24 -- la
-- Vulnérabilité côté héros ne décroissait jamais, alors que le glossaire la
-- décrit comme "-1 au début de chaque tour" sans distinction héros/ennemi ;
-- resté invisible jusqu'ici faute d'un move ennemi qui la posait sur un héros
-- -- voir Malédiction du Nécromancien Novice, seul cas qui l'exerçait).
function Game.decay_end_of_turn_statuses(state)
  for _, h in ipairs(state.heroes) do
    if (h.incapacite or 0) > 0 then h.incapacite = math.max(0, h.incapacite - 1) end
    if (h.vulnerabilite or 0) > 0 then h.vulnerabilite = math.max(0, h.vulnerabilite - 1) end
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
