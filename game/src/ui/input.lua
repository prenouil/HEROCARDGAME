-- Traduit les clics/survol souris en appels au Controller. Toute la logique de
-- "qui est cliquable maintenant" est dérivée de state.pending, jamais dupliquée.
-- Sélectionner une carte assigne directement son propriétaire (2026-08-20,
-- voir Game.select_card) : il ne reste que 2 temps, carte -> cible.

local View = require("src.ui.view")
local Save = require("src.ui.save")
-- Molette sur l'écran "Construis ton deck" (2026-09-02) : Input.wheelmoved ne
-- reçoit que dx/dy (crans de molette, voir main.lua), jamais la position du
-- curseur -- seul endroit de ce fichier qui a besoin de la relire lui-même
-- (love.mouse.getPosition(), divisée par SCALE comme partout ailleurs).
local SCALE = require("src.ui.layout_scale")

local Input = {}

local function find_rect(rects_by_id, x, y)
  for id, r in pairs(rects_by_id) do
    if View.point_in(r, x, y) then return id end
  end
  return nil
end

--- Menu pause (2026-09-02, demande explicite) : passe AVANT tout le reste,
-- même "voir le deck" -- c'est l'overlay le plus "extérieur" (dessiné en
-- dernier, voir View.draw). Un clic hors des 2 boutons ne fait rien --
-- contrairement à la fenêtre "voir le deck", qui se ferme au clic extérieur,
-- ESC (Controller:handle_escape) reste le seul raccourci pour la refermer
-- sans choisir une des 2 options.
local function pause_menu_click(controller, x, y)
  if not controller.pause_menu_open then return false end
  if View.point_in(View.pause_menu_continue_button, x, y) then controller:close_pause_menu()
  elseif View.point_in(View.pause_menu_return_button, x, y) then controller:pause_menu_return_to_menu()
  end
  return true
end

local function pause_menu_hovering(controller, x, y)
  if not controller.pause_menu_open then return false end
  return View.point_in(View.pause_menu_continue_button, x, y) or View.point_in(View.pause_menu_return_button, x, y)
end

--- Fenêtre "voir le deck" (2026-08-30, demande explicite) : passe AVANT tout
-- le reste (menu_click compris) tant qu'elle est ouverte -- un clic sur
-- "Fermer" OU en dehors du panneau la referme, un clic À L'INTÉRIEUR (sur une
-- carte, par exemple) ne fait rien de plus que "consommer" le clic, jamais
-- retomber sur l'écran masqué en dessous. Réutilisée telle quelle par
-- mousepressed_tap/arrow ET is_hovering_clickable_tap/arrow, même schéma que
-- menu_click/post_combat_click.
local function deck_view_click(controller, x, y)
  if not controller.deck_view_open then return false end
  if View.point_in(View.deck_view_close_button, x, y) or not View.point_in(View.deck_view_panel_rect, x, y) then
    controller:close_deck_view()
  end
  return true
end

local function deck_view_hovering(controller, x, y)
  if not controller.deck_view_open then return false end
  return View.point_in(View.deck_view_close_button, x, y) or not View.point_in(View.deck_view_panel_rect, x, y)
end

--- Sélecteur de test "toutes les cartes" (2026-10-01, demande explicite) :
-- même priorité/schéma que deck_view_click juste au-dessus -- un clic sur
-- "Fermer" OU en dehors du panneau le referme, un clic sur UNE CARTE l'ajoute
-- au deck (voir Controller:pick_debug_card) sans jamais fermer l'overlay
-- (outil de test, pensé pour en ajouter plusieurs d'affilée).
local function debug_card_picker_click(controller, x, y)
  if not controller.debug_card_picker then return false end
  if View.point_in(View.debug_card_picker_close_button, x, y) or not View.point_in(View.debug_card_picker_panel_rect, x, y) then
    controller:close_debug_card_picker()
    return true
  end
  local layout = View.debug_card_picker_layout()
  local scroll = math.max(0, math.min(layout.max_scroll, controller.debug_card_picker.scroll or 0))
  for i, def in ipairs(layout.cards) do
    if View.point_in(View.debug_card_picker_rect_at(i, scroll), x, y) then
      controller:pick_debug_card(def)
      break
    end
  end
  return true
end

local function debug_card_picker_hovering(controller, x, y)
  if not controller.debug_card_picker then return false end
  return true -- overlay modal : tout le panneau réagit (cartes cliquables + fermeture)
end

--- Fenêtre PARTAGÉE "Choisis un pouvoir à oublier à jamais" (2026-10-03,
-- "Le Puit de l'Oubli"/"Prédiction de la Mort" -- "Sacrifier un pouvoir à la
-- place") : même priorité/schéma que debug_card_picker_click juste au-dessus
-- -- un clic sur "Retour" OU en dehors du panneau le referme SANS rien
-- détruire (voir Controller:close_power_well_picker), un clic sur UNE CARTE
-- lance le zoom/éclatement (Controller:choose_power_well_card). Pendant
-- l'animation (`pw.anim`), tout clic est simplement "consommé" -- rien n'est
-- plus cliquable, la grille elle-même n'est plus affichée (voir
-- draw_power_well).
local function power_well_click(controller, x, y)
  local pw = controller.power_well
  if not pw then return false end
  if pw.anim then return true end
  if View.point_in(View.power_well_back_button, x, y) or not View.point_in(View.power_well_panel_rect, x, y) then
    controller:close_power_well_picker()
    return true
  end
  local layout = View.power_well_layout(controller)
  local scroll = math.max(0, math.min(layout.max_scroll, pw.scroll or 0))
  for i, c in ipairs(layout.cards) do
    if View.point_in(View.power_well_rect_at(controller, i, scroll), x, y) then
      controller:choose_power_well_card(c.uid)
      break
    end
  end
  return true
end

local function power_well_hovering(controller, x, y)
  return controller.power_well ~= nil
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
        if b.id == "adventure" then controller:enter_adventure_slots()
        elseif b.id == "boss" then controller:enter_team_select("boss_test")
        elseif b.id == "run" then controller:enter_team_select("bounded")
        elseif b.id == "solo" then controller:enter_team_select("solo")
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
  -- Écran "Aventure" (2026-10-05, demande explicite) : un clic sur un
  -- emplacement le crée s'il n'existe pas encore puis route vers le choix
  -- d'équipe (voir Controller:choose_adventure_slot) ; la croix rouge
  -- supprime sa sauvegarde SANS y entrer (testée avant le bouton d'emplacement
  -- lui-même, même si les 2 rects ne se chevauchent jamais -- par principe,
  -- comme power_well_click teste "Retour" avant la grille) ; "Retour" revient
  -- au menu, même schéma que les autres écrans à bouton unique.
  if controller.screen == "adventure_slots" then
    for _, b in ipairs(View.adventure_slot_delete_buttons) do
      if Save.slot_exists(b.slot) and View.point_in(b, x, y) then
        controller:delete_adventure_slot(b.slot)
        return true
      end
    end
    for _, b in ipairs(View.adventure_slot_buttons) do
      if View.point_in(b, x, y) then controller:choose_adventure_slot(b.slot); return true end
    end
    if View.point_in(View.adventure_back_button, x, y) then controller:back_to_menu() end
    return true
  end
  -- Écran "Sélection de quête" (2026-10-06, demande explicite) : `class_id`
  -- relu depuis `controller.quest_select.data`, JAMAIS recalculé ici -- un
  -- bandeau "Pas de quête de ..." (class_id absent) n'est simplement pas
  -- testé, donc pas cliquable. "Retour" renvoie au choix d'emplacement (pas
  -- directement au menu -- l'étape logiquement précédente), voir
  -- Controller:enter_adventure_slots.
  if controller.screen == "quest_select" then
    local data = controller.quest_select and controller.quest_select.data
    if data then
      if View.point_in(View.quest_banners[1], x, y) then controller:choose_quest("main"); return true end
      for i = 1, 2 do
        local class_id = data.class_quest_ids and data.class_quest_ids[i]
        if class_id and View.point_in(View.quest_banners[i + 1], x, y) then
          controller:choose_quest("class", class_id)
          return true
        end
      end
      if data.companion_quest_class_id and View.point_in(View.quest_banners[4], x, y) then
        controller:choose_quest("companion", data.companion_quest_class_id)
        return true
      end
    end
    if View.point_in(View.quest_back_button, x, y) then controller:enter_adventure_slots() end
    return true
  end
  -- Écran "Félicitations" (2026-10-06, demande explicite) : un seul bouton.
  if controller.screen == "quest_reward" then
    if View.point_in(View.quest_reward_continue_button, x, y) then controller:continue_from_quest_reward() end
    return true
  end
  -- Écran "Choisis un boss" (2026-09-02, étendu le même jour -- niveau
  -- réglable + sélection avant lancement) : le réglage de niveau est UNIQUE
  -- (partagé, plus un par carte -- voir View.boss_select_level_minus/plus)
  -- et testé AVANT le corps des cartes ; un clic sur une carte sélectionne ce
  -- boss (ne lance plus rien directement, voir Controller:select_boss).
  -- "Combattre" : inerte tant qu'aucun boss n'est sélectionné (voir
  -- draw_boss_select).
  if controller.screen == "boss_select" then
    if View.point_in(View.boss_select_level_minus, x, y) then controller:adjust_boss_level(-1); return true end
    if View.point_in(View.boss_select_level_plus, x, y) then controller:adjust_boss_level(1); return true end
    for _, b in ipairs(View.boss_select_buttons) do
      if View.point_in(b, x, y) then controller:select_boss(b.biome); return true end
    end
    if View.point_in(View.boss_select_combat_button, x, y) then controller:launch_boss_fight(); return true end
    if View.point_in(View.boss_select_back_button, x, y) then controller:back_to_menu() end
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
  if controller.screen == "adventure_slots" then
    for _, b in ipairs(View.adventure_slot_delete_buttons) do
      if Save.slot_exists(b.slot) and View.point_in(b, x, y) then return true end
    end
    for _, b in ipairs(View.adventure_slot_buttons) do
      if View.point_in(b, x, y) then return true end
    end
    return View.point_in(View.adventure_back_button, x, y)
  end
  if controller.screen == "quest_select" then
    local data = controller.quest_select and controller.quest_select.data
    if data then
      if View.point_in(View.quest_banners[1], x, y) then return true end
      for i = 1, 2 do
        if data.class_quest_ids and data.class_quest_ids[i] and View.point_in(View.quest_banners[i + 1], x, y) then
          return true
        end
      end
      if data.companion_quest_class_id and View.point_in(View.quest_banners[4], x, y) then return true end
    end
    return View.point_in(View.quest_back_button, x, y)
  end
  if controller.screen == "quest_reward" then
    return View.point_in(View.quest_reward_continue_button, x, y)
  end
  if controller.screen == "boss_select" then
    if View.point_in(View.boss_select_level_minus, x, y) or View.point_in(View.boss_select_level_plus, x, y) then
      return true
    end
    for _, b in ipairs(View.boss_select_buttons) do
      if View.point_in(b, x, y) then return true end
    end
    return View.point_in(View.boss_select_combat_button, x, y) or View.point_in(View.boss_select_back_button, x, y)
  end
  return false
end

--- Écran "Construis ton deck" ("Run Solo", 2026-09-02, demande explicite) :
-- clic GAUCHE sur une carte du haut = en ajouter une copie en bas
-- (Controller:deck_builder_add) ; clic gauche sur une carte du bas = la
-- retirer (Controller:deck_builder_remove) -- le clic DROIT (bascule
-- amélioration) est géré à part dans Input.mousepressed, jamais ici (ce
-- fichier ne reçoit que des clics GAUCHE, voir mousepressed_tap/arrow).
local function deck_builder_click(controller, x, y)
  if controller.screen ~= "deck_builder" then return false end
  local db = controller.deck_builder
  if not db then return true end

  if View.point_in(View.deck_builder_back_button, x, y) then controller:back_to_menu(); return true end
  if #db.bottom_cards >= View.DECK_BUILDER_MIN_CARDS and View.point_in(View.deck_builder_test_button, x, y) then
    controller:launch_solo_test()
    return true
  end

  local top_layout = View.deck_builder_top_layout(controller)
  local top_scroll = math.max(0, math.min(top_layout.max_scroll, db.top_scroll or 0))
  local top_index = View.deck_builder_hit(top_layout, top_scroll, #db.top_defs, x, y)
  if top_index then controller:deck_builder_add(top_index); return true end

  local bottom_layout = View.deck_builder_bottom_layout(controller)
  local bottom_scroll = math.max(0, math.min(bottom_layout.max_scroll, db.bottom_scroll or 0))
  local bottom_index = View.deck_builder_hit(bottom_layout, bottom_scroll, #db.bottom_cards, x, y)
  if bottom_index then controller:deck_builder_remove(bottom_index); return true end

  return true
end

local function deck_builder_hovering(controller, x, y)
  if controller.screen ~= "deck_builder" then return false end
  local db = controller.deck_builder
  if not db then return false end
  if View.point_in(View.deck_builder_back_button, x, y) then return true end
  if #db.bottom_cards >= View.DECK_BUILDER_MIN_CARDS and View.point_in(View.deck_builder_test_button, x, y) then return true end
  local top_layout = View.deck_builder_top_layout(controller)
  local top_scroll = math.max(0, math.min(top_layout.max_scroll, db.top_scroll or 0))
  if View.deck_builder_hit(top_layout, top_scroll, #db.top_defs, x, y) then return true end
  local bottom_layout = View.deck_builder_bottom_layout(controller)
  local bottom_scroll = math.max(0, math.min(bottom_layout.max_scroll, db.bottom_scroll or 0))
  if View.deck_builder_hit(bottom_layout, bottom_scroll, #db.bottom_cards, x, y) then return true end
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
  if controller.screen == "campfire" then
    local cf = controller.campfire
    if cf and not cf.resolved then
      local rects = View.campfire_hero_rects(controller)
      for _, h in ipairs(controller.state.heroes) do
        local r = rects[h.id]
        -- Mort définitive (2026-09-25, pilier du sacrifice -- ancien
        -- comportement voulu, pas un bug, devenu obsolète) : un aventurier
        -- mort n'est plus une cible cliquable ici -- Controller:
        -- choose_campfire_hero le refuse déjà, ce filtre évite en plus le
        -- retour `true` (qui marquerait le clic "consommé") sur un portrait
        -- qui ne fait plus rien.
        if r and h.hp > 0 and View.point_in(r, x, y) then controller:choose_campfire_hero(h.id); return true end
      end
    end
    return true
  end
  if controller.screen == "refuge" then
    if controller.refuge and View.point_in(View.refuge_rest_button, x, y) then
      controller:choose_refuge_rest()
    end
    return true
  end
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
  -- "Prédiction de la Mort" (2026-10-03) : une seule carte à cliquer, directement
  -- au-dessus du héros concerné (jamais une sélection en 2 temps comme le
  -- Temple) -- seuls les héros avec une entrée dans `p.eligible` répondent
  -- (héros mort/carte déjà prise = carte de dos non interactive, voir
  -- draw_prediction). "Sacrifier un pouvoir à la place" ouvre la fenêtre
  -- partagée (voir power_well_click plus haut, testée AVANT ce dispatch).
  if controller.screen == "prediction" then
    local p = controller.prediction
    if p and not p.resolved then
      local card_rects = View.prediction_card_rects(controller)
      for _, h in ipairs(controller.state.heroes) do
        if p.eligible[h.id] then
          local r = card_rects[h.id]
          if r and View.point_in(r, x, y) then controller:choose_prediction_card(h.id); return true end
        end
      end
      if View.point_in(View.prediction_sacrifice_button, x, y) then controller:prediction_open_sacrifice() end
    end
    return true
  end
  -- "Le Puit de l'Oubli" (2026-10-03) : simple écran d'intro, 1 seul bouton --
  -- la vraie sélection vit dans la fenêtre partagée (voir power_well_click).
  if controller.screen == "puits" then
    if controller.puits and View.point_in(View.puits_choose_button, x, y) then
      controller:puits_open_picker()
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
    -- Onglets Départ/Trépas-Avancé-Artefact (2026-10-03, demande explicite) :
    -- seulement cliquables quand un héros est mis en avant -- les boutons ne
    -- sont de toute façon affichés que dans ce cas (voir draw_team_select).
    for _, b in ipairs(View.team_select_tab_button_rects()) do
      if View.point_in(b, x, y) then controller:team_select_switch_tab(b.id); return true end
    end
  end

  -- "Voir le deck" (2026-08-30, demande explicite) : clic sur le deck qui se
  -- construit en bas à gauche au fil des aventuriers confirmés (voir
  -- View.team_select_deck_rect/draw_team_deck) -- ouvre la même fenêtre que
  -- la pioche/défausse en combat, voir Controller:open_deck_view.
  if View.point_in(View.team_select_deck_rect(#ts.selected_ids), x, y) then
    controller:open_deck_view(); return true
  end

  -- `team_select_hero_interactive` (2026-08-30, bug signalé) : ignore la case
  -- laissée VIDE par un héros mis en avant/en transit -- draw_team_select
  -- (view.lua) n'y dessine plus rien depuis son introduction, mais le rect
  -- lui-même reste dans available_ids/selected_ids (positions stables pour
  -- les autres), donc toujours cliquable sans ce filtre.
  local available_id = find_rect(View.team_select_available_rects(controller), x, y)
  if available_id and controller:team_select_hero_interactive(available_id) then
    controller:team_select_focus(available_id); return true
  end
  local party_id = find_rect(View.team_select_party_rects(controller), x, y)
  if party_id and controller:team_select_hero_interactive(party_id) then
    controller:team_select_focus(party_id); return true
  end

  if #ts.selected_ids == ts.max_team_size and View.point_in(View.team_select_launch_button, x, y) then
    controller:team_select_launch()
    return true
  end

  if View.point_in(View.team_select_autofill_button, x, y) then
    controller:team_select_autofill()
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
  elseif controller.run_mode == "solo_test" then controller:start_solo_test()
  else controller:reset_run()
  end
end

local function mousepressed_tap(controller, x, y, button)
  if button ~= 1 then return end
  if pause_menu_click(controller, x, y) then return end
  if deck_view_click(controller, x, y) then return end
  if debug_card_picker_click(controller, x, y) then return end
  if power_well_click(controller, x, y) then return end
  if menu_click(controller, x, y) then return end
  if deck_builder_click(controller, x, y) then return end
  if team_select_click(controller, x, y) then return end
  if controller.screen == "bossVictory" then return end
  local state = controller.state

  -- Défaite en mode "Aventure" (2026-10-07, demande explicite -- "pas
  -- d'option rejouer, seulement revenir au menu, plus un bouton admin
  -- discret qui permet de rejouer le dernier combat") : `controller.save_slot`
  -- distingue les 2 cas -- jamais de "Rejouer avec la même équipe" pour ce
  -- mode (repartirait sur une toute NOUVELLE run, contournerait la défaite
  -- réelle demandée par ce mode) ; le bouton discret restaure directement la
  -- photo du combat perdu (Controller:restart_combat, déjà utilisée par
  -- "Recommencer le combat" en pleine partie -- même mécanisme, pas un 2ᵉ).
  if controller.screen == "defeat" then
    if controller.save_slot then
      if View.point_in(View.overlay_admin_restart_combat_button, x, y) then controller:restart_combat()
      elseif View.point_in(View.overlay_menu_button_alone, x, y) then controller:back_to_menu()
      end
    else
      if View.point_in(View.overlay_restart_button, x, y) then restart_after_defeat(controller)
      elseif View.point_in(View.overlay_menu_button, x, y) then controller:back_to_menu()
      end
    end
    return
  end

  -- Écran de victoire à gains détachés (2026-09-02, demande explicite) : 2
  -- gains cliquables indépendamment (PO/carte, voir Controller:click_victory_
  -- gold/click_victory_card) plus la rangée de draft classique une fois la
  -- carte "?" cliquée (inchangée -- même View.draft_rects/draft_skip_button
  -- qu'avant, juste repositionnés, voir view.lua) et "Continuer" (actif
  -- seulement une fois les 2 gains faits, guard redondant avec
  -- Controller:victory_continue -- même schéma défensif que draft_card_ready
  -- ci-dessous).
  if controller.screen == "victory" then
    -- Bouton discret "Debug" (2026-10-01, demande explicite) : toujours actif
    -- sur l'écran de draft, même avant que les gains ne soient affichés --
    -- voir View.debug_card_picker_button (view/victory.lua).
    if View.point_in(View.debug_card_picker_button, x, y) then controller:open_debug_card_picker(); return end
    if controller.victory_gains_shown then
      if not controller.victory_gold_collected and not controller.victory_gold_flying
        and View.point_in(View.victory_gold_rect, x, y) then
        controller:click_victory_gold(); return
      end
      if not controller.draft_picks and not controller.victory_card_collected
        and View.point_in(View.victory_card_rect, x, y) then
        controller:click_victory_card(); return
      end
      local rects = View.draft_rects(controller)
      for i, r in ipairs(rects) do
        if View.point_in(r, x, y) and controller:draft_card_ready(i) then controller:choose_draft_card(i); return end
      end
      -- "Ne rien prendre" (2026-08-30, demande explicite) : voir View.draft_skip_button.
      if controller.draft_cards_shown and View.point_in(View.draft_skip_button, x, y) then
        controller:skip_draft(); return
      end
      if View.point_in(View.victory_continue_button, x, y) then controller:victory_continue() end
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
    local hand_id = View.hand_hit(state, x, y, View.hand_hiding_uids(controller))
    if hand_id then controller:select_card(hand_id)
    else controller:confirm_pending() end
    return
  end

  if View.point_in(View.end_turn_button, x, y) then controller:end_turn(); return end
  if View.point_in(View.restart_button, x, y) then controller:restart_combat(); return end
  if View.point_in(View.restart_turn_button, x, y) then controller:restart_turn(); return end
  if View.point_in(View.instant_victory_button, x, y) then controller:trigger_instant_victory(); return end
  -- "Voir le deck" (2026-08-30, demande explicite) : 3 déclencheurs pour la
  -- même fenêtre, mais PAS le même contenu (2026-08-30, 2ᵉ demande explicite --
  -- "quand on clique sur Pioche, on ne voit que les cartes actuellement dans
  -- la pioche, et quand on clique sur la défausse, on ne voit que les cartes
  -- actuellement dans la défausse") -- la pioche/la défausse filtrent sur
  -- elles-mêmes, le bouton dédié seul garde "toutes les cartes" (voir
  -- Controller:open_deck_view/View.deck_view_button).
  if View.point_in(View.deck_pile_rect, x, y) then controller:open_deck_view("deck"); return end
  if View.point_in(View.discard_pile_rect, x, y) then controller:open_deck_view("discard"); return end
  if View.point_in(View.deck_view_button, x, y) then controller:open_deck_view(); return end

  local pending = state.pending
  -- Sélectionner une carte l'assigne directement à son propriétaire
  -- (2026-08-20, voir Game.select_card) : plus de bouton "Jouer" à choisir,
  -- `pending` n'existe donc jamais sans `pending.hero_id` déjà fixé.
  if pending and pending.hero_id then
    if pending.def.target == "enemy" or pending.def.target == "conditional" or pending.def.target == "enemy-or-ally" then
      local enemy_id = find_rect(View.enemy_rects(state), x, y)
      if enemy_id then controller:resolve_target("enemy", enemy_id); return end
    end
    if pending.def.target == "ally" or pending.def.target == "enemy-or-ally" then
      local hero_id = find_rect(View.hero_rects(state), x, y)
      if hero_id then controller:resolve_target("ally", hero_id); return end
    end
  end

  -- Sélection/désélection d'une carte de la main (toujours possible tant
  -- qu'aucune cible n'est en cours de résolution).
  local hand_id = View.hand_hit(state, x, y, View.hand_hiding_uids(controller))
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
  if pause_menu_click(controller, x, y) then return end
  if deck_view_click(controller, x, y) then return end
  if debug_card_picker_click(controller, x, y) then return end
  if power_well_click(controller, x, y) then return end
  if menu_click(controller, x, y) then return end
  if deck_builder_click(controller, x, y) then return end
  if team_select_click(controller, x, y) then return end
  if controller.screen == "bossVictory" then return end
  local state = controller.state

  -- Défaite en mode "Aventure" (2026-10-07, demande explicite -- "pas
  -- d'option rejouer, seulement revenir au menu, plus un bouton admin
  -- discret qui permet de rejouer le dernier combat") : `controller.save_slot`
  -- distingue les 2 cas -- jamais de "Rejouer avec la même équipe" pour ce
  -- mode (repartirait sur une toute NOUVELLE run, contournerait la défaite
  -- réelle demandée par ce mode) ; le bouton discret restaure directement la
  -- photo du combat perdu (Controller:restart_combat, déjà utilisée par
  -- "Recommencer le combat" en pleine partie -- même mécanisme, pas un 2ᵉ).
  if controller.screen == "defeat" then
    if controller.save_slot then
      if View.point_in(View.overlay_admin_restart_combat_button, x, y) then controller:restart_combat()
      elseif View.point_in(View.overlay_menu_button_alone, x, y) then controller:back_to_menu()
      end
    else
      if View.point_in(View.overlay_restart_button, x, y) then restart_after_defeat(controller)
      elseif View.point_in(View.overlay_menu_button, x, y) then controller:back_to_menu()
      end
    end
    return
  end

  -- Écran de victoire à gains détachés (2026-09-02, demande explicite) : 2
  -- gains cliquables indépendamment (PO/carte, voir Controller:click_victory_
  -- gold/click_victory_card) plus la rangée de draft classique une fois la
  -- carte "?" cliquée (inchangée -- même View.draft_rects/draft_skip_button
  -- qu'avant, juste repositionnés, voir view.lua) et "Continuer" (actif
  -- seulement une fois les 2 gains faits, guard redondant avec
  -- Controller:victory_continue -- même schéma défensif que draft_card_ready
  -- ci-dessous).
  if controller.screen == "victory" then
    -- Bouton discret "Debug" (2026-10-01, demande explicite) : toujours actif
    -- sur l'écran de draft, même avant que les gains ne soient affichés --
    -- voir View.debug_card_picker_button (view/victory.lua).
    if View.point_in(View.debug_card_picker_button, x, y) then controller:open_debug_card_picker(); return end
    if controller.victory_gains_shown then
      if not controller.victory_gold_collected and not controller.victory_gold_flying
        and View.point_in(View.victory_gold_rect, x, y) then
        controller:click_victory_gold(); return
      end
      if not controller.draft_picks and not controller.victory_card_collected
        and View.point_in(View.victory_card_rect, x, y) then
        controller:click_victory_card(); return
      end
      local rects = View.draft_rects(controller)
      for i, r in ipairs(rects) do
        if View.point_in(r, x, y) and controller:draft_card_ready(i) then controller:choose_draft_card(i); return end
      end
      -- "Ne rien prendre" (2026-08-30, demande explicite) : voir View.draft_skip_button.
      if controller.draft_cards_shown and View.point_in(View.draft_skip_button, x, y) then
        controller:skip_draft(); return
      end
      if View.point_in(View.victory_continue_button, x, y) then controller:victory_continue() end
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
    local hand_id = View.hand_hit(state, x, y, View.hand_hiding_uids(controller))
    if hand_id then controller:select_card(hand_id)
    else controller:confirm_pending() end
    return
  end

  if View.point_in(View.end_turn_button, x, y) then controller:end_turn(); return end
  if View.point_in(View.restart_button, x, y) then controller:restart_combat(); return end
  if View.point_in(View.restart_turn_button, x, y) then controller:restart_turn(); return end
  if View.point_in(View.instant_victory_button, x, y) then controller:trigger_instant_victory(); return end
  -- "Voir le deck" (2026-08-30, demande explicite) : voir le commentaire
  -- détaillé dans mousepressed_tap.
  if View.point_in(View.deck_pile_rect, x, y) then controller:open_deck_view("deck"); return end
  if View.point_in(View.discard_pile_rect, x, y) then controller:open_deck_view("discard"); return end
  if View.point_in(View.deck_view_button, x, y) then controller:open_deck_view(); return end

  local pending = state.pending

  -- Sélectionner une carte l'assigne directement à son propriétaire
  -- (2026-08-20, voir Game.select_card) : `pending` n'existe donc jamais sans
  -- `pending.hero_id` déjà fixé, il ne reste que l'attente de la cible finale
  -- (ennemi/allié). Un clic hors cible valide annule tout (décision explicite
  -- du porteur de projet -- pas de retour en arrière d'un cran).
  if pending and pending.hero_id then
    if pending.def.target == "enemy" or pending.def.target == "conditional" or pending.def.target == "enemy-or-ally" then
      local enemy_id = find_rect(View.enemy_rects(state), x, y)
      if enemy_id then controller:resolve_target("enemy", enemy_id); return end
    end
    if pending.def.target == "ally" or pending.def.target == "enemy-or-ally" then
      local hero_id = find_rect(View.hero_rects(state), x, y)
      if hero_id then controller:resolve_target("ally", hero_id); return end
    end
    controller:cancel_pending()
    return
  end

  -- Pas de carte en attente : un clic sur la main la sélectionne.
  local hand_id = View.hand_hit(state, x, y, View.hand_hiding_uids(controller))
  if hand_id then controller:select_card(hand_id) end
end

-- Clic DROIT (2026-09-02, demande explicite -- écran "Construis ton deck",
-- bascule base/améliorée d'une carte du panneau du bas) : seul geste de ce
-- fichier qui n'est PAS un clic gauche -- traité à part, avant le garde-fou
-- `button ~= 1` ci-dessous qui ignorait silencieusement tout le reste.
local function deck_builder_right_click(controller, x, y)
  if controller.screen ~= "deck_builder" then return end
  local db = controller.deck_builder
  if not db then return end
  local bottom_layout = View.deck_builder_bottom_layout(controller)
  local bottom_scroll = math.max(0, math.min(bottom_layout.max_scroll, db.bottom_scroll or 0))
  local index = View.deck_builder_hit(bottom_layout, bottom_scroll, #db.bottom_cards, x, y)
  if index then controller:deck_builder_toggle_upgrade(index) end
end

function Input.mousepressed(controller, x, y, button)
  if button == 2 then deck_builder_right_click(controller, x, y); return end
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
  if controller.screen == "campfire" then
    local cf = controller.campfire
    if not cf or cf.resolved then return false end
    local rects = View.campfire_hero_rects(controller)
    -- Mort définitive (2026-09-25) : un portrait mort ne doit pas non plus se
    -- déclarer survolable-cliquable (curseur), même contrat que le commentaire
    -- ci-dessus le promettait déjà pour "un portrait mort".
    for _, h in ipairs(controller.state.heroes) do
      if h.hp > 0 and View.point_in(rects[h.id], x, y) then return true end
    end
    return false
  end
  if controller.screen == "refuge" then
    return controller.refuge ~= nil and View.point_in(View.refuge_rest_button, x, y)
  end
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
  if controller.screen == "prediction" then
    local p = controller.prediction
    if not p or p.resolved then return false end
    local card_rects = View.prediction_card_rects(controller)
    for _, h in ipairs(controller.state.heroes) do
      if p.eligible[h.id] and View.point_in(card_rects[h.id], x, y) then return true end
    end
    return View.point_in(View.prediction_sacrifice_button, x, y)
  end
  if controller.screen == "puits" then
    return controller.puits ~= nil and View.point_in(View.puits_choose_button, x, y)
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
    for _, b in ipairs(View.team_select_tab_button_rects()) do
      if View.point_in(b, x, y) then return true end
    end
  end
  if View.point_in(View.team_select_deck_rect(#ts.selected_ids), x, y) then return true end
  -- Même filtre que team_select_click (2026-08-30, bug signalé) : sinon le
  -- curseur "main" s'affiche encore sur la case vide laissée par un héros
  -- mis en avant/en transit.
  local available_id = find_rect(View.team_select_available_rects(controller), x, y)
  if available_id and controller:team_select_hero_interactive(available_id) then return true end
  local party_id = find_rect(View.team_select_party_rects(controller), x, y)
  if party_id and controller:team_select_hero_interactive(party_id) then return true end
  if #ts.selected_ids == ts.max_team_size and View.point_in(View.team_select_launch_button, x, y) then return true end
  if View.point_in(View.team_select_autofill_button, x, y) then return true end
  return false
end

local function is_hovering_clickable_tap(controller, x, y)
  if controller.pause_menu_open then return pause_menu_hovering(controller, x, y) end
  if controller.deck_view_open then return deck_view_hovering(controller, x, y) end
  if controller.debug_card_picker then return debug_card_picker_hovering(controller, x, y) end
  if controller.power_well then return power_well_hovering(controller, x, y) end
  if controller.screen == "menu" or controller.screen == "options" or controller.screen == "boss_select"
    or controller.screen == "adventure_slots" or controller.screen == "quest_select"
    or controller.screen == "quest_reward" then
    return menu_hovering(controller, x, y)
  end
  if controller.screen == "deck_builder" then return deck_builder_hovering(controller, x, y) end
  if controller.screen == "team_select" then return team_select_hovering(controller, x, y) end
  if controller.screen == "bossVictory" then return false end
  local state = controller.state

  if controller.screen == "defeat" then
    if controller.save_slot then
      return View.point_in(View.overlay_admin_restart_combat_button, x, y) or View.point_in(View.overlay_menu_button_alone, x, y)
    end
    return View.point_in(View.overlay_restart_button, x, y) or View.point_in(View.overlay_menu_button, x, y)
  end

  if controller.screen == "victory" then
    if View.point_in(View.debug_card_picker_button, x, y) then return true end
    if not controller.victory_gains_shown then return false end
    if not controller.victory_gold_collected and not controller.victory_gold_flying
      and View.point_in(View.victory_gold_rect, x, y) then return true end
    if not controller.draft_picks and not controller.victory_card_collected
      and View.point_in(View.victory_card_rect, x, y) then return true end
    local rects = View.draft_rects(controller)
    for i, r in ipairs(rects) do
      if View.point_in(r, x, y) and controller:draft_card_ready(i) then return true end
    end
    if controller.draft_cards_shown and View.point_in(View.draft_skip_button, x, y) then return true end
    if controller.victory_gold_collected and controller.victory_card_collected
      and View.point_in(View.victory_continue_button, x, y) then return true end
    return false
  end

  if controller.screen == "campfire" or controller.screen == "refuge" or controller.screen == "forge" or controller.screen == "temple"
    or controller.screen == "prediction" or controller.screen == "puits" then return post_combat_hovering(controller, x, y) end

  -- Carte "sans cible" en attente de confirmation (2026-08-27) : n'importe où
  -- est cliquable (soit ça valide, soit ça échange/désélectionne, voir
  -- mousepressed_tap) -- jamais un clic ignoré dans cet état.
  if state.pending and state.pending.awaiting_confirm_kind then return true end

  if View.point_in(View.end_turn_button, x, y) then return true end
  if View.point_in(View.restart_button, x, y) then return true end
  if View.point_in(View.restart_turn_button, x, y) then return true end
  if View.point_in(View.instant_victory_button, x, y) then return true end
  if View.point_in(View.deck_pile_rect, x, y) or View.point_in(View.discard_pile_rect, x, y)
    or View.point_in(View.deck_view_button, x, y) then return true end

  local pending = state.pending
  if pending and pending.hero_id then
    if pending.def.target == "enemy" or pending.def.target == "conditional" or pending.def.target == "enemy-or-ally" then
      if find_rect(View.enemy_rects(state), x, y) then return true end
    end
    if pending.def.target == "ally" or pending.def.target == "enemy-or-ally" then
      if find_rect(View.hero_rects(state), x, y) then return true end
    end
  end

  return View.hand_hit(state, x, y, View.hand_hiding_uids(controller)) ~= nil
end

-- Contrairement au mode tap, une zone/cible invalide ANNULE au clic (voir
-- mousepressed_arrow) -- mais on ne l'annonce pas comme "cliquable" au survol
-- (curseur main), le curseur ne réagit qu'aux vraies opportunités d'action.
local function is_hovering_clickable_arrow(controller, x, y)
  if controller.pause_menu_open then return pause_menu_hovering(controller, x, y) end
  if controller.deck_view_open then return deck_view_hovering(controller, x, y) end
  if controller.debug_card_picker then return debug_card_picker_hovering(controller, x, y) end
  if controller.power_well then return power_well_hovering(controller, x, y) end
  if controller.screen == "menu" or controller.screen == "options" or controller.screen == "boss_select"
    or controller.screen == "adventure_slots" or controller.screen == "quest_select"
    or controller.screen == "quest_reward" then
    return menu_hovering(controller, x, y)
  end
  if controller.screen == "deck_builder" then return deck_builder_hovering(controller, x, y) end
  if controller.screen == "team_select" then return team_select_hovering(controller, x, y) end
  if controller.screen == "bossVictory" then return false end
  local state = controller.state

  if controller.screen == "defeat" then
    if controller.save_slot then
      return View.point_in(View.overlay_admin_restart_combat_button, x, y) or View.point_in(View.overlay_menu_button_alone, x, y)
    end
    return View.point_in(View.overlay_restart_button, x, y) or View.point_in(View.overlay_menu_button, x, y)
  end

  if controller.screen == "victory" then
    if View.point_in(View.debug_card_picker_button, x, y) then return true end
    if not controller.victory_gains_shown then return false end
    if not controller.victory_gold_collected and not controller.victory_gold_flying
      and View.point_in(View.victory_gold_rect, x, y) then return true end
    if not controller.draft_picks and not controller.victory_card_collected
      and View.point_in(View.victory_card_rect, x, y) then return true end
    local rects = View.draft_rects(controller)
    for i, r in ipairs(rects) do
      if View.point_in(r, x, y) and controller:draft_card_ready(i) then return true end
    end
    if controller.draft_cards_shown and View.point_in(View.draft_skip_button, x, y) then return true end
    if controller.victory_gold_collected and controller.victory_card_collected
      and View.point_in(View.victory_continue_button, x, y) then return true end
    return false
  end

  if controller.screen == "campfire" or controller.screen == "refuge" or controller.screen == "forge" or controller.screen == "temple"
    or controller.screen == "prediction" or controller.screen == "puits" then return post_combat_hovering(controller, x, y) end

  -- Carte "sans cible" en attente de confirmation (2026-08-27) : même garde
  -- qu'en mode tap ci-dessus -- n'importe où est cliquable.
  if state.pending and state.pending.awaiting_confirm_kind then return true end

  if View.point_in(View.end_turn_button, x, y) then return true end
  if View.point_in(View.restart_button, x, y) then return true end
  if View.point_in(View.restart_turn_button, x, y) then return true end
  if View.point_in(View.instant_victory_button, x, y) then return true end
  if View.point_in(View.deck_pile_rect, x, y) or View.point_in(View.discard_pile_rect, x, y)
    or View.point_in(View.deck_view_button, x, y) then return true end

  local pending = state.pending
  if pending and pending.hero_id then
    if pending.def.target == "enemy" or pending.def.target == "conditional" or pending.def.target == "enemy-or-ally" then
      if find_rect(View.enemy_rects(state), x, y) then return true end
    end
    if pending.def.target == "ally" or pending.def.target == "enemy-or-ally" then
      if find_rect(View.hero_rects(state), x, y) then return true end
    end
    return false
  end

  return View.hand_hit(state, x, y, View.hand_hiding_uids(controller)) ~= nil
end

function Input.is_hovering_clickable(controller, x, y)
  if controller.input_mode == "arrow" then return is_hovering_clickable_arrow(controller, x, y) end
  return is_hovering_clickable_tap(controller, x, y)
end

function Input.mousemoved(controller, x, y)
  if controller.pause_menu_open then controller:set_hover(nil, nil); return end
  if controller.deck_view_open then controller:set_hover(nil, nil); return end
  if controller.debug_card_picker then controller:set_hover(nil, nil); return end
  if controller.power_well then controller:set_hover(nil, nil); return end
  if controller.screen == "menu" or controller.screen == "options" or controller.screen == "bossVictory"
    or controller.screen == "adventure_slots" or controller.screen == "quest_select"
    or controller.screen == "quest_reward" then
    controller:set_hover(nil, nil)
    return
  end

  -- Écran "Choisis un boss" (2026-09-02, demande explicite -- infobulle par
  -- carte, valeurs dépendantes du niveau réglé) : hors des 4 cartes, aucune
  -- infobulle (Retour/Combattre/le réglage de niveau n'en ont pas besoin).
  if controller.screen == "boss_select" then
    for _, b in ipairs(View.boss_select_buttons) do
      if View.point_in(b, x, y) then controller:set_hover("boss_preview", b.biome); return end
    end
    controller:set_hover(nil, nil)
    return
  end

  -- Écran "Construis ton deck" (2026-09-02) : infobulle générique "card"
  -- (déjà utilisée partout ailleurs -- mots-clés du glossaire présents dans
  -- def.desc, voir tooltip_lines dans view.lua) sur n'importe quelle carte
  -- des 2 panneaux, rien en dehors.
  if controller.screen == "deck_builder" then
    local db = controller.deck_builder
    if db then
      local top_layout = View.deck_builder_top_layout(controller)
      local top_scroll = math.max(0, math.min(top_layout.max_scroll, db.top_scroll or 0))
      local top_index = View.deck_builder_hit(top_layout, top_scroll, #db.top_defs, x, y)
      if top_index then controller:set_hover("card", db.top_defs[top_index]); return end
      local bottom_layout = View.deck_builder_bottom_layout(controller)
      local bottom_scroll = math.max(0, math.min(bottom_layout.max_scroll, db.bottom_scroll or 0))
      local bottom_index = View.deck_builder_hit(bottom_layout, bottom_scroll, #db.bottom_cards, x, y)
      if bottom_index then controller:set_hover("card", db.bottom_cards[bottom_index].def); return end
    end
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
      -- Cartes affichées au centre (2026-08-30, bug signalé -- "pareil pour
      -- les cartes") : seulement les cartes de l'onglet actif, SETTLED (pas
      -- celles encore en plein vol, dont la position réelle diverge de leur
      -- rect de repos tant qu'elles n'ont pas fini d'arriver, voir
      -- Controller:update).
      for _, a in ipairs(ts.card_anims) do
        if a.mode == "in" and a.elapsed >= a.duration and View.point_in(a.to, x, y) then
          controller:set_hover("card", a.def)
          return
        end
      end

      -- Projecteur (2026-08-30, bug signalé -- "les info bulles [doivent]
      -- marcher sur les aventuriers") : le héros mis en avant n'était détecté
      -- par AUCUN des 2 rects ci-dessous une fois déplacé là (ils pointent
      -- toujours vers sa case d'ORIGINE, exclue exprès -- voir
      -- team_select_hero_interactive) -- ni bond au survol, ni infobulle,
      -- tant qu'il y restait.
      if ts.focused_id and View.point_in(View.team_select_spotlight_rect, x, y) then
        controller:team_select_hover(ts.focused_id); return
      end

      -- Même filtre que team_select_click (2026-08-30, bug signalé) : sinon
      -- l'infobulle/le son de survol se déclenchent encore sur la case vide
      -- laissée par un héros mis en avant/en transit.
      local available_id = find_rect(View.team_select_available_rects(controller), x, y)
      if available_id and controller:team_select_hero_interactive(available_id) then
        controller:team_select_hover(available_id); return
      end
      local party_id = find_rect(View.team_select_party_rects(controller), x, y)
      if party_id and controller:team_select_hero_interactive(party_id) then
        controller:team_select_hover(party_id); return
      end
    end
    controller:set_hover(nil, nil)
    return
  end

  -- Écran de draft (2026-08-09, bug signalé) : aucune infobulle mot-clé sur les
  -- 3 cartes de loot, parce que cette fonction s'arrêtait net hors "playing".
  -- Gardé par draft_card_ready comme le clic -- pas de survol tant que la carte
  -- est encore de dos.
  if controller.screen == "victory" then
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

  -- Écran "prediction" (2026-10-03) : même esprit que "temple" juste
  -- au-dessus -- infobulle mot-clé sur chaque carte "Mise à mort" (un héros
  -- sans carte éligible n'a qu'une carte de dos, rien à détailler) ET sur
  -- chaque portrait d'aventurier (description de classe + PV).
  if controller.screen == "prediction" then
    local p = controller.prediction
    if p then
      local card_rects = View.prediction_card_rects(controller)
      for _, h in ipairs(controller.state.heroes) do
        local def = p.eligible[h.id]
        if def and View.point_in(card_rects[h.id], x, y) then controller:set_hover("card", def); return end
      end
    end
    local hero_id = find_rect(View.temple_hero_rects(controller), x, y)
    if hero_id then controller:set_hover("hero", hero_id); return end
    controller:set_hover(nil, nil)
    return
  end

  if controller.screen ~= "playing" then controller:set_hover(nil, nil); return end
  local state = controller.state

  if controller.input_mode == "arrow" then
    local hovered_uid = View.hand_hit(state, x, y, View.hand_hiding_uids(controller))
    controller:set_arrow_hand_hover(hovered_uid)
  end

  local hero_id = find_rect(View.hero_rects(state), x, y)
  if hero_id then controller:set_hover("hero", hero_id); return end

  -- Un ennemi entièrement explosé (2026-08-30, voir Controller:update/
  -- self.enemy_death -- draw_enemy ne dessine plus rien pour lui) ne garde
  -- pas d'infobulle : son emplacement, sinon vide à l'écran, ne doit plus
  -- réagir à la souris.
  local enemy_id = find_rect(View.enemy_rects(state), x, y)
  if enemy_id then
    local death = controller.enemy_death[enemy_id]
    if not (death and death.exploded) then controller:set_hover("enemy", enemy_id); return end
  end

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

  local hover_uid = View.hand_hit(state, x, y, View.hand_hiding_uids(controller))
  if hover_uid then
    for _, c in ipairs(state.hand) do
      if c.uid == hover_uid then controller:set_hover("card", c.def); return end
    end
  end

  controller:set_hover(nil, nil)
end

--- Molette (2026-08-30, demande explicite -- défilement de la fenêtre "voir
-- le deck") : seule utilisatrice pour l'instant -- ne fait rien tant que la
-- fenêtre n'est pas ouverte (voir Controller:scroll_deck_view, qui garde
-- déjà ce même garde-fou, doublé ici pour ne pas dépenser un appel pour rien).
function Input.wheelmoved(controller, dx, dy)
  if controller.deck_view_open then controller:scroll_deck_view(dy); return end
  if controller.debug_card_picker then controller:scroll_debug_card_picker(dy); return end
  if controller.power_well then controller:scroll_power_well(dy); return end
  -- Écran "Construis ton deck" (2026-09-02, demande explicite -- "la partie
  -- haute et la partie basse sont indépendantes, chacune leur ascenseur") :
  -- le panneau défilé dépend d'où le curseur se trouve AU MOMENT du cran de
  -- molette (love.mouse.getPosition(), voir le commentaire de SCALE en tête
  -- de ce fichier -- seul appel de ce genre ici, dx/dy n'étant que des crans).
  if controller.screen == "deck_builder" and controller.deck_builder then
    local mx, my = love.mouse.getPosition()
    mx, my = mx / SCALE, my / SCALE
    if View.point_in(View.deck_builder_top_panel_rect, mx, my) then
      controller:scroll_deck_builder("top", dy)
    elseif View.point_in(View.deck_builder_bottom_panel_rect, mx, my) then
      controller:scroll_deck_builder("bottom", dy)
    end
  end
end

return Input
