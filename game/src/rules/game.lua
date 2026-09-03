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
local Cards = require("src.data.cards")

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

-- Même idiome que def_has_cat ci-dessus, mais sur `def.types` (2026-09-03,
-- cartes "Enchantement" -- Frénésie du Guerrier compte les cartes de type
-- "offensive" jouées ce tour, voir Game.on_card_played) : les 2 champs sont
-- des tableaux de tags distincts (`cats` = catégories internes/mots-clés de
-- carte, `types` = Offensive/Support/Enchantement affichés sur la cellule en
-- haut de la carte, voir cards.lua/view.lua) -- jamais confondus.
local function def_has_type(def, t)
  if not def or not def.types then return false end
  for _, x in ipairs(def.types) do
    if x == t then return true end
  end
  return false
end
-- Exposée publiquement (2026-08-28, demande explicite -- petit effet visuel
-- de disparition sur une carte "Furtif" défaussée, voir
-- Controller:animate_discard_snapshot dans src/ui/controller.lua) : la UI a
-- besoin du même test, jamais une 2ᵉ copie de cette logique côté view/controller.
Game.card_has_cat = def_has_cat

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
-- Mana de départ du Mage (2026-08-30, demande explicite -- "le Mage démarre
-- CHAQUE combat à mana_start, qui est de 2 !") : UNE SEULE constante,
-- utilisée à la fois par fresh_hero (tout premier combat d'un run) ET
-- carried_hero (chaque combat suivant, voir plus bas) -- avant ce correctif,
-- carried_hero remettait le Mana à 0 au lieu de le remonter à ce niveau
-- (confusion avec Corruption/Discrétion, qui elles repartent bien à 0 -- le
-- Mana est un cas à part : une réserve remise à un niveau FIXE non nul à
-- chaque combat, pas une ressource qui démarre vide).
local MAGE_MANA_START = 2

local function fresh_hero(def)
  return {
    id = def.id, class_id = def.class_id, name = def.name, icon = def.icon, label = def.label, max_hp = def.max_hp,
    hp = def.max_hp, defense = 0, esquive = 0, camoufle = 0,
    -- Incandescence (2026-09-02, "marche comme la Puissance sauf qu'elle ne
    -- descend pas" -- statut Volcan, côté ennemi surtout, mais initialisé ici
    -- comme les autres champs de statut par cohérence si jamais un futur
    -- effet l'accordait à un héros).
    incapacite = 0, vulnerabilite = 0, puissance = 0, incandescence = 0, saignements = 0, brulure = 0,
    -- Provocation (2026-08-28, statut propre au Paladin, clarifié après coup --
    -- "+50% de chances d'être ciblé par les ennemis, puis diminue de 1") : un
    -- statut de combat comme les autres (voir STATUS_KEYS/STATUS_TOOLTIP_FIELDS
    -- côté UI), décroît via Game.start_turn plutôt que
    -- Game.decay_end_of_turn_statuses -- voir son commentaire, le tirage de
    -- cible (Encounter.roll_telegraphs) doit encore voir la valeur PLEINE ce
    -- tour-ci.
    provocation = 0,
    -- Boucliers programmés (2026-08-28, carte "Infranchissable") : liste de
    -- {amount, turns_left}, consommée par Game.start_turn -- voir
    -- Game.schedule_shield, seul point d'entrée pour y ajouter une entrée.
    scheduled_shields = {},
    played_card_this_turn = false,
    mana = def.class_id == "mage" and MAGE_MANA_START or nil,
    discretion = def.class_id == "assassin" and 0 or nil,
    -- Corruption (2026-08-29, ressource propre au Nécromancien, voir
    -- Combat.deal_damage pour le gain automatique par PV perdu) : même
    -- convention que mana/discretion, nil pour toute autre classe.
    corruption = def.class_id == "necromancien" and 0 or nil,
    -- Inspiration/Encore (2026-08-29, statuts GÉNÉRIQUES du Barde -- voir
    -- consume_inspiration dans combat.lua/Game.resolve_pending) :
    -- contrairement à mana/discretion, N'IMPORTE QUEL héros peut les porter
    -- (accordés par une carte Barde à n'importe quel allié) -- initialisés
    -- pour TOUTE classe, comme puissance/esquive, pas conditionnés à
    -- class_id == "barde". `inspiration_shielded_turns` ("Dernier rappel") :
    -- bloque la décroissance auto de fin de tour pour N tours, indépendant de
    -- la consommation à l'usage.
    inspiration = 0, inspiration_shielded_turns = 0, encore_extra_plays = nil,
    -- Gratuite (2026-09-02, statut GÉNÉRIQUE -- "Bis" du Barde) : coût 0 tant
    -- que > 0, décompté de 1 par carte jouée (Game.on_card_played), jamais en
    -- fin de tour -- voir Combat.effective_cost.
    gratuite = nil,
    -- Servant d'os (Nécromancien) : dégâts "brut" programmés à un ennemi
    -- ALÉATOIRE tiré au moment où l'entrée se déclenche -- voir
    -- Game.schedule_damage, même structure que scheduled_shields ci-dessus.
    scheduled_damages = {},
    -- Bénédiction/malédiction du Temple (2026-08-28/29, demande explicite) :
    -- nil tant qu'aucune n'a été accordée -- voir src/rules/temple.lua
    -- (Temple.assign) pour l'attribution, 2 champs INDÉPENDANTS (un
    -- aventurier peut cumuler les deux à la fois, voir temple.lua). Tous les
    -- champs "miroir" en dessous (thorns, card_cost_delta, etc.) sont
    -- recopiés depuis l'effet actif par
    -- Game.apply_combat_start_temple_effects à CHAQUE entrée en combat --
    -- jamais lus directement ailleurs comme "nil au départ", cette fonction
    -- ne fait qu'exister pour que les champs soient documentés une fois ici.
    blessing = nil, curse = nil,
    thorns = nil, card_cost_delta = nil, targeting_bonus = nil, force_amnesie = nil,
    extra_draw = nil, turn_start_shield = nil, death_ward = nil, reserviste = nil,
    discard_on_draw_chance = nil,
    -- Enchantements (2026-09-03, demande explicite -- 2 par classe, jamais
    -- "Départ", accordés par la carte correspondante au moment où elle est
    -- jouée -- voir cards.lua) : nil tant qu'aucun n'a été joué CE combat,
    -- comme blessing/curse ci-dessus mais remis à nil à CHAQUE combat (voir
    -- carried_hero plus bas) plutôt que persistant tout le run, puisqu'il
    -- faut rejouer la carte pour réactiver le pouvoir. `frenesie_bonus_pct`
    -- (Guerrier) est le seul champ non-nil par défaut (0, pas nil) -- décroît
    -- au sens où il repart à 0 CHAQUE TOUR même une fois Frénésie active,
    -- voir Game.start_turn.
    instinct_chasseur = nil, frenesie_step = nil, frenesie_bonus_pct = 0,
    bouclier_vivant_ratio = nil, shield_thorns = nil,
    combustion_differee = nil, second_souffle = nil,
    ombre_patiente = nil, imperceptible = nil,
    rite_de_la_chair = nil, pacte_survie = nil,
    memoire_melodique = nil, tournee_finale = nil,
  }
end

--- Retranscrit l'effet de Temple actif de `n` (bénédiction ET malédiction,
-- indépendamment) en CHAMPS SIMPLES sur le héros -- seul endroit qui
-- connaisse Temple.effects ; combat.lua/encounter.lua/deck.lua ne lisent
-- ensuite que ces champs, jamais "Temple"/"blessing"/"curse" directement
-- (même principe que hero.discretion pour l'Assassin). Appelé à CHAQUE
-- entrée en combat (fresh_hero n'a jamais d'effet, mais carried_hero si) --
-- recalcule tout depuis zéro plutôt que de préserver l'ancien état, donc
-- "1 fois par combat" (death_ward/reserviste) redevient vrai à chaque
-- nouveau combat sans logique de reset séparée.
-- `combat_start_heal`/`combat_start_curse_damage` (2026-08-28/29) : montant
-- EFFECTIVEMENT appliqué à CETTE entrée en combat précise (peut être <
-- l'effet déclaré si déjà proche du plafond/déjà bas, ou nil si rien à
-- montrer) -- lus et remis à nil par Controller:play_hero_ready_hops
-- (view.lua affiche le flottant vert/rouge exact, synchronisé avec le petit
-- saut de CET aventurier). La RÈGLE vit ici, pas dans le contrôleur.
local function apply_combat_start_temple_effects(n)
  n.combat_start_heal = nil
  n.combat_start_curse_damage = nil
  n.thorns = nil; n.card_cost_delta = nil; n.targeting_bonus = nil; n.force_amnesie = nil
  n.extra_draw = nil; n.turn_start_shield = nil; n.death_ward = nil; n.reserviste = nil
  n.discard_on_draw_chance = nil
  if n.hp <= 0 then return end

  local blessing = n.blessing and Temple.by_id(n.blessing)
  if blessing then
    if blessing.combat_start_heal then
      local before = n.hp
      n.hp = math.min(n.max_hp, n.hp + blessing.combat_start_heal)
      local healed = n.hp - before
      if healed > 0 then n.combat_start_heal = healed end
    end
    if blessing.combat_start_status then
      for field, amount in pairs(blessing.combat_start_status) do
        n[field] = (n[field] or 0) + amount
      end
    end
    n.thorns = blessing.thorns
    n.extra_draw = blessing.extra_draw
    n.turn_start_shield = blessing.turn_start_shield
    n.death_ward = blessing.death_ward or nil
    n.reserviste = blessing.reserviste or nil
  end

  local curse = n.curse and Temple.by_id(n.curse)
  if curse then
    if curse.combat_start_damage then
      local before = n.hp
      n.hp = math.max(1, n.hp - curse.combat_start_damage) -- jamais tué par un simple tic passif
      local lost = before - n.hp
      if lost > 0 then n.combat_start_curse_damage = lost end
    end
    if curse.combat_start_status then
      for field, amount in pairs(curse.combat_start_status) do
        n[field] = (n[field] or 0) + amount
      end
    end
    n.card_cost_delta = curse.card_cost_delta
    n.targeting_bonus = curse.targeting_bonus
    n.force_amnesie = curse.force_amnesie or nil
    n.discard_on_draw_chance = curse.discard_on_draw_chance
  end
end

--- Remet `card.def` sur sa forme CANONIQUE (2026-09-02, demande explicite --
-- "le coût d'Avalanche de coups doit repasser à 1 à la fin de chaque
-- combat. C'est un effet temporaire") : annule tout override posé pour LE
-- COMBAT qui vient de se terminer (aujourd'hui, seul `zero_cost_def`, plus
-- bas dans ce fichier, en pose un, mais cette fonction est volontairement
-- générique -- "canonique" plutôt que "pas zero_cost", pour rester correcte
-- si un futur effet posait un autre override temporaire similaire). Respecte
-- `is_upgraded` : une carte améliorée à la Forge reste améliorée (son
-- def canonique redevient `Cards.upgraded_def(base)`, pas `base` tout court)
-- -- seul ce qu'un EFFET DE CARTE a modifié en cours de combat (ex. le coût)
-- est annulé, jamais ce que le joueur a choisi de façon permanente. Placée
-- ICI (avant Game.start_next_combat/start_boss_combat, ses 2 seuls appelants)
-- plutôt qu'à côté de `zero_cost_def` -- Lua résout les locales du chunk
-- dans l'ordre du fichier, une locale définie APRÈS son premier appel
-- resterait invisible (résolue en global nil, voir l'erreur d'origine).
local function reset_temporary_card_state(card)
  local base = Cards.by_code(card.def.code)
  if not base then return end -- ne devrait jamais arriver, filet de sécurité
  card.def = card.def.is_upgraded and Cards.upgraded_def(base) or base
end

local function carried_hero(h)
  -- Entre deux combats d'un même run, seuls les PV persistent (blessures non
  -- soignées) ; tout le reste repart à zéro -- SAUF `blessing`/`curse`
  -- (2026-08-28/29), qui durent tout le run une fois accordés par le Temple
  -- (voir src/rules/temple.lua) : `shallow_copy` les propage déjà tels quels,
  -- rien à faire de spécial ici pour ces 2 champs.
  local n = shallow_copy(h)
  n.defense = 0; n.esquive = 0; n.camoufle = 0
  n.incapacite = 0; n.vulnerabilite = 0; n.puissance = 0; n.incandescence = 0; n.saignements = 0; n.brulure = 0
  n.provocation = 0; n.scheduled_shields = {}
  n.played_card_this_turn = false
  -- Inspiration/Encore/Bouclier programmé de Servant d'os (2026-08-29) : des
  -- statuts de COMBAT comme puissance/provocation ci-dessus, jamais reportés
  -- d'un combat à l'autre -- Corruption, elle, EST une ressource propre à la
  -- classe (comme mana/discretion) mais DOIT repartir à 0 à chaque nouveau
  -- combat (intention de design confirmée explicitement, 2026-08-29 -- "en
  -- général... les ressources spécifiques sont reset aux débuts de chaque
  -- combat" -- contrairement au bug déjà connu sur mana/discretion, voir
  -- reference_reset-ressource-par-combat.md côté agent_content -- Corruption
  -- ne doit pas hériter du même oubli).
  n.inspiration = 0; n.inspiration_shielded_turns = 0; n.encore_extra_plays = nil
  n.gratuite = nil
  n.scheduled_damages = {}
  -- Discrétion (Assassin) (2026-08-30, bug confirmé -- "Mana et Discrétion
  -- doivent repartir à 0 à chaque combat") : même traitement que Corruption
  -- juste au-dessus -- ressource propre à une classe, mais qui NE doit PAS
  -- survivre d'un combat à l'autre, contrairement aux PV. Oubliée ici depuis
  -- l'origine (voir reference_reset-ressource-par-combat.md côté
  -- agent_content, qui documentait déjà ce bug) -- Corruption avait été
  -- corrigée sans que celle-ci le soit, jamais une bonne raison à ce
  -- qu'elles se comportent différemment.
  if n.discretion ~= nil then n.discretion = 0 end
  if n.corruption ~= nil then n.corruption = 0 end
  -- Mana (Mage) (2026-08-30, correction du correctif précédent -- "c'est une
  -- erreur de ma part, le Mage démarre CHAQUE combat à mana_start, qui est
  -- de 2 !") : PAS un simple reset à 0 comme Discrétion/Corruption
  -- ci-dessus -- une remise à niveau FIXE non nulle, même MAGE_MANA_START
  -- que fresh_hero (voir sa définition, tout premier combat d'un run) --
  -- jamais 2 sources de vérité pour cette valeur.
  if n.mana ~= nil then n.mana = MAGE_MANA_START end
  -- Enchantements (2026-09-03) : remis à nil (rien joué CE combat) à chaque
  -- nouveau combat, même principe que puissance/provocation plus haut --
  -- toujours à rejouer pour être réactivés, jamais reportés d'un combat à
  -- l'autre (contrairement à blessing/curse, propagés tels quels par
  -- shallow_copy ci-dessus, rien à faire pour ces 2-là).
  n.instinct_chasseur = nil; n.frenesie_step = nil; n.frenesie_bonus_pct = 0
  n.bouclier_vivant_ratio = nil; n.shield_thorns = nil
  n.combustion_differee = nil; n.second_souffle = nil
  n.ombre_patiente = nil; n.imperceptible = nil
  n.rite_de_la_chair = nil; n.pacte_survie = nil
  n.memoire_melodique = nil; n.tournee_finale = nil
  apply_combat_start_temple_effects(n)
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
-- "Imperceptible" (2026-09-03, Enchantement de l'Assassin -- hero.imperceptible) :
-- +2/+4 à CHAQUE gain de Discrétion, quelle qu'en soit la source -- appliqué
-- ICI, seul point d'entrée pour un gain de Discrétion (voir le commentaire
-- au-dessus de cette fonction), donc valable aussi bien pour les cartes
-- Assassinat/En traître/Préparation que pour le passif générique "+1 quand un
-- allié joue une carte"/"+5 en fin de tour sans agir" -- rien à dupliquer
-- ailleurs.
function Game.gain_discretion(state, hero, amount)
  if hero.imperceptible then amount = amount + hero.imperceptible end
  local was_camoufle = (hero.camoufle or 0) > 0
  hero.discretion = math.min(10, (hero.discretion or 0) + amount)
  if hero.discretion >= 10 then
    hero.camoufle = 1
    if not was_camoufle then Combat.log(state, hero.name .. " atteint 10 Discrétion : Camouflé.", "power") end
    -- "Ombre patiente" (2026-09-03, Enchantement de l'Assassin --
    -- hero.ombre_patiente) : Puissance à CHAQUE entrée en Camouflé (`not
    -- was_camoufle` = transition 0->1, pas "reste Camouflé") -- répétable
    -- sans plafond dans un même combat si la Discrétion retombe puis remonte
    -- à 10 plusieurs fois, confirmé explicitement par le porteur de projet.
    if not was_camoufle and hero.ombre_patiente then
      Combat.apply_status(hero, "puissance", hero.ombre_patiente)
      Combat.log(state, hero.name .. " (Ombre patiente) gagne " .. hero.ombre_patiente .. " Puissance.", "power")
    end
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
    -- "Amnésie" (2026-08-28, demande explicite) : 4ᵉ zone de cartes, à part de
    -- deck/main/défausse -- une carte qui y tombe (voir Game.finish_card) ne
    -- revient jamais dans la rotation de CE combat, seulement repêchée avec le
    -- reste au tout début du combat SUIVANT (voir Game.start_next_combat/
    -- start_boss_combat, qui la vident dans `reclaimed`).
    exhausted = {},
    pending = nil, turn = 1, over = false, energy = 0,
    run = { combat_index = 1 }, draft_picks = nil,
    combat_snapshot = nil, turn_snapshot = nil, uid_counter = 0, log = {},
    rng = nil, -- créés par Game.reset_run (voir Game.new_rng_streams)
    -- "Mémoire mélodique" (2026-09-03, Enchantement du Barde) : uids de cartes
    -- en main rendues gratuites JUSTE POUR CE TOUR -- revenues à leur coût
    -- normal au tour suivant (voir Game.start_turn), jamais au combat suivant
    -- comme le "coût 0" permanent d'Avalanche de coups (ctx.zero_cost,
    -- reset_temporary_card_state) -- mécanisme distinct et parallèle, pas une
    -- réutilisation.
    turn_free_uids = {},
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
    -- "Le Maladroit" (2026-08-29, malédiction -- 50% de chance qu'une carte
    -- piochée soit aussitôt défaussée, voir Game.fill_hand_with_bonus_draws) :
    -- flux dédié, jamais state.rng.deck (qui pilote l'ORDRE du deck -- un tirage
    -- de plus ou de moins ici ne doit jamais décaler ce que la pioche aurait
    -- sorti sans cette malédiction).
    curse = Rng.new(master_seed + 7),
    -- Servant d'os (2026-08-29, Nécromancien -- hero.scheduled_damages) : tire
    -- la cible ALÉATOIRE de chaque dégât programmé qui se déclenche (voir
    -- Game.start_turn) -- flux dédié, jamais state.rng.encounter/enemy_turn,
    -- même raison d'être que "curse" ci-dessus (ne jamais décaler un AUTRE
    -- tirage reproductible pour un contenu qui n'existait pas encore).
    necro = Rng.new(master_seed + 8),
    -- "Mémoire mélodique" (2026-09-03, Enchantement du Barde) : tire la carte
    -- au hasard dans le reste de la main rendue gratuite ce tour-ci -- flux
    -- dédié, même raison d'être que "curse"/"necro" ci-dessus (ne jamais
    -- décaler un AUTRE tirage reproductible).
    enchantment = Rng.new(master_seed + 9),
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
-- `selected_ids` (optionnel, 2026-08-29, écran de sélection d'équipe -- voir
-- Controller:enter_team_select) : liste des 4 ids choisis parmi les 6
-- `Heroes.defs` (n'importe quel ordre/sous-ensemble) -- par défaut
-- `Heroes.DEFAULT_PARTY_IDS` (les 4 héros historiques), pour que tout appel
-- existant (tests compris) qui ne passe rien continue de se comporter
-- exactement comme avant.
-- 2 biomes tirés SANS remise parmi les 4 (2026-09-01, demande explicite --
-- "tirage de biome sans remise") : toujours distincts au sein d'un même run
-- "bounded". Consomme `rng` (state.rng.encounter), même flux que le reste de
-- la génération de rencontre, pour rester reproductible à l'identique pour
-- un seed de run donné.
local function pick_run_biomes(rng)
  local pool = {}
  for _, b in ipairs(Enemies.ALL_BIOMES) do pool[#pool + 1] = b end
  local first = table.remove(pool, rng:random(#pool))
  local second = table.remove(pool, rng:random(#pool))
  return { first, second }
end

--- Biome du combat EN COURS (2026-09-01) : combats 1-4 du run "bounded" ->
-- 1er biome tiré, combats 5-8 -> 2e -- voir BOUNDED_COMBAT_COUNT (8) dans
-- controller.lua/view.lua. `nil` si ce run n'a pas de biomes (mode "Infini",
-- qui ne reçoit PAS cette mécanique -- voir Game.reset_run/random_pool).
function Game.current_biome(state)
  if not state.run.biomes then return nil end
  return state.run.combat_index <= 4 and state.run.biomes[1] or state.run.biomes[2]
end

-- `mode` (optionnel, 2026-09-01, "bounded"|"infini"|nil -- même vocabulaire
-- que Controller.run_mode, mais ce module n'en connaissait rien jusqu'ici) :
-- SEUL mode qui reçoit la mécanique de biomes (tirage des 2 biomes, rencontre
-- confinée à un biome, Élite au 4e/8e combat) -- "infini" (bientôt retiré du
-- jeu, demande explicite de ne rien lui ajouter) et l'absence de mode ("Tester
-- le boss", qui ne passe même pas par cette fonction) gardent l'ancien
-- comportement : pool complet, jamais de state.run.biomes.
function Game.reset_run(state, seed, selected_ids, mode)
  selected_ids = selected_ids or Heroes.DEFAULT_PARTY_IDS
  local heroes = {}
  for i, id in ipairs(selected_ids) do heroes[i] = fresh_hero(Heroes.by_id(id)) end
  state.heroes = heroes
  state.run = { combat_index = 1, is_boss = false, mode = mode }
  state.rng = Game.new_rng_streams(seed)
  if mode == "bounded" then state.run.biomes = pick_run_biomes(state.rng.encounter) end
  local budget = Encounter.budget_for_combat(1)
  local instances = Encounter.generate_encounter(budget, state.rng.encounter, Game.current_biome(state))
  local enemies = {}
  for i, inst in ipairs(instances) do
    enemies[i] = Encounter.instantiate_enemy(inst.template, inst.level, function() return Game.next_uid(state) end, state.rng.encounter)
  end
  state.enemies = enemies
  state.deck = Deck.build_starting_deck(selected_ids, function() return Game.next_uid(state) end, state.rng.deck)
  state.hand = {}; state.discard = {}; state.exhausted = {}; state.pending = nil
  state.turn = 1; state.over = false; state.energy = 0
  -- "PO" (or, 2026-09-02, demande explicite -- "un run commence avec 100 PO") :
  -- posé UNIQUEMENT ici, jamais dans start_next_combat/start_boss_combat/
  -- start_boss_test ni dans snapshot_combat/snapshot_turn -- persiste tout le
  -- run, comme state.deck, contrairement à state.energy (qui repart à 0 à
  -- CHAQUE combat, voir ces mêmes fonctions).
  state.gold = 100
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
  local instances = Encounter.generate_encounter(budget, state.rng.encounter, Game.current_biome(state))
  local enemies = {}
  for i, inst in ipairs(instances) do
    enemies[i] = Encounter.instantiate_enemy(inst.template, inst.level, function() return Game.next_uid(state) end, state.rng.encounter)
  end
  -- Élite au 4e combat de chaque biome (2026-09-01, demande explicite --
  -- "un ennemi au hasard") : combat_index 4 (fin du 1er biome) et 8 (fin du
  -- 2e, juste avant le Boss) -- 1 seul ennemi parmi ceux tirés pour CE combat,
  -- jamais systématiquement le même template ("l'ancre" du biome).
  if state.run.mode == "bounded" and (state.run.combat_index == 4 or state.run.combat_index == 8) and #enemies > 0 then
    Encounter.promote_to_elite(enemies[state.rng.encounter:random(#enemies)])
  end
  state.enemies = enemies
  local reclaimed = {}
  for _, c in ipairs(state.deck) do reclaimed[#reclaimed + 1] = c end
  for _, c in ipairs(state.hand) do reclaimed[#reclaimed + 1] = c end
  for _, c in ipairs(state.discard) do reclaimed[#reclaimed + 1] = c end
  -- "Amnésie" (2026-08-28) : "disparait pour le RESTE du combat" -- revient
  -- donc bien ici, au tout début du combat suivant, mélangée avec le reste.
  for _, c in ipairs(state.exhausted) do reclaimed[#reclaimed + 1] = c end
  -- Effets temporaires de carte (2026-09-02, "Avalanche de coups" -- voir
  -- reset_temporary_card_state) : annulés ICI, sur TOUTES les cartes
  -- reprises, avant même le mélange -- "à la fin de chaque combat", et ce
  -- combat vient de se terminer.
  for _, c in ipairs(reclaimed) do reset_temporary_card_state(c) end
  state.deck = Deck.shuffle(reclaimed, state.rng.deck)
  state.hand = {}; state.discard = {}; state.exhausted = {}; state.pending = nil
  state.turn = 1; state.energy = 0
  state.log = {}
  Combat.log(state, "Combat " .. state.run.combat_index .. " (budget " .. budget .. ") : " .. Encounter.summary(state.enemies), "sys")
  Game.snapshot_combat(state)
  Game.start_turn(state)
end

--- Combat de boss autonome (2026-08-21, demande explicite) : bouton "Tester
-- un boss" au menu -- mêmes fondations qu'un run normal (nouveaux héros
-- pleine vie, nouveau deck, nouveaux flux aléatoires) mais rencontre FIXE
-- (Encounter.boss_encounter) plutôt que tirée par le budget. Ne touche jamais
-- `state.run.combat_index`/le mode de run -- ce n'est pas un run normal, voir
-- Controller:start_boss_test (self.run_mode reste nil). `biome` (2026-09-02,
-- demande explicite -- écran "Choisis un boss" après la sélection d'équipe) :
-- choisit le boss précis (voir Encounter.BOSS_BY_BIOME) -- absent, retombe
-- sur le tirage aléatoire d'avant (Encounter.boss_encounter), jamais un cas
-- d'erreur. `level` (même demande, boutons -/+ 1-9 sur l'écran de choix) :
-- transmis tel quel, absent = niveau 1 (voir Encounter.boss_encounter).
function Game.start_boss_test(state, seed, selected_ids, biome, level)
  selected_ids = selected_ids or Heroes.DEFAULT_PARTY_IDS
  local heroes = {}
  for i, id in ipairs(selected_ids) do heroes[i] = fresh_hero(Heroes.by_id(id)) end
  state.heroes = heroes
  state.run = { combat_index = 1, is_boss = true }
  state.rng = Game.new_rng_streams(seed)
  state.enemies = Encounter.boss_encounter(function() return Game.next_uid(state) end, state.rng.encounter, biome, level)
  state.deck = Deck.build_starting_deck(selected_ids, function() return Game.next_uid(state) end, state.rng.deck)
  state.hand = {}; state.discard = {}; state.exhausted = {}; state.pending = nil
  state.turn = 1; state.over = false; state.energy = 0
  state.log = {}
  Combat.log(state, "Test du boss : " .. Encounter.summary(state.enemies), "sys")
  Game.snapshot_combat(state)
  Game.start_turn(state)
end

--- "Run Solo" (2026-09-02, menu "Run Solo", écran "Construis ton deck") : ne
-- prépare QUE le 1er combat -- un seul héros, rencontre ALÉATOIRE
-- (Encounter.generate_encounter, même budget que le tout 1er combat d'un run
-- normal) au lieu d'un boss fixe, ET un deck ENTIÈREMENT fourni par l'appelant
-- (`deck_defs`, liste de defs -- base OU améliorée, choisies carte par carte
-- sur l'écran de construction) plutôt que Deck.build_starting_deck.
-- `hero_id` : un seul, pas une liste `selected_ids` comme les autres
-- Game.start_*. Les combats SUIVANTS (2026-09-03, refonte -- demande
-- explicite : "il faut enchainer les combats à la suite avec la difficulté
-- qui augmente [...] sans évènements ni draft entre chaque combat. Pas de
-- fin") ne repassent PLUS par cette fonction : `state.run.mode` reste nil ici
-- (jamais "bounded"), donc Game.start_next_combat -- appelé directement par
-- Controller:advance_to_next_combat après chaque victoire, voir
-- Controller:enter_solo_victory -- lui suffit tel quel pour enchaîner : budget
-- croissant (Encounter.budget_for_combat(combat_index)), jamais d'Élite/de
-- biome (conditions réservées à `mode == "bounded"`), jamais de boss (seul
-- Game.start_boss_combat en pose, jamais appelé pour ce run_mode).
function Game.start_solo_run(state, seed, hero_id, deck_defs)
  state.heroes = { fresh_hero(Heroes.by_id(hero_id)) }
  state.run = { combat_index = 1, is_boss = false }
  state.rng = Game.new_rng_streams(seed)
  local budget = Encounter.budget_for_combat(1)
  local instances = Encounter.generate_encounter(budget, state.rng.encounter, nil)
  local enemies = {}
  for i, inst in ipairs(instances) do
    enemies[i] = Encounter.instantiate_enemy(inst.template, inst.level, function() return Game.next_uid(state) end, state.rng.encounter)
  end
  state.enemies = enemies
  local cards = {}
  for _, def in ipairs(deck_defs) do cards[#cards + 1] = { uid = Game.next_uid(state), def = def } end
  state.deck = Deck.shuffle(cards, state.rng.deck)
  state.hand = {}; state.discard = {}; state.exhausted = {}; state.pending = nil
  state.turn = 1; state.over = false; state.energy = 0
  state.log = {}
  Combat.log(state, "Run Solo (budget " .. budget .. ") : " .. Encounter.summary(state.enemies), "sys")
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
  -- Boss choisi par le dernier biome traversé (2026-09-01, demande explicite) :
  -- Game.current_biome résout au 2ᵉ biome du run pour tout combat_index > 4,
  -- boss (déjà incrémenté ci-dessus) compris -- aucun cas particulier requis
  -- ici. nil pour un run sans biomes (ne devrait pas arriver pour un run
  -- "bounded" réel, mais Encounter.boss_encounter retombe alors sur un
  -- tirage aléatoire par sécurité, jamais une erreur).
  state.enemies = Encounter.boss_encounter(function() return Game.next_uid(state) end, state.rng.encounter, Game.current_biome(state))
  local reclaimed = {}
  for _, c in ipairs(state.deck) do reclaimed[#reclaimed + 1] = c end
  for _, c in ipairs(state.hand) do reclaimed[#reclaimed + 1] = c end
  for _, c in ipairs(state.discard) do reclaimed[#reclaimed + 1] = c end
  for _, c in ipairs(state.exhausted) do reclaimed[#reclaimed + 1] = c end
  -- Effets temporaires de carte (2026-09-02) : voir le commentaire équivalent
  -- dans Game.start_next_combat.
  for _, c in ipairs(reclaimed) do reset_temporary_card_state(c) end
  state.deck = Deck.shuffle(reclaimed, state.rng.deck)
  state.hand = {}; state.discard = {}; state.exhausted = {}; state.pending = nil
  state.turn = 1; state.energy = 0
  state.log = {}
  Combat.log(state, "Le Boss : " .. Encounter.summary(state.enemies), "sys")
  Game.snapshot_combat(state)
  Game.start_turn(state)
end

-- ---------- début de tour ----------

--- Programme un gain de Bouclier `turns_from_now` débuts de tour plus tard
-- (2026-08-28, carte "Infranchissable") : seul point d'entrée pour ajouter une
-- entrée à `hero.scheduled_shields`, consommée par Game.start_turn --
-- `turns_from_now = 2` (version améliorée) programme 2 gains DISTINCTS
-- (celui-ci ET un appel séparé à 1), pas un seul gain doublé plus tard.
function Game.schedule_shield(hero, amount, turns_from_now)
  hero.scheduled_shields = hero.scheduled_shields or {}
  hero.scheduled_shields[#hero.scheduled_shields + 1] = { amount = amount, turns_left = turns_from_now }
end

--- Programme `amount` dégâts "brut" à un ennemi ALÉATOIRE, `turns_from_now`
-- débuts de tour plus tard (2026-08-29, carte "Servant d'os", Nécromancien) :
-- même principe que Game.schedule_shield ci-dessus, mais la cible n'est tirée
-- qu'AU MOMENT où l'entrée se déclenche (voir Game.start_turn), jamais fixée
-- ici -- 3 (ou 4, version améliorée) entrées DISTINCTES programmées séparément
-- par la carte, chacune peut donc toucher un ennemi différent.
function Game.schedule_damage(hero, amount, turns_from_now)
  hero.scheduled_damages = hero.scheduled_damages or {}
  hero.scheduled_damages[#hero.scheduled_damages + 1] = { amount = amount, turns_left = turns_from_now }
end

--- "Le Réserviste" (2026-08-29, bénédiction -- hero.reserviste, "1 fois par
-- combat") : au lieu de la remise à niveau FIXE habituelle, l'énergie non
-- dépensée du tour précédent (`state.energy`, encore intacte à cet instant --
-- rien d'autre ne la touche entre la fin d'un tour et le prochain start_turn)
-- s'AJOUTE à Game.TURN_START_ENERGY, une seule fois pour tout le combat.
-- Jamais sur le tout 1er tour d'un combat (`state.turn == 1`, voir l'appelant)
-- : `state.energy` y vaut toujours 0 (remis par start_next_combat/reset_run/
-- start_boss_combat/start_boss_test), le déclencher là gâcherait la charge
-- pour rien. Ne consomme qu'UNE charge par tour même si plusieurs aventuriers
-- la portent (l'énergie est une réserve globale, pas cumulable par porteur).
local function reserviste_bonus_energy(state)
  for _, h in ipairs(state.heroes) do
    if h.hp > 0 and h.reserviste then
      h.reserviste = false
      Combat.log(state, h.name .. " (Le Réserviste) conserve l'énergie du tour précédent.", "power")
      return state.energy
    end
  end
  return 0
end

--- "Le Maladroit" (2026-08-29, malédiction -- hero.discard_on_draw_chance) :
-- chaque carte de `drawn_uids` qui appartient à un aventurier maudit a une
-- chance de partir aussitôt en défausse au lieu de rester en main. Retourne
-- la liste FILTRÉE (sans les uids défaussés) : ces cartes ne doivent JAMAIS
-- apparaître dans l'animation de pioche (Controller:consume_drawn_animation)
-- -- une carte qui "arrive" en main pour en repartir aussitôt serait plus
-- confus qu'utile, elle atterrit directement en défausse, sans vol du tout.
function Game.apply_maladroit_discards(state, drawn_uids)
  local survivors = {}
  for _, uid in ipairs(drawn_uids) do
    local idx
    for i, c in ipairs(state.hand) do if c.uid == uid then idx = i break end end
    local discarded = false
    if idx then
      local card = state.hand[idx]
      local owner = Combat.hero_by_id(state, card.def.class_id)
      if owner and owner.discard_on_draw_chance and state.rng.curse:random() < owner.discard_on_draw_chance then
        table.remove(state.hand, idx)
        state.discard[#state.discard + 1] = card
        Combat.log(state, card.def.name .. " (Le Maladroit) est défaussée aussitôt piochée.", "foe")
        discarded = true
      end
    end
    if not discarded then survivors[#survivors + 1] = uid end
  end
  return survivors
end

--- Pioche jusqu'à Deck.HAND_SIZE, PLUS les piochers supplémentaires accordés
-- par "L'Archiviste" (2026-08-29, bénédiction -- hero.extra_draw), PUIS
-- applique "Le Maladroit" sur tout le lot -- fusionne pioche normale + pioche
-- bonus en un seul retour pour que l'animation les traite comme un seul
-- geste, remélange compris s'il survient dans l'un OU l'autre lot. Seul
-- point d'entrée "pioche de début de tour" -- Clairvoyance (carte, milieu de
-- tour) appelle Deck.draw_cards directement et gère son propre appel à
-- Game.apply_maladroit_discards, voir cards.lua.
function Game.fill_hand_with_bonus_draws(state)
  local drawn = Deck.fill_hand(state)
  local reshuffled_at = state.last_draw_reshuffled_at
  local extra = 0
  for _, h in ipairs(state.heroes) do
    if h.hp > 0 and h.extra_draw then extra = extra + h.extra_draw end
  end
  if extra > 0 then
    local extra_drawn = Deck.draw_cards(state, extra)
    if state.last_draw_reshuffled_at and not reshuffled_at then
      reshuffled_at = #drawn + state.last_draw_reshuffled_at
    end
    for _, uid in ipairs(extra_drawn) do drawn[#drawn + 1] = uid end
  end
  drawn = Game.apply_maladroit_discards(state, drawn)
  state.last_drawn_uids = drawn
  state.last_draw_reshuffled_at = reshuffled_at
  return drawn
end

--- Équivalent startTurn : énergie globale remise à Game.TURN_START_ENERGY
-- PILE (2026-08-11, précisé par le porteur de projet -- ni un plancher ni un
-- plafond, une remise à niveau fixe qu'il en reste plus ou moins avant), SAUF
-- "Le Réserviste" ci-dessus (2026-08-29) -- statuts qui décroissent,
-- télégraphie ennemie, pioche à HAND_SIZE (+ bonus/malédictions).
-- Retourne la liste des uids piochés (pour que la UI puisse les animer).
function Game.start_turn(state)
  if state.over then return {} end
  -- "Mémoire mélodique" (2026-09-03, Enchantement du Barde) : les cartes
  -- rendues gratuites JUSTE POUR LE TOUR précédent (voir Game.resolve_pending/
  -- state.turn_free_uids) reviennent à leur coût normal ICI, avant tout autre
  -- traitement de ce nouveau tour -- `reset_temporary_card_state` (déjà
  -- utilisée par Game.start_next_combat/start_boss_combat pour Avalanche de
  -- coups) respecte `is_upgraded`, donc une carte améliorée reste améliorée,
  -- seul le coût 0 posé par Mémoire mélodique s'efface.
  for _, c in ipairs(state.hand) do
    if state.turn_free_uids[c.uid] then reset_temporary_card_state(c) end
  end
  state.turn_free_uids = {}
  local bonus_energy = state.turn > 1 and reserviste_bonus_energy(state) or 0
  state.energy = Game.TURN_START_ENERGY + bonus_energy
  for _, h in ipairs(state.heroes) do
    if h.hp > 0 then
      h.defense = 0
      h.played_card_this_turn = false
      -- Frénésie (2026-09-03, Enchantement du Guerrier -- hero.frenesie_bonus_pct) :
      -- repart à 0 CHAQUE tour (même si Frénésie reste active tout le
      -- combat, voir hero.frenesie_step) -- "depuis le début du tour",
      -- jamais un cumul entre tours.
      h.frenesie_bonus_pct = 0
      -- "Rite de la Chair" (2026-09-03, Enchantement du Nécromancien --
      -- hero.rite_de_la_chair) : Corruption automatique à CHAQUE début de
      -- tour, inconditionnel (plus de seuil de PV bas -- tranché
      -- explicitement par le porteur de projet, plus large que la 1ʳᵉ
      -- mouture proposée).
      if h.rite_de_la_chair then
        h.corruption = (h.corruption or 0) + h.rite_de_la_chair
        Combat.log(state, h.name .. " (Rite de la Chair) gagne " .. h.rite_de_la_chair .. " Corruption.", "power")
      end
      -- Puissance ne décroît plus ICI (2026-09-02, demande explicite -- "la
      -- puissance descend à la fin de chaque tour, que ce soit pour les
      -- aventuriers ou les ennemis") : déplacée en FIN de tour, aux côtés
      -- d'Incapacité/Vulnérabilité, voir Game.decay_end_of_turn_statuses --
      -- et désormais symétrique héros/ennemis (avant : seuls les héros la
      -- perdaient, et en DÉBUT de tour, jamais les ennemis).
      -- "Le Protecteur" (2026-08-29, bénédiction -- hero.turn_start_shield) :
      -- APRÈS la remise à 0 de la Défense juste au-dessus, sinon le gain
      -- serait effacé aussitôt -- chaque DÉBUT DE TOUR, pas seulement à
      -- l'entrée en combat (contrairement à la plupart des autres effets).
      -- `{state=state}` (2026-09-03) : pas un `ctx` de carte complet (pas de
      -- `hero`, donc l'Inspiration n'y voit toujours aucun effet, inchangé) --
      -- juste assez pour que "Bouclier vivant" (Combat.grant_defense) puisse
      -- retrouver le reste de l'équipe même pour CE gain hors carte.
      if h.turn_start_shield then Combat.grant_defense(h, h.turn_start_shield, { state = state }) end
      -- Boucliers programmés (2026-08-28, "Infranchissable") : même raison
      -- d'être qu'au-dessus (après la remise à 0 de la Défense).
      if h.scheduled_shields and #h.scheduled_shields > 0 then
        local remaining = {}
        for _, entry in ipairs(h.scheduled_shields) do
          entry.turns_left = entry.turns_left - 1
          if entry.turns_left <= 0 then
            Combat.grant_defense(h, entry.amount, { state = state })
            Combat.log(state, h.name .. " reçoit " .. entry.amount .. " bouclier programmé.", "you")
          else
            remaining[#remaining + 1] = entry
          end
        end
        h.scheduled_shields = remaining
      end
      -- Servant d'os (2026-08-29, Nécromancien) : même mécanique que les
      -- boucliers programmés juste au-dessus, mais la cible (un ennemi VIVANT
      -- au moment du déclenchement, jamais fixée à la pose) est tirée via
      -- state.rng.necro -- rien ne se passe s'il n'y a plus d'ennemi vivant
      -- (combat déjà gagné), l'entrée est simplement consommée.
      if h.scheduled_damages and #h.scheduled_damages > 0 then
        local remaining_dmg = {}
        for _, entry in ipairs(h.scheduled_damages) do
          entry.turns_left = entry.turns_left - 1
          if entry.turns_left <= 0 then
            local targets = Combat.living_enemies(state)
            if #targets > 0 then
              local target = targets[state.rng.necro:random(#targets)]
              Combat.deal_damage(state, h, target, entry.amount, nil, nil, { brut = true })
              Combat.log(state, h.name .. " frappe " .. target.name .. " avec un Servant d'os (" .. entry.amount .. " brut).", "you")
            end
          else
            remaining_dmg[#remaining_dmg + 1] = entry
          end
        end
        h.scheduled_damages = remaining_dmg
      end
    end
  end
  Combat.log(state, "— Tour " .. state.turn .. " : énergie à " .. state.energy .. ", pioche à " .. Deck.HAND_SIZE .. " —", "sys")

  Encounter.roll_telegraphs(state)

  -- Golem de Pierre, "Protection" (2026-09-01, demande explicite) : EXCEPTION
  -- au fonctionnement habituel (tout le reste du bestiaire se résout dans
  -- Game.resolve_enemy_action, après la phase joueur) -- inconditionnel,
  -- indépendant du move choisi (qui reste Poing de Pierre uniquement).
  -- APRÈS Encounter.roll_telegraphs, pas avant (bug trouvé en test) :
  -- roll_telegraphs ÉCRASE `e.defense` pour chaque ennemi vivant
  -- (`e.defense = shield_rolled + defense_bonus_this_turn`), donc accorder
  -- Protection avant ce tirage se ferait aussitôt effacer. Reste bien "en
  -- tout début de tour, avant la phase joueur" pour le JOUEUR (roll_telegraphs
  -- ne fait que préparer les prochaines actions ennemies, aucune résolution
  -- de dégât/action visible avant que le joueur ne joue une carte). Plusieurs
  -- Golems possibles dans un même combat : chacun déclenche sa propre
  -- distribution.
  for _, g in ipairs(state.enemies) do
    if g.hp > 0 and g.template_id == "golem" then
      for _, other in ipairs(state.enemies) do
        if other ~= g and other.hp > 0 then
          Combat.grant_defense(other, 2)
        end
      end
      Combat.log(state, g.name .. " renforce ses alliés de 2 bouclier.", "foe")
    end
  end

  -- Provocation décroît APRÈS le tirage de cible ci-dessus (2026-08-28,
  -- clarification explicite -- "décroit juste après l'application de l'effet,
  -- vers le début du tour") : ce tirage doit encore voir la valeur PLEINE pour
  -- CE tour, la décroissance ne doit affecter que le suivant.
  for _, h in ipairs(state.heroes) do
    if h.hp > 0 and (h.provocation or 0) > 0 then h.provocation = h.provocation - 1 end
  end

  Game.snapshot_turn(state)
  local drawn = Game.fill_hand_with_bonus_draws(state)

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
  if state.energy < Combat.effective_cost(hero, def) then return false end
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
  if not hero then state.pending = nil; return end
  local cost = Combat.effective_cost(hero, def)
  if state.energy < cost or (def.mana_cost and (hero.mana or 0) < def.mana_cost) then
    state.pending = nil; return
  end

  local target = nil
  if def.target == "enemy" or (def.target == "conditional" and kind == "enemy")
    or (def.target == "enemy-or-ally" and kind == "enemy") then
    if kind ~= "enemy" then return end
    target = Combat.enemy_by_id(state, target_id)
    if not target or target.hp <= 0 then return end
  elseif def.target == "ally" or (def.target == "enemy-or-ally" and kind == "ally") then
    if kind ~= "ally" then return end
    target = Combat.hero_by_id(state, target_id)
    if not target or target.hp <= 0 then return end
  elseif def.target == "self" or (def.target == "conditional" and kind == "self") then
    target = hero
  end
  -- def.target == "all-enemies" : target reste nil, l'effet itère living_enemies() lui-même.

  state.energy = state.energy - cost
  if def.mana_cost then
    hero.mana = hero.mana - def.mana_cost
    -- "Second Souffle" (2026-09-03, Enchantement du Mage -- hero.second_souffle) :
    -- CHAQUE fois que le Mage tombe à 0 mana (jamais négatif, voir
    -- Combat.can_play qui bloque déjà toute carte trop coûteuse) -- répétable,
    -- sans plafond, explicitement à l'ESSAI (2026-09-03, "pour l'instant") --
    -- à rééquilibrer si besoin plus tard, garder cette note tant que ce statut
    -- expérimental n'a pas été confirmé/révisé par le porteur de projet.
    if hero.mana == 0 and hero.second_souffle then
      hero.mana = hero.mana + hero.second_souffle
      Combat.log(state, hero.name .. " (Second Souffle) regagne " .. hero.second_souffle .. " mana.", "power")
    end
  end
  -- Coût variable en Corruption (2026-08-29, Nécromancien -- "1 (+X, 0-N
  -- Corruption)") : X = tout ce que le héros peut fournir jusqu'au plafond
  -- `def.corruption_cost_cap`, déduit ICI (jamais un choix du joueur, jamais
  -- une case à cocher) -- exposé à l'effet via `ctx.corruption_spent`, calculé
  -- une seule fois avant l'effet (pas recalculé si l'effet touche la
  -- Corruption entre-temps, ex. Pacte funeste -- ce champ est un instantané
  -- au moment où la carte se résout).
  local corruption_spent = 0
  if def.corruption_cost_cap then
    corruption_spent = math.min(hero.corruption or 0, def.corruption_cost_cap)
    -- Ne jamais dépenser plus de Corruption que nécessaire pour revenir à PV
    -- max (2026-09-02, demande explicite -- "Rite mineur"/"Communion des
    -- morts" utilisaient TOUJOURS le maximum disponible même déjà proches de
    -- PV max). Opt-in via `def.heal_per_corruption` (X PV rendus par point de
    -- Corruption dépensé) -- laisse "Servant d'os" (dégâts, pas de ce champ)
    -- intact malgré le même `corruption_cost_cap`.
    if def.heal_per_corruption then
      local room = math.max(0, (hero.max_hp or hero.hp) - hero.hp)
      local max_useful = math.ceil(room / def.heal_per_corruption)
      corruption_spent = math.min(corruption_spent, max_useful)
    end
    hero.corruption = (hero.corruption or 0) - corruption_spent
  end
  local ctx = { state = state, hero = hero, target = target, card_def = def, corruption_spent = corruption_spent }
  def.effect(ctx)
  -- "Encore" (2026-08-29, carte "Bis" du Barde -- hero.encore_extra_plays) :
  -- rejoue le MÊME effet, avec le MÊME ctx, autant de fois que la charge
  -- l'indique -- consommée AVANT la boucle pour ne jamais se déclencher sur
  -- elle-même. `ctx.inspiration_consumed` reste partagé entre les répétitions
  -- (voir consume_inspiration, combat.lua) : le bonus d'Inspiration éventuel
  -- ne s'applique qu'une fois au total, jamais une fois par répétition.
  local extra_plays = hero.encore_extra_plays
  if extra_plays and extra_plays > 0 then
    hero.encore_extra_plays = nil
    for _ = 1, extra_plays do def.effect(ctx) end
    Combat.log(state, def.name .. " se déclenche " .. extra_plays .. " fois de plus (Encore).", "power")
  end
  Game.on_card_played(state, hero, def)
  Game.apply_memoire_melodique(state, hero, pending.uid)
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
  if (hero.gratuite or 0) > 0 then hero.gratuite = hero.gratuite - 1 end
  -- Frénésie (2026-09-03, Enchantement du Guerrier -- hero.frenesie_step) :
  -- CHAQUE carte Offensive du Guerrier jouée incrémente le bonus de dégâts
  -- pour la PROCHAINE (pas celle-ci -- elle vient de se résoudre avec la
  -- valeur PRÉCÉDENTE, voir Combat.damage_multiplier) -- une carte de zone
  -- (Coup de taille) ne compte que pour +1, quel que soit le nombre
  -- d'ennemis touchés, puisque cette fonction se déclenche 1 SEULE fois par
  -- carte jouée, jamais par cible touchée -- tranché explicitement par le
  -- porteur de projet.
  if hero.frenesie_step and def_has_type(def, "offensive") then
    hero.frenesie_bonus_pct = (hero.frenesie_bonus_pct or 0) + hero.frenesie_step
  end
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

--- Def clonée avec cost=0 (2026-08-28, carte "Avalanche de coups" -- "son
-- coût devient 0") : JAMAIS `instance.def.cost = 0` en place -- toutes les
-- instances non-améliorées d'une même carte partagent le même def (voir
-- Cards.list/Cards.upgraded_def, même raison d'être que ce dernier), muter
-- directement rendrait TOUTE carte du même code gratuite, y compris dans un
-- futur run. Même idiome que Cards.upgraded_def : clone superficiel, un seul
-- champ changé, `code` préservé (Cards.by_code continue de fonctionner).
local function zero_cost_def(def)
  local d = {}
  for k, v in pairs(def) do d[k] = v end
  d.cost = 0
  return d
end

--- "Mémoire mélodique" (2026-09-03, Enchantement du Barde --
-- hero.memoire_melodique) : CHAQUE carte Barde jouée (donc `hero.class_id ==
-- "barde"` suffit -- un héros ne joue jamais que les cartes de sa propre
-- classe, voir Game.select_card) rend gratuite, jusqu'à la fin du tour, UNE
-- carte au hasard parmi le RESTE de la main -- jamais la carte tout juste
-- jouée elle-même, encore présente dans `state.hand` à cet instant précis
-- (Game.finish_card ne la retire qu'ENSUITE, voir Game.resolve_pending) --
-- exclue explicitement via `played_uid`. Réutilise `zero_cost_def` ci-dessus
-- comme Avalanche de coups, mais le uid rejoint `state.turn_free_uids`
-- plutôt que de compter sur `reset_temporary_card_state` à la prochaine
-- ENTRÉE EN COMBAT -- revenue à son coût normal au tour SUIVANT (voir
-- Game.start_turn), pas au combat suivant : mécanisme parallèle assumé, pas
-- une pure réutilisation (collision théorique avec un "coût 0" permanent
-- d'Avalanche de coups sur LA MÊME copie de carte non gérée -- combo assez
-- rare, Guerrier ET Barde requis dans la même main, pour être laissée de
-- côté pour l'instant).
function Game.apply_memoire_melodique(state, hero, played_uid)
  if not (hero.memoire_melodique and hero.class_id == "barde") then return end
  local candidates = {}
  for _, c in ipairs(state.hand) do
    if c.uid ~= played_uid then candidates[#candidates + 1] = c end
  end
  if #candidates == 0 then return end
  local pick = candidates[state.rng.enchantment:random(#candidates)]
  pick.def = zero_cost_def(pick.def)
  state.turn_free_uids[pick.uid] = true
  Combat.log(state, pick.def.name .. " devient gratuite ce tour-ci (Mémoire mélodique).", "power")
end

--- Équivalent finishCard : retire la carte de la main vers défausse/main/dessus
-- du deck/zone "Amnésie" selon ce que l'effet a demandé (ctx.return_to_hand /
-- return_to_deck_top / carte taguée "amnesie", voir cards.lua -- Clairvoyance
-- / "L'Amnésique", malédiction -- TOUTES les cartes de l'aventurier maudit,
-- voir ctx.hero.force_amnesie ci-dessous).
-- `ctx.zero_cost` (2026-08-28, "Avalanche de coups") : appliqué à CETTE
-- instance précise avant de la router, quelle que soit sa destination finale
-- (main si elle vient de tuer sa cible, sinon défausse) -- temporaire pour
-- cette copie de carte (2026-09-02, revirement -- voir
-- reset_temporary_card_state ci-dessus, appelée par Game.start_next_combat/
-- start_boss_combat au moment où les cartes du combat précédent sont
-- reprises dans le nouveau deck).
function Game.finish_card(state, pending, ctx)
  local idx
  for i, c in ipairs(state.hand) do
    if c.uid == pending.uid then idx = i break end
  end
  if idx then
    local card = table.remove(state.hand, idx)
    if ctx and ctx.zero_cost then card.def = zero_cost_def(card.def) end
    local forced_amnesie = ctx and ctx.hero and ctx.hero.force_amnesie
    if (ctx and ctx.card_def and def_has_cat(ctx.card_def, "amnesie")) or forced_amnesie then
      -- "Disparait pour le reste du combat" (2026-08-28) : jamais en défausse,
      -- jamais repiochable avant le combat suivant -- voir Game.start_next_combat/
      -- start_boss_combat, seuls endroits qui repêchent `state.exhausted`.
      state.exhausted[#state.exhausted + 1] = card
    elseif ctx and ctx.return_to_hand then
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
      -- "La Renaissante" (2026-08-29) : même garde-fou que Combat.deal_damage
      -- (voir son commentaire) -- le saignement ne passe pas par cette
      -- fonction, dupliqué ici volontairement plutôt qu'un détour par combat.lua.
      if h.hp <= 0 and h.death_ward then
        h.hp = 1
        h.death_ward = false
        Combat.log(state, h.name .. " aurait dû mourir du saignement, mais reste debout à 1 PV !", "power")
      end
      Combat.log(state, h.name .. " saigne : " .. dmg .. " dégâts.", "foe")
      h.saignements = h.saignements - 1
    end
  end
  Game.sync_camoufle_visibility(state) -- un héros peut mourir du saignement
end

-- "Brûlure" (2026-09-01, nouveau statut transversal, Volcan -- demande
-- explicite : "inflige X dégâts à chaque tour. Ne réduit pas à la fin du
-- tour.") : calquée sur Game.tick_bleed ci-dessus, SANS la ligne de
-- décrément -- la seule vraie différence entre les deux mécaniques. Reste
-- délibérément en dehors de Game.decay_end_of_turn_statuses, exactement comme
-- le Saignement (décrémenté ici, pas là-bas) -- jamais de décroissance
-- automatique pour Brûlure, nulle part.
function Game.tick_burn(state)
  for _, e in ipairs(state.enemies) do
    if e.hp > 0 and (e.brulure or 0) > 0 then
      local dmg = e.brulure
      e.hp = e.hp - dmg
      Combat.log(state, e.name .. " brûle : " .. dmg .. " dégâts.", "sys")
    end
  end
  for _, h in ipairs(state.heroes) do
    if h.hp > 0 and (h.brulure or 0) > 0 then
      local dmg = h.brulure
      h.hp = h.hp - dmg
      if h.hp <= 0 and h.death_ward then
        h.hp = 1
        h.death_ward = false
        Combat.log(state, h.name .. " aurait dû mourir de la brûlure, mais reste debout à 1 PV !", "power")
      end
      Combat.log(state, h.name .. " brûle : " .. dmg .. " dégâts.", "foe")
    end
  end
  Game.sync_camoufle_visibility(state) -- un héros peut mourir de la brûlure
end

-- Retourne `true` si le coup a réellement touché, `false` s'il a été esquivé
-- ou n'avait pas de cible valide (2026-09-02, bug signalé -- "l'esquive
-- permet d'éviter les dégâts d'une attaque mais aussi tous les autres effets
-- négatifs, saignement/vulnérabilité/etc.") : avant, cette valeur de retour
-- n'existait pas, donc les bolt-ons `move.bleed`/`move.burn`/`move.lands`
-- (voir le kind "dmg" plus bas) s'appliquaient quand même après une esquive
-- -- seuls les DÉGÂTS PURS étaient bien annulés. L'appelant doit désormais
-- vérifier cette valeur avant d'appliquer quoi que ce soit d'autre.
local function resolve_enemy_attack(state, e, amount, brut)
  local target = Combat.hero_by_id(state, e.target_hero_id)
  if not target or target.hp <= 0 then return false end
  if (target.esquive or 0) > 0 then
    target.esquive = target.esquive - 1
    Combat.log(state, e.name .. " utilise " .. e.next_move.name .. " sur " .. target.name .. "… esquivé !", "sys")
    return false
  end
  -- source_unit = e (pas source_hero, qui reste nil pour garder le texte/la
  -- couleur "foe" du journal) : la propre Incapacité de l'ennemi qui frappe
  -- doit réduire SES dégâts -- jusqu'ici jamais lue nulle part (bug signalé,
  -- 2026-08-09 -- Lâcheté pose bien Incapacité sur un ennemi, mais rien n'en
  -- tenait compte à la résolution).
  Combat.deal_damage(state, nil, target, amount, "physique", nil, { brut = brut, source_unit = e })
  return true
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
      -- Esquive (2026-09-02, bug signalé -- "l'esquive permet d'éviter... les
      -- effets négatifs, saignement/vulnérabilité/etc.") : ce kind n'avait
      -- jamais vérifié Esquive, contrairement au kind "dmg" (voir
      -- resolve_enemy_attack) -- un statut comme la Malédiction du
      -- Nécromancien Novice touchait donc TOUJOURS sa cible, esquive ou pas.
      -- Même message/décompte que resolve_enemy_attack, pour un comportement
      -- identique quel que soit le kind du coup.
      if (target.esquive or 0) > 0 then
        target.esquive = target.esquive - 1
        Combat.log(state, e.name .. " utilise " .. move.name .. " sur " .. target.name .. "… esquivé !", "sys")
      else
        target[move.status_key] = (target[move.status_key] or 0) + move.amount
        local label = Enemies.status_labels[move.status_key] or move.status_key
        local msg = e.name .. " inflige " .. label .. " " .. move.amount
        -- status_key2/amount2 (optionnel, 2026-09-01, Nécromancien Novice/
        -- Élémentaire de Cendre -- "Malédiction"/"Souffle Étouffant" posent
        -- désormais 2 statuts d'un coup) : même mutation directe, un 2ᵉ champ
        -- plutôt qu'une liste, pour rester un simple ajout au-dessus du champ
        -- existant sans jamais avoir plus de 2 statuts à gérer.
        if move.status_key2 then
          target[move.status_key2] = (target[move.status_key2] or 0) + move.amount2
          local label2 = Enemies.status_labels[move.status_key2] or move.status_key2
          msg = msg .. " et " .. label2 .. " " .. move.amount2
        end
        Combat.log(state, msg .. " à " .. target.name .. ".", "foe")
      end
    end
  elseif move.kind == "buff-self" then
    -- Générique, PAS spécifique à l'Aigle Géant malgré son seul usage actuel
    -- (2026-08-30, "Envol") : même mutation directe que "debuff" ci-dessus
    -- (jamais Combat.apply_status, réservée aux effets de CARTE -- voir son
    -- commentaire dans combat.lua) -- un futur ennemi qui se buffe lui-même
    -- réutilise ce kind tel quel, sans repasser par ici.
    e[move.status_key] = (e[move.status_key] or 0) + move.amount
    Combat.log(state, e.name .. " " .. (move.log_text or "se transforme") .. ".", "foe")
    -- `dmg_all_amount` (optionnel, 2026-08-30, demande explicite -- "Envol
    -- doit faire des dégâts faibles sur tous les aventuriers") : même
    -- résolution que le kind "dmg-all" ci-dessous (Onde Sylvestre), juste
    -- greffée sur ce buff plutôt qu'un kind séparé -- un statut ET des
    -- dégâts à toute l'équipe, dans le MÊME move.
    if move.dmg_all_amount then
      resolve_enemy_attack_all(state, e, move.dmg_all_amount)
    end
  elseif move.kind == "dmg" then
    -- Bolt-ons (bleed/burn) gardés par `landed` (2026-09-02, bug signalé --
    -- "l'esquive permet d'éviter... les effets négatifs, saignement/
    -- vulnérabilité/etc.") : resolve_enemy_attack renvoie désormais si le
    -- coup a vraiment touché -- avant, ces 2 blocs s'exécutaient
    -- inconditionnellement même après un "esquivé !" (seuls les dégâts purs,
    -- gérés DANS resolve_enemy_attack, étaient bien annulés).
    local landed = resolve_enemy_attack(state, e, move.amount, move.brut)
    if landed and move.bleed then
      local target = Combat.hero_by_id(state, e.target_hero_id)
      if target and target.hp > 0 then target.saignements = (target.saignements or 0) + move.bleed end
    end
    -- move.burn (2026-09-01, Cracheur de Braise -- "Brûlure") : même bolt-on
    -- que move.bleed juste au-dessus, sur le champ h.brulure/e.brulure --
    -- jamais décrémenté automatiquement (voir Game.tick_burn), contrairement
    -- au Saignement.
    if landed and move.burn then
      local target = Combat.hero_by_id(state, e.target_hero_id)
      if target and target.hp > 0 then target.brulure = (target.brulure or 0) + move.burn end
    end
    -- "Charge en Piqué" de l'Aigle Géant (2026-08-30, `move.lands`) : générique
    -- comme "buff-self" ci-dessus -- un coup qui "atterrit" annule "Vol" (ou
    -- tout futur statut similaire), quel que soit l'ennemi qui le porte.
    -- PAS gardé par `landed` (2026-09-02) : "atterrir" décrit l'AIGLE
    -- lui-même (il redescend au sol), pas un effet sur le héros -- il
    -- atterrit qu'il ait touché ou non.
    if move.lands then e.vol = 0 end
  elseif move.kind == "dmg-all" then
    resolve_enemy_attack_all(state, e, move.amount)
  elseif move.kind == "revive" then
    -- Généralisé (2026-09-01, demande explicite -- Prêtre Déchu doit relever
    -- Squelette Archer/Garde-Ossements, pas seulement les Pousses d'Arbre de
    -- l'Homme Arbre) : `move.revive_template_ids` (liste) remplace le
    -- `template_id == "pousse"` codé en dur -- l'Homme Arbre porte désormais
    -- `revive_template_ids = { "pousse" }` sur son propre move (voir
    -- enemies.lua), même mécanique, plus rien de spécifique à lui ici.
    local wanted = {}
    for _, id in ipairs(move.revive_template_ids or {}) do wanted[id] = true end
    local revived = 0
    for _, o in ipairs(state.enemies) do
      if wanted[o.template_id] and o.hp <= 0 then
        o.hp = o.max_hp
        revived = revived + 1
      end
    end
    if revived > 0 then
      Combat.log(state, e.name .. " ramène " .. revived .. " alliés à la vie.", "foe")
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
-- Puissance rejoint ce groupe (2026-09-02, demande explicite -- "la puissance
-- descend à la fin de chaque tour, que ce soit pour les aventuriers ou les
-- ennemis") : avant, seuls les héros la perdaient, et en DÉBUT de tour (voir
-- Game.start_turn) -- désormais symétrique aux deux côtés et à la même étape
-- qu'Incapacité/Vulnérabilité. Incandescence (nouveau statut, Volcan, "marche
-- comme la Puissance sauf qu'elle ne descend pas") reste VOLONTAIREMENT
-- absente d'ici, même traitement que Vol/Brûlure -- jamais décrémentée
-- automatiquement, seul un effet explicite peut la retirer.
function Game.decay_end_of_turn_statuses(state)
  for _, h in ipairs(state.heroes) do
    if (h.incapacite or 0) > 0 then h.incapacite = math.max(0, h.incapacite - 1) end
    if (h.vulnerabilite or 0) > 0 then h.vulnerabilite = math.max(0, h.vulnerabilite - 1) end
    if (h.puissance or 0) > 0 then h.puissance = math.max(0, h.puissance - 1) end
    -- Inspiration (2026-08-29, Barde) : -1 automatique en fin de tour, EN PLUS
    -- de la consommation à l'usage (consume_inspiration, combat.lua) --
    -- "Dernier rappel" protège cette décroissance auto pour N tours
    -- (h.inspiration_shielded_turns), sans jamais toucher la consommation à
    -- l'usage. "Encore" (h.encore_extra_plays, carte "Bis") : NE se perd PLUS
    -- en fin de tour (2026-09-02, simplification explicite du glossaire --
    -- persiste jusqu'à consommation par la prochaine carte jouée, voir
    -- Game.resolve_pending, seul autre endroit qui le touche).
    if (h.inspiration_shielded_turns or 0) > 0 then
      h.inspiration_shielded_turns = h.inspiration_shielded_turns - 1
    elseif (h.inspiration or 0) > 0 then
      h.inspiration = h.inspiration - 1
    end
  end
  for _, e in ipairs(state.enemies) do
    if (e.incapacite or 0) > 0 then e.incapacite = math.max(0, e.incapacite - 1) end
    if (e.vulnerabilite or 0) > 0 then e.vulnerabilite = math.max(0, e.vulnerabilite - 1) end
    if (e.puissance or 0) > 0 then e.puissance = math.max(0, e.puissance - 1) end
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

-- "PO" gagnées à la victoire (2026-09-02, demande explicite -- "calculée en
-- fonction des ennemis vaincus, nombre et niveaux") : réutilise le coût déjà
-- calibré par ennemi (Enemies.cost_at_level, la même donnée qui pilote le
-- budget de rencontre -- déjà "nombre × difficulté par niveau") plutôt qu'une
-- formule séparée à recalibrer de zéro. Ratio 0.5 explicitement en
-- placeholder à ajuster en playtest (même convention que
-- Encounter.BUDGET_GROWTH/Enemies.LEVEL_GROWTH, déjà commentés ainsi).
-- Appelée une fois la victoire acquise -- `state.enemies` contient encore
-- les ennemis du combat qui vient d'être gagné (tous morts), pas encore
-- écrasé par le prochain (voir Controller:enter_victory_screen, appelée
-- avant tout Game.start_next_combat/start_boss_combat).
function Game.compute_gold_reward(state)
  local total = 0
  for _, e in ipairs(state.enemies) do
    local template = Enemies.by_id(e.template_id)
    if template then total = total + Enemies.cost_at_level(template, e.level) end
  end
  return Enemies.round(total * 0.5)
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
