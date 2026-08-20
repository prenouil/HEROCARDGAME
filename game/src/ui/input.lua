-- Traduit les clics/survol souris en appels au Controller. Toute la logique de
-- "qui est cliquable maintenant" est dérivée de state.pending, jamais dupliquée.
-- Sélectionner une carte assigne directement son propriétaire (2026-08-20,
-- voir Game.select_card) : il ne reste que 2 temps, carte -> cible.

local View = require("src.ui.view")

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

  if controller.screen == "feuDeCamp" then
    if View.point_in(View.feu_de_camp_heal_rect, x, y) then controller:choose_feu_de_camp_heal()
    elseif View.point_in(View.feu_de_camp_upgrade_rect, x, y) then controller:choose_feu_de_camp_upgrade()
    elseif View.point_in(View.feu_de_camp_skip_button, x, y) then controller:choose_feu_de_camp_skip()
    end
    return
  end

  -- screen == "playing"
  if View.point_in(View.end_turn_button, x, y) then controller:end_turn(); return end
  if View.point_in(View.restart_button, x, y) then controller:restart_combat(); return end
  if View.point_in(View.restart_turn_button, x, y) then controller:restart_turn(); return end
  if View.point_in(View.instant_victory_button, x, y) then controller:trigger_instant_victory(); return end

  local pending = state.pending
  -- Sélectionner une carte l'assigne directement à son propriétaire
  -- (2026-08-20, voir Game.select_card) : plus de bouton "Jouer" à choisir,
  -- `pending` n'existe donc jamais sans `pending.hero_id` déjà fixé.
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
-- de règles/pending que le mode tap (Game.select_card, resolve_target,
-- cancel_pending) -- seule la façon de déclencher ces appels change.
-- Différence actée avec le porteur de projet : un clic sur une cible invalide
-- (ennemi/allié) annule TOUT, retour à la main -- jamais de retour en arrière
-- d'un cran.
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

  if controller.screen == "feuDeCamp" then
    if View.point_in(View.feu_de_camp_heal_rect, x, y) then controller:choose_feu_de_camp_heal()
    elseif View.point_in(View.feu_de_camp_upgrade_rect, x, y) then controller:choose_feu_de_camp_upgrade()
    elseif View.point_in(View.feu_de_camp_skip_button, x, y) then controller:choose_feu_de_camp_skip()
    end
    return
  end

  -- screen == "playing"
  if View.point_in(View.end_turn_button, x, y) then controller:end_turn(); return end
  if View.point_in(View.restart_button, x, y) then controller:restart_combat(); return end
  if View.point_in(View.restart_turn_button, x, y) then controller:restart_turn(); return end
  if View.point_in(View.instant_victory_button, x, y) then controller:trigger_instant_victory(); return end

  local pending = state.pending

  -- Sélectionner une carte l'assigne directement à son propriétaire
  -- (2026-08-20, voir Game.select_card) : `pending` n'existe donc jamais sans
  -- `pending.hero_id` déjà fixé, il ne reste que l'attente de la cible finale
  -- (ennemi/allié). Un clic hors cible valide annule tout (décision explicite
  -- du porteur de projet -- pas de retour en arrière d'un cran).
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
  if controller.input_mode == "arrow" then mousepressed_arrow(controller, x, y, button)
  else mousepressed_tap(controller, x, y, button) end
end

-- Curseur main au survol : relit les mêmes conditions que mousepressed (sans
-- déclencher d'action), pour que "cliquable visuellement" == "cliquable pour
-- de vrai" -- appelé chaque frame depuis love.update (main.lua).

--- Partagée entre les deux modes (tap/flèche, le clic sur cet écran ne dépend
-- pas du mode d'entrée -- voir les deux blocs "feuDeCamp" identiques dans
-- mousepressed_tap/mousepressed_arrow ci-dessus).
local function feu_de_camp_hovering(controller, x, y)
  local fdc = controller.feu_de_camp
  if not fdc then return false end
  if fdc.heal_target and View.point_in(View.feu_de_camp_heal_rect, x, y) then return true end
  if fdc.upgrade_targets and View.point_in(View.feu_de_camp_upgrade_rect, x, y) then return true end
  if not fdc.heal_target and not fdc.upgrade_targets and View.point_in(View.feu_de_camp_skip_button, x, y) then return true end
  return false
end

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

  if controller.screen == "feuDeCamp" then return feu_de_camp_hovering(controller, x, y) end

  if View.point_in(View.end_turn_button, x, y) then return true end
  if View.point_in(View.restart_button, x, y) then return true end
  if View.point_in(View.restart_turn_button, x, y) then return true end
  if View.point_in(View.instant_victory_button, x, y) then return true end

  local pending = state.pending
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

  if controller.screen == "feuDeCamp" then return feu_de_camp_hovering(controller, x, y) end

  if View.point_in(View.end_turn_button, x, y) then return true end
  if View.point_in(View.restart_button, x, y) then return true end
  if View.point_in(View.restart_turn_button, x, y) then return true end
  if View.point_in(View.instant_victory_button, x, y) then return true end

  local pending = state.pending
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

  -- Écran "feuDeCamp" (2026-08-10) : infobulle mot-clé sur les 2 cartes
  -- proposées à l'amélioration -- même souci de cohérence que le bug draft
  -- ci-dessus (jamais un écran de cartes sans infobulle).
  if controller.screen == "feuDeCamp" then
    local fdc = controller.feu_de_camp
    if fdc and fdc.upgrade_targets then
      local rows = View.feu_de_camp_upgrade_card_rects()
      for i, r in ipairs(rows) do
        if View.point_in(r, x, y) then
          controller:set_hover("card", fdc.upgrade_targets[i].def)
          return
        end
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
