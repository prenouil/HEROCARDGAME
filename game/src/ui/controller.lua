-- Colle la UI au moteur de règles pur (src/rules) et au séquenceur (src/util).
-- Tout ce qui est "attendre 1s entre deux ennemis", "montrer l'écran de draft",
-- "revenir au village après une défaite" vit ici — jamais dans src/rules.

local Game = require("src.rules.game")
local Combat = require("src.rules.combat")
local Draft = require("src.rules.draft")
local FeuDeCamp = require("src.rules.feu_de_camp")
local Sequencer = require("src.util.sequencer")
-- Dépendance à la UI (rects de layout, purs -- aucun appel love.graphics dedans)
-- nécessaire pour savoir D'OÙ une carte part visuellement quand elle est piochée
-- ou défaussée ; voir View.hand_rects_for/deck_pile_rect/discard_pile_rect.
local View = require("src.ui.view")
local Sfx = require("src.ui.sfx")

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

-- Écran "feuDeCamp" (2026-08-10, demande explicite) : entre le draft de fin de
-- combat et le combat suivant, s'intercale de façon transparente (n'avance
-- jamais le budget de difficulté). Petite pause après le choix pour laisser le
-- temps à l'animation/au son de soin ou d'amélioration de se voir avant que le
-- combat suivant démarre.
local FEU_DE_CAMP_RESOLVE_PAUSE = 0.6

-- Choix "amélioration" (2026-08-11, demande explicite) : les 2 cartes de base
-- et les flèches disparaissent en fondu pendant que les 2 cartes améliorées se
-- recentrent dans leur case, PUIS 1s de pause (cartes déjà réglées, juste le
-- temps de les lire) avant d'enchaîner sur le combat suivant -- remplace la
-- pause générique FEU_DE_CAMP_RESOLVE_PAUSE sur ce chemin précis.
local FEU_DE_CAMP_UPGRADE_ANIM_DURATION = 0.5
local FEU_DE_CAMP_UPGRADE_HOLD_PAUSE = 1.0

-- VFX de lisibilité (2026-08-09, party "amélioration des visuels") : tous
-- dérivés du même mécanisme de diff avant/après déjà en place pour la
-- secousse (voir Controller:react_to_diff, ex-shake_from_diff), pas de
-- nouveau point d'accroche dans src/rules.
local FLOATER_DURATION = 0.9 -- s -- nombre de dégâts/soin flottant
local PARTICLE_DURATION = 0.45 -- s -- petit burst de pixels à l'impact
local PARTICLE_COUNT = 6
local STATUS_POP_DURATION = 0.35 -- s -- pop d'échelle d'un badge de statut à son application
local SHIELD_FX_DURATION = 1.0 -- s -- gros bouclier en fondu sur un gain de Défense
-- Champs de statut comparés avant/après pour déclencher le pop.
local STATUS_KEYS = { "defense", "esquive", "saignements", "incapacite", "vulnerabilite", "puissance", "camoufle" }

function Controller.new()
  local self = setmetatable({}, Controller)
  self.state = Game.new_state()
  self.seq = Sequencer.new()
  self.screen = "menu" -- "menu" | "options" | "playing" | "draft" | "feuDeCamp" | "bossVictory" | "defeat"
  -- Mode de run choisi au menu (2026-08-21, demande explicite) : "infini"
  -- (illimité, l'ancien comportement par défaut), "bounded" (5 combats puis
  -- l'Homme Arbre, voir Controller:finish_feu_de_camp/Game.start_boss_combat)
  -- ou "boss_test" (combat isolé contre le boss, voir
  -- Controller:start_boss_test -- une victoire ramène au menu plutôt que
  -- d'enchaîner un faux combat suivant). nil tant qu'aucun run n'a encore
  -- démarré (écran "menu").
  self.run_mode = nil
  self.draft_picks = nil
  self.feu_de_camp = nil -- { heal_target = hero|nil, upgrade_targets = {instance,instance}|nil }, voir enter_feu_de_camp_screen
  self.feu_de_camp_upgrade_anim = nil -- { base_defs = {def,def}, t = elapsed }, voir choose_feu_de_camp_upgrade
  self.feu_de_camp_upgrade_anim_duration = FEU_DE_CAMP_UPGRADE_ANIM_DURATION -- lu par view.lua pour l'easing
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
  -- n'est appelé qu'au clic sur "Jouer un run"/"Mode infini", voir Input.mousepressed.
  return self
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
  self.feu_de_camp = nil
  self.feu_de_camp_upgrade_anim = nil
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
function Controller:reset_run(mode)
  self.run_mode = mode or self.run_mode or "infini"
  self.screen = "playing"
  self:clear_animation_state()
  Game.reset_run(self.state)
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
-- Controller:finish_feu_de_camp.
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
      end
    end
  end
  return i > 0 and ((i - 1) * END_TURN_DISCARD_STAGGER + END_TURN_DISCARD_FLIGHT_DURATION) or 0
end

--- Anime une seule carte (celle qui vient d'être jouée, si elle a bien fini en
-- défausse -- pas si elle est restée en main ou retournée au sommet du deck)
-- depuis son rect dans `hand_before` (capturé avant l'appel qui la résout).
function Controller:maybe_animate_played_discard(played_uid, hand_before)
  if not played_uid then return end
  local last = self.state.discard[#self.state.discard]
  if not last or last.uid ~= played_uid then return end -- pas parti en défausse (main/dessus du deck/pas encore résolu)
  local hand_rects = View.hand_rects_for(hand_before)
  local origin = hand_rects[played_uid]
  if not origin then return end
  self.card_anims[#self.card_anims + 1] = {
    from = origin, to = View.discard_pile_rect, elapsed = 0, delay = 0,
    duration = FLIGHT_DURATION, fade_in = false, def = last.def,
  }
  Sfx.play("flup")
end

--- Capture PV + statuts de toutes les unités -- même principe que l'ancien
-- snapshot_hp (juste avant un appel de règles), étendu pour que
-- Controller:react_to_diff puisse aussi détecter l'application d'un statut,
-- pas seulement une perte de PV.
function Controller:snapshot_units()
  local out = {}
  local function capture(list)
    for _, u in ipairs(list) do
      local snap = { hp = u.hp }
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
function Controller:play_hero_ready_hops()
  local self_ = self
  for _, h in ipairs(self_.state.heroes) do
    if h.hp > 0 then
      local hero_ref = h
      self_.seq:push(function()
        self_:pulse(hero_ref.id, "pulse-up")
        Sfx.play("hop")
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
  if self.feu_de_camp_upgrade_anim then self.feu_de_camp_upgrade_anim.t = self.feu_de_camp_upgrade_anim.t + dt end
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
  if Game.end_turn_requested(self.state) then
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
  self:enter_feu_de_camp_screen()
end

-- ---------- feu de camp ----------

--- Entre sur l'écran "feuDeCamp", entre le draft et le combat suivant (2026-08-10,
-- demande explicite). Les deux options possibles (soin/résurrection de
-- l'aventurier le plus blessé, amélioration de 2 cartes tirées au hasard) sont
-- tirées ICI, une seule fois, via state.rng.feu_de_camp -- même principe que
-- Draft.pick_cards pour l'écran de draft : ce qui sera montré au joueur ne
-- dépend jamais de quand il clique, seulement de l'état au moment d'entrer sur
-- l'écran. nil sur l'un ou l'autre grise l'option correspondante côté UI.
function Controller:enter_feu_de_camp_screen()
  self.screen = "feuDeCamp"
  local rng = self.state.rng.feu_de_camp
  local heal_target = FeuDeCamp.most_wounded_hero(self.state, rng)
  local upgrade_targets = FeuDeCamp.pick_upgrade_targets(self.state, rng)
  self.feu_de_camp = { heal_target = heal_target, upgrade_targets = upgrade_targets }
end

--- Vrai tant que le choix n'est pas encore fait -- garde contre un double-clic
-- pendant FEU_DE_CAMP_RESOLVE_PAUSE (self.screen reste "feuDeCamp" jusqu'à ce
-- que finish_feu_de_camp bascule réellement d'écran, voir son commentaire).
local function feu_de_camp_choosable(self)
  local fdc = self.feu_de_camp
  return self.screen == "feuDeCamp" and fdc ~= nil and not fdc.resolved
end

function Controller:choose_feu_de_camp_heal()
  if not feu_de_camp_choosable(self) then return end
  local fdc = self.feu_de_camp
  if not fdc.heal_target then return end
  fdc.resolved = true
  local hero = fdc.heal_target
  local before_hp = hero.hp
  FeuDeCamp.heal_hero(hero)
  local healed = hero.hp - before_hp
  if healed > 0 then self:spawn_floater(hero.id, healed, "heal") end
  Sfx.play("heal")
  self:finish_feu_de_camp()
end

--- Snapshot des defs de BASE avant mutation (2026-08-11, demande explicite) --
-- FeuDeCamp.apply_upgrades remplace `instance.def` par la version "+" ; l'anim
-- de transition a besoin des deux (base qui s'efface en fondu, "+" qui se
-- recentre) donc on garde les defs de base à part avant l'appel, jamais
-- reconstruites après coup (Cards.upgraded_def sur un def déjà amélioré
-- doublerait le suffixe " +").
function Controller:choose_feu_de_camp_upgrade()
  if not feu_de_camp_choosable(self) then return end
  local fdc = self.feu_de_camp
  if not fdc.upgrade_targets then return end
  fdc.resolved = true
  local base_defs = {}
  for i, instance in ipairs(fdc.upgrade_targets) do base_defs[i] = instance.def end
  FeuDeCamp.apply_upgrades(fdc.upgrade_targets)
  self.feu_de_camp_upgrade_anim = { base_defs = base_defs, t = 0 }
  Sfx.play("upgrade")
  self:finish_feu_de_camp(FEU_DE_CAMP_UPGRADE_ANIM_DURATION + FEU_DE_CAMP_UPGRADE_HOLD_PAUSE)
end

--- "Passer" (2026-08-10, demande explicite) : seule option valide quand le
-- soin ET l'amélioration sont tous les deux grisés (personne blessé et moins
-- de 2 cartes améliorables).
function Controller:choose_feu_de_camp_skip()
  if not feu_de_camp_choosable(self) then return end
  local fdc = self.feu_de_camp
  if fdc.heal_target or fdc.upgrade_targets then return end
  fdc.resolved = true
  self:finish_feu_de_camp()
end

--- `pause` (optionnel) : durée avant l'étape suivante -- FEU_DE_CAMP_RESOLVE_PAUSE
-- par défaut (soin/passer), plus long sur le chemin amélioration pour laisser
-- l'animation de fondu/recentrage se jouer (voir choose_feu_de_camp_upgrade).
function Controller:finish_feu_de_camp(pause)
  local self_ = self
  -- Même idiome que Controller:enter_draft_screen (fn vide + durée = "attends",
  -- PUIS l'étape suivante fait le travail) : Sequencer:push exécute run_fn
  -- immédiatement et attend `wait_after` avant l'étape SUIVANTE, jamais avant
  -- run_fn lui-même -- voir src/util/sequencer.lua.
  self.seq:push(function() end, pause or FEU_DE_CAMP_RESOLVE_PAUSE)
  self.seq:push(function()
    self_.feu_de_camp = nil
    self_.feu_de_camp_upgrade_anim = nil
    self_.card_anims = {}
    -- Le cas "Tester le boss" gagné ne passe plus jamais par ici (2026-08-21+ :
    -- state.run.is_boss fait sortir la victoire du boss via
    -- Controller:handle_combat_victory/enter_boss_victory bien avant
    -- d'atteindre le draft ou le feu de camp, voir plus haut) -- cette fonction
    -- ne gère donc plus que la progression ENTRE deux combats non-boss d'un
    -- run normal, boss compris comme destination (pas comme victoire).
    -- Run borné à 5 combats + 1 boss : le combat contre l'Homme Arbre
    -- (Game.start_boss_combat) remplace le 6ᵉ combat classique --
    -- `state.run.combat_index` porte encore le numéro du combat qui vient
    -- d'être gagné (Game.start_next_combat/start_boss_combat, plus bas, sont
    -- ce qui l'incrémente), donc >= 5 ici veut dire "le 5ᵉ combat vient
    -- d'être bouclé".
    self_.screen = "playing"
    self_.state.over = false
    if self_.run_mode == "bounded" and self_.state.run.combat_index >= 5 then
      Game.start_boss_combat(self_.state)
    else
      Game.start_next_combat(self_.state)
    end
    self_:consume_drawn_animation()
    if self_.state.over then self_:handle_combat_victory() end
  end)
end

return Controller
