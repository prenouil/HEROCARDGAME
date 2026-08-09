-- Traduit les clics/survol souris en appels au Controller. Toute la logique de
-- "qui est cliquable maintenant" est dérivée de state.pending, jamais dupliquée :
-- on relit les mêmes conditions que la séquence à 3 temps du prototype
-- (carte -> héros -> cible).

local View = require("src.ui.view")
local Combat = require("src.rules.combat")

local Input = {}

local function find_rect(rects_by_id, x, y)
  for id, r in pairs(rects_by_id) do
    if View.point_in(r, x, y) then return id end
  end
  return nil
end

local function mousepressed_tap(controller, x, y, button)
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

-- Mode "flèche" (2026-08-09, spike de ciblage dynamique demandé par le porteur
-- de projet, inspiré de Slay the Spire) : réutilise EXACTEMENT le même moteur
-- de règles/pending que le mode à 3 clics (Game.select_card, choose_mode_and_assign,
-- resolve_target, cancel_pending) -- seule la façon de déclencher ces appels
-- change. Différence actée avec le porteur de projet : un clic sur une cible
-- invalide (héros/zone/cible finale) annule TOUT, retour à la main -- jamais
-- de retour en arrière d'un cran.
local function mousepressed_arrow(controller, x, y, button)
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
  if View.point_in(View.end_turn_button, x, y) then controller:end_turn(); return end
  if View.point_in(View.restart_button, x, y) then controller:restart_combat(); return end
  if View.point_in(View.instant_victory_button, x, y) then controller:trigger_instant_victory(); return end

  local pending = state.pending

  -- Étape 1 : carte sélectionnée, en attente du choix de l'aventurier. Un
  -- clic sur une autre carte de la main change la sélection (comme en mode
  -- tap) ; un clic sur une zone valide assigne héros+mode ; tout le reste
  -- (zone invalide comprise) annule la sélection en cours.
  if pending and not pending.mode then
    local hand_id = find_rect(View.hand_rects(state), x, y)
    if hand_id then controller:select_card(hand_id); return end

    local zones = View.hero_zone_rects(state)
    for _, h in ipairs(state.heroes) do
      local z = zones[h.id]
      if z and View.point_in(z.play, x, y) then
        if Combat.can_play(h, pending) then controller:choose_mode_and_assign(h.id, "play") else controller:cancel_pending() end
        return
      end
      if z and View.point_in(z.concentrate, x, y) then
        if Combat.can_concentrate(h) then controller:choose_mode_and_assign(h.id, "concentrate") else controller:cancel_pending() end
        return
      end
    end
    controller:cancel_pending()
    return
  end

  -- Étape 2 : aventurier choisi, en attente de la cible finale (ennemi/allié).
  -- Un clic hors cible valide annule tout (décision explicite du porteur de
  -- projet -- pas de retour en arrière d'un cran).
  if pending and pending.hero_id then
    if pending.def.target == "enemy" or pending.def.target == "conditional" then
      local enemy_id = find_rect(View.enemy_rects(state), x, y)
      if enemy_id then controller:resolve_target("enemy", enemy_id); return end
    end
    if pending.def.target == "ally" then
      local hero_id = find_rect(View.hero_rects(state), x, y)
      if hero_id then controller:resolve_target("ally", hero_id); return end
    end
    controller:cancel_pending()
    return
  end

  -- Pas de carte en attente : un clic sur la main la sélectionne.
  local hand_id = find_rect(View.hand_rects(state), x, y)
  if hand_id then controller:select_card(hand_id) end
end

function Input.mousepressed(controller, x, y, button)
  if button ~= 1 then return end
  if controller.screen == "playing" and View.point_in(View.mode_toggle_button, x, y) then
    controller:toggle_input_mode()
    return
  end
  if controller.input_mode == "arrow" then mousepressed_arrow(controller, x, y, button)
  else mousepressed_tap(controller, x, y, button) end
end

-- Curseur main au survol : relit les mêmes conditions que mousepressed (sans
-- déclencher d'action), pour que "cliquable visuellement" == "cliquable pour
-- de vrai" -- appelé chaque frame depuis love.update (main.lua).
local function is_hovering_clickable_tap(controller, x, y)
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

-- Contrairement au mode tap, une zone/cible invalide ANNULE au clic (voir
-- mousepressed_arrow) -- mais on ne l'annonce pas comme "cliquable" au survol
-- (curseur main), le curseur ne réagit qu'aux vraies opportunités d'action.
local function is_hovering_clickable_arrow(controller, x, y)
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

  if View.point_in(View.end_turn_button, x, y) then return true end
  if View.point_in(View.restart_button, x, y) then return true end
  if View.point_in(View.instant_victory_button, x, y) then return true end

  local pending = state.pending
  if pending and not pending.mode then
    if find_rect(View.hand_rects(state), x, y) then return true end
    local zones = View.hero_zone_rects(state)
    for _, h in ipairs(state.heroes) do
      local z = zones[h.id]
      if z then
        if View.point_in(z.play, x, y) and Combat.can_play(h, pending) then return true end
        if View.point_in(z.concentrate, x, y) and Combat.can_concentrate(h) then return true end
      end
    end
    return false
  end

  if pending and pending.hero_id then
    if pending.def.target == "enemy" or pending.def.target == "conditional" then
      if find_rect(View.enemy_rects(state), x, y) then return true end
    end
    if pending.def.target == "ally" then
      if find_rect(View.hero_rects(state), x, y) then return true end
    end
    return false
  end

  return find_rect(View.hand_rects(state), x, y) ~= nil
end

function Input.is_hovering_clickable(controller, x, y)
  if controller.screen == "playing" and View.point_in(View.mode_toggle_button, x, y) then return true end
  if controller.input_mode == "arrow" then return is_hovering_clickable_arrow(controller, x, y) end
  return is_hovering_clickable_tap(controller, x, y)
end

function Input.mousemoved(controller, x, y)
  -- Écran de draft (2026-08-09, bug signalé) : aucune infobulle mot-clé sur les
  -- 3 cartes de loot, parce que cette fonction s'arrêtait net hors "playing".
  -- Gardé par draft_card_ready comme le clic -- pas de survol tant que la carte
  -- est encore de dos.
  if controller.screen == "draft" then
    local rects = View.draft_rects(controller)
    for i, r in ipairs(rects) do
      if View.point_in(r, x, y) and controller:draft_card_ready(i) then
        controller:set_hover("card", controller.draft_picks[i])
        return
      end
    end
    controller:set_hover(nil, nil)
    return
  end

  if controller.screen ~= "playing" then controller:set_hover(nil, nil); return end
  local state = controller.state

  if controller.input_mode == "arrow" then
    local hovered_uid = find_rect(View.hand_rects(state), x, y)
    controller:set_arrow_hand_hover(hovered_uid)
  end

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
