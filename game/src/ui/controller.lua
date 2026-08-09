-- Colle la UI au moteur de règles pur (src/rules) et au séquenceur (src/util).
-- Tout ce qui est "attendre 1s entre deux ennemis", "montrer l'écran de draft",
-- "revenir au village après une défaite" vit ici — jamais dans src/rules.

local Game = require("src.rules.game")
local Combat = require("src.rules.combat")
local Draft = require("src.rules.draft")
local Sequencer = require("src.util.sequencer")
-- Dépendance à la UI (rects de layout, purs -- aucun appel love.graphics dedans)
-- nécessaire pour savoir D'OÙ une carte part visuellement quand elle est piochée
-- ou défaussée ; voir View.hand_rects_for/deck_pile_rect/discard_pile_rect.
local View = require("src.ui.view")

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

function Controller.new()
  local self = setmetatable({}, Controller)
  self.state = Game.new_state()
  self.seq = Sequencer.new()
  self.screen = "playing" -- "playing" | "draft" | "defeat"
  self.draft_picks = nil
  self.victory_anim = nil -- { t = elapsed } pendant le zoom+bump du titre "Victoire !"
  self.victory_title_duration = VICTORY_TITLE_DURATION -- lu par view.lua pour l'easing
  self.draft_cards_shown = false -- les 3 cartes (de dos) n'apparaissent qu'après le titre
  self.draft_flip = {} -- [index] = { t = elapsed } une fois le retournement démarré
  self.draft_flip_duration = DRAFT_FLIP_DURATION -- lu par view.lua pour l'easing
  self.anim = {} -- [unit_id] = { kind = "pulse-up"|"pulse-down"|"shake", t = elapsed }
  self.card_anims = {} -- liste de { from, to, elapsed, delay, duration, fade_in, name } -- voir View.draw
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
  self.victory_anim = nil
  self.draft_cards_shown = false
  self.draft_flip = {}
  self.seq:clear()
  self.anim = {}
  self.card_anims = {}
  Game.reset_run(self.state)
  self:consume_drawn_animation()
  -- Game.start_turn (appelé par reset_run) peut déclencher la victoire via le
  -- Pouvoir de Classe du Guerrier (coups gratuits) -- même garde qu'ailleurs.
  if self.state.over then self:enter_draft_screen() end
end

function Controller:restart_combat()
  self.screen = "playing"
  self.seq:clear()
  self.anim = {}
  self.card_anims = {}
  Game.restore_combat_snapshot(self.state)
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
      local name
      for _, c in ipairs(self.state.hand) do if c.uid == uid then name = c.def.name break end end
      self.card_anims[#self.card_anims + 1] = {
        from = origin, to = dest, elapsed = 0, delay = (i - 1) * DRAW_STAGGER,
        duration = FLIGHT_DURATION, fade_in = true, name = name, uid = uid,
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
  if drawn then self:animate_draw(drawn) end
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
          duration = FLIGHT_DURATION, fade_in = false, name = c.def.name,
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
    duration = FLIGHT_DURATION, fade_in = false, name = last.def.name,
  }
end

function Controller:snapshot_hp()
  local hp = {}
  for _, h in ipairs(self.state.heroes) do hp[h.id] = h.hp end
  for _, e in ipairs(self.state.enemies) do hp[e.id] = e.hp end
  return hp
end

--- Compare les PV avant/après un appel de règles et déclenche une secousse sur
-- toute unité qui en a perdu — substitut simple au triggerShake() du
-- prototype (branché directement dans dealDamage côté JS ; ici on le déduit
-- après coup pour ne pas faire dépendre src/rules de la UI).
function Controller:shake_from_diff(before)
  for _, h in ipairs(self.state.heroes) do
    if before[h.id] and h.hp < before[h.id] then self:pulse(h.id, "shake") end
  end
  for _, e in ipairs(self.state.enemies) do
    if before[e.id] and e.hp < before[e.id] then self:pulse(e.id, "shake") end
  end
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
  if self.state.mage_keep_pending then
    local hand_before = Game.shallow_copy(self.state.hand)
    Game.resolve_mage_keep(self.state, uid)
    self:animate_discard_snapshot(hand_before, uid)
    self:advance_after_discard_sequenced()
    return
  end
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
  local before = self:snapshot_hp()
  local resolved = Game.assign_hero(self.state, hero_id)
  if resolved then self:pulse(hero_id, "pulse-up") end
  self:shake_from_diff(before)
  self:maybe_animate_played_discard(played_uid, hand_before)
  self:consume_drawn_animation() -- Clairvoyance : le mode "concentrate" ne pioche jamais, mais "play" le peut
  if resolved then self:after_card_resolved() end
end

function Controller:resolve_target(kind, target_id)
  local pending = self.state.pending
  if not pending or not pending.hero_id then return end
  local played_uid, hand_before = pending.uid, Game.shallow_copy(self.state.hand)
  self:pulse(pending.hero_id, "pulse-up")
  local before = self:snapshot_hp()
  Game.resolve_pending(self.state, kind, target_id)
  self:shake_from_diff(before)
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
  local result = Game.end_turn_requested(self.state)
  if result == "discarded" then
    self:animate_discard_snapshot(hand_before)
    self:advance_after_discard_sequenced()
  end
  -- result == "mage-keep" : la UI affiche déjà le bandeau via state.mage_keep_pending.
end

function Controller:choose_mage_keep_none()
  local hand_before = Game.shallow_copy(self.state.hand)
  Game.resolve_mage_keep_none(self.state)
  self:animate_discard_snapshot(hand_before)
  self:advance_after_discard_sequenced()
end

--- Équivalent discardThenAdvance + advanceAfterDiscard, paceé sur le séquenceur :
-- saignements -> vérifs -> un ennemi à la fois (1s d'écart) -> décroissance -> tour suivant.
function Controller:advance_after_discard_sequenced()
  local self_ = self
  self_.seq:push(function()
    local before = self_:snapshot_hp()
    Game.tick_bleed(self_.state)
    self_:shake_from_diff(before)

    if Game.check_defeat(self_.state) then self_:enter_defeat_screen(); return end
    if Game.check_victory(self_.state) then self_:enter_draft_screen(); return end

    for _, e in ipairs(self_.state.enemies) do
      if e.hp > 0 and e.next_move then
        local enemy_ref = e
        self_.seq:push(function()
          if self_.state.over then return end
          self_:pulse(enemy_ref.id, "pulse-down")
          local hp_before = self_:snapshot_hp()
          Game.resolve_enemy_action(self_.state, enemy_ref)
          self_:shake_from_diff(hp_before)
          if Game.check_defeat(self_.state) then self_:enter_defeat_screen() end
        end, ENEMY_STEP_WAIT)
      end
    end

    self_.seq:push(function()
      if self_.state.over then return end
      Game.decay_end_of_turn_statuses(self_.state)
      if Game.check_defeat(self_.state) then self_:enter_defeat_screen(); return end
      self_.state.turn = self_.state.turn + 1
      Game.start_turn(self_.state)
      self_:consume_drawn_animation()
      -- Le Pouvoir de Classe du Guerrier (coups gratuits) peut achever le
      -- dernier ennemi dès Game.start_turn, avant même qu'une carte ne soit
      -- jouée -- rien d'autre dans cette séquence ne vérifierait la victoire.
      if self_.state.over then self_:enter_draft_screen() end
    end)
  end)
end

-- ---------- victoire / défaite / draft ----------

function Controller:enter_defeat_screen()
  self.screen = "defeat"
  self.seq:clear() -- inutile de finir de dérouler les ennemis restants une fois la défaite actée
end

function Controller:enter_draft_screen()
  self.screen = "draft"
  self.draft_picks = Draft.pick_cards(self.state)
  self.draft_cards_shown = false
  self.draft_flip = {}
  self.victory_anim = { t = 0 }
  local self_ = self
  self.seq:push(function() end, VICTORY_TITLE_DURATION)
  self.seq:push(function() self_.draft_cards_shown = true end, DRAFT_FACEDOWN_PAUSE)
  for i = 1, #self.draft_picks do
    local idx = i
    self.seq:push(function() self_.draft_flip[idx] = { t = 0 } end, DRAFT_FLIP_DURATION + DRAFT_FLIP_GAP)
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
  self.screen = "playing"
  self.state.over = false
  self.card_anims = {}
  Game.start_next_combat(self.state)
  self:consume_drawn_animation()
  if self.state.over then self:enter_draft_screen() end
end

return Controller
