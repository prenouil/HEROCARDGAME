-- Colle la UI au moteur de règles pur (src/rules) et au séquenceur (src/util).
-- Tout ce qui est "attendre 1s entre deux ennemis", "montrer l'écran de draft",
-- "revenir au village après une défaite" vit ici — jamais dans src/rules.

local Game = require("src.rules.game")
local Combat = require("src.rules.combat")
local Draft = require("src.rules.draft")
local Forge = require("src.rules.forge")
local Temple = require("src.rules.temple")
-- Écran "Choisis ton équipe" (2026-08-29, avant chaque run -- voir
-- Controller:enter_team_select) : catalogue des 6 aventuriers débloqués
-- (Heroes.defs) et leurs cartes (Cards.list, filtrées par class_id).
local Heroes = require("src.data.heroes")
local Cards = require("src.data.cards")
local Sequencer = require("src.util.sequencer")
-- Dépendance à la UI (rects de layout, purs -- aucun appel love.graphics dedans)
-- nécessaire pour savoir D'OÙ une carte part visuellement quand elle est piochée
-- ou défaussée ; voir View.hand_rects_for/deck_pile_rect/discard_pile_rect.
local View = require("src.ui.view")
local Sfx = require("src.ui.sfx")
-- Uniquement pour les couleurs des particules de cendres/étincelles
-- (2026-08-28, voir Controller:spawn_ash) -- draw_particles (view.lua) reste
-- l'unique endroit qui dessine réellement, ce module ne fait que choisir la
-- teinte à leur passer.
local Theme = require("src.ui.theme")

local Controller = {}
Controller.__index = Controller

local ANIM_PULSE = 0.38 -- s, calque sur les 380ms de pulseUp/pulseDown du prototype
local ANIM_SHAKE = 1.0  -- s, calque sur les 1000ms de shakeUnit
local HOVER_DELAY = 1.0 -- s, calque sur le délai d'infobulle du prototype
local ENEMY_STEP_WAIT = 1.0 -- s, calque sur le sleep(1000) entre chaque ennemi
local FLIGHT_DURATION = 0.38 -- s, calque sur FLIGHT_MS (380ms) du prototype -- utilisé
-- UNIQUEMENT par la défausse d'une carte tout juste jouée (maybe_animate_played_discard,
-- geste fréquent en cours de tour, doit rester vif) ; la pioche et la défausse de fin de
-- tour ont chacune leur propre rythme plus lent ci-dessous (2026-08-21, séquence d'onboarding).

-- Séquence de début/fin de tour redécoupée en étapes lisibles (2026-08-21,
-- demande explicite -- onboarding) : chaque beat attend le précédent plutôt que
-- de se chevaucher, pour que le regard du joueur puisse suivre "énergie -> pioche
-- -> aventuriers prêts" en début de tour, et "défausse -> (pause) -> monstres" en
-- fin de tour.
local TURN_ENERGY_ANIM_DURATION = 0.9 -- s -- le gros chiffre d'énergie qui se pose sur sa pastille (accentué 2026-08-21, voir ENERGY_TURN_ANIM_START_SCALE côté view.lua)
local DRAW_FLIGHT_STAGGER = 0.11 -- s entre deux cartes piochées en DÉBUT DE TOUR -- plus lent que l'ancien DRAW_STAGGER
local DRAW_FLIGHT_DURATION = 0.5 -- s -- vol de pioche, plus lent que FLIGHT_DURATION, avec petit rebond d'arrivée (voir ease_out_back côté view.lua)
local HERO_READY_STAGGER = 0.15 -- s entre le saut "prêt" de chaque aventurier vivant, gauche à droite
local END_TURN_DISCARD_STAGGER = 0.09 -- s entre deux cartes défaussées en FIN DE TOUR -- plus lent que l'ancien DISCARD_STAGGER
local END_TURN_DISCARD_FLIGHT_DURATION = 0.48 -- s -- vol de défausse de fin de tour, plus lent que FLIGHT_DURATION
local END_TURN_TO_ENEMY_RESOLUTION_PAUSE = 1.0 -- s -- pause dédiée entre la fin de la défausse et le début de la résolution des monstres, pour ne jamais les confondre visuellement
local ENEMY_TELEGRAPH_TO_ACTION_DELAY = 0.2 -- s entre le saut/télégraphe d'un monstre et l'action qui touche réellement sa cible

-- Remélange défausse -> pioche (2026-08-21, demande explicite) : quelques
-- "fantômes" de carte (pas de face précise -- ce sont des cartes anonymes
-- qui repartent mélangées, montrer LAQUELLE serait trompeur) volent de la
-- défausse vers la pioche pour rendre l'événement visible, plutôt qu'un
-- remélange silencieux. Voir Controller:animate_reshuffle.
local RESHUFFLE_GHOST_COUNT = 3
local RESHUFFLE_GHOST_STAGGER = 0.08
local RESHUFFLE_GHOST_FLIGHT_DURATION = 0.42
local RESHUFFLE_TOTAL_DURATION = (RESHUFFLE_GHOST_COUNT - 1) * RESHUFFLE_GHOST_STAGGER + RESHUFFLE_GHOST_FLIGHT_DURATION

-- Séquence d'entrée sur l'écran de draft (2026-08-08, demande explicite) :
-- 1) titre "Victoire !" en zoom + bump (≤2s) -- rien d'autre à l'écran ;
-- 2) SEULEMENT ENSUITE, les 3 cartes apparaissent de dos, toutes ensemble ;
-- 3) 1s de pause cartes de dos ;
-- 4) retournement une par une, lentement, avant de laisser la main au joueur
--    (une carte n'est cliquable qu'une fois SON retournement terminé).
-- Durées exposées sur `self` (pas de constante dupliquée côté view.lua, qui
-- n'a pas accès à ce module -- controller.lua dépend déjà de view.lua, jamais
-- l'inverse, voir note d'architecture sur les animations de vol de carte).
local VICTORY_TITLE_DURATION = 1.4
local DRAFT_FACEDOWN_PAUSE = 1.0
local DRAFT_FLIP_DURATION = 0.5
local DRAFT_FLIP_GAP = 0.2 -- pause entre la fin d'un retournement et le début du suivant
local BOSS_VICTORY_HOLD_DURATION = 2.2 -- s -- temps où "Boss vaincu !" reste affiché avant le retour au menu

-- Écrans "La Forge"/"Le Temple" (2026-08-28, demande explicite -- remplacent
-- l'ancien écran "feuDeCamp" unique, voir Controller:enter_post_combat_sequence) :
-- entre le draft de fin de combat et le combat suivant, s'intercalent de façon
-- transparente (n'avancent jamais le budget de difficulté). Chacun apparaît de
-- façon INDÉPENDANTE et ALÉATOIRE (voir POST_COMBAT_FORGE_CHANCE/TEMPLE_CHANCE),
-- jamais plus d'une fois chacun pour un même combat gagné -- 0, 1 ou 2 écrans
-- avant le combat suivant. Petite pause après un choix pour laisser le temps à
-- l'animation/au son de se voir avant l'étape suivante.
local POST_COMBAT_RESOLVE_PAUSE = 0.6
-- Placeholders à ajuster en playtest (2026-08-28) -- indépendantes l'une de
-- l'autre : les 4 issues ("ni l'un ni l'autre", "Forge seule", "Temple seul",
-- "les deux") sont donc toutes possibles, pas seulement les 3 citées explicitement.
local POST_COMBAT_FORGE_CHANCE = 0.4
local POST_COMBAT_TEMPLE_CHANCE = 0.4

-- Choix "amélioration" à la Forge (2026-08-11, demande explicite -- adapté au
-- 2026-08-28 pour 1 carte choisie parmi jusqu'à 4, plus 2 cartes systématiques) :
-- les 3 autres propositions ET la carte de base de celle choisie disparaissent
-- en fondu pendant que sa version améliorée se recentre dans la case centrale,
-- PUIS 1s de pause (carte déjà réglée, juste le temps de la lire) avant
-- d'enchaîner sur l'étape suivante -- remplace la pause générique
-- POST_COMBAT_RESOLVE_PAUSE sur ce chemin précis.
local FORGE_UPGRADE_ANIM_DURATION = 0.5
local FORGE_UPGRADE_HOLD_PAUSE = 1.0

-- Choix au Temple (2026-08-29, refonte -- "après le choix, les statues non
-- choisies fade et laisse la place à celle choisie, avec l'indication 'Bonne
-- chance ...'") : même timing que la Forge ci-dessus, même raison d'être
-- (laisser le joueur voir/lire le résultat avant d'enchaîner).
local TEMPLE_CHOICE_ANIM_DURATION = 0.5
local TEMPLE_CHOICE_HOLD_PAUSE = 1.0

-- Écran "Choisis ton équipe" (2026-08-29, demande explicite -- avant chaque
-- run, choisir 4 des 6 `Heroes.defs`) : durée du vol des cartes du héros mis
-- en avant, entrant OU sortant (même durée dans les 2 sens, voir
-- Controller:team_select_spawn_cards/team_select_fly_out_current) -- SAUF le
-- rassemblement vers le deck (voir TEAM_CARD_GATHER_* plus bas), qui a son
-- propre rythme, plus lent.
local TEAM_CARD_FLY_DURATION = 0.4
local TEAM_CARD_SIDES = { "left", "right", "top", "bottom" }
-- Déplacement d'un PORTRAIT de héros (2026-08-30, demande explicite --
-- "quand je sélectionne un aventurier, il se déplace sur le côté droit, le
-- déplacement est visible" / "quand je valide, il se déplace en bas") : plus
-- lent que le vol des cartes, un personnage a plus de "poids" visuel qu'une carte.
local TEAM_HERO_MOVE_DURATION = 0.45
-- "Quand on sélectionne [valide] un aventurier, le mouvement vers le groupe
-- du bas doit être plus lent... Par contre, pour retirer un aventurier, on
-- ne change pas la vitesse actuelle" (2026-08-30, demande explicite) : un
-- 2ᵉ rythme, UNIQUEMENT pour Controller:team_select_confirm quand il AJOUTE
-- (jamais quand il retire, qui garde TEAM_HERO_MOVE_DURATION ci-dessus,
-- jamais non plus pour team_select_focus/team_select_cancel).
local TEAM_HERO_MOVE_DURATION_SLOW = 0.9
-- "Les cartes doivent rejoindre le deck une par une, plus lentement"
-- (2026-08-30, demande explicite) : durée de vol individuelle allongée
-- (0.4 -> 0.7) PLUS un décalage croissant entre chaque carte -- voir
-- Controller:team_select_fly_out_current(gather_target), déclenché
-- uniquement par une VALIDATION qui ajoute (jamais un retrait, jamais
-- Annuler/changement de focus, qui gardent un envol groupé instantané).
local TEAM_CARD_GATHER_DURATION = 0.7
local TEAM_CARD_GATHER_STAGGER = 0.12
-- "J'adore le son des cartes qui vont dans le deck. Je voudrais le même
-- quand elles arrivent à l'écran et quand elles en partent" (2026-08-30),
-- puis corrigé aussitôt après ("c'était une erreur... pas 6 fois, 2-3 fois,
-- sinon ça surcharge -- par contre c'est très bien pour le deck") : contraste
-- volontaire avec le rassemblement vers le deck (1 "flup" PAR carte, décalé
-- -- voir TEAM_CARD_GATHER_STAGGER, gardé tel quel) -- ici les 6 cartes
-- s'envolent toutes EN MÊME TEMPS (aucun décalage visuel), donc seulement
-- TEAM_CARD_BURST_COUNT flups en rafale suffisent à évoquer le mouvement,
-- sans le surcharger -- voir Controller:team_select_play_card_burst.
local TEAM_CARD_BURST_COUNT = 3
local TEAM_CARD_BURST_STAGGER = 0.07

-- VFX de lisibilité (2026-08-09, party "amélioration des visuels") : tous
-- dérivés du même mécanisme de diff avant/après déjà en place pour la
-- secousse (voir Controller:react_to_diff, ex-shake_from_diff), pas de
-- nouveau point d'accroche dans src/rules.
local FLOATER_DURATION = 0.9 -- s -- nombre de dégâts/soin flottant
local PARTICLE_DURATION = 0.45 -- s -- petit burst de pixels à l'impact
local PARTICLE_COUNT = 6
local STATUS_POP_DURATION = 0.35 -- s -- pop d'échelle d'un badge de statut à son application
local SHIELD_FX_DURATION = 1.0 -- s -- gros bouclier en fondu sur un gain de Défense
-- "Amnésie" (2026-08-28, demande explicite) : durée du rétrécissement/fondu
-- sur place d'une carte qui se disperse en cendres, voir
-- Controller:play_amnesie_vanish -- plus long que PARTICLE_DURATION pour que
-- les cendres (dessinées avec le même controller.particles/particle_duration)
-- aient le temps de retomber pendant que la carte s'efface.
local ASH_DISSOLVE_DURATION = 0.5
local ASH_PARTICLE_COUNT = 10
-- "Furtif" (2026-08-28, demande explicite) : petit nuage de particules
-- teinté Discrétion quand une carte Furtif restée en main se défausse en fin
-- de tour (voir Controller:animate_discard_snapshot) -- bien moins de
-- particules que les cendres d'Amnésie, un simple accent visuel synchronisé
-- avec le flottant de Discrétion (voir Controller:react_to_diff).
local FURTIF_SPARKLE_COUNT = 5
-- Champs de statut comparés avant/après pour déclencher le pop.
local STATUS_KEYS = { "defense", "esquive", "saignements", "incapacite", "vulnerabilite", "puissance", "camoufle", "provocation" }

function Controller.new()
  local self = setmetatable({}, Controller)
  self.state = Game.new_state()
  self.seq = Sequencer.new()
  self.screen = "menu" -- "menu" | "options" | "team_select" | "playing" | "draft" | "forge" | "temple" | "bossVictory" | "defeat"
  -- Mode de run choisi au menu (2026-08-21, demande explicite) : "infini"
  -- (illimité, l'ancien comportement par défaut), "bounded" (5 combats puis
  -- l'Homme Arbre, voir Controller:advance_to_next_combat/Game.start_boss_combat)
  -- ou "boss_test" (combat isolé contre le boss, voir
  -- Controller:start_boss_test -- une victoire ramène au menu plutôt que
  -- d'enchaîner un faux combat suivant). nil tant qu'aucun run n'a encore
  -- démarré (écran "menu").
  self.run_mode = nil
  -- Dernière équipe lancée avec succès (2026-08-29, écran de choix
  -- d'équipe) : liste de 4 ids -- reconduite par "Rejouer" après une défaite
  -- (voir restart_after_defeat, input.lua) sans repasser par l'écran de
  -- sélection, même logique de confort que self.run_mode. nil tant qu'aucune
  -- run n'a encore été lancée via cet écran (Heroes.DEFAULT_PARTY_IDS sert
  -- alors de repli, voir Controller:reset_run).
  self.last_selected_ids = nil
  -- { mode, available_ids = {id,...}, selected_ids = {id,...}, focused_id,
  -- card_anims = {{def, from, to, elapsed, duration, mode="in"|"out"}, ...} },
  -- voir Controller:enter_team_select.
  self.team_select = nil
  self.draft_picks = nil
  -- File des écrans "camp" restant à montrer après le combat qui vient d'être
  -- gagné (2026-08-28) -- {"forge"}/{"temple"}/{"forge","temple"}/{} selon les
  -- tirages de Controller:enter_post_combat_sequence ; consommée un élément à
  -- la fois par Controller:advance_post_combat_queue.
  self.post_combat_queue = {}
  self.forge = nil -- { choices = {instance,...}, resolved = bool|nil }, voir enter_forge_screen
  self.forge_upgrade_anim = nil -- { chosen_index, base_def, t = elapsed }, voir choose_forge_card
  self.forge_upgrade_anim_duration = FORGE_UPGRADE_ANIM_DURATION -- lu par view.lua pour l'easing
  -- { type = "blessing"|"curse", choices = {effect,...}, eligible = {hero,...},
  -- chosen_effect_index = nil|int, chosen_hero_id = nil|id, resolved = bool|nil },
  -- voir Controller:enter_temple_screen (2026-08-29, refonte complète).
  self.temple = nil
  self.temple_choice_anim = nil -- { chosen_index, t = elapsed }, voir Controller:confirm_temple_choice
  self.temple_choice_anim_duration = TEMPLE_CHOICE_ANIM_DURATION -- lu par view.lua pour l'easing
  self.victory_anim = nil -- { t = elapsed } pendant le zoom+bump du titre "Victoire !"
  self.victory_title_duration = VICTORY_TITLE_DURATION -- lu par view.lua pour l'easing
  self.draft_cards_shown = false -- les 3 cartes (de dos) n'apparaissent qu'après le titre
  self.draft_flip = {} -- [index] = { t = elapsed } une fois le retournement démarré
  self.draft_flip_duration = DRAFT_FLIP_DURATION -- lu par view.lua pour l'easing
  self.anim = {} -- [unit_id] = { kind = "pulse-up"|"pulse-down"|"shake", t = elapsed }
  self.card_anims = {} -- liste de { from, to, elapsed, delay, duration, fade_in, def } -- voir View.draw
  self.floaters = {} -- liste de { x, y, text, kind = "damage"|"heal", t } -- lu par view.lua
  self.particles = {} -- liste de { x, y, vx, vy, t } -- petit burst à l'impact
  self.status_pop = {} -- [unit_id] = { [status_key] = elapsed } -- pop d'un badge à son application
  self.shield_fx = {} -- [unit_id] = { t = elapsed } -- gros bouclier en fondu sur un gain de Défense
  self.floater_duration = FLOATER_DURATION -- lus par view.lua, même logique que victory_title_duration
  self.particle_duration = PARTICLE_DURATION
  self.status_pop_duration = STATUS_POP_DURATION
  self.shield_fx_duration = SHIELD_FX_DURATION
  -- Séquence de début de tour (2026-08-21, demande explicite -- onboarding) :
  -- le gros chiffre d'énergie qui se pose sur sa pastille, voir
  -- Controller:spawn_energy_turn_anim / draw_energy_turn_anim (view.lua).
  self.energy_turn_anim = nil -- { t = elapsed, value = N }
  self.energy_turn_anim_duration = TURN_ENERGY_ANIM_DURATION -- lu par view.lua pour l'easing
  -- Cartes déjà dans state.hand mais dont le vol pioche -> main n'a pas encore
  -- démarré visuellement (2026-08-21, bug signalé -- pendant l'attente de
  -- l'anim d'énergie ou du remélange défausse -> pioche, Game.start_turn/
  -- Deck.fill_hand ont déjà rempli state.hand mais aucun card_anims n'existe
  -- encore pour ces uids) : la main les cache tant qu'ils y sont, voir
  -- draw_hand (view.lua) et Controller:consume_drawn_animation/animate_draw.
  self.pending_draw_uids = {}
  -- Sons de vol de carte différés (2026-08-21, demande explicite -- "1 son par
  -- carte, sans se superposer" : quand N cartes bougent d'un coup, N "flup"
  -- espacés, pas un seul son joué pour tout le paquet) : liste de
  -- { delay = secondes restantes, name }, décrémentée dans Controller:update.
  self.pending_sfx = {}
  self.hover = { target = nil, kind = nil, t = 0 } -- kind: "hero"|"enemy"|"card"
  -- Mode d'entrée alterné (2026-08-09, spike) : "tap" = séquence à 3 clics
  -- (existant) ; "arrow" = sélection au survol + flèche dynamique façon Slay
  -- the Spire -- devenu le défaut (2026-08-09, retour positif du porteur de
  -- projet après playtest), "tap" reste disponible via le bouton de bascule.
  self.input_mode = "arrow"
  self.arrow_hand_hover_uid = nil -- carte de la main survolée en mode "arrow" (agrandissement immédiat, sans délai de tooltip)
  -- Plus de run démarré automatiquement (2026-08-21, demande explicite --
  -- l'appli s'ouvre désormais sur le menu principal) : `self:reset_run(mode)`
  -- n'est appelé qu'au clic sur "Jouer un run"/"Mode infini", voir Input.mousepressed --
  -- en passant désormais par l'écran de choix d'équipe (2026-08-29), voir
  -- Controller:enter_team_select.
  return self
end

-- ---------- écran "Choisis ton équipe" ----------

--- Entre sur l'écran de choix d'équipe (2026-08-29, demande explicite --
-- avant chaque run, choisir 4 des 6 `Heroes.defs`) : appelé au clic sur
-- "Jouer un run"/"Mode infini" au menu (voir menu_click, input.lua), PAS sur
-- "Tester le boss" (reste un raccourci fixe à l'équipe historique, voir
-- Controller:start_boss_test -- aucune sélection n'a de sens pour un test
-- isolé). `mode` ("infini"/"bounded") est juste mémorisé ici, transmis tel
-- quel à Controller:reset_run une fois "Partir à l'aventure" cliqué.
function Controller:enter_team_select(mode)
  self.screen = "team_select"
  local available = {}
  for _, def in ipairs(Heroes.defs) do available[#available + 1] = def.id end
  self.team_select = {
    mode = mode, available_ids = available, selected_ids = {},
    focused_id = nil, card_anims = {}, hero_anims = {},
  }
end

--- Survol d'un aventurier sur l'écran de choix d'équipe (2026-08-30, demande
-- explicite -- "il n'y a aucun son dans cette fenêtre, il faut en ajouter à
-- toutes les actions joueurs : survol, clic, déplacement...") : un seul
-- "flush" au moment où le survol COMMENCE sur ce héros précis, jamais répété
-- tant qu'on reste dessus -- Controller:set_hover ignore déjà un appel
-- répété avec la même cible (voir son commentaire), donc comparer AVANT de
-- l'appeler est le seul moyen de détecter "ça vient de changer" ici.
function Controller:team_select_hover(id)
  if not (self.hover.kind == "team_hero" and self.hover.target == id) then
    Sfx.play("flush")
  end
  self:set_hover("team_hero", id)
end

--- Position ACTUELLE (rangée disponible OU équipe confirmée -- les 2 listes
-- sont mutuellement exclusives, voir enter_team_select) du héros `id`
-- (2026-08-30) -- jamais la position projecteur, qui n'est jamais son
-- emplacement "de rangement", juste où il se trouve pendant qu'on le regarde.
function Controller:team_select_home_rect(id)
  local avail = View.team_select_available_rects(self)
  if avail[id] then return avail[id] end
  return View.team_select_party_rects(self)[id]
end

--- Fait voyager le portrait de `id` de `from` à `to` (2026-08-30, voir
-- ts.hero_anims/draw_team_select) -- si une anim était déjà en cours pour ce
-- même héros (reclic rapide avant la fin du mouvement précédent), capture sa
-- position ACTUELLE interpolée comme nouveau départ plutôt que de sauter
-- depuis `from` (même principe que team_select_fly_out_current pour les
-- cartes) : `from` n'est donc qu'un repli pour le cas normal (aucune anim en
-- cours).
-- `duration` (optionnel, 2026-08-30 -- "le mouvement vers le groupe du bas
-- doit être plus lent" à la validation, jamais au retrait) : par défaut
-- TEAM_HERO_MOVE_DURATION (mise en avant, Annuler, retrait -- vitesse
-- inchangée dans ces 3 cas), TEAM_HERO_MOVE_DURATION_SLOW passé
-- explicitement par team_select_confirm uniquement quand il AJOUTE.
function Controller:team_select_move_hero(id, from, to, duration)
  local ts = self.team_select
  for i = #ts.hero_anims, 1, -1 do
    if ts.hero_anims[i].id == id then
      local a = ts.hero_anims[i]
      local p = math.min(1, a.elapsed / a.duration)
      from = { x = a.from.x + (a.to.x - a.from.x) * p, y = a.from.y + (a.to.y - a.from.y) * p, w = to.w, h = to.h }
      table.remove(ts.hero_anims, i)
      break
    end
  end
  ts.hero_anims[#ts.hero_anims + 1] = { id = id, from = from, to = to, elapsed = 0, duration = duration or TEAM_HERO_MOVE_DURATION }
end

--- Les 3 cartes "depart" de `class_id`, PLUS le nombre de cartes "avance"
-- (2026-08-30, demande explicite -- "il ne faut en fait afficher que les 3
-- cartes de départ. À la place de montrer les cartes avancées, on montre 1
-- seule carte de dos avec le nombre de cartes avancées actuellement
-- débloquées") : ce nombre est dérivé de Cards.list, jamais codé en dur --
-- vaut 3 pour toute classe aujourd'hui (aucun système de déblocage
-- n'existe encore), mais suivrait automatiquement si une classe en gagnait
-- plus tard. Voir Controller:team_select_spawn_cards, seul appelant.
local function depart_cards_and_advance_count(class_id)
  local depart, advance_count = {}, 0
  for _, def in ipairs(Cards.list) do
    if def.class_id == class_id then
      if def.tier == "depart" then depart[#depart + 1] = def
      elseif def.tier == "avance" then advance_count = advance_count + 1 end
    end
  end
  return depart, advance_count
end

--- Bascule chaque vol "in" encore actif en vol "out" (2026-08-29) : point
-- commun à "changer de héros mis en avant", "Annuler" et "Valider" -- capture
-- la position ACTUELLE de la carte (elle peut être interrompue en plein vol
-- d'entrée, pas seulement déjà posée) pour que le vol de sortie reparte de
-- là, jamais un saut brusque vers sa position cible d'abord. Les entrées déjà
-- "out" (un 2ᵉ changement avant la fin de la 1ʳᵉ sortie) restent telles
-- quelles, jamais relancées.
-- `gather_target` (optionnel, 2026-08-30, "Valider" qui AJOUTE un héros à
-- l'équipe -- "ses cartes se regroupent pour aller rejoindre le deck [...]
-- une par une, plus lentement") : toutes les cartes convergent vers CE
-- rectangle unique au lieu de partir chacune vers un bord aléatoire, chacune
-- DÉCALÉE d'un cran (`a.delay`, lu par Controller:update pour la suppression
-- et par draw_team_select pour l'interpolation -- même champ/même
-- convention que `controller.card_anims` en combat, voir animate_draw) et
-- avec un vol individuel plus lent (TEAM_CARD_GATHER_DURATION). Absent
-- (Annuler/Retirer/changement de focus) : comportement inchangé, envol
-- groupé instantané vers un bord aléatoire, vitesse normale.
function Controller:team_select_fly_out_current(gather_target)
  local ts = self.team_select
  if not ts then return end
  local i = 0
  for _, a in ipairs(ts.card_anims) do
    if a.mode == "in" then
      i = i + 1
      local p = math.min(1, a.elapsed / a.duration)
      local cur = { x = a.from.x + (a.to.x - a.from.x) * p, y = a.from.y + (a.to.y - a.from.y) * p, w = a.to.w, h = a.to.h }
      a.mode = "out"
      a.from = cur
      if gather_target then
        a.to = { x = gather_target.x, y = gather_target.y, w = gather_target.w, h = gather_target.h }
        a.duration = TEAM_CARD_GATHER_DURATION
        a.delay = (i - 1) * TEAM_CARD_GATHER_STAGGER
        -- 1 "flup" PAR carte, espacé du même délai que son vol (2026-08-30,
        -- demande explicite -- même idiome que Controller:animate_draw pour
        -- la pioche en rafale) : jamais un seul son pour tout le lot. Cas
        -- SPÉCIAL au rassemblement vers le deck seulement -- voir le
        -- commentaire sur TEAM_CARD_BURST_COUNT : les 6 cartes s'envolent ici
        -- réellement l'une après l'autre, contrairement au bloc `else`
        -- ci-dessous.
        self:schedule_sfx("flup", a.delay)
      else
        a.to = View.team_select_offscreen_rect(a.to, TEAM_CARD_SIDES[math.random(#TEAM_CARD_SIDES)])
        a.duration = TEAM_CARD_FLY_DURATION
        a.delay = 0
      end
      a.elapsed = 0
    end
  end
  -- Rafale courte, pas 1 son par carte (2026-08-30, "c'était une erreur...
  -- pas 6 fois, 2-3 fois, sinon ça surcharge") : les 6 cartes s'envolent
  -- TOUTES EN MÊME TEMPS ici (aucun a.delay), un flup par carte sonnait donc
  -- comme 6 échos simultanés plutôt qu'un mouvement décalé -- jamais pour le
  -- rassemblement (gather_target), qui garde son flup par carte ci-dessus,
  -- explicitement approuvé tel quel.
  if i > 0 and not gather_target then self:team_select_play_card_burst() end
end

--- Rafale courte de "flup" (2026-08-30, voir team_select_fly_out_current/
-- team_select_spawn_cards) : TEAM_CARD_BURST_COUNT sons rapprochés, jamais
-- un par carte -- pour toute volée de cartes qui bouge TOUTE ENSEMBLE (pas
-- de décalage visuel entre elles), contrairement au rassemblement vers le
-- deck qui a son propre rythme carte par carte.
function Controller:team_select_play_card_burst()
  for j = 1, TEAM_CARD_BURST_COUNT do
    self:schedule_sfx("flup", (j - 1) * TEAM_CARD_BURST_STAGGER)
  end
end

--- Fait voler TOUTES les cartes de `id` depuis un bord aléatoire (chacune le
-- sien, indépendamment) jusqu'à sa position cible au centre (2026-08-29) --
-- AJOUTE ces entrées à `ts.card_anims`, ne le vide jamais (les vols "out" en
-- cours, voir team_select_fly_out_current ci-dessus, doivent pouvoir
-- continuer à se dessiner/s'auto-supprimer en parallèle, voir
-- Controller:update). Abandonne si le focus a déjà changé entre-temps
-- (appelé via self.seq -- voir Controller:team_select_focus).
function Controller:team_select_spawn_cards(id)
  local ts = self.team_select
  if not ts or ts.focused_id ~= id then return end
  local def = Heroes.by_id(id)
  local depart, advance_count = depart_cards_and_advance_count(def.class_id)
  -- +1 pour la carte de dos "cartes Avancées" (2026-08-30, demande explicite) --
  -- voir View.team_select_card_rects, sa grille s'adapte déjà à N'IMPORTE QUEL
  -- nombre d'items, jamais figée à 6.
  local targets = View.team_select_card_rects(#depart + 1)
  for i, card_def in ipairs(depart) do
    local to = targets[i]
    local from = View.team_select_offscreen_rect(to, TEAM_CARD_SIDES[math.random(#TEAM_CARD_SIDES)])
    ts.card_anims[#ts.card_anims + 1] = {
      def = card_def, from = from, to = to, elapsed = 0,
      duration = TEAM_CARD_FLY_DURATION, mode = "in",
    }
  end
  local back_to = targets[#depart + 1]
  local back_from = View.team_select_offscreen_rect(back_to, TEAM_CARD_SIDES[math.random(#TEAM_CARD_SIDES)])
  ts.card_anims[#ts.card_anims + 1] = {
    is_back = true, class_id = def.class_id, count = advance_count,
    from = back_from, to = back_to, elapsed = 0,
    duration = TEAM_CARD_FLY_DURATION, mode = "in",
  }
  -- Rafale courte, pas 1 flup par carte (2026-08-30 -- voir le commentaire
  -- sur TEAM_CARD_BURST_COUNT) : les 4 cartes (3 Départ + 1 dos) arrivent
  -- toutes ensemble.
  self:team_select_play_card_burst()
end

--- Clique un aventurier (disponible OU déjà dans l'équipe -- "il peut être
-- resélectionné normalement", 2026-08-29) : le met en avant -- SON PORTRAIT
-- se déplace réellement vers le projecteur à droite (2026-08-30, demande
-- explicite -- "le déplacement est visible"), l'ancien mis en avant (s'il y
-- en avait un) repart vers sa rangée d'origine -- fait sortir les cartes
-- actuellement affichées (s'il y en a) puis entrer les siennes -- l'entrée
-- est différée d'exactement la durée du vol de sortie via self.seq, pour ne
-- jamais les faire se croiser au même endroit en même temps. Re-cliquer le
-- héros DÉJÀ mis en avant ne fait rien (idempotent).
function Controller:team_select_focus(id)
  local ts = self.team_select
  if not ts or ts.focused_id == id then return end
  Sfx.play("hop")
  local had_focus = ts.focused_id ~= nil
  self:team_select_fly_out_current()
  if had_focus then
    local prev_id = ts.focused_id
    self:team_select_move_hero(prev_id, View.team_select_spotlight_rect, self:team_select_home_rect(prev_id))
  end
  self:team_select_move_hero(id, self:team_select_home_rect(id), View.team_select_spotlight_rect)
  ts.focused_id = id
  local self_ = self
  if had_focus then self.seq:push(function() end, TEAM_CARD_FLY_DURATION) end
  self.seq:push(function() self_:team_select_spawn_cards(id) end)
end

--- "Annuler" (2026-08-29) : referme le focus sans rien changer à l'équipe --
-- fait sortir les cartes affichées et renvoie le portrait vers sa rangée
-- d'origine (2026-08-30, "le déplacement est visible", même mouvement que
-- team_select_focus quand un autre héros prend sa place).
function Controller:team_select_cancel()
  local ts = self.team_select
  if not ts or not ts.focused_id then return end
  -- Pas de "flup" générique ici (2026-08-30, retiré -- team_select_fly_out_current
  -- en joue désormais un PAR carte, décalé, ça suffit largement, un de plus
  -- ferait doublon/surcharge).
  self:team_select_fly_out_current()
  local id = ts.focused_id
  self:team_select_move_hero(id, View.team_select_spotlight_rect, self:team_select_home_rect(id))
  ts.focused_id = nil
end

--- "Valider" (2026-08-29) : bascule l'aventurier mis en avant entre les 2
-- listes -- l'AJOUTE à l'équipe s'il n'y était pas (refusé, sans effet, si
-- l'équipe compte déjà 4 -- bouton visuellement désactivé dans ce cas, voir
-- draw_team_select), ou l'en RETIRE s'il y était déjà ("resélectionné
-- normalement pour être sorti du groupe" -- le bouton se relabellise
-- "Retirer" côté vue). Le portrait se déplace vers sa NOUVELLE rangée
-- (2026-08-30, "il se déplace en bas") -- calculée APRÈS la bascule de
-- liste, donc déjà la rangée équipe en cas d'ajout. En cas d'AJOUT
-- seulement, ses cartes convergent vers le deck (grossi d'un cran, voir
-- View.team_select_deck_rect) plutôt que de partir vers des bords aléatoires
-- -- un retrait n'alimente jamais le deck, il se contente de refermer le
-- focus normalement. Referme le focus dans les 2 cas, comme "Annuler".
function Controller:team_select_confirm()
  local ts = self.team_select
  if not ts or not ts.focused_id then return end
  local id = ts.focused_id
  local index_in_selected
  for i, sid in ipairs(ts.selected_ids) do if sid == id then index_in_selected = i break end end
  local adding
  if index_in_selected then
    table.remove(ts.selected_ids, index_in_selected)
    ts.available_ids[#ts.available_ids + 1] = id
    adding = false
  else
    if #ts.selected_ids >= 4 then return end
    ts.selected_ids[#ts.selected_ids + 1] = id
    local index_in_available
    for i, aid in ipairs(ts.available_ids) do if aid == id then index_in_available = i break end end
    if index_in_available then table.remove(ts.available_ids, index_in_available) end
    adding = true
  end
  -- "flup" retiré ici pour le retrait (2026-08-30) : team_select_fly_out_current
  -- (appelée juste en dessous) en joue désormais un PAR carte qui s'envole,
  -- suffisant à lui seul -- garde "upgrade" pour l'ajout (fanfare distincte
  -- de tout son de carte, propre au fait de rejoindre l'équipe).
  if adding then Sfx.play("upgrade") end
  self:team_select_move_hero(id, View.team_select_spotlight_rect, self:team_select_home_rect(id),
    adding and TEAM_HERO_MOVE_DURATION_SLOW or nil)
  if adding then
    self:team_select_fly_out_current(View.team_select_deck_rect(#ts.selected_ids))
  else
    self:team_select_fly_out_current()
  end
  ts.focused_id = nil
end

--- "Partir à l'aventure" (2026-08-29) : n'a d'effet qu'à exactement 4
-- aventuriers confirmés (bouton visuellement inerte sinon, voir
-- draw_team_select) -- lance la run avec CETTE sélection précise via
-- Controller:reset_run, qui accepte désormais `selected_ids` en plus de `mode`.
function Controller:team_select_launch()
  local ts = self.team_select
  if not ts or #ts.selected_ids ~= 4 then return end
  Sfx.play("woosh")
  local mode, selected_ids = ts.mode, ts.selected_ids
  self.team_select = nil
  self:reset_run(mode, selected_ids)
end

function Controller:toggle_input_mode()
  self.input_mode = (self.input_mode == "arrow") and "tap" or "arrow"
  self.arrow_hand_hover_uid = nil
end

function Controller:set_arrow_hand_hover(uid)
  self.arrow_hand_hover_uid = uid
end

-- ---------- menu ----------

function Controller:enter_menu()
  self.screen = "menu"
end

function Controller:enter_options()
  self.screen = "options"
end

function Controller:back_to_menu()
  self:enter_menu()
end

--- Remise à zéro de tout l'état d'animation du Controller (2026-08-21,
-- factorisé -- avant, dupliqué à l'identique dans reset_run/restart_combat/
-- restart_turn, et maintenant aussi start_boss_test). `self.screen` n'est PAS
-- touché ici : chaque appelant sait mieux que cette fonction quel écran
-- vient ensuite (souvent "playing", mais enter_draft_screen peut encore
-- s'appliquer juste après selon `state.over`).
function Controller:clear_animation_state()
  self.draft_picks = nil
  self.post_combat_queue = {}
  self.forge = nil
  self.forge_upgrade_anim = nil
  self.temple = nil
  self.temple_choice_anim = nil
  self.victory_anim = nil
  self.draft_cards_shown = false
  self.draft_flip = {}
  self.seq:clear()
  self.anim = {}
  self.card_anims = {}
  self.floaters = {}
  self.particles = {}
  self.status_pop = {}
  self.shield_fx = {}
  self.energy_turn_anim = nil
  self.pending_draw_uids = {}
  self.pending_sfx = {}
end

--- `mode` : "infini" | "bounded" (2026-08-21, demande explicite -- voir
-- self.run_mode). Absent (ex. le bouton "Rejouer" de l'écran de défaite, voir
-- Input.mousepressed), reconduit le dernier mode actif plutôt que d'en
-- imposer un par défaut -- mourir en run borné puis "Rejouer" doit relancer
-- un run borné, pas basculer sur l'infini.
-- `selected_ids` (optionnel, 2026-08-29, écran de choix d'équipe -- voir
-- Controller:team_select_launch) : liste de 4 ids. Absent, reconduit la
-- DERNIÈRE équipe lancée avec succès (self.last_selected_ids -- même confort
-- que `mode` pour "Rejouer", qui ne repasse jamais par l'écran de sélection),
-- ou Heroes.DEFAULT_PARTY_IDS si aucune run n'est encore passée par cet écran.
function Controller:reset_run(mode, selected_ids)
  self.run_mode = mode or self.run_mode or "infini"
  selected_ids = selected_ids or self.last_selected_ids or Heroes.DEFAULT_PARTY_IDS
  self.last_selected_ids = selected_ids
  self.screen = "playing"
  self:clear_animation_state()
  Game.reset_run(self.state, nil, selected_ids)
  -- Game.start_turn (appelé par reset_run) ne peut plus infliger de dégâts à
  -- ce jour -- garde-fou conservé par précaution, voir advance_after_discard_sequenced.
  if self.state.over then self:handle_combat_victory(); return end
  -- Séquence de début de tour rejouée dès le tout premier tour de la partie
  -- (2026-08-21, demande explicite -- "l'animation pour l'énergie doit aussi
  -- se faire au début de la partie") : même mise en scène que chaque tour
  -- normal, voir Controller:play_turn_start_sequence.
  self:play_turn_start_sequence()
end

--- "Tester le boss" au menu (2026-08-21, demande explicite) : combat autonome
-- contre l'Homme Arbre + ses 4 Pousses d'Arbre (voir Game.start_boss_test),
-- héros frais comme un nouveau run. `run_mode = "boss_test"` (ni "infini" ni
-- "bounded") : "Rejouer" après une défaite relance le même test plutôt que de
-- retomber sur le mode infini, et une victoire ramène au menu plutôt que
-- d'enchaîner sur un faux "combat 2" -- voir Input.mousepressed et
-- Controller:advance_to_next_combat.
function Controller:start_boss_test()
  self.screen = "playing"
  self.run_mode = "boss_test"
  self:clear_animation_state()
  Game.start_boss_test(self.state)
  if self.state.over then self:handle_combat_victory(); return end
  self:play_turn_start_sequence()
end

function Controller:restart_combat()
  self.screen = "playing"
  self:clear_animation_state()
  Game.restore_combat_snapshot(self.state)
  self:consume_drawn_animation()
  if self.state.over then self:handle_combat_victory() end
end

--- Recommence uniquement le tour en cours (2026-08-10, demande explicite) --
-- même nettoyage d'état d'animation que restart_combat, mais restaure la photo de
-- tour (Game.restore_turn_snapshot) plutôt que celle de combat.
function Controller:restart_turn()
  self.screen = "playing"
  self:clear_animation_state()
  Game.restore_turn_snapshot(self.state)
  self:consume_drawn_animation()
  if self.state.over then self:handle_combat_victory() end
end

--- Outil de test (2026-08-08) : termine le combat en cours par une victoire
-- immédiate (tous les ennemis à 0 PV), sans passer par la résolution réelle --
-- réutilise le même chemin que la victoire normale (`Game.check_victory` +
-- `enter_draft_screen`) pour que l'écran de récompense se comporte à
-- l'identique, seule la façon d'y arriver diffère.
function Controller:trigger_instant_victory()
  if self.screen ~= "playing" or self.state.over then return end
  for _, e in ipairs(self.state.enemies) do e.hp = 0 end
  if Game.check_victory(self.state) then self:handle_combat_victory() end
end

-- ---------- cosmétique ----------

function Controller:pulse(unit_id, kind)
  self.anim[unit_id] = { kind = kind, t = 0 }
end

--- Joue un son après `delay` secondes plutôt qu'immédiatement (2026-08-21,
-- demande explicite -- "1 son par carte, sans se superposer" : plusieurs
-- cartes qui bougent d'un coup doivent s'entendre une par une, espacées,
-- jamais un seul son joué pour tout le paquet). `delay <= 0` joue tout de
-- suite, même résultat qu'un Sfx.play direct. Voir Controller:update pour le
-- décompte.
function Controller:schedule_sfx(name, delay)
  if not delay or delay <= 0 then Sfx.play(name); return end
  self.pending_sfx[#self.pending_sfx + 1] = { delay = delay, name = name }
end

-- ---------- vol de cartes (pioche <-> main <-> défausse) ----------

--- Anime les cartes dont les uids sont donnés depuis la pioche vers leur
-- emplacement ACTUEL dans state.hand (appelé APRÈS que la pioche a eu lieu :
-- les cartes sont déjà dans state.hand, donc View.hand_rects reflète leur
-- position d'arrivée directement). Renvoie la durée totale du vol (2026-08-21,
-- demande explicite -- la suite de la séquence de tour, ex. le saut "prêt" des
-- aventuriers, doit attendre que la dernière carte soit arrivée avant de démarrer).
-- Retire chaque uid de `pending_draw_uids` au moment où SON entrée de vol
-- existe vraiment (2026-08-21, bug signalé -- voir le commentaire sur ce
-- champ dans Controller.new) : c'est CE moment précis, pas l'appel global à
-- consume_drawn_animation, qui doit faire réapparaître la carte en main.
function Controller:animate_draw(drawn_uids)
  if not drawn_uids or #drawn_uids == 0 then return 0 end
  local hand_rects = View.hand_rects(self.state)
  local origin = View.deck_pile_rect
  for i, uid in ipairs(drawn_uids) do
    local dest = hand_rects[uid]
    if dest then
      local def
      for _, c in ipairs(self.state.hand) do if c.uid == uid then def = c.def break end end
      local delay = (i - 1) * DRAW_FLIGHT_STAGGER
      self.card_anims[#self.card_anims + 1] = {
        from = origin, to = dest, elapsed = 0, delay = delay,
        duration = DRAW_FLIGHT_DURATION, fade_in = true, def = def, uid = uid,
      }
      self.pending_draw_uids[uid] = nil
      -- 1 "flup" PAR carte, espacé du même délai que son vol (2026-08-21,
      -- demande explicite -- "sans se superposer") : jamais un seul son pour
      -- tout le paquet, voir Controller:schedule_sfx.
      self:schedule_sfx("flup", delay)
    end
  end
  return (#drawn_uids - 1) * DRAW_FLIGHT_STAGGER + DRAW_FLIGHT_DURATION
end

--- Quelques cartes anonymes qui volent de la défausse vers la pioche
-- (2026-08-21, demande explicite -- rendre visible le remélange défausse ->
-- pioche quand le deck se vide en cours de pioche) : `def = nil`, dessiné en
-- silhouette simple par draw_card_flights (view.lua), jamais une face
-- précise -- ce sont des cartes qui repartent mélangées, en montrer une serait
-- trompeur. Renvoie la durée totale, même contrat que animate_draw/
-- animate_discard_snapshot.
function Controller:animate_reshuffle()
  local origin, dest = View.discard_pile_rect, View.deck_pile_rect
  for i = 1, RESHUFFLE_GHOST_COUNT do
    local delay = (i - 1) * RESHUFFLE_GHOST_STAGGER
    self.card_anims[#self.card_anims + 1] = {
      from = origin, to = dest, elapsed = 0, delay = delay,
      duration = RESHUFFLE_GHOST_FLIGHT_DURATION, fade_in = false, def = nil,
    }
    self:schedule_sfx("flup", delay)
  end
  return RESHUFFLE_TOTAL_DURATION
end

--- Lit state.last_drawn_uids (posé par Deck.draw_cards/fill_hand, voir
-- src/rules/deck.lua) et lance l'animation correspondante, puis le vide --
-- point d'accroche unique pour tous les chemins de pioche (début de tour,
-- Clairvoyance en cours de tour), sans dupliquer l'appel dans chacun. Renvoie
-- la durée totale AVANT que la suite de la séquence (ex. le saut des
-- aventuriers) ne puisse démarrer.
--
-- Remélange en cours de pioche (2026-08-21, demande explicite, ex. "pioche 2
-- cartes, pioche vide, passage défausse -> pioche, pioche des 3 cartes
-- restantes") : `state.last_draw_reshuffled_at` (voir Deck.lua) coupe alors le
-- vol en 2 lots avec Controller:animate_reshuffle joué ENTRE les deux, plutôt
-- qu'un seul vol qui ferait apparaître les cartes d'après-remélange comme si
-- elles venaient d'un deck resté plein. Toutes les cartes concernées (les 2
-- lots) restent marquées `pending_draw_uids` dès le départ -- voir plus bas --
-- pour ne jamais apparaître "déjà en main" pendant l'attente du remélange.
function Controller:consume_drawn_animation()
  local drawn = self.state.last_drawn_uids
  local reshuffled_at = self.state.last_draw_reshuffled_at
  self.state.last_drawn_uids = nil
  self.state.last_draw_reshuffled_at = nil
  if not drawn or #drawn == 0 then return 0 end
  for _, uid in ipairs(drawn) do self.pending_draw_uids[uid] = true end

  if reshuffled_at ~= nil then
    local batch1, batch2 = {}, {}
    for i, uid in ipairs(drawn) do
      if i <= reshuffled_at then batch1[#batch1 + 1] = uid else batch2[#batch2 + 1] = uid end
    end
    local self_ = self
    local d1 = #batch1 > 0 and self:animate_draw(batch1) or 0
    self_.seq:push(function() end, d1)
    self_.seq:push(function()
      if self_.state.over then return end
      self_:animate_reshuffle()
    end, RESHUFFLE_TOTAL_DURATION)
    self_.seq:push(function()
      if self_.state.over then return end
      if #batch2 > 0 then self_:animate_draw(batch2) end
    end)
    return d1 + RESHUFFLE_TOTAL_DURATION + (#batch2 > 0 and ((#batch2 - 1) * DRAW_FLIGHT_STAGGER + DRAW_FLIGHT_DURATION) or 0)
  end

  return self:animate_draw(drawn)
end

--- Anime `cards` (liste de {uid, def, ...}, une COPIE de state.hand prise
-- AVANT la défausse -- voir View.hand_rects_for) depuis leur position d'ORIGINE
-- dans cette main-là vers la défausse. `exclude_uid` (optionnel) : carte à ne
-- pas animer (celle que le Mage garde). Renvoie la durée totale du vol
-- (2026-08-21, demande explicite -- la résolution des monstres doit attendre
-- que cette défausse-ci soit visuellement finie, PLUS une pause dédiée, avant
-- de démarrer -- voir END_TURN_TO_ENEMY_RESOLUTION_PAUSE dans end_turn).
function Controller:animate_discard_snapshot(cards, exclude_uid)
  if not cards or #cards == 0 then return 0 end
  local hand_rects = View.hand_rects_for(cards)
  local dest = View.discard_pile_rect
  local i = 0
  for _, c in ipairs(cards) do
    if c.uid ~= exclude_uid then
      i = i + 1
      local origin = hand_rects[c.uid]
      if origin then
        local delay = (i - 1) * END_TURN_DISCARD_STAGGER
        self.card_anims[#self.card_anims + 1] = {
          from = origin, to = dest, elapsed = 0, delay = delay,
          duration = END_TURN_DISCARD_FLIGHT_DURATION, fade_in = false, def = c.def,
        }
        self:schedule_sfx("flup", delay)
        -- "Furtif" (2026-08-28, demande explicite -- "un petit effet de
        -- disparition qui incrémente le compteur de discrétion") : la carte
        -- part quand même en défausse (voir Game.discard_cards, inchangé pour
        -- ce cas), juste une petite étincelle en plus à son point de départ --
        -- le VRAI gain de Discrétion (+2, voir Game.grant_furtif_discard_discretion)
        -- est déjà couvert par le flottant générique de Controller:react_to_diff,
        -- appelé par Controller:end_turn AVANT cette fonction -- pas dupliqué ici.
        if Game.card_has_cat(c.def, "furtif") then
          self:spawn_ash(origin, Theme.discretion, FURTIF_SPARKLE_COUNT, -10)
        end
      end
    end
  end
  return i > 0 and ((i - 1) * END_TURN_DISCARD_STAGGER + END_TURN_DISCARD_FLIGHT_DURATION) or 0
end

--- Anime une seule carte (celle qui vient d'être jouée, si elle a bien fini en
-- défausse OU en cendres -- pas si elle est restée en main ou retournée au
-- sommet du deck) depuis son rect dans `hand_before` (capturé avant l'appel
-- qui la résout). "Amnésie" (2026-08-28) vérifiée EN PREMIER : une carte
-- Amnésie finit dans state.exhausted, jamais state.discard (voir
-- Game.finish_card) -- sans ce détour, elle ne recevrait AUCUNE animation du
-- tout (juste retirée de la main en silence).
function Controller:maybe_animate_played_discard(played_uid, hand_before)
  if not played_uid then return end
  local hand_rects = View.hand_rects_for(hand_before)
  local origin = hand_rects[played_uid]
  if not origin then return end
  local last_exhausted = self.state.exhausted[#self.state.exhausted]
  if last_exhausted and last_exhausted.uid == played_uid then
    self:play_amnesie_vanish(origin, last_exhausted.def)
    return
  end
  local last = self.state.discard[#self.state.discard]
  if not last or last.uid ~= played_uid then return end -- pas parti en défausse (main/dessus du deck/pas encore résolu)
  self.card_anims[#self.card_anims + 1] = {
    from = origin, to = View.discard_pile_rect, elapsed = 0, delay = 0,
    duration = FLIGHT_DURATION, fade_in = false, def = last.def,
  }
  Sfx.play("flup")
end

--- Capture PV + statuts de toutes les unités -- même principe que l'ancien
-- snapshot_hp (juste avant un appel de règles), étendu pour que
-- Controller:react_to_diff puisse aussi détecter l'application d'un statut,
-- pas seulement une perte de PV. `discretion` à part, PAS dans STATUS_KEYS
-- (2026-08-28, demande explicite -- flottant dédié comme un gain de PV,
-- jamais un pop de badge : Discrétion ne s'affiche nulle part en badge,
-- juste en texte sous le portrait, voir draw_hero) -- nil pour les 3 classes
-- qui n'ont pas ce champ, jamais traité comme 0 (romprait le `and` de garde
-- dans Controller:react_to_diff).
function Controller:snapshot_units()
  local out = {}
  local function capture(list)
    for _, u in ipairs(list) do
      local snap = { hp = u.hp, discretion = u.discretion }
      for _, k in ipairs(STATUS_KEYS) do snap[k] = u[k] or 0 end
      out[u.id] = snap
    end
  end
  capture(self.state.heroes)
  capture(self.state.enemies)
  return out
end

function Controller:spawn_floater(unit_id, amount, kind)
  local r = View.unit_rect(self.state, unit_id)
  if not r then return end
  self.floaters[#self.floaters + 1] = {
    x = r.x + r.w / 2 + (math.random() - 0.5) * 22, y = r.y + r.h * 0.35,
    text = (amount > 0 and "+" or "") .. amount, kind = kind, t = 0,
  }
end

function Controller:spawn_impact(unit_id)
  local r = View.unit_rect(self.state, unit_id)
  if not r then return end
  local cx, cy = r.x + r.w / 2, r.y + r.h / 2
  for _ = 1, PARTICLE_COUNT do
    local angle = math.random() * math.pi * 2
    local speed = 60 + math.random() * 70
    self.particles[#self.particles + 1] = {
      x = cx, y = cy, vx = math.cos(angle) * speed, vy = math.sin(angle) * speed, t = 0,
    }
  end
end

--- Petit nuage de particules réparties sur tout un RECT (pas un point comme
-- spawn_impact, une carte entière) -- réutilise `self.particles`/
-- draw_particles (view.lua) tel quel, `color`/`gravity` (2026-08-28) sont
-- lus en priorité sur les valeurs par défaut (voir leur commentaire côté
-- view.lua). `gravity` négative = dérive vers le HAUT (cendres qui
-- s'envolent), jamais une vraie chute comme le burst d'impact au combat.
function Controller:spawn_ash(rect, color, count, gravity)
  for _ = 1, count do
    local angle = math.random() * math.pi * 2
    local speed = 15 + math.random() * 35
    self.particles[#self.particles + 1] = {
      x = rect.x + math.random() * rect.w, y = rect.y + math.random() * rect.h,
      vx = math.cos(angle) * speed, vy = math.sin(angle) * speed - 20,
      t = 0, color = color, gravity = gravity,
    }
  end
end

--- "Amnésie" (2026-08-28, demande explicite -- "la carte, au lieu d'aller
-- dans la défausse, se disperse en cendre") : la carte ne vole nulle part
-- (elle ne rejoint jamais state.discard, voir state.exhausted dans game.lua)
-- -- juste un rétrécissement/fondu SUR PLACE (voir le cas `a.dissolve` dans
-- draw_card_flights, view.lua) + un burst de cendres grises par-dessus.
function Controller:play_amnesie_vanish(rect, def)
  self.card_anims[#self.card_anims + 1] = {
    from = rect, to = rect, elapsed = 0, delay = 0,
    duration = ASH_DISSOLVE_DURATION, dissolve = true, def = def,
  }
  self:spawn_ash(rect, Theme.ash, ASH_PARTICLE_COUNT, -30)
  Sfx.play("ash")
end

function Controller:pop_status(unit_id, key)
  self.status_pop[unit_id] = self.status_pop[unit_id] or {}
  self.status_pop[unit_id][key] = 0
end

--- Gros chiffre d'énergie qui se pose sur sa pastille en début de tour
-- (2026-08-21, demande explicite -- premier beat de la séquence de tour, amène
-- le regard du joueur à cet endroit avant même que la pioche ne démarre). Expire
-- tout seul dans Controller:update, comme victory_anim/floaters.
function Controller:spawn_energy_turn_anim(value)
  self.energy_turn_anim = { t = 0, value = value }
  Sfx.play("woosh")
end

--- Chaque aventurier vivant saute un peu vers le haut, l'un après l'autre de
-- gauche à droite (2026-08-21, demande explicite -- dernier beat de la séquence
-- de début de tour, signale "prêt à jouer") -- réutilise l'anim "pulse-up"
-- existante (celle jouée quand une carte se résout sur ce héros), jamais un
-- second mécanisme de rebond à maintenir. `state.heroes` est déjà dans l'ordre
-- d'affichage gauche->droite (voir View.hero_rects), donc une simple itération
-- suffit -- pas besoin de trier.
-- `hero_ref.combat_start_heal`/`combat_start_curse_damage` (2026-08-28/29,
-- demande explicite -- bénédiction/malédiction du Temple) : posés par
-- Game.carried_hero AVANT que ce beat ne joue (chaque entrée en combat
-- rebâtit les héros via carried_hero, voir advance_to_next_combat) --
-- affichés ICI, synchronisés sur le saut de CE héros précisément plutôt
-- qu'en un seul bloc au tout début. Consommés (mis à nil) tout de suite
-- après affichage : ne doivent jamais rejouer sur un tour normal, seulement
-- à l'entrée en combat.
function Controller:play_hero_ready_hops()
  local self_ = self
  for _, h in ipairs(self_.state.heroes) do
    if h.hp > 0 then
      local hero_ref = h
      self_.seq:push(function()
        self_:pulse(hero_ref.id, "pulse-up")
        Sfx.play("hop")
        if hero_ref.combat_start_heal then
          self_:spawn_floater(hero_ref.id, hero_ref.combat_start_heal, "heal")
          hero_ref.combat_start_heal = nil
        end
        if hero_ref.combat_start_curse_damage then
          self_:spawn_floater(hero_ref.id, -hero_ref.combat_start_curse_damage, "damage")
          hero_ref.combat_start_curse_damage = nil
        end
      end, HERO_READY_STAGGER)
    end
  end
end

--- Les 3 beats de début de tour (2026-08-21, demande explicite -- énergie ->
-- pioche -> aventuriers prêts), factorisés pour être rejoués identiques en
-- tout début de partie (voir Controller:reset_run) et à chaque tour normal
-- (voir advance_after_discard_sequenced) -- suppose que state.energy/
-- state.hand/state.last_drawn_uids sont DÉJÀ à jour (Game.start_turn ou
-- Game.reset_run déjà appelé) : ne fait que la mise en scène, aucune règle.
-- `consume_drawn_animation` renvoie désormais sa VRAIE durée totale, remélange
-- défausse -> pioche compris quand il y en a un (2026-08-21, voir son
-- commentaire) -- le saut des aventuriers est donc poussé sur le séquenceur
-- DEPUIS L'INTÉRIEUR de l'étape de pioche, avec cette durée comme attente,
-- plutôt que précalculé à l'avance sur un simple compte de cartes (qui
-- ignorerait un éventuel remélange et ferait sauter les aventuriers trop tôt,
-- par-dessus la fin de la pioche).
function Controller:play_turn_start_sequence()
  local self_ = self
  -- Marquer `pending_draw_uids` DÈS CE BEAT, pas seulement à l'intérieur de
  -- consume_drawn_animation (2026-08-21, bug persistant -- root cause réelle :
  -- Game.start_turn a déjà rempli state.hand de façon synchrone AVANT même que
  -- ce beat démarre, mais l'ancien code ne peuplait pending_draw_uids qu'au
  -- moment où consume_drawn_animation s'exécutait enfin, APRÈS l'attente de
  -- l'anim d'énergie -- entre les deux, rien ne cachait ces cartes, d'où le
  -- symptôme "déjà visibles, puis vol qui semble partir de zéro / zoomer" :
  -- une carte pleinement affichée en main qui, une fois consume_drawn_animation
  -- enfin lancé, se met soudain à "revoler" depuis la pioche par-dessus
  -- elle-même -- le rebond d'arrivée (ease_out_back) sur une carte qui était
  -- déjà là, à sa taille normale, donnait l'illusion d'un grossissement.
  if self_.state.last_drawn_uids then
    for _, uid in ipairs(self_.state.last_drawn_uids) do self_.pending_draw_uids[uid] = true end
  end
  self_:spawn_energy_turn_anim(self_.state.energy)
  self_.seq:push(function() end, TURN_ENERGY_ANIM_DURATION)
  self_.seq:push(function()
    if self_.state.over then return end
    local draw_total = self_:consume_drawn_animation()
    self_.seq:push(function()
      if self_.state.over then return end
      self_:play_hero_ready_hops()
    end, draw_total)
  end)
end

-- `amount` (optionnel, 2026-08-24, demande explicite) : montant de Défense
-- absorbé par ce fondu quand il vient d'intercepter un coup (voir
-- Controller:react_to_diff) -- nil sur un simple gain de Défense, voir
-- draw_shield_fx (view.lua), seul endroit qui l'affiche.
function Controller:spawn_shield_fx(unit_id, amount)
  self.shield_fx[unit_id] = { t = 0, amount = amount }
end

--- Compare PV + statuts avant/après un appel de règles et en déduit tous les
-- retours visuels ET sonores : secousse + nombre flottant + burst de pixels +
-- "plarf"/"waof" sur une perte de PV (selon `opts.dmg_type`, "physique" par
-- défaut), nombre flottant vert sur un soin, pop d'un badge sur toute valeur
-- de statut qui vient d'augmenter (Camouflage compris), gros bouclier
-- + "shting" sur un gain de Défense OU sur un coup intercepté par du
-- bouclier -- MÊME partiellement (2026-08-24, demande explicite : avant,
-- seul un coup INTÉGRALEMENT absorbé jouait le son, sans aucun visuel ; le
-- fondu affiche maintenant le montant absorbé, EN PLUS du nombre flottant de
-- PV perdus si l'absorption n'était que partielle -- voir Combat.deal_damage,
-- qui retire d'abord la Défense avant de laisser passer le reste en PV). Le
-- son d'impact/bouclier ne joue qu'une fois par appel, même si plusieurs
-- unités sont touchées (carte à zone) -- pas une salve de sons identiques
-- superposés. `opts.skip_shield_sfx` : évite un faux "shting" quand la
-- Défense retombe à 0 en début de tour (Game.start_turn), qui n'est pas un
-- blocage de dégâts. Remplace l'ancien shake_from_diff, mêmes points d'appel.
function Controller:react_to_diff(before, opts)
  opts = opts or {}
  local hit_sfx = (opts.dmg_type == "magique") and "hit_magic" or "hit_physical"
  local hit_played, shield_played = false, false
  local function react(u)
    local b = before[u.id]
    if not b then return end
    if u.hp < b.hp then
      self:pulse(u.id, "shake")
      self:spawn_floater(u.id, u.hp - b.hp, "damage")
      self:spawn_impact(u.id)
      if not hit_played then Sfx.play(hit_sfx); hit_played = true end
    elseif u.hp > b.hp then
      self:spawn_floater(u.id, u.hp - b.hp, "heal")
    end
    -- Discrétion (2026-08-28, demande explicite -- "un effet qui indique la
    -- valeur, comme pour un gain de PV") : flottant dédié sur TOUTE hausse,
    -- quelle que soit la source (allié qui agit +1, fin de tour sans agir +5,
    -- carte propre, carte "Furtif" défaussée +2) -- ce diff générique les
    -- couvre TOUTES d'un coup, jamais un site d'appel par source.
    if u.discretion and b.discretion and u.discretion > b.discretion then
      self:spawn_floater(u.id, u.discretion - b.discretion, "discretion")
    end
    for _, k in ipairs(STATUS_KEYS) do
      if (u[k] or 0) > b[k] then self:pop_status(u.id, k) end
    end
    local defense_before, defense_now = b.defense or 0, u.defense or 0
    local absorbed = defense_before - defense_now
    if defense_now > defense_before then
      self:spawn_shield_fx(u.id)
      if not shield_played then Sfx.play("shield"); shield_played = true end
    elseif not opts.skip_shield_sfx and absorbed > 0 then
      self:spawn_shield_fx(u.id, absorbed)
      if not shield_played then Sfx.play("shield"); shield_played = true end
    end
  end
  for _, h in ipairs(self.state.heroes) do react(h) end
  for _, e in ipairs(self.state.enemies) do react(e) end
end

function Controller:update(dt)
  self.seq:update(dt)
  for id, a in pairs(self.anim) do
    a.t = a.t + dt
    local limit = (a.kind == "shake") and ANIM_SHAKE or ANIM_PULSE
    if a.t >= limit then self.anim[id] = nil end
  end
  for i = #self.card_anims, 1, -1 do
    local a = self.card_anims[i]
    a.elapsed = a.elapsed + dt
    if a.elapsed >= a.delay + a.duration then table.remove(self.card_anims, i) end
  end
  -- Écran "Choisis ton équipe" (2026-08-29) : "in" ne se supprime JAMAIS tout
  -- seul (elapsed clampé à duration par le rendu -- voir draw_team_select --
  -- fige la carte à sa position cible, c'est l'état "posée" -- pas de 2ᵉ
  -- système séparé pour ça) ; seul "out" se retire une fois son vol de sortie
  -- terminé.
  if self.team_select then
    local ts_anims = self.team_select.card_anims
    for i = #ts_anims, 1, -1 do
      local a = ts_anims[i]
      a.elapsed = a.elapsed + dt
      -- `a.delay` (2026-08-30, rassemblement vers le deck décalé carte par
      -- carte -- voir team_select_fly_out_current) : nil/0 dans tous les
      -- autres cas, la comparaison reste équivalente à avant.
      if a.mode == "out" and a.elapsed >= (a.delay or 0) + a.duration then table.remove(ts_anims, i) end
    end
    -- Portraits en transit (2026-08-30) : contrairement aux cartes "in",
    -- jamais figés indéfiniment sur place -- une fois l'anim finie, le héros
    -- est exactement à `to` (rangée ou projecteur), la logique de rendu
    -- normale (draw_team_select) prend le relais sans discontinuité visible,
    -- donc l'entrée peut toujours être supprimée dès `elapsed >= duration`.
    local hero_anims = self.team_select.hero_anims
    for i = #hero_anims, 1, -1 do
      local a = hero_anims[i]
      a.elapsed = a.elapsed + dt
      if a.elapsed >= a.duration then table.remove(hero_anims, i) end
    end
  end
  for i = #self.floaters, 1, -1 do
    local f = self.floaters[i]
    f.t = f.t + dt
    if f.t >= self.floater_duration then table.remove(self.floaters, i) end
  end
  for i = #self.particles, 1, -1 do
    local p = self.particles[i]
    p.t = p.t + dt
    if p.t >= self.particle_duration then table.remove(self.particles, i) end
  end
  for _, keys in pairs(self.status_pop) do
    for k, t in pairs(keys) do
      t = t + dt
      if t >= self.status_pop_duration then keys[k] = nil else keys[k] = t end
    end
  end
  for id, s in pairs(self.shield_fx) do
    s.t = s.t + dt
    if s.t >= self.shield_fx_duration then self.shield_fx[id] = nil end
  end
  for i = #self.pending_sfx, 1, -1 do
    local p = self.pending_sfx[i]
    p.delay = p.delay - dt
    if p.delay <= 0 then
      Sfx.play(p.name)
      table.remove(self.pending_sfx, i)
    end
  end
  -- Teste `kind`, pas `target` (2ᵉ occurrence du même bug que hover_ready ci-
  -- dessous -- la pioche/défausse ont `target = nil`, le minuteur ne montait
  -- donc jamais et l'infobulle ne se déclenchait jamais, même après le premier
  -- correctif) : c'est CE compteur qui alimente hover_ready, les deux doivent
  -- utiliser la même condition.
  if self.hover.kind then self.hover.t = self.hover.t + dt end
  if self.energy_turn_anim then
    self.energy_turn_anim.t = self.energy_turn_anim.t + dt
    if self.energy_turn_anim.t >= self.energy_turn_anim_duration then self.energy_turn_anim = nil end
  end
  if self.victory_anim then self.victory_anim.t = self.victory_anim.t + dt end
  for _, f in pairs(self.draft_flip) do f.t = f.t + dt end
  if self.forge_upgrade_anim then self.forge_upgrade_anim.t = self.forge_upgrade_anim.t + dt end
  if self.temple_choice_anim then self.temple_choice_anim.t = self.temple_choice_anim.t + dt end
end

function Controller:set_hover(kind, target)
  if self.hover.kind == kind and self.hover.target == target then return end
  self.hover.kind = kind
  self.hover.target = target
  self.hover.t = 0
end

-- Teste `kind`, pas `target` (bug signalé 2026-08-21) : la pioche/défausse
-- (voir Input.mousemoved) survolent avec `target = nil` -- il n'y a pas
-- d'identifiant naturel à leur donner, contrairement à un héros/ennemi/carte.
-- `set_hover(nil, nil)` (le seul appel qui efface vraiment le survol) laisse
-- `kind` nil lui aussi, donc ce test reste équivalent à l'ancien pour hero/
-- enemy/card, qui avaient toujours un `target` non-nil.
function Controller:hover_ready()
  return self.hover.kind ~= nil and self.hover.t >= HOVER_DELAY
end

-- ---------- jouer une carte ----------

-- Chaque carte appartient à un héros précis (def.class_id, voir Heroes.class_name
-- -- 2026-08-20, une classe = un seul héros) : la sélectionner l'assigne
-- DIRECTEMENT à son propriétaire (Game.select_card), il n'y a plus de choix
-- de héros à faire côté joueur -- remplace l'ancien Controller:assign_hero,
-- qui ne s'appelait plus qu'au clic sur "Jouer". Un héros peut aussi agir
-- plusieurs fois par tour désormais (2026-08-20, demande explicite) : il n'y
-- a donc plus de champ has_acted à comparer avant/après pour savoir si la
-- sélection a réellement abouti -- Game.select_card renvoie directement
-- "deselected"|"refused"|"assigned".
-- Plus aucune carte ne se résout au sein de la sélection elle-même
-- (2026-08-27, voir Game.assign_hero) : même une carte "sans cible" (soi/tous
-- les ennemis) attend désormais un clic de confirmation (voir
-- Controller:confirm_pending), au même titre qu'une carte à cible attend un
-- clic de cible (resolve_target) -- l'animation de pulsation du héros et la
-- résolution réelle vivent donc entièrement dans ces deux fonctions, jamais ici.
function Controller:select_card(uid)
  if self.screen ~= "playing" or self.state.over then return end
  Game.select_card(self.state, uid)
end

function Controller:cancel_pending()
  Game.cancel_pending(self.state)
end

--- Confirme une carte "sans cible" (soi/tous les ennemis) en attente d'un
-- second clic (2026-08-27, demande explicite -- avant, ces cartes se
-- résolvaient dès la sélection, sans laisser au joueur l'occasion de changer
-- d'avis ; voir Game.assign_hero, qui pose `pending.awaiting_confirm_kind` au
-- lieu de résoudre immédiatement). Réutilise exactement resolve_target, qui
-- gère déjà pulse/react_to_diff/animation de défausse quel que soit `kind` --
-- jamais une deuxième copie de cette logique.
function Controller:confirm_pending()
  local pending = self.state.pending
  if not pending or not pending.awaiting_confirm_kind then return end
  local target_id = pending.awaiting_confirm_kind == "self" and pending.hero_id or nil
  self:resolve_target(pending.awaiting_confirm_kind, target_id)
end

function Controller:resolve_target(kind, target_id)
  local pending = self.state.pending
  if not pending or not pending.hero_id then return end
  local played_uid, hand_before = pending.uid, Game.shallow_copy(self.state.hand)
  local dmg_type = pending.def.dmg_type
  self:pulse(pending.hero_id, "pulse-up")
  local before = self:snapshot_units()
  Game.resolve_pending(self.state, kind, target_id)
  self:react_to_diff(before, { dmg_type = dmg_type })
  self:maybe_animate_played_discard(played_uid, hand_before)
  self:consume_drawn_animation() -- Clairvoyance pioche 1 carte dans son effet
  self:after_card_resolved()
end

function Controller:after_card_resolved()
  if self.state.over then self:handle_combat_victory() end
end

-- ---------- fin de tour ----------

-- Défausse de fin de tour puis résolution des monstres, avec une pause dédiée
-- entre les deux (2026-08-21, demande explicite -- avant, la défausse ne
-- faisait qu'animer pendant que la résolution des monstres démarrait déjà en
-- arrière-plan sur la même frame ou presque, les deux se lisaient comme un
-- seul événement confus). `animate_discard_snapshot` renvoie la durée totale
-- de son propre vol -- on l'attend, PLUS END_TURN_TO_ENEMY_RESOLUTION_PAUSE,
-- avant de lancer la suite.
function Controller:end_turn()
  local hand_before = Game.shallow_copy(self.state.hand)
  -- Discrétion "Furtif" (2026-08-28) : Game.end_turn_requested accorde +2
  -- Discrétion par carte Furtif restée en main (voir
  -- Game.grant_furtif_discard_discretion, appelé avant la défausse
  -- elle-même) -- avant/après ici pour que react_to_diff en déduise le
  -- flottant, même mécanisme générique que tout autre gain de Discrétion.
  local before = self:snapshot_units()
  if Game.end_turn_requested(self.state) then
    self:react_to_diff(before)
    local discard_duration = self:animate_discard_snapshot(hand_before)
    self:advance_after_discard_sequenced(discard_duration + END_TURN_TO_ENEMY_RESOLUTION_PAUSE)
  end
end

--- Équivalent discardThenAdvance + advanceAfterDiscard, paceé sur le séquenceur :
-- (pause dédiée après la défausse) -> saignements -> vérifs -> un ennemi à la
-- fois (télégraphe -> petite pause -> action -> 1s d'écart) -> décroissance ->
-- tour suivant (énergie -> pioche -> aventuriers prêts). `pre_pause` (2026-08-21,
-- demande explicite) : temps d'attente avant même le premier beat, voir end_turn.
function Controller:advance_after_discard_sequenced(pre_pause)
  local self_ = self
  self_.seq:push(function() end, pre_pause or 0)
  self_.seq:push(function()
    local before = self_:snapshot_units()
    Game.tick_bleed(self_.state)
    self_:react_to_diff(before)

    if Game.check_defeat(self_.state) then self_:enter_defeat_screen(); return end
    if Game.check_victory(self_.state) then self_:handle_combat_victory(); return end

    for _, e in ipairs(self_.state.enemies) do
      if e.hp > 0 and e.next_move then
        local enemy_ref = e
        -- Saut/télégraphe du monstre, PUIS une petite pause avant que l'action
        -- ne touche réellement sa cible (2026-08-21, demande explicite --
        -- avant, les deux se produisaient dans le même appel, sans transition,
        -- ce qui ne laissait pas le temps de comprendre qui frappait quoi).
        self_.seq:push(function()
          if self_.state.over then return end
          self_:pulse(enemy_ref.id, "pulse-down")
          Sfx.play("enemy_telegraph")
        end, ENEMY_TELEGRAPH_TO_ACTION_DELAY)
        self_.seq:push(function()
          if self_.state.over then return end
          local hp_before = self_:snapshot_units()
          Game.resolve_enemy_action(self_.state, enemy_ref)
          self_:react_to_diff(hp_before)
          if Game.check_defeat(self_.state) then self_:enter_defeat_screen() end
        end, ENEMY_STEP_WAIT)
      end
    end

    self_.seq:push(function()
      if self_.state.over then return end
      Game.decay_end_of_turn_statuses(self_.state)
      if Game.check_defeat(self_.state) then self_:enter_defeat_screen(); return end
      -- Discrétion de l'Assassin (2026-08-24) : "+5 s'IL termine le tour sans
      -- avoir joué de carte lui-même" -- doit lire played_card_this_turn
      -- AVANT que Game.start_turn ne le remette à false pour le tour suivant.
      local discretion_before = self_:snapshot_units()
      Game.tick_discretion_end_of_turn(self_.state)
      self_:react_to_diff(discretion_before)
      self_.state.turn = self_.state.turn + 1
      local turn_before = self_:snapshot_units()
      Game.start_turn(self_.state)
      -- skip_shield_sfx : la Défense de chaque héros retombe à 0 ici (reset de
      -- tour, pas un blocage de dégâts) -- sans cette garde, "shting" jouerait
      -- à chaque tour pour quiconque avait de la Défense restante.
      self_:react_to_diff(turn_before, { skip_shield_sfx = true })
      -- Game.start_turn ne peut plus, à ce jour, infliger de dégâts (les
      -- Pouvoirs de Classe qui le faisaient ont été retirés) -- ce garde-fou
      -- reste par précaution si un futur pouvoir redonnait ce pouvoir à
      -- start_turn, plutôt que d'être supprimé puis oublié le jour venu.
      if self_.state.over then self_:handle_combat_victory(); return end

      self_:play_turn_start_sequence()
    end)
  end)
end

-- ---------- victoire / défaite / draft ----------

function Controller:enter_defeat_screen()
  self.screen = "defeat"
  self.seq:clear() -- inutile de finir de dérouler les ennemis restants une fois la défaite actée
  Sfx.play("defeat")
end

-- Dispatch central de toute victoire de combat (2026-08-21, demande explicite --
-- "il faut enlever le draft de carte et le feu de camp après le boss") : tous
-- les appels de victoire du contrôleur passent par ici plutôt que d'appeler
-- enter_draft_screen directement, pour qu'un seul endroit décide entre le
-- chemin normal (draft -> feu de camp -> combat suivant) et le boss (aucun des
-- deux, juste un bref titre puis retour au menu -- state.run.is_boss est posé
-- par Game.start_boss_test/start_boss_combat, jamais par ce fichier).
function Controller:handle_combat_victory()
  if self.state.run.is_boss then
    self:enter_boss_victory()
  else
    self:enter_draft_screen()
  end
end

function Controller:enter_boss_victory()
  self.screen = "bossVictory"
  self.card_anims = {}
  self.victory_anim = { t = 0 }
  Sfx.play("victory")
  local self_ = self
  self.seq:push(function() end, BOSS_VICTORY_HOLD_DURATION)
  self.seq:push(function() self_:enter_menu() end)
end

function Controller:enter_draft_screen()
  self.screen = "draft"
  self.draft_picks = Draft.pick_cards(self.state)
  self.draft_cards_shown = false
  self.draft_flip = {}
  self.victory_anim = { t = 0 }
  Sfx.play("victory")
  local self_ = self
  self.seq:push(function() end, VICTORY_TITLE_DURATION)
  self.seq:push(function() self_.draft_cards_shown = true end, DRAFT_FACEDOWN_PAUSE)
  for i = 1, #self.draft_picks do
    local idx = i
    -- "flush" (même son que la pioche, demandé identique) au retournement de
    -- CHAQUE carte, pas seulement au premier -- cohérent avec le "une par une".
    self.seq:push(function() self_.draft_flip[idx] = { t = 0 }; Sfx.play("flush") end, DRAFT_FLIP_DURATION + DRAFT_FLIP_GAP)
  end
end

--- Vrai une fois que LE retournement de cette carte (et lui seul) est
-- terminé -- chaque carte devient cliquable dès la fin de SON animation,
-- pas seulement une fois les 3 retournées (cohérent avec le "une par une").
function Controller:draft_card_ready(index)
  local f = self.draft_flip[index]
  return f ~= nil and f.t >= DRAFT_FLIP_DURATION
end

function Controller:choose_draft_card(index)
  if self.screen ~= "draft" or not self.draft_picks or not self:draft_card_ready(index) then return end
  local def = self.draft_picks[index]
  self.state.deck[#self.state.deck + 1] = { uid = Game.next_uid(self.state), def = def }
  Combat.log(self.state, def.name .. " ajoutée au deck.", "sys")
  self.draft_picks = nil
  self.card_anims = {}
  self:enter_post_combat_sequence()
end

-- ---------- forge / temple (post-combat) ----------

--- Tire, une seule fois par combat gagné, LEQUEL des 2 écrans "camp" apparaîtra
-- (0, 1 ou 2 -- jamais le même deux fois, voir POST_COMBAT_FORGE_CHANCE/
-- TEMPLE_CHANCE en tête de fichier) puis lance la file (voir
-- advance_post_combat_queue). `state.rng.post_combat` : flux dédié à CE
-- tirage-là seulement, jamais celui qui décide du CONTENU de la Forge/du
-- Temple (state.rng.forge/temple, consommés seulement si l'écran apparaît
-- vraiment) -- comme ça, ajouter/retirer un écran de la file ne décale jamais
-- les tirages de l'autre.
function Controller:enter_post_combat_sequence()
  local rng = self.state.rng.post_combat
  local queue = {}
  if rng:random() < POST_COMBAT_FORGE_CHANCE then queue[#queue + 1] = "forge" end
  if rng:random() < POST_COMBAT_TEMPLE_CHANCE then queue[#queue + 1] = "temple" end
  self.post_combat_queue = queue
  self:advance_post_combat_queue()
end

--- Dépile le prochain écran "camp" à montrer (Forge, Temple, ou aucun -- passe
-- alors directement au combat suivant). Point de retour unique de
-- finish_forge/finish_temple, jamais d'aiguillage dupliqué ailleurs.
function Controller:advance_post_combat_queue()
  local next_screen = table.remove(self.post_combat_queue, 1)
  if next_screen == "forge" then
    self:enter_forge_screen()
  elseif next_screen == "temple" then
    self:enter_temple_screen()
  else
    self:advance_to_next_combat()
  end
end

--- Entre sur l'écran "La Forge" (2026-08-28, demande explicite) : jusqu'à
-- Forge.CHOICE_COUNT (4) cartes tirées au hasard parmi tout le deck encore
-- améliorable, moins si le deck n'en a pas assez, jusqu'à 0 -- tirées ICI, une
-- seule fois, via state.rng.forge, même principe que Draft.pick_cards.
function Controller:enter_forge_screen()
  self.screen = "forge"
  self.forge = { choices = Forge.pick_choices(self.state, self.state.rng.forge) }
end

--- Vrai tant que le choix n'est pas encore fait -- garde contre un double-clic
-- pendant la pause de résolution (self.screen reste "forge" jusqu'à ce que
-- finish_forge bascule réellement d'écran).
local function forge_choosable(self)
  local f = self.forge
  return self.screen == "forge" and f ~= nil and not f.resolved
end

--- Snapshot du def de BASE avant mutation (2026-08-11, demande explicite) --
-- Forge.apply_upgrade remplace `instance.def` par la version "+" ; l'anim de
-- transition a besoin des deux (base qui s'efface en fondu, "+" qui se
-- recentre) donc on garde le def de base à part avant l'appel, jamais
-- reconstruit après coup (Cards.upgraded_def sur un def déjà amélioré
-- doublerait le suffixe " +"). Les AUTRES propositions (jamais choisies)
-- s'effacent simplement en fondu, voir draw_forge dans view.lua -- rien à
-- mémoriser pour elles, leur def de base reste ce qu'il est.
function Controller:choose_forge_card(index)
  if not forge_choosable(self) then return end
  local f = self.forge
  local instance = f.choices[index]
  if not instance then return end
  f.resolved = true
  local base_def = instance.def
  Forge.apply_upgrade(instance)
  self.forge_upgrade_anim = { chosen_index = index, base_def = base_def, t = 0 }
  Sfx.play("upgrade")
  self:finish_forge(FORGE_UPGRADE_ANIM_DURATION + FORGE_UPGRADE_HOLD_PAUSE)
end

--- "Passer" -- seule option valide quand aucune carte n'est proposée (deck
-- entièrement amélioré, voir Forge.pick_choices).
function Controller:choose_forge_skip()
  if not forge_choosable(self) then return end
  local f = self.forge
  if #f.choices > 0 then return end
  f.resolved = true
  self:finish_forge()
end

--- `pause` (optionnel) : durée avant l'étape suivante -- POST_COMBAT_RESOLVE_PAUSE
-- par défaut (passer), plus long après un vrai choix pour laisser l'animation
-- de fondu/recentrage se jouer (voir choose_forge_card).
function Controller:finish_forge(pause)
  local self_ = self
  self.seq:push(function() end, pause or POST_COMBAT_RESOLVE_PAUSE)
  self.seq:push(function()
    self_.forge = nil
    self_.forge_upgrade_anim = nil
    self_.card_anims = {}
    self_:advance_post_combat_queue()
  end)
end

--- Entre sur l'écran "Le Temple" (2026-08-29, refonte complète -- demande
-- explicite) : tire d'abord le TYPE de cette visite (bénédiction OU
-- malédiction, jamais les deux -- voir Temple.roll_type), puis jusqu'à 3
-- effets distincts de ce type et la liste des aventuriers éligibles -- tout
-- ICI, une seule fois, via state.rng.temple. AUCUN "Passer" possible sur cet
-- écran ("il ne peut pas ne pas choisir") : si aucun type n'a rien à
-- proposer, Temple.roll_type renvoie nil et cet écran n'apparaît simplement
-- pas -- on saute directement à la suite de la file, exactement comme si le
-- Temple n'avait pas été tiré du tout ce combat-ci.
function Controller:enter_temple_screen()
  local rng = self.state.rng.temple
  local t = Temple.roll_type(self.state, rng)
  if not t then
    self:advance_post_combat_queue()
    return
  end
  self.screen = "temple"
  self.temple = {
    type = t,
    choices = Temple.pick_choices(t, rng),
    eligible = Temple.eligible_heroes(self.state, t),
    chosen_effect_index = nil, chosen_hero_id = nil,
  }
end

local function temple_choosable(self)
  local t = self.temple
  return self.screen == "temple" and t ~= nil and not t.resolved
end

--- Le joueur clique une des statues proposées -- change juste la sélection
-- tant que non confirmé (voir Controller:confirm_temple_choice), comme pour
-- l'aventurier ci-dessous. Les 3 statues sont toujours du MÊME type, donc
-- toujours compatibles avec n'importe quel aventurier éligible -- pas de
-- grisage entre les deux dimensions, seule l'éligibilité de l'AVENTURIER
-- limite quoi que ce soit (voir choose_temple_hero).
function Controller:choose_temple_effect(index)
  if not temple_choosable(self) then return end
  local t = self.temple
  if not t.choices[index] then return end
  t.chosen_effect_index = index
end

--- Le joueur clique un des aventuriers -- refuse silencieusement un id hors
-- de `eligible` (aventurier mort ou déjà porteur de ce TYPE d'effet, voir
-- Temple.eligible_heroes -- grisés côté UI, voir View.temple_hero_rects/
-- draw_temple).
function Controller:choose_temple_hero(hero_id)
  if not temple_choosable(self) then return end
  local t = self.temple
  local found = false
  for _, h in ipairs(t.eligible) do if h.id == hero_id then found = true end end
  if not found then return end
  t.chosen_hero_id = hero_id
end

--- "Confirmer" (2026-08-29, demande explicite -- "le joueur doit choisir 1
-- aventurier et 1 effet, puis confirmer") : ne fait rien tant que les DEUX ne
-- sont pas choisis -- jamais de résolution automatique dès le 2ᵉ clic,
-- contrairement à la Forge/Assassinat/etc. Lance ensuite l'anim "les statues
-- non choisies fade, celle choisie reste + 'Bonne chance'" (voir
-- temple_choice_anim, consommée par draw_temple dans view.lua).
function Controller:confirm_temple_choice()
  if not temple_choosable(self) then return end
  local t = self.temple
  if not t.chosen_effect_index or not t.chosen_hero_id then return end
  local hero
  for _, h in ipairs(t.eligible) do if h.id == t.chosen_hero_id then hero = h end end
  if not hero then return end
  t.resolved = true
  Temple.assign(hero, t.choices[t.chosen_effect_index])
  self.temple_choice_anim = { chosen_index = t.chosen_effect_index, t = 0 }
  Sfx.play("heal")
  self:finish_temple(TEMPLE_CHOICE_ANIM_DURATION + TEMPLE_CHOICE_HOLD_PAUSE)
end

function Controller:finish_temple(pause)
  local self_ = self
  self.seq:push(function() end, pause or POST_COMBAT_RESOLVE_PAUSE)
  self.seq:push(function()
    self_.temple = nil
    self_.temple_choice_anim = nil
    self_:advance_post_combat_queue()
  end)
end

--- Dernière étape de la file "camp" (Forge/Temple épuisées, ou aucune des deux
-- n'était apparue) : bascule vers le combat suivant, comme l'ancien
-- finish_feu_de_camp. Le cas "Tester le boss" gagné ne passe plus jamais par
-- ici (2026-08-21+ : state.run.is_boss fait sortir la victoire du boss via
-- Controller:handle_combat_victory/enter_boss_victory bien avant d'atteindre
-- le draft ou le camp) -- cette fonction ne gère donc que la progression ENTRE
-- deux combats non-boss d'un run normal, boss compris comme destination (pas
-- comme victoire). Run borné à 5 combats + 1 boss : le combat contre l'Homme
-- Arbre (Game.start_boss_combat) remplace le 6ᵉ combat classique --
-- `state.run.combat_index` porte encore le numéro du combat qui vient d'être
-- gagné (Game.start_next_combat/start_boss_combat, plus bas, sont ce qui
-- l'incrémente), donc >= 5 ici veut dire "le 5ᵉ combat vient d'être bouclé".
-- `play_turn_start_sequence()` (2026-08-28, remplace un simple
-- consume_drawn_animation) : nécessaire pour que le petit saut de chaque
-- aventurier (voir play_hero_ready_hops) rejoue à l'entrée en combat, pas
-- seulement en cours de run -- c'est CE beat qui affiche le flottant vert
-- d'une bénédiction de soin (voir hero.combat_start_heal, posé par
-- Game.carried_hero). `skip_shield_sfx` : la Défense de chaque héros retombe à
-- 0 à l'entrée en combat (voir carried_hero), pas un blocage de dégâts.
function Controller:advance_to_next_combat()
  local self_ = self
  self.screen = "playing"
  self.state.over = false
  local before = self:snapshot_units()
  if self.run_mode == "bounded" and self.state.run.combat_index >= 5 then
    Game.start_boss_combat(self.state)
  else
    Game.start_next_combat(self.state)
  end
  self:react_to_diff(before, { skip_shield_sfx = true })
  if self.state.over then self_:handle_combat_victory(); return end
  self:play_turn_start_sequence()
end

return Controller
