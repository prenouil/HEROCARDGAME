-- Traduit les clics/survol souris en appels au Controller. Toute la logique de
-- "qui est cliquable maintenant" est dérivée de state.pending / state.mage_keep_pending,
-- jamais dupliquée : on relit les mêmes conditions que la séquence à 3 temps du
-- prototype (carte -> héros -> cible).

local View = require("src.ui.view")
local Combat = require("src.rules.combat")

local Input = {}

local function find_rect(rects_by_id, x, y)
  for id, r in pairs(rects_by_id) do
    if View.point_in(r, x, y) then return id end
  end
  return nil
end

function Input.mousepressed(controller, x, y, button)
  if button ~= 1 then return end
  local state = controller.state

  if controller.screen == "defeat" then
    if View.point_in(View.overlay_restart_button, x, y) then controller:reset_run() end
    return
  end

  if controller.screen == "draft" then
    local rects = View.draft_rects(controller)
    for i, r in ipairs(rects) do
      if View.point_in(r, x, y) and controller:draft_card_ready(i) then controller:choose_draft_card(i); return end
    end
    return
  end

  -- screen == "playing"
  if state.mage_keep_pending then
    if View.point_in(View.mage_discard_all_button, x, y) then
      controller:choose_mage_keep_none()
      return
    end
    local hand_id = find_rect(View.hand_rects(state), x, y)
    if hand_id then controller:select_card(hand_id) end
    return
  end

  if View.point_in(View.end_turn_button, x, y) then controller:end_turn(); return end
  if View.point_in(View.restart_button, x, y) then controller:restart_combat(); return end
  if View.point_in(View.instant_victory_button, x, y) then controller:trigger_instant_victory(); return end

  local pending = state.pending
  -- Boutons "Jouer"/"Se concentrer" par héros (2026-08-08) : un clic choisit
  -- le mode ET le héros en un seul geste -- remplace l'ancienne rangée
  -- globale + le clic-héros séparé qui suivait.
  if pending and not pending.mode then
    if View.point_in(View.cancel_button, x, y) then controller:cancel_pending(); return end
    local buttons = View.hero_action_rects(state)
    for _, h in ipairs(state.heroes) do
      local btns = buttons[h.id]
      if btns then
        if View.point_in(btns.play, x, y) then
          if Combat.can_play(h, pending) then controller:choose_mode_and_assign(h.id, "play") end
          return
        end
        if View.point_in(btns.concentrate, x, y) then
          if Combat.can_concentrate(h) then controller:choose_mode_and_assign(h.id, "concentrate") end
          return
        end
      end
    end
  end

  if pending and pending.hero_id then
    if pending.def.target == "enemy" or pending.def.target == "conditional" then
      local enemy_id = find_rect(View.enemy_rects(state), x, y)
      if enemy_id then controller:resolve_target("enemy", enemy_id); return end
    end
    if pending.def.target == "ally" then
      local hero_id = find_rect(View.hero_rects(state), x, y)
      if hero_id then controller:resolve_target("ally", hero_id); return end
    end
  end

  -- Sélection/désélection d'une carte de la main (toujours possible tant
  -- qu'aucune cible n'est en cours de résolution).
  local hand_id = find_rect(View.hand_rects(state), x, y)
  if hand_id then controller:select_card(hand_id) end
end

-- Curseur main au survol : relit les mêmes conditions que mousepressed (sans
-- déclencher d'action), pour que "cliquable visuellement" == "cliquable pour
-- de vrai" -- appelé chaque frame depuis love.update (main.lua).
function Input.is_hovering_clickable(controller, x, y)
  local state = controller.state

  if controller.screen == "defeat" then
    return View.point_in(View.overlay_restart_button, x, y)
  end

  if controller.screen == "draft" then
    local rects = View.draft_rects(controller)
    for i, r in ipairs(rects) do
      if View.point_in(r, x, y) and controller:draft_card_ready(i) then return true end
    end
    return false
  end

  if state.mage_keep_pending then
    if View.point_in(View.mage_discard_all_button, x, y) then return true end
    return find_rect(View.hand_rects(state), x, y) ~= nil
  end

  if View.point_in(View.end_turn_button, x, y) then return true end
  if View.point_in(View.restart_button, x, y) then return true end
  if View.point_in(View.instant_victory_button, x, y) then return true end

  local pending = state.pending
  if pending and not pending.mode then
    if View.point_in(View.cancel_button, x, y) then return true end
    local buttons = View.hero_action_rects(state)
    for _, h in ipairs(state.heroes) do
      local btns = buttons[h.id]
      if btns then
        if View.point_in(btns.play, x, y) and Combat.can_play(h, pending) then return true end
        if View.point_in(btns.concentrate, x, y) and Combat.can_concentrate(h) then return true end
      end
    end
  end

  if pending and pending.hero_id then
    if pending.def.target == "enemy" or pending.def.target == "conditional" then
      if find_rect(View.enemy_rects(state), x, y) then return true end
    end
    if pending.def.target == "ally" then
      if find_rect(View.hero_rects(state), x, y) then return true end
    end
  end

  return find_rect(View.hand_rects(state), x, y) ~= nil
end

function Input.mousemoved(controller, x, y)
  if controller.screen ~= "playing" then controller:set_hover(nil, nil); return end
  local state = controller.state

  local hero_id = find_rect(View.hero_rects(state), x, y)
  if hero_id then controller:set_hover("hero", hero_id); return end

  local enemy_id = find_rect(View.enemy_rects(state), x, y)
  if enemy_id then controller:set_hover("enemy", enemy_id); return end

  local hand_rects = View.hand_rects(state)
  for _, c in ipairs(state.hand) do
    local r = hand_rects[c.uid]
    if View.point_in(r, x, y) then controller:set_hover("card", c.def); return end
  end

  controller:set_hover(nil, nil)
end

return Input
