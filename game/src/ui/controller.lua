-- Colle la UI au moteur de règles pur (src/rules) et au séquenceur (src/util).
-- Tout ce qui est "attendre 1s entre deux ennemis", "montrer l'écran de draft",
-- "revenir au village après une défaite" vit ici — jamais dans src/rules.

local Game = require("src.rules.game")
local Combat = require("src.rules.combat")
local Draft = require("src.rules.draft")
local Sequencer = require("src.util.sequencer")

local Controller = {}
Controller.__index = Controller

local ANIM_PULSE = 0.38 -- s, calque sur les 380ms de pulseUp/pulseDown du prototype
local ANIM_SHAKE = 1.0  -- s, calque sur les 1000ms de shakeUnit
local HOVER_DELAY = 1.0 -- s, calque sur le délai d'infobulle du prototype
local ENEMY_STEP_WAIT = 1.0 -- s, calque sur le sleep(1000) entre chaque ennemi

function Controller.new()
  local self = setmetatable({}, Controller)
  self.state = Game.new_state()
  self.seq = Sequencer.new()
  self.screen = "playing" -- "playing" | "draft" | "defeat"
  self.draft_picks = nil
  self.draft_revealed = {}
  self.anim = {} -- [unit_id] = { kind = "pulse-up"|"pulse-down"|"shake", t = elapsed }
  self.hover = { target = nil, kind = nil, t = 0 } -- kind: "hero"|"enemy"|"card"
  self:reset_run()
  return self
end

function Controller:reset_run()
  self.screen = "playing"
  self.draft_picks = nil
  self.seq:clear()
  self.anim = {}
  Game.reset_run(self.state)
end

function Controller:restart_combat()
  self.screen = "playing"
  self.seq:clear()
  self.anim = {}
  Game.restore_combat_snapshot(self.state)
end

-- ---------- cosmétique ----------

function Controller:pulse(unit_id, kind)
  self.anim[unit_id] = { kind = kind, t = 0 }
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
  if self.hover.target then self.hover.t = self.hover.t + dt end
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
    Game.resolve_mage_keep(self.state, uid)
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

function Controller:assign_hero(hero_id)
  local pending = self.state.pending
  if not pending then return end
  self:pulse(hero_id, "pulse-up")
  local before = self:snapshot_hp()
  local resolved = Game.assign_hero(self.state, hero_id)
  self:shake_from_diff(before)
  if resolved then self:after_card_resolved() end
end

function Controller:resolve_target(kind, target_id)
  local pending = self.state.pending
  if not pending or not pending.hero_id then return end
  local before = self:snapshot_hp()
  Game.resolve_pending(self.state, kind, target_id)
  self:shake_from_diff(before)
  self:after_card_resolved()
end

function Controller:after_card_resolved()
  if self.state.over then self:enter_draft_screen() end
end

-- ---------- fin de tour ----------

function Controller:end_turn()
  local result = Game.end_turn_requested(self.state)
  if result == "discarded" then self:advance_after_discard_sequenced() end
  -- result == "mage-keep" : la UI affiche déjà le bandeau via state.mage_keep_pending.
end

function Controller:choose_mage_keep_none()
  Game.resolve_mage_keep_none(self.state)
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
  self.draft_revealed = {}
  local self_ = self
  for i = 1, #self.draft_picks do
    local idx = i
    self.seq:push(function() self_.draft_revealed[idx] = true end, 0.3)
  end
end

function Controller:choose_draft_card(index)
  if self.screen ~= "draft" or not self.draft_picks or not self.draft_revealed[index] then return end
  local def = self.draft_picks[index]
  self.state.deck[#self.state.deck + 1] = { uid = Game.next_uid(self.state), def = def }
  Combat.log(self.state, def.name .. " ajoutée au deck.", "sys")
  self.draft_picks = nil
  self.screen = "playing"
  self.state.over = false
  Game.start_next_combat(self.state)
end

return Controller
