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

-- Écrans "menu"/"options" (2026-08-21, demande explicite) : mêmes boutons
-- quel que soit le mode d'entrée (tap/flèche), jamais de ciblage de carte en
-- jeu -- factorisé une seule fois, comme feu_de_camp_hovering plus bas,
-- réutilisé par mousepressed_tap/arrow ET is_hovering_clickable_tap/arrow.
-- Renvoie true si le clic a été traité par un de ces 2 écrans (pour que
-- l'appelant sache s'arrêter là, jamais retomber sur la logique "playing").
local function menu_click(controller, x, y)
  if controller.screen == "menu" then
    for _, b in ipairs(View.menu_buttons) do
      if View.point_in(b, x, y) then
        if b.id == "boss" then controller:start_boss_test()
        elseif b.id == "run" then controller:enter_team_select("bounded")
        elseif b.id == "infini" then controller:enter_team_select("infini")
        elseif b.id == "options" then controller:enter_options()
        elseif b.id == "quit" then love.event.quit()
        end
        return true
      end
    end
    return true
  end
  if controller.screen == "options" then
    if View.point_in(View.back_button, x, y) then controller:back_to_menu() end
    return true
  end
  return false
end

local function menu_hovering(controller, x, y)
  if controller.screen == "menu" then
    for _, b in ipairs(View.menu_buttons) do
      if View.point_in(b, x, y) then return true end
    end
    return false
  end
  if controller.screen == "options" then
    return View.point_in(View.back_button, x, y)
  end
  return false
end

--- Écrans "forge"/"temple" (2026-08-28, demande explicite) : même geste quel
-- que soit le mode d'entrée (tap/flèche) -- factorisé une seule fois, comme
-- menu_click, réutilisé par mousepressed_tap/arrow ET
-- is_hovering_clickable_tap/arrow (voir post_combat_hovering plus bas).
-- `t.eligible`/`f.choices` : seules les cibles RÉELLEMENT valides sont
-- testées (aventurier mort/déjà béni, ou 0 carte proposée) -- un clic hors de
-- ces zones ne fait rien de plus que "return true" (l'écran a bien traité le
-- clic, même si aucune action n'en résulte), jamais retomber sur la logique
-- "playing" en dessous.
local function post_combat_click(controller, x, y)
  if controller.screen == "forge" then
    local f = controller.forge
    if f and #f.choices > 0 then
      -- Les 2 cartes de la colonne (base ET améliorée, 2026-08-30, voir
      -- View.forge_upgraded_card_rects) sélectionnent le même choix --
      -- cliquer l'une ou l'autre revient au même, jamais seulement la base.
      local rects = View.forge_card_rects(controller)
      for i, r in ipairs(rects) do
        if View.point_in(r, x, y) then controller:choose_forge_card(i); return true end
      end
      local up_rects = View.forge_upgraded_card_rects(controller)
      for i, r in ipairs(up_rects) do
        if View.point_in(r, x, y) then controller:choose_forge_card(i); return true end
      end
    elseif f and View.point_in(View.forge_skip_button, x, y) then
      controller:choose_forge_skip()
    end
    return true
  end
  if controller.screen == "temple" then
    local t = controller.temple
    if t and not t.resolved then
      local effect_rects = View.temple_effect_rects(controller)
      for i, r in ipairs(effect_rects) do
        if View.point_in(r, x, y) then controller:choose_temple_effect(i); return true end
      end
      local hero_rects = View.temple_hero_rects(controller)
      for _, h in ipairs(t.eligible) do
        local r = hero_rects[h.id]
        if r and View.point_in(r, x, y) then controller:choose_temple_hero(h.id); return true end
      end
      if View.point_in(View.temple_confirm_button, x, y) then controller:confirm_temple_choice() end
    end
    return true
  end
  return false
end

--- Écran "Choisis ton équipe" (2026-08-29, demande explicite -- avant chaque
-- run) : même geste quel que soit le mode d'entrée (tap/flèche), comme
-- menu_click/post_combat_click ci-dessus. Cliquer un aventurier (disponible
-- OU déjà dans l'équipe) le met en avant ("resélectionné normalement" pour
-- en sortir un déjà confirmé, voir Controller:team_select_focus) ; "Annuler"/
-- "Valider" ne sont testés que quand un focus est actif ; "Partir à
-- l'aventure" seulement à 4 aventuriers confirmés. Un clic hors de toute
-- zone active ne fait rien de plus que "return true" (l'écran a bien traité
-- le clic), jamais retomber sur la logique "playing" en dessous.
local function team_select_click(controller, x, y)
  if controller.screen ~= "team_select" then return false end
  local ts = controller.team_select
  if not ts then return true end

  if ts.focused_id then
    if View.point_in(View.team_select_cancel_button, x, y) then controller:team_select_cancel(); return true end
    if View.point_in(View.team_select_confirm_button, x, y) then controller:team_select_confirm(); return true end
  end

  local available_id = find_rect(View.team_select_available_rects(controller), x, y)
  if available_id then controller:team_select_focus(available_id); return true end
  local party_id = find_rect(View.team_select_party_rects(controller), x, y)
  if party_id then controller:team_select_focus(party_id); return true end

  if #ts.selected_ids == 4 and View.point_in(View.team_select_launch_button, x, y) then
    controller:team_select_launch()
    return true
  end

  return true
end

--- "Rejouer" sur l'écran de défaite (2026-08-21, demande explicite) : relance
-- le même mode qu'à la mort -- `run_mode == "boss_test"` relance le test du
-- boss (Game.start_boss_test, jamais Game.reset_run, qui tirerait une
-- rencontre normale par le budget), tout le reste (nil/infini/bounded) passe
-- par reset_run(), qui reconduit déjà self.run_mode tout seul.
local function restart_after_defeat(controller)
  if controller.run_mode == "boss_test" then controller:start_boss_test()
  else controller:reset_run()
  end
end

local function mousepressed_tap(controller, x, y, button)
  if button ~= 1 then return end
  if menu_click(controller, x, y) then return end
  if team_select_click(controller, x, y) then return end
  if controller.screen == "bossVictory" then return end
  local state = controller.state

  if controller.screen == "defeat" then
    if View.point_in(View.overlay_restart_button, x, y) then restart_after_defeat(controller) end
    return
  end

  if controller.screen == "draft" then
    local rects = View.draft_rects(controller)
    for i, r in ipairs(rects) do
      if View.point_in(r, x, y) and controller:draft_card_ready(i) then controller:choose_draft_card(i); return end
    end
    return
  end

  if post_combat_click(controller, x, y) then return end

  -- screen == "playing"

  -- Carte "sans cible" en attente de confirmation (2026-08-27, voir
  -- Game.assign_hero/Controller:confirm_pending) : AVANT même les boutons
  -- (Fin de tour compris) -- tout clic "consomme" d'abord cette confirmation
  -- plutôt que de laisser `pending` bloqué non résolu si le joueur clique
  -- ailleurs que sur la main. Reclique la même carte -> désélection (déjà géré
  -- par Game.select_card) ; une autre carte -> échange la sélection ; tout le
  -- reste -> valide la carte en attente.
  if state.pending and state.pending.awaiting_confirm_kind then
    local hand_id = View.hand_hit(state, x, y)
    if hand_id then controller:select_card(hand_id)
    else controller:confirm_pending() end
    return
  end

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
  local hand_id = View.hand_hit(state, x, y)
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
  if menu_click(controller, x, y) then return end
  if team_select_click(controller, x, y) then return end
  if controller.screen == "bossVictory" then return end
  local state = controller.state

  if controller.screen == "defeat" then
    if View.point_in(View.overlay_restart_button, x, y) then restart_after_defeat(controller) end
    return
  end

  if controller.screen == "draft" then
    local rects = View.draft_rects(controller)
    for i, r in ipairs(rects) do
      if View.point_in(r, x, y) and controller:draft_card_ready(i) then controller:choose_draft_card(i); return end
    end
    return
  end

  if post_combat_click(controller, x, y) then return end

  -- screen == "playing"

  -- Carte "sans cible" en attente de confirmation (2026-08-27) : même garde
  -- qu'en mode tap ci-dessus (voir le commentaire détaillé dans
  -- mousepressed_tap) -- délibérément AVANT la règle "clic hors cible valide
  -- annule tout" du mode flèche (juste en dessous) : ici, un clic hors main
  -- CONFIRME, il n'annule jamais.
  if state.pending and state.pending.awaiting_confirm_kind then
    local hand_id = View.hand_hit(state, x, y)
    if hand_id then controller:select_card(hand_id)
    else controller:confirm_pending() end
    return
  end

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
  local hand_id = View.hand_hit(state, x, y)
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

--- Partagée entre les deux modes (tap/flèche, le clic sur ces écrans ne
-- dépend pas du mode d'entrée -- voir post_combat_click ci-dessus). Ne
-- déclare cliquable QUE ce qui produirait une vraie action (cartes réellement
-- proposées, aventurier réellement éligible) -- jamais un portrait
-- mort/déjà béni ou une carte inexistante, même si post_combat_click les
-- laisserait passer sans erreur (silencieusement no-op).
local function post_combat_hovering(controller, x, y)
  if controller.screen == "forge" then
    local f = controller.forge
    if not f then return false end
    if #f.choices == 0 then return View.point_in(View.forge_skip_button, x, y) end
    local rects = View.forge_card_rects(controller)
    for _, r in ipairs(rects) do if View.point_in(r, x, y) then return true end end
    local up_rects = View.forge_upgraded_card_rects(controller)
    for _, r in ipairs(up_rects) do if View.point_in(r, x, y) then return true end end
    return false
  end
  if controller.screen == "temple" then
    local t = controller.temple
    if not t or t.resolved then return false end
    local effect_rects = View.temple_effect_rects(controller)
    for _, r in ipairs(effect_rects) do if View.point_in(r, x, y) then return true end end
    local hero_rects = View.temple_hero_rects(controller)
    for _, h in ipairs(t.eligible) do
      local r = hero_rects[h.id]
      if r and View.point_in(r, x, y) then return true end
    end
    if t.chosen_effect_index and t.chosen_hero_id and View.point_in(View.temple_confirm_button, x, y) then
      return true
    end
    return false
  end
  return false
end

--- Curseur main sur l'écran "Choisis ton équipe" (2026-08-29) : partagée
-- entre les 2 modes, même geste que team_select_click ci-dessus -- vraie
-- opportunité d'action seulement (un aventurier, Annuler/Valider si un focus
-- est actif, "Partir à l'aventure" seulement à 4 confirmés).
local function team_select_hovering(controller, x, y)
  local ts = controller.team_select
  if not ts then return false end
  if ts.focused_id then
    if View.point_in(View.team_select_cancel_button, x, y) then return true end
    if View.point_in(View.team_select_confirm_button, x, y) then return true end
  end
  if find_rect(View.team_select_available_rects(controller), x, y) then return true end
  if find_rect(View.team_select_party_rects(controller), x, y) then return true end
  if #ts.selected_ids == 4 and View.point_in(View.team_select_launch_button, x, y) then return true end
  return false
end

local function is_hovering_clickable_tap(controller, x, y)
  if controller.screen == "menu" or controller.screen == "options" then
    return menu_hovering(controller, x, y)
  end
  if controller.screen == "team_select" then return team_select_hovering(controller, x, y) end
  if controller.screen == "bossVictory" then return false end
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

  if controller.screen == "forge" or controller.screen == "temple" then return post_combat_hovering(controller, x, y) end

  -- Carte "sans cible" en attente de confirmation (2026-08-27) : n'importe où
  -- est cliquable (soit ça valide, soit ça échange/désélectionne, voir
  -- mousepressed_tap) -- jamais un clic ignoré dans cet état.
  if state.pending and state.pending.awaiting_confirm_kind then return true end

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

  return View.hand_hit(state, x, y) ~= nil
end

-- Contrairement au mode tap, une zone/cible invalide ANNULE au clic (voir
-- mousepressed_arrow) -- mais on ne l'annonce pas comme "cliquable" au survol
-- (curseur main), le curseur ne réagit qu'aux vraies opportunités d'action.
local function is_hovering_clickable_arrow(controller, x, y)
  if controller.screen == "menu" or controller.screen == "options" then
    return menu_hovering(controller, x, y)
  end
  if controller.screen == "team_select" then return team_select_hovering(controller, x, y) end
  if controller.screen == "bossVictory" then return false end
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

  if controller.screen == "forge" or controller.screen == "temple" then return post_combat_hovering(controller, x, y) end

  -- Carte "sans cible" en attente de confirmation (2026-08-27) : même garde
  -- qu'en mode tap ci-dessus -- n'importe où est cliquable.
  if state.pending and state.pending.awaiting_confirm_kind then return true end

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

  return View.hand_hit(state, x, y) ~= nil
end

function Input.is_hovering_clickable(controller, x, y)
  if controller.input_mode == "arrow" then return is_hovering_clickable_arrow(controller, x, y) end
  return is_hovering_clickable_tap(controller, x, y)
end

function Input.mousemoved(controller, x, y)
  if controller.screen == "menu" or controller.screen == "options" or controller.screen == "bossVictory" then
    controller:set_hover(nil, nil)
    return
  end

  -- Écran "Choisis ton équipe" (2026-08-29) : "quand je les survole, ils
  -- réagissent" -- survole aussi bien la rangée du haut (disponibles) que
  -- celle du bas (équipe confirmée), même kind "team_hero" pour les 2 (voir
  -- tooltip_lines/h.kind == "team_hero" dans view.lua -- aucun héros réel
  -- n'existe encore dans controller.state à ce stade, h.target porte l'ID du
  -- def directement, pas un héros de state.heroes).
  if controller.screen == "team_select" then
    local ts = controller.team_select
    if ts then
      local available_id = find_rect(View.team_select_available_rects(controller), x, y)
      if available_id then controller:team_select_hover(available_id); return end
      local party_id = find_rect(View.team_select_party_rects(controller), x, y)
      if party_id then controller:team_select_hover(party_id); return end
    end
    controller:set_hover(nil, nil)
    return
  end

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

  -- Écran "forge" (2026-08-28) : infobulle mot-clé sur les cartes proposées à
  -- l'amélioration -- même souci de cohérence que le bug draft ci-dessus
  -- (jamais un écran de cartes sans infobulle).
  if controller.screen == "forge" then
    local f = controller.forge
    if f then
      local rects = View.forge_card_rects(controller)
      for i, r in ipairs(rects) do
        if View.point_in(r, x, y) then
          controller:set_hover("card", f.choices[i].def)
          return
        end
      end
    end
    controller:set_hover(nil, nil)
    return
  end

  -- Écran "temple" (2026-08-28/29) : infobulle sur chaque statue (nom +
  -- descriptif complet -- "seul le titre apparait sous chaque statue", voir
  -- tooltip_lines/h.kind == "temple_effect" dans view.lua) ET sur chaque
  -- portrait d'aventurier (description de classe + statuts + la ligne de
  -- bénédiction/malédiction) -- un aventurier mort/déjà porteur reste
  -- survolable pour l'infobulle même s'il n'est pas cliquable (voir
  -- post_combat_hovering, plus restrictif).
  if controller.screen == "temple" then
    local t = controller.temple
    if t then
      local effect_rects = View.temple_effect_rects(controller)
      for i, r in ipairs(effect_rects) do
        if View.point_in(r, x, y) then controller:set_hover("temple_effect", t.choices[i]); return end
      end
    end
    local rects = View.temple_hero_rects(controller)
    local hero_id = find_rect(rects, x, y)
    if hero_id then controller:set_hover("hero", hero_id); return end
    controller:set_hover(nil, nil)
    return
  end

  if controller.screen ~= "playing" then controller:set_hover(nil, nil); return end
  local state = controller.state

  if controller.input_mode == "arrow" then
    local hovered_uid = View.hand_hit(state, x, y)
    controller:set_arrow_hand_hover(hovered_uid)
  end

  local hero_id = find_rect(View.hero_rects(state), x, y)
  if hero_id then controller:set_hover("hero", hero_id); return end

  local enemy_id = find_rect(View.enemy_rects(state), x, y)
  if enemy_id then controller:set_hover("enemy", enemy_id); return end

  -- Pioche/défausse (2026-08-21, demande explicite) : survolables pour une
  -- infobulle (nombre de cartes + règle associée, voir tooltip_lines dans
  -- view.lua) -- ne deviennent pas cliquables pour autant, aucun mousepressed
  -- ne les gère.
  if View.point_in(View.deck_pile_rect, x, y) then controller:set_hover("deck", nil); return end
  if View.point_in(View.discard_pile_rect, x, y) then controller:set_hover("discard", nil); return end
  -- "Fin de tour" (2026-08-27, demande explicite) : infobulle expliquant l'effet
  -- (défausse de la main + tour ennemi) -- le bouton reste cliquable comme avant
  -- (voir plus haut dans ce fichier), ceci ajoute juste le survol.
  if View.point_in(View.end_turn_button, x, y) then controller:set_hover("end_turn", nil); return end

  local hover_uid = View.hand_hit(state, x, y)
  if hover_uid then
    for _, c in ipairs(state.hand) do
      if c.uid == hover_uid then controller:set_hover("card", c.def); return end
    end
  end

  controller:set_hover(nil, nil)
end

return Input
