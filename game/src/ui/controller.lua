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
local FLIGHT_DURATION = 0.38 -- s, calque sur FLIGHT_MS (380ms) du prototype
local DRAW_STAGGER = 0.07 -- s entre deux cartes piochées, calque sur i*70ms
local DISCARD_STAGGER = 0.06 -- s entre deux cartes défaussées, calque sur i*60ms

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

-- Écran "feuDeCamp" (2026-08-10, demande explicite) : entre le draft de fin de
-- combat et le combat suivant, s'intercale de façon transparente (n'avance
-- jamais le budget de difficulté). Petite pause après le choix pour laisser le
-- temps à l'animation/au son de soin ou d'amélioration de se voir avant que le
-- combat suivant démarre.
local FEU_DE_CAMP_RESOLVE_PAUSE = 0.6

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
  self.screen = "playing" -- "playing" | "draft" | "feuDeCamp" | "defeat"
  self.draft_picks = nil
  self.feu_de_camp = nil -- { heal_target = hero|nil, upgrade_targets = {instance,instance}|nil }, voir enter_feu_de_camp_screen
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
  self.hover = { target = nil, kind = nil, t = 0 } -- kind: "hero"|"enemy"|"card"
  -- Mode d'entrée alterné (2026-08-09, spike) : "tap" = séquence à 3 clics
  -- (existant) ; "arrow" = sélection au survol + flèche dynamique façon Slay
  -- the Spire -- devenu le défaut (2026-08-09, retour positif du porteur de
  -- projet après playtest), "tap" reste disponible via le bouton de bascule.
  self.input_mode = "arrow"
  self.arrow_hand_hover_uid = nil -- carte de la main survolée en mode "arrow" (agrandissement immédiat, sans délai de tooltip)
  self:reset_run()
  return self
end

function Controller:toggle_input_mode()
  self.input_mode = (self.input_mode == "arrow") and "tap" or "arrow"
  self.arrow_hand_hover_uid = nil
end

function Controller:set_arrow_hand_hover(uid)
  self.arrow_hand_hover_uid = uid
end

function Controller:reset_run()
  self.screen = "playing"
  self.draft_picks = nil
  self.feu_de_camp = nil
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
  Game.reset_run(self.state)
  self:consume_drawn_animation()
  -- Game.start_turn (appelé par reset_run) ne peut plus infliger de dégâts à
  -- ce jour -- garde-fou conservé par précaution, voir advance_after_discard_sequenced.
  if self.state.over then self:enter_draft_screen() end
end

function Controller:restart_combat()
  self.screen = "playing"
  self.seq:clear()
  self.anim = {}
  self.card_anims = {}
  self.floaters = {}
  self.particles = {}
  self.status_pop = {}
  self.shield_fx = {}
  Game.restore_combat_snapshot(self.state)
  self:consume_drawn_animation()
  if self.state.over then self:enter_draft_screen() end
end

--- Recommence uniquement le tour en cours (2026-08-10, demande explicite) --
-- même nettoyage d'état d'animation que restart_combat, mais restaure la photo de
-- tour (Game.restore_turn_snapshot) plutôt que celle de combat.
function Controller:restart_turn()
  self.screen = "playing"
  self.seq:clear()
  self.anim = {}
  self.card_anims = {}
  self.floaters = {}
  self.particles = {}
  self.status_pop = {}
  self.shield_fx = {}
  Game.restore_turn_snapshot(self.state)
  self:consume_drawn_animation()
  if self.state.over then self:enter_draft_screen() end
end

--- Outil de test (2026-08-08) : termine le combat en cours par une victoire
-- immédiate (tous les ennemis à 0 PV), sans passer par la résolution réelle --
-- réutilise le même chemin que la victoire normale (`Game.check_victory` +
-- `enter_draft_screen`) pour que l'écran de récompense se comporte à
-- l'identique, seule la façon d'y arriver diffère.
function Controller:trigger_instant_victory()
  if self.screen ~= "playing" or self.state.over then return end
  for _, e in ipairs(self.state.enemies) do e.hp = 0 end
  if Game.check_victory(self.state) then self:enter_draft_screen() end
end

-- ---------- cosmétique ----------

function Controller:pulse(unit_id, kind)
  self.anim[unit_id] = { kind = kind, t = 0 }
end

-- ---------- vol de cartes (pioche <-> main <-> défausse) ----------

--- Anime les cartes dont les uids sont donnés depuis la pioche vers leur
-- emplacement ACTUEL dans state.hand (appelé APRÈS que la pioche a eu lieu :
-- les cartes sont déjà dans state.hand, donc View.hand_rects reflète leur
-- position d'arrivée directement).
function Controller:animate_draw(drawn_uids)
  if not drawn_uids or #drawn_uids == 0 then return end
  local hand_rects = View.hand_rects(self.state)
  local origin = View.deck_pile_rect
  for i, uid in ipairs(drawn_uids) do
    local dest = hand_rects[uid]
    if dest then
      local def
      for _, c in ipairs(self.state.hand) do if c.uid == uid then def = c.def break end end
      self.card_anims[#self.card_anims + 1] = {
        from = origin, to = dest, elapsed = 0, delay = (i - 1) * DRAW_STAGGER,
        duration = FLIGHT_DURATION, fade_in = true, def = def, uid = uid,
      }
    end
  end
end

--- Lit state.last_drawn_uids (posé par Deck.draw_cards/fill_hand, voir
-- src/rules/deck.lua) et lance l'animation correspondante, puis le vide --
-- point d'accroche unique pour tous les chemins de pioche (début de tour,
-- Clairvoyance en cours de tour), sans dupliquer l'appel dans chacun.
function Controller:consume_drawn_animation()
  local drawn = self.state.last_drawn_uids
  self.state.last_drawn_uids = nil
  if drawn then
    self:animate_draw(drawn)
    if #drawn > 0 then Sfx.play("flush") end
  end
end

--- Anime `cards` (liste de {uid, def, ...}, une COPIE de state.hand prise
-- AVANT la défausse -- voir View.hand_rects_for) depuis leur position d'ORIGINE
-- dans cette main-là vers la défausse. `exclude_uid` (optionnel) : carte à ne
-- pas animer (celle que le Mage garde).
function Controller:animate_discard_snapshot(cards, exclude_uid)
  if not cards or #cards == 0 then return end
  local hand_rects = View.hand_rects_for(cards)
  local dest = View.discard_pile_rect
  local i = 0
  for _, c in ipairs(cards) do
    if c.uid ~= exclude_uid then
      i = i + 1
      local origin = hand_rects[c.uid]
      if origin then
        self.card_anims[#self.card_anims + 1] = {
          from = origin, to = dest, elapsed = 0, delay = (i - 1) * DISCARD_STAGGER,
          duration = FLIGHT_DURATION, fade_in = false, def = c.def,
        }
      end
    end
  end
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

function Controller:spawn_shield_fx(unit_id)
  self.shield_fx[unit_id] = { t = 0 }
end

--- Compare PV + statuts avant/après un appel de règles et en déduit tous les
-- retours visuels ET sonores : secousse + nombre flottant + burst de pixels +
-- "plarf"/"waof" sur une perte de PV (selon `opts.dmg_type`, "physique" par
-- défaut), nombre flottant vert sur un soin, pop d'un badge sur toute valeur
-- de statut qui vient d'augmenter (Camouflage compris), gros bouclier
-- + "shting" sur un gain de Défense OU des dégâts intégralement absorbés
-- (défense qui baisse sans perte de PV -- voir Combat.deal_damage). Le son
-- d'impact/bouclier ne joue qu'une fois par appel, même si plusieurs unités
-- sont touchées (carte à zone) -- pas une salve de sons identiques superposés.
-- `opts.skip_shield_sfx` : évite un faux "shting" quand la Défense retombe à
-- 0 en début de tour (Game.start_turn), qui n'est pas un blocage de dégâts.
-- Remplace l'ancien shake_from_diff, mêmes points d'appel.
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
    local defense_now = u.defense or 0
    if defense_now > b.defense then
      self:spawn_shield_fx(u.id)
      if not shield_played then Sfx.play("shield"); shield_played = true end
    elseif not opts.skip_shield_sfx and defense_now < b.defense and u.hp == b.hp then
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
  if self.hover.target then self.hover.t = self.hover.t + dt end
  if self.victory_anim then self.victory_anim.t = self.victory_anim.t + dt end
  for _, f in pairs(self.draft_flip) do f.t = f.t + dt end
end

function Controller:set_hover(kind, target)
  if self.hover.kind == kind and self.hover.target == target then return end
  self.hover.kind = kind
  self.hover.target = target
  self.hover.t = 0
end

function Controller:hover_ready()
  return self.hover.target ~= nil and self.hover.t >= HOVER_DELAY
end

-- ---------- jouer une carte ----------

function Controller:select_card(uid)
  if self.screen ~= "playing" or self.state.over then return end
  Game.select_card(self.state, uid)
end

function Controller:set_pending_mode(mode)
  Game.set_pending_mode(self.state, mode)
end

function Controller:cancel_pending()
  Game.cancel_pending(self.state)
end

-- Boutons "Jouer"/"Se concentrer" par héros (2026-08-08) : choisit le mode et
-- assigne le héros en un seul appel -- Input.lua a déjà vérifié l'éligibilité
-- (Combat.can_play/can_concentrate) avant d'appeler ceci, mais on revérifie
-- que rien n'a changé entre-temps (mode déjà choisi = clic ignoré).
function Controller:choose_mode_and_assign(hero_id, mode)
  local pending = self.state.pending
  if not pending or pending.mode then return end
  self:set_pending_mode(mode)
  self:assign_hero(hero_id)
end

-- L'animation de pulsation du héros (et donc, indirectement, le voile gris
-- "a agi" qui suit au prochain affichage) ne doit se déclencher qu'à la
-- résolution RÉELLE de l'action -- pas à la simple assignation, qui peut
-- encore attendre un clic de cible (ennemi/allié). D'où le `if resolved`
-- ci-dessous : pour une carte auto-résolue (soi/tous les ennemis/concentration),
-- `Game.assign_hero` résout tout en un seul appel et `resolved` est déjà vrai ;
-- pour une carte à cible, le pulse est différé jusqu'à `resolve_target`.
function Controller:assign_hero(hero_id)
  local pending = self.state.pending
  if not pending then return end
  local played_uid, hand_before = pending.uid, Game.shallow_copy(self.state.hand)
  local dmg_type, is_concentrate = pending.def.dmg_type, pending.mode == "concentrate"
  local before = self:snapshot_units()
  local resolved = Game.assign_hero(self.state, hero_id)
  if resolved then self:pulse(hero_id, "pulse-up") end
  if resolved and is_concentrate then Sfx.play("concentrate") end
  self:react_to_diff(before, { dmg_type = dmg_type })
  self:maybe_animate_played_discard(played_uid, hand_before)
  self:consume_drawn_animation() -- Clairvoyance : le mode "concentrate" ne pioche jamais, mais "play" le peut
  if resolved then self:after_card_resolved() end
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
  if self.state.over then self:enter_draft_screen() end
end

-- ---------- fin de tour ----------

function Controller:end_turn()
  local hand_before = Game.shallow_copy(self.state.hand)
  if Game.end_turn_requested(self.state) then
    self:animate_discard_snapshot(hand_before)
    self:advance_after_discard_sequenced()
  end
end

--- Équivalent discardThenAdvance + advanceAfterDiscard, paceé sur le séquenceur :
-- saignements -> vérifs -> un ennemi à la fois (1s d'écart) -> décroissance -> tour suivant.
function Controller:advance_after_discard_sequenced()
  local self_ = self
  self_.seq:push(function()
    local before = self_:snapshot_units()
    Game.tick_bleed(self_.state)
    self_:react_to_diff(before)

    if Game.check_defeat(self_.state) then self_:enter_defeat_screen(); return end
    if Game.check_victory(self_.state) then self_:enter_draft_screen(); return end

    for _, e in ipairs(self_.state.enemies) do
      if e.hp > 0 and e.next_move then
        local enemy_ref = e
        self_.seq:push(function()
          if self_.state.over then return end
          self_:pulse(enemy_ref.id, "pulse-down")
          Sfx.play("enemy_telegraph")
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
      self_.state.turn = self_.state.turn + 1
      local turn_before = self_:snapshot_units()
      Game.start_turn(self_.state)
      -- skip_shield_sfx : la Défense de chaque héros retombe à 0 ici (reset de
      -- tour, pas un blocage de dégâts) -- sans cette garde, "shting" jouerait
      -- à chaque tour pour quiconque avait de la Défense restante.
      self_:react_to_diff(turn_before, { skip_shield_sfx = true })
      self_:consume_drawn_animation()
      -- Game.start_turn ne peut plus, à ce jour, infliger de dégâts (les
      -- Pouvoirs de Classe qui le faisaient ont été retirés) -- ce garde-fou
      -- reste par précaution si un futur pouvoir redonnait ce pouvoir à
      -- start_turn, plutôt que d'être supprimé puis oublié le jour venu.
      if self_.state.over then self_:enter_draft_screen() end
    end)
  end)
end

-- ---------- victoire / défaite / draft ----------

function Controller:enter_defeat_screen()
  self.screen = "defeat"
  self.seq:clear() -- inutile de finir de dérouler les ennemis restants une fois la défaite actée
  Sfx.play("defeat")
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
  local healed = hero.max_hp - hero.hp
  FeuDeCamp.heal_hero(hero)
  if healed > 0 then self:spawn_floater(hero.id, healed, "heal") end
  Sfx.play("heal")
  self:finish_feu_de_camp()
end

function Controller:choose_feu_de_camp_upgrade()
  if not feu_de_camp_choosable(self) then return end
  local fdc = self.feu_de_camp
  if not fdc.upgrade_targets then return end
  fdc.resolved = true
  FeuDeCamp.apply_upgrades(fdc.upgrade_targets)
  Sfx.play("upgrade")
  self:finish_feu_de_camp()
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

function Controller:finish_feu_de_camp()
  local self_ = self
  -- Même idiome que Controller:enter_draft_screen (fn vide + durée = "attends",
  -- PUIS l'étape suivante fait le travail) : Sequencer:push exécute run_fn
  -- immédiatement et attend `wait_after` avant l'étape SUIVANTE, jamais avant
  -- run_fn lui-même -- voir src/util/sequencer.lua.
  self.seq:push(function() end, FEU_DE_CAMP_RESOLVE_PAUSE)
  self.seq:push(function()
    self_.feu_de_camp = nil
    self_.screen = "playing"
    self_.state.over = false
    self_.card_anims = {}
    Game.start_next_combat(self_.state)
    self_:consume_drawn_animation()
    if self_.state.over then self_:enter_draft_screen() end
  end)
end

return Controller
