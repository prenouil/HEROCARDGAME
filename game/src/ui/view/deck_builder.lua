-- Écran "Construis ton deck" (Run Solo) (2026-09-25, extrait de l'ex-
-- monolithe view.lua -- voir src/ui/view/init.lua pour le contexte).
local Theme = require("src.ui.theme")
local Background = require("src.ui.background")
local Heroes = require("src.data.heroes")
local SCALE = require("src.ui.layout_scale")
local CardUI = require("src.ui.view.cards")

return function(View, UI)
  -- Écran "Construis ton deck" ("Run Solo", 2026-09-02, demande explicite) :
  -- panneau du haut = toutes les cartes de l'aventurier choisi (Cards.list
  -- filtrée par class_id, voir Controller:enter_deck_builder), panneau du bas
  -- = le deck en construction -- CHACUN son défilement indépendant (molette,
  -- voir Controller:scroll_deck_builder), même geste que View.deck_view_layout
  -- (fenêtre "voir le deck") mais dupliqué en 2 zones distinctes plutôt que
  -- factorisé en un module à part -- la mise en page (colonnes/ascenseur) reste
  -- identique, seules les données diffèrent.
  View.deck_builder_top_panel_rect = { x = 40, y = 50, w = UI.W - 80, h = 260 }
  View.deck_builder_bottom_panel_rect = { x = 40, y = 330, w = UI.W - 80, h = 250 }
  View.deck_builder_back_button = { x = 40, y = 630, w = 180, h = 60, label = "Retour" }
  View.deck_builder_test_button = { x = UI.W - 240, y = 630, w = 200, h = 60, label = "Tester" }
  View.DECK_BUILDER_MIN_CARDS = 12

  -- Consolidée en un champ de View plutôt qu'un local de haut niveau
  -- (héritage de l'ex-monolithe, où la limite des 200 locaux par chunk était
  -- serrée -- non pertinente dans ce fichier séparé, gardé par cohérence avec
  -- le code existant) : `View` est une table déjà existante, lui ajouter des
  -- champs ne coûte aucun local supplémentaire.
  do
    local GAP, LABEL_H, CARD_W_REF, SCROLLBAR_W = 10, 14, 78, 10
    View._deck_builder_fx = { SCROLLBAR_W = SCROLLBAR_W }

    -- Même formule que View.deck_view_layout (deck_view.lua) : carte à taille
    -- FIXE, colonnes adaptées à la largeur, défilement vertical si le contenu
    -- déborde -- dupliquée ici plutôt que réutilisée telle quelle
    -- (`View.deck_view_panel_rect` est un rect UNIQUE, pas paramétrable par zone).
    local function layout(panel_rect, count)
      local area_x, area_y = panel_rect.x + 10, panel_rect.y + 28
      local area_w, area_h = panel_rect.w - 20, panel_rect.h - 38
      local aspect = UI.CARD_H / UI.CARD_W
      local card_w = CARD_W_REF
      local card_h = card_w * aspect
      local cell_w, cell_h = card_w + GAP, card_h + LABEL_H + GAP
      local function compute(usable_w)
        local cols = math.max(1, math.floor(usable_w / cell_w))
        local rows = count > 0 and math.ceil(count / cols) or 0
        return cols, rows, rows * cell_h
      end
      local cols, rows, content_h = compute(area_w)
      local max_scroll = math.max(0, content_h - area_h)
      if max_scroll > 0 then
        cols, rows, content_h = compute(area_w - SCROLLBAR_W - 6)
        max_scroll = math.max(0, content_h - area_h)
      end
      local grid_w = cols * cell_w
      local ox = area_x + (area_w - (max_scroll > 0 and SCROLLBAR_W + 6 or 0) - grid_w) / 2
      return {
        cols = cols, rows = rows, card_w = card_w, card_h = card_h, cell_w = cell_w, cell_h = cell_h,
        area_x = area_x, area_y = area_y, area_w = area_w, area_h = area_h, ox = ox,
        content_h = content_h, max_scroll = max_scroll,
      }
    end
    View._deck_builder_fx.layout = layout
  end

  function View.deck_builder_top_layout(controller)
    local db = controller.deck_builder
    return View._deck_builder_fx.layout(View.deck_builder_top_panel_rect, db and #db.top_defs or 0)
  end

  function View.deck_builder_bottom_layout(controller)
    local db = controller.deck_builder
    return View._deck_builder_fx.layout(View.deck_builder_bottom_panel_rect, db and #db.bottom_cards or 0)
  end

  -- Rect ÉCRAN d'une carte à `index` (1-based), défilement déjà appliqué --
  -- réutilisée à la fois par le rendu et par Controller:deck_builder_add/
  -- remove (positions de départ/arrivée des vols de carte).
  function View.deck_builder_rect_at(layout, scroll, index)
    local col = (index - 1) % layout.cols
    local row = math.floor((index - 1) / layout.cols)
    return {
      x = layout.ox + col * layout.cell_w, y = layout.area_y - scroll + row * layout.cell_h,
      w = layout.card_w, h = layout.card_h,
    }
  end

  -- Index (1-based) de la carte sous (x, y), ou nil -- hors zone visible
  -- (scissor) ou hors grille (au-delà de `count`, ou dans un interstice entre
  -- 2 cartes). `scroll` DÉJÀ borné par l'appelant (Input.lua).
  function View.deck_builder_hit(layout, scroll, count, x, y)
    if x < layout.area_x or x > layout.area_x + layout.area_w then return nil end
    if y < layout.area_y or y > layout.area_y + layout.area_h then return nil end
    local rel_x, rel_y = x - layout.ox, y - (layout.area_y - scroll)
    if rel_x < 0 or rel_y < 0 then return nil end
    local col = math.floor(rel_x / layout.cell_w)
    local row = math.floor(rel_y / layout.cell_h)
    if col < 0 or col >= layout.cols then return nil end
    if (rel_x - col * layout.cell_w) > layout.card_w then return nil end
    if (rel_y - row * layout.cell_h) > layout.card_h then return nil end
    local index = row * layout.cols + col + 1
    if index < 1 or index > count then return nil end
    return index
  end

  -- Suite de View._deck_builder_fx : rendu de l'écran, consolidé dans le même
  -- champ (`View._deck_builder_fx.draw`) par cohérence avec le code d'origine.
  do
    -- Ascenseur générique (extrait de draw_deck_view) : réutilisable par les 2
    -- panneaux indépendants, juste paramétré par `layout`/`scroll`/`track_x`.
    local function draw_scrollbar(layout, scroll, track_x)
      if layout.max_scroll <= 0 then return end
      UI.set(Theme.panel_light)
      love.graphics.rectangle("fill", track_x, layout.area_y, View._deck_builder_fx.SCROLLBAR_W, layout.area_h, 4, 4)
      local thumb_h = math.max(24, layout.area_h * layout.area_h / layout.content_h)
      local thumb_y = layout.area_y + (layout.area_h - thumb_h) * (scroll / layout.max_scroll)
      UI.set(Theme.accent)
      love.graphics.rectangle("fill", track_x, thumb_y, View._deck_builder_fx.SCROLLBAR_W, thumb_h, 4, 4)
    end

    -- Une carte de la grille, recadrée au panneau (scissor, coordonnées ÉCRAN --
    -- voir SCALE) et rendue via le canvas partagé (même idiome que
    -- draw_deck_view, seul moyen d'appliquer un fondu d'alpha uniforme sur tout
    -- le dessin de la carte -- `alpha` sert aux cartes en train de s'évanouir).
    local function draw_card(def, rect, scissor_x, scissor_y, scissor_w, scissor_h, alpha)
      love.graphics.setScissor()
      love.graphics.push()
      love.graphics.origin()
      local prev_canvas = love.graphics.getCanvas()
      UI.card_flight_canvas = UI.card_flight_canvas or love.graphics.newCanvas(UI.CARD_W, UI.CARD_H)
      love.graphics.setCanvas(UI.card_flight_canvas)
      love.graphics.clear(0, 0, 0, 0)
      CardUI.draw_card_face(def, UI.CARD_W, UI.CARD_H, def.cost, def.desc, Theme.muted, false)
      love.graphics.setCanvas(prev_canvas)
      love.graphics.pop()
      love.graphics.setScissor(scissor_x, scissor_y, scissor_w, scissor_h)
      love.graphics.setColor(1, 1, 1, alpha or 1)
      love.graphics.draw(UI.card_flight_canvas, rect.x, rect.y, 0, rect.w / UI.CARD_W, rect.h / UI.CARD_H)
      love.graphics.setColor(1, 1, 1, 1)
    end

    -- Écran "Construis ton deck" ("Run Solo", 2026-09-02, demande explicite) :
    -- panneau du haut (toutes les cartes de l'aventurier, cliquer = en ajouter
    -- une copie en bas) et panneau du bas (le deck en construction, cliquer =
    -- la retirer -- clic DROIT = bascule base/améliorée, voir
    -- Input.mousepressed). `db.reflow_from`/`reflow_t` : capturés par
    -- Controller:deck_builder_remove juste avant de retirer une carte --
    -- pendant `reflow_duration`, les cartes RESTANTES glissent depuis leur
    -- ANCIENNE position vers leur nouvelle. `db.fading_cards` : la carte
    -- retirée elle-même, qui s'évanouit sur place (alpha 1 -> 0).
    local function draw(controller)
      local db = controller.deck_builder
      if not db then return end
      Background.draw(nil, UI.W, UI.H)
      UI.text("Construis ton deck", 0, 14, UI.W, 22, Theme.text)

      local top_layout = View.deck_builder_top_layout(controller)
      local bottom_layout = View.deck_builder_bottom_layout(controller)
      local top_scroll = math.max(0, math.min(top_layout.max_scroll, db.top_scroll or 0))
      local bottom_scroll = math.max(0, math.min(bottom_layout.max_scroll, db.bottom_scroll or 0))

      local tp = View.deck_builder_top_panel_rect
      UI.text(Heroes.class_name[db.hero_id] .. " -- clique pour ajouter une copie en bas.", tp.x, tp.y - 4, tp.w, 12, Theme.muted, "left")
      local top_scissor_x, top_scissor_y = top_layout.area_x * SCALE, top_layout.area_y * SCALE
      local top_scissor_w, top_scissor_h = top_layout.area_w * SCALE, top_layout.area_h * SCALE
      love.graphics.setScissor(top_scissor_x, top_scissor_y, top_scissor_w, top_scissor_h)
      for i, def in ipairs(db.top_defs) do
        local rect = View.deck_builder_rect_at(top_layout, top_scroll, i)
        draw_card(def, rect, top_scissor_x, top_scissor_y, top_scissor_w, top_scissor_h, 1)
      end
      love.graphics.setScissor()
      draw_scrollbar(top_layout, top_scroll, top_layout.area_x + top_layout.area_w - View._deck_builder_fx.SCROLLBAR_W)

      local bp = View.deck_builder_bottom_panel_rect
      UI.text("Ton deck (" .. #db.bottom_cards .. " -- " .. View.DECK_BUILDER_MIN_CARDS .. " minimum) -- clique pour retirer, clic droit pour améliorer/rétrograder.",
        bp.x, bp.y - 4, bp.w, 12, Theme.muted, "left")
      local bot_scissor_x, bot_scissor_y = bottom_layout.area_x * SCALE, bottom_layout.area_y * SCALE
      local bot_scissor_w, bot_scissor_h = bottom_layout.area_w * SCALE, bottom_layout.area_h * SCALE
      love.graphics.setScissor(bot_scissor_x, bot_scissor_y, bot_scissor_w, bot_scissor_h)
      local reflow_p = 1
      if db.reflow_t and db.reflow_duration and db.reflow_t < db.reflow_duration then
        reflow_p = db.reflow_t / db.reflow_duration
      end
      for i, entry in ipairs(db.bottom_cards) do
        local target = View.deck_builder_rect_at(bottom_layout, bottom_scroll, i)
        local rect = target
        local from = db.reflow_from and db.reflow_from[entry.uid]
        if from and reflow_p < 1 then
          rect = {
            x = from.x + (target.x - from.x) * reflow_p, y = from.y + (target.y - from.y) * reflow_p,
            w = target.w, h = target.h,
          }
        end
        draw_card(entry.def, rect, bot_scissor_x, bot_scissor_y, bot_scissor_w, bot_scissor_h, 1)
      end
      for _, f in ipairs(db.fading_cards) do
        local p = math.min(1, f.t / f.duration)
        draw_card(f.def, f.rect, bot_scissor_x, bot_scissor_y, bot_scissor_w, bot_scissor_h, 1 - p)
      end
      love.graphics.setScissor()
      draw_scrollbar(bottom_layout, bottom_scroll, bottom_layout.area_x + bottom_layout.area_w - View._deck_builder_fx.SCROLLBAR_W)

      UI.draw_menu_style_button(View.deck_builder_back_button)
      local ready = #db.bottom_cards >= View.DECK_BUILDER_MIN_CARDS
      local tb = View.deck_builder_test_button
      if ready then
        local pulse = 0.5 + 0.5 * math.sin(love.timer.getTime() * 4)
        UI.set(Theme.accent, 0.35 + 0.35 * pulse)
        love.graphics.rectangle("fill", tb.x - 5, tb.y - 5, tb.w + 10, tb.h + 10, 12, 12)
      end
      UI.set(ready and Theme.heal or Theme.panel_light)
      love.graphics.rectangle("fill", tb.x, tb.y, tb.w, tb.h, 10, 10)
      UI.set(ready and Theme.accent or Theme.muted); love.graphics.setLineWidth(3)
      love.graphics.rectangle("line", tb.x, tb.y, tb.w, tb.h, 10, 10)
      love.graphics.setLineWidth(1)
      UI.text(tb.label, tb.x, tb.y + tb.h / 2 - 12, tb.w, 24, ready and Theme.bg or Theme.muted, "center")
    end

    View._deck_builder_fx.draw = draw
  end
end
