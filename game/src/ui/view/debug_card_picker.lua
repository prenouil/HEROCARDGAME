-- Sélecteur de test "toutes les cartes" (2026-10-01, demande explicite --
-- "dans la fenêtre de draft, j'aimerais un bouton supplémentaire discret,
-- pour mes tests, qui me permet d'afficher toutes les cartes du jeu et de
-- choisir celle que je veux ajouter à mon deck") : overlay dédié, ouvert
-- UNIQUEMENT depuis la fenêtre de draft (voir le bouton discret posé par
-- view/victory.lua et Controller:open_debug_card_picker). Même schéma visuel
-- que view/deck_view.lua (panneau fixe, grille de cartes, ascenseur) --
-- fichier séparé plutôt que d'étendre deck_view.lua : celui-ci liste des
-- cartes POSSÉDÉES (main/pioche/défausse), lecture seule ; celui-ci liste TOUT
-- Cards.list (y compris les cartes normalement jamais draftables, un outil de
-- test n'a pas à respecter cette règle) et chaque carte est CLIQUABLE pour
-- l'ajouter au deck.
local Theme = require("src.ui.theme")
local Cards = require("src.data.cards")
local SCALE = require("src.ui.layout_scale")
local CardUI = require("src.ui.view.cards")

return function(View, UI)
  View.debug_card_picker_panel_rect = { x = 40, y = 40, w = UI.W - 80, h = UI.H - 80 }
  View.debug_card_picker_close_button = {
    x = View.debug_card_picker_panel_rect.x + View.debug_card_picker_panel_rect.w - 90,
    y = View.debug_card_picker_panel_rect.y + 10, w = 80, h = 26, label = "Fermer",
  }

  -- Liste STATIQUE (2026-10-01) : Cards.list ne change jamais en cours de
  -- partie, triée par classe puis nom pour un ordre stable -- même tri que
  -- View.deck_view_cards, aucun besoin de la recalculer par frame à partir de
  -- controller (contrairement à deck_view, dont le contenu dépend de
  -- l'écran/de la source affichée).
  local sorted_defs
  function View.debug_card_picker_cards()
    if not sorted_defs then
      sorted_defs = {}
      for _, def in ipairs(Cards.list) do sorted_defs[#sorted_defs + 1] = def end
      table.sort(sorted_defs, function(a, b)
        if a.class_id ~= b.class_id then return a.class_id < b.class_id end
        if a.name ~= b.name then return a.name < b.name end
        return false
      end)
    end
    return sorted_defs
  end

  -- Même formule de mise en page que View.deck_view_layout (voir son
  -- commentaire) -- dupliquée plutôt que partagée : ce fichier n'a aucune
  -- dépendance vers deck_view.lua (et réciproquement), chacun son propre
  -- budget de locales de chunk.
  local DEBUG_PICKER_GAP = 10
  local DEBUG_PICKER_LABEL_H = 14
  local DEBUG_PICKER_CARD_W = 78
  local DEBUG_PICKER_SCROLLBAR_W = 10
  function View.debug_card_picker_layout()
    local cards = View.debug_card_picker_cards()
    local p = View.debug_card_picker_panel_rect
    local area_x, area_y = p.x + 20, p.y + 56
    local area_w, area_h = p.w - 40, p.h - 76

    local aspect = UI.CARD_H / UI.CARD_W
    local card_w = DEBUG_PICKER_CARD_W
    local card_h = card_w * aspect
    local cell_w, cell_h = card_w + DEBUG_PICKER_GAP, card_h + DEBUG_PICKER_LABEL_H + DEBUG_PICKER_GAP

    local function compute(usable_w)
      local cols = math.max(1, math.floor(usable_w / cell_w))
      local rows = #cards > 0 and math.ceil(#cards / cols) or 0
      return cols, rows, rows * cell_h
    end

    local cols, rows, content_h = compute(area_w)
    local max_scroll = math.max(0, content_h - area_h)
    if max_scroll > 0 then
      cols, rows, content_h = compute(area_w - DEBUG_PICKER_SCROLLBAR_W - 6)
      max_scroll = math.max(0, content_h - area_h)
    end

    local grid_w = cols * cell_w
    local ox = area_x + (area_w - (max_scroll > 0 and DEBUG_PICKER_SCROLLBAR_W + 6 or 0) - grid_w) / 2

    return {
      cards = cards, cols = cols, rows = rows, card_w = card_w, card_h = card_h,
      cell_w = cell_w, cell_h = cell_h, area_x = area_x, area_y = area_y,
      area_w = area_w, area_h = area_h, ox = ox, content_h = content_h, max_scroll = max_scroll,
    }
  end

  --- Rect ÉCRAN de la carte à l'index `index` de la grille courante (2026-10-01) :
  -- même calcul que le rendu ci-dessous -- seul point de vérité pour le
  -- hit-testing (Input.lua), jamais un second calcul qui pourrait diverger.
  function View.debug_card_picker_rect_at(index, scroll)
    local layout = View.debug_card_picker_layout()
    local col = (index - 1) % layout.cols
    local row = math.floor((index - 1) / layout.cols)
    return {
      x = layout.ox + col * layout.cell_w,
      y = layout.area_y - scroll + row * layout.cell_h,
      w = layout.card_w, h = layout.card_h,
    }
  end

  local function draw_debug_card_picker(controller)
    local dcp = controller.debug_card_picker
    if not dcp then return end
    UI.set(Theme.black, 0.75); love.graphics.rectangle("fill", 0, 0, UI.W, UI.H)

    local p = View.debug_card_picker_panel_rect
    UI.panel(p.x, p.y, p.w, p.h, Theme.panel)
    UI.set(Theme.accent); love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", p.x, p.y, p.w, p.h, 10, 10)
    love.graphics.setLineWidth(1)

    local cards = View.debug_card_picker_cards()
    UI.text("[Debug] Ajouter une carte au deck (" .. #cards .. ")", p.x + 20, p.y + 16, p.w - 130, 18, Theme.text, "left")

    local cb = View.debug_card_picker_close_button
    UI.set(Theme.panel_light); love.graphics.rectangle("fill", cb.x, cb.y, cb.w, cb.h, 8, 8)
    UI.set(Theme.muted); love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", cb.x, cb.y, cb.w, cb.h, 8, 8)
    love.graphics.setLineWidth(1)
    UI.text(cb.label, cb.x, cb.y + 6, cb.w, 14, Theme.text, "center")

    local layout = View.debug_card_picker_layout()
    local scroll = math.max(0, math.min(layout.max_scroll, dcp.scroll or 0))
    local oy = layout.area_y - scroll

    local scissor_x, scissor_y = layout.area_x * SCALE, layout.area_y * SCALE
    local scissor_w, scissor_h = layout.area_w * SCALE, layout.area_h * SCALE
    love.graphics.setScissor(scissor_x, scissor_y, scissor_w, scissor_h)

    UI.card_flight_canvas = UI.card_flight_canvas or love.graphics.newCanvas(UI.CARD_W, UI.CARD_H)
    for i, def in ipairs(cards) do
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
      CardUI.draw_card_face(def, UI.CARD_W, UI.CARD_H, tostring(def.cost or 0), def.desc, Theme.muted, false, false, false, false)
      love.graphics.setCanvas(prev_canvas)
      love.graphics.pop()
      love.graphics.setScissor(scissor_x, scissor_y, scissor_w, scissor_h)
      love.graphics.setColor(1, 1, 1, 1)
      love.graphics.draw(UI.card_flight_canvas, cx, cy, 0, layout.card_w / UI.CARD_W, layout.card_h / UI.CARD_H)
    end
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setScissor()

    if layout.max_scroll > 0 then
      local track_x = layout.area_x + layout.area_w - DEBUG_PICKER_SCROLLBAR_W
      UI.set(Theme.panel_light)
      love.graphics.rectangle("fill", track_x, layout.area_y, DEBUG_PICKER_SCROLLBAR_W, layout.area_h, 4, 4)
      local thumb_h = math.max(24, layout.area_h * layout.area_h / layout.content_h)
      local thumb_y = layout.area_y + (layout.area_h - thumb_h) * (scroll / layout.max_scroll)
      UI.set(Theme.accent)
      love.graphics.rectangle("fill", track_x, thumb_y, DEBUG_PICKER_SCROLLBAR_W, thumb_h, 4, 4)
    end
  end
  View.draw_debug_card_picker = draw_debug_card_picker
end
