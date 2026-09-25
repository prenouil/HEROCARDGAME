-- Fenêtre "Voir le deck" (2026-09-25, extrait de l'ex-monolithe view.lua --
-- voir src/ui/view/init.lua pour le contexte du découpage). Overlay
-- cross-écran (combat ET choix d'équipe), voir Controller.deck_view_open.
local Theme = require("src.ui.theme")
local Deck = require("src.rules.deck")
local SCALE = require("src.ui.layout_scale")
local CardUI = require("src.ui.view.cards")

return function(View, UI)
  -- Fenêtre "voir le deck" elle-même (2026-08-30) : grand panneau centré,
  -- au-dessus de N'IMPORTE quel écran (voir Controller.deck_view_open) --
  -- volontairement à taille fixe plutôt que collée à une pile précise,
  -- puisque ce même panneau s'ouvre aussi bien depuis la pioche/défausse en
  -- combat que depuis le deck de l'écran de choix d'équipe.
  View.deck_view_panel_rect = { x = 40, y = 40, w = UI.W - 80, h = UI.H - 80 }
  View.deck_view_close_button = {
    x = View.deck_view_panel_rect.x + View.deck_view_panel_rect.w - 90,
    y = View.deck_view_panel_rect.y + 10, w = 80, h = 26, label = "Fermer",
  }

  -- PAS de regroupement par doublon (2026-08-30, demande explicite -- "pour
  -- l'instant, il n'y a pas beaucoup de cartes dans un deck, je préfère ne pas
  -- regrouper et lister toutes les cartes même identiques") : une entrée par
  -- exemplaire réellement possédé, jamais un badge "×N" -- triée par classe
  -- puis nom pour un ordre stable d'un appel à l'autre.
  function View.deck_view_cards(controller)
    local defs = {}
    if controller.screen == "team_select" then
      local ts = controller.team_select
      if ts then
        for _, class_id in ipairs(ts.selected_ids) do
          for _, def in ipairs(Deck.starting_cards_for_class(class_id)) do defs[#defs + 1] = def end
        end
      end
    else
      local state = controller.state
      local source = controller.deck_view_source or "all"
      if state then
        if source == "deck" then
          for _, c in ipairs(state.deck) do defs[#defs + 1] = c.def end
        elseif source == "discard" then
          for _, c in ipairs(state.discard) do defs[#defs + 1] = c.def end
        else
          for _, c in ipairs(state.deck) do defs[#defs + 1] = c.def end
          for _, c in ipairs(state.hand) do defs[#defs + 1] = c.def end
          for _, c in ipairs(state.discard) do defs[#defs + 1] = c.def end
        end
      end
    end
    table.sort(defs, function(a, b)
      if a.class_id ~= b.class_id then return a.class_id < b.class_id end
      if a.name ~= b.name then return a.name < b.name end
      return false
    end)
    local out = {}
    for _, def in ipairs(defs) do out[#out + 1] = { def = def } end
    return out
  end

  local function deck_view_title(controller)
    local cards = View.deck_view_cards(controller)
    local source = controller.deck_view_source or "all"
    local label
    if controller.screen ~= "team_select" and source == "deck" then label = "Pioche"
    elseif controller.screen ~= "team_select" and source == "discard" then label = "Défausse"
    else label = "Toutes les cartes" end
    return label .. " (" .. #cards .. ")"
  end

  -- Taille de carte FIXE, colonnes adaptées à la largeur, DÉFILEMENT vertical
  -- si le contenu déborde en hauteur (2026-08-30, demande explicite -- "prévoir
  -- un ascenseur s'il y a trop de cartes") : la carte garde TOUJOURS sa taille
  -- de référence, seul le nombre de lignes visibles change, le reste se
  -- découvre en défilant (molette, voir Controller:scroll_deck_view/
  -- Input.wheelmoved). Pure calcul, sans rien dessiner -- appelée à la fois
  -- par draw_deck_view (rendu) et Controller:scroll_deck_view (bornes de
  -- défilement), pour ne jamais avoir 2 formules de mise en page qui
  -- pourraient diverger.
  local DECK_VIEW_GAP = 10
  local DECK_VIEW_LABEL_H = 14
  local DECK_VIEW_CARD_W = 78
  local DECK_VIEW_SCROLLBAR_W = 10
  function View.deck_view_layout(controller)
    local cards = View.deck_view_cards(controller)
    local p = View.deck_view_panel_rect
    local area_x, area_y = p.x + 20, p.y + 56
    local area_w, area_h = p.w - 40, p.h - 76

    local aspect = UI.CARD_H / UI.CARD_W
    local card_w = DECK_VIEW_CARD_W
    local card_h = card_w * aspect
    local cell_w, cell_h = card_w + DECK_VIEW_GAP, card_h + DECK_VIEW_LABEL_H + DECK_VIEW_GAP

    local function compute(usable_w)
      local cols = math.max(1, math.floor(usable_w / cell_w))
      local rows = #cards > 0 and math.ceil(#cards / cols) or 0
      return cols, rows, rows * cell_h
    end

    local cols, rows, content_h = compute(area_w)
    local max_scroll = math.max(0, content_h - area_h)
    -- Une fois qu'on sait qu'un ascenseur sera affiché, sa largeur est retirée
    -- de la zone utile aux cartes -- recalcule cols/rows avec cette largeur
    -- réduite (jamais de chevauchement carte/ascenseur).
    if max_scroll > 0 then
      cols, rows, content_h = compute(area_w - DECK_VIEW_SCROLLBAR_W - 6)
      max_scroll = math.max(0, content_h - area_h)
    end

    local grid_w = cols * cell_w
    local ox = area_x + (area_w - (max_scroll > 0 and DECK_VIEW_SCROLLBAR_W + 6 or 0) - grid_w) / 2

    return {
      cards = cards, cols = cols, rows = rows, card_w = card_w, card_h = card_h,
      cell_w = cell_w, cell_h = cell_h, area_x = area_x, area_y = area_y,
      area_w = area_w, area_h = area_h, ox = ox, content_h = content_h, max_scroll = max_scroll,
    }
  end

  --- Fenêtre "voir le deck" (2026-08-30, demande explicite -- accessible depuis
  -- la pioche, la défausse, le deck de l'écran de choix d'équipe, et un bouton
  -- dédié) : panneau fixe (View.deck_view_panel_rect) par-dessus l'écran
  -- courant, grille de cartes recalculée à chaque frame.
  local function draw_deck_view(controller)
    if not controller.deck_view_open then return end
    UI.set(Theme.black, 0.75); love.graphics.rectangle("fill", 0, 0, UI.W, UI.H)

    local p = View.deck_view_panel_rect
    UI.panel(p.x, p.y, p.w, p.h, Theme.panel)
    UI.set(Theme.accent); love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", p.x, p.y, p.w, p.h, 10, 10)
    love.graphics.setLineWidth(1)

    UI.text(deck_view_title(controller), p.x + 20, p.y + 16, p.w - 130, 18, Theme.text, "left")

    local cb = View.deck_view_close_button
    UI.set(Theme.panel_light); love.graphics.rectangle("fill", cb.x, cb.y, cb.w, cb.h, 8, 8)
    UI.set(Theme.muted); love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", cb.x, cb.y, cb.w, cb.h, 8, 8)
    love.graphics.setLineWidth(1)
    UI.text(cb.label, cb.x, cb.y + 6, cb.w, 14, Theme.text, "center")

    local layout = View.deck_view_layout(controller)
    local cards = layout.cards
    if #cards == 0 then
      UI.text("Aucune carte pour l'instant.", layout.area_x, layout.area_y + layout.area_h / 2 - 10, layout.area_w, 14, Theme.muted)
      return
    end

    local scroll = math.max(0, math.min(layout.max_scroll, controller.deck_view_scroll or 0))
    local oy = layout.area_y - scroll

    -- Défilement (2026-08-30) : recadre le rendu à la zone de contenu (bornes
    -- en pixels ÉCRAN, voir SCALE -- love.graphics.setScissor ignore les
    -- transformations ambiantes, contrairement à tout le reste de ce fichier)
    -- -- sans ça, les cartes qui débordent en haut/bas de `area_h` resteraient
    -- visibles par-dessus le titre/le bouton "Fermer". Le rect est désactivé
    -- PENDANT le rendu de chaque carte dans le canvas réutilisé ci-dessous,
    -- PUIS réactivé pour la recomposer à l'écran.
    local scissor_x, scissor_y = layout.area_x * SCALE, layout.area_y * SCALE
    local scissor_w, scissor_h = layout.area_w * SCALE, layout.area_h * SCALE
    love.graphics.setScissor(scissor_x, scissor_y, scissor_w, scissor_h)

    UI.card_flight_canvas = UI.card_flight_canvas or love.graphics.newCanvas(UI.CARD_W, UI.CARD_H)
    for i, entry in ipairs(cards) do
      local col = (i - 1) % layout.cols
      local row = math.floor((i - 1) / layout.cols)
      local cx = layout.ox + col * layout.cell_w
      local cy = oy + row * layout.cell_h

      love.graphics.setScissor()
      love.graphics.push()
      love.graphics.origin()
      local prev_canvas = love.graphics.getCanvas()
      love.graphics.setCanvas(UI.card_flight_canvas)
      love.graphics.clear(0, 0, 0, 0)
      CardUI.draw_card_face(entry.def, UI.CARD_W, UI.CARD_H, tostring(entry.def.cost or 0), entry.def.desc, Theme.muted, false, false, false, false)
      love.graphics.setCanvas(prev_canvas)
      love.graphics.pop()
      love.graphics.setScissor(scissor_x, scissor_y, scissor_w, scissor_h)
      love.graphics.setColor(1, 1, 1, 1)
      love.graphics.draw(UI.card_flight_canvas, cx, cy, 0, layout.card_w / UI.CARD_W, layout.card_h / UI.CARD_H)
    end
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setScissor()

    -- Ascenseur (2026-08-30, demande explicite -- "prévoir un ascenseur s'il y
    -- a trop de cartes") : simple indicateur (molette pour défiler) -- track +
    -- curseur proportionné à la part visible du contenu total, jamais affiché
    -- quand tout tient déjà à l'écran.
    if layout.max_scroll > 0 then
      local track_x = layout.area_x + layout.area_w - DECK_VIEW_SCROLLBAR_W
      UI.set(Theme.panel_light)
      love.graphics.rectangle("fill", track_x, layout.area_y, DECK_VIEW_SCROLLBAR_W, layout.area_h, 4, 4)
      local thumb_h = math.max(24, layout.area_h * layout.area_h / layout.content_h)
      local thumb_y = layout.area_y + (layout.area_h - thumb_h) * (scroll / layout.max_scroll)
      UI.set(Theme.accent)
      love.graphics.rectangle("fill", track_x, thumb_y, DECK_VIEW_SCROLLBAR_W, thumb_h, 4, 4)
    end
  end
  View.draw_deck_view = draw_deck_view
end
