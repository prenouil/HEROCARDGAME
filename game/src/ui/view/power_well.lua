-- Fenêtre PARTAGÉE "Choisis un pouvoir à oublier à jamais" (2026-10-03,
-- "Le Puit de l'Oubli" ET "Prédiction de la Mort" -- "Sacrifier un pouvoir à
-- la place", demande explicite -- "cela affiche la même fenêtre avec le même
-- mécanisme") : overlay par-dessus l'écran "puits" OU "prediction", même
-- schéma que view/deck_view.lua/view/debug_card_picker.lua (panneau fixe,
-- grille de cartes, ascenseur) -- liste `Game.all_owned_card_instances`
-- (deck + main + défausse, SANS filtre -- n'importe quelle carte possédée
-- peut être oubliée) plutôt que Cards.list (debug_card_picker) ou une
-- source/écran (deck_view) -- fichier séparé plutôt que d'étendre l'un des
-- deux, même raisonnement qu'eux : besoin différent, formule de mise en page
-- dupliquée plutôt que partagée (voir leurs propres commentaires).
local Theme = require("src.ui.theme")
local Game = require("src.rules.game")
local SCALE = require("src.ui.layout_scale")
local CardUI = require("src.ui.view.cards")

return function(View, UI)
  View.power_well_panel_rect = { x = 40, y = 40, w = UI.W - 80, h = UI.H - 80 }
  View.power_well_back_button = {
    x = View.power_well_panel_rect.x + View.power_well_panel_rect.w - 90,
    y = View.power_well_panel_rect.y + 10, w = 80, h = 26, label = "Retour",
  }

  -- Centre de l'écran, où la carte choisie zoome avant d'éclater (2026-10-03,
  -- demande explicite -- "la carte se zoom lentement, puis se craquèle et
  -- explose en pixel") : 2.2x la taille canonique, assez grand pour qu'on
  -- voie bien la carte avant qu'elle n'éclate, voir Controller:
  -- choose_power_well_card/spawn_card_shatter, seuls lecteurs.
  local CENTER_SCALE = 2.2
  function View.power_well_center_rect()
    local w, h = UI.CARD_W * CENTER_SCALE, UI.CARD_H * CENTER_SCALE
    return { x = (UI.W - w) / 2, y = (UI.H - h) / 2, w = w, h = h }
  end

  -- Même formule que View.debug_card_picker_layout (voir son commentaire) --
  -- dupliquée, pas partagée : la source de la liste diffère (toutes les
  -- cartes possédées, pas tout Cards.list), et ce fichier n'a aucune
  -- dépendance vers debug_card_picker.lua.
  local POWER_WELL_GAP = 10
  local POWER_WELL_LABEL_H = 14
  local POWER_WELL_CARD_W = 78
  local POWER_WELL_SCROLLBAR_W = 10
  function View.power_well_layout(controller)
    local cards = Game.all_owned_card_instances(controller.state)
    local p = View.power_well_panel_rect
    local area_x, area_y = p.x + 20, p.y + 56
    local area_w, area_h = p.w - 40, p.h - 76

    local aspect = UI.CARD_H / UI.CARD_W
    local card_w = POWER_WELL_CARD_W
    local card_h = card_w * aspect
    local cell_w, cell_h = card_w + POWER_WELL_GAP, card_h + POWER_WELL_LABEL_H + POWER_WELL_GAP

    local function compute(usable_w)
      local cols = math.max(1, math.floor(usable_w / cell_w))
      local rows = #cards > 0 and math.ceil(#cards / cols) or 0
      return cols, rows, rows * cell_h
    end

    local cols, rows, content_h = compute(area_w)
    local max_scroll = math.max(0, content_h - area_h)
    if max_scroll > 0 then
      cols, rows, content_h = compute(area_w - POWER_WELL_SCROLLBAR_W - 6)
      max_scroll = math.max(0, content_h - area_h)
    end

    local grid_w = cols * cell_w
    local ox = area_x + (area_w - (max_scroll > 0 and POWER_WELL_SCROLLBAR_W + 6 or 0) - grid_w) / 2

    return {
      cards = cards, cols = cols, rows = rows, card_w = card_w, card_h = card_h,
      cell_w = cell_w, cell_h = cell_h, area_x = area_x, area_y = area_y,
      area_w = area_w, area_h = area_h, ox = ox, content_h = content_h, max_scroll = max_scroll,
    }
  end

  --- Rect ÉCRAN de la carte à l'index `index` de la grille courante
  -- (2026-10-03) : même calcul que le rendu ci-dessous -- seul point de
  -- vérité pour le hit-testing (Input.lua), jamais un second calcul qui
  -- pourrait diverger.
  function View.power_well_rect_at(controller, index, scroll)
    local layout = View.power_well_layout(controller)
    local col = (index - 1) % layout.cols
    local row = math.floor((index - 1) / layout.cols)
    return {
      x = layout.ox + col * layout.cell_w,
      y = layout.area_y - scroll + row * layout.cell_h,
      w = layout.card_w, h = layout.card_h,
    }
  end

  --- Dessine `def` à une taille/position arbitraire (2026-10-03, zoom de
  -- l'éclatement) : contrairement à CardUI.draw_faded_card (toujours à sa
  -- taille canonique CARD_W/CARD_H), celle-ci passe par un simple push/
  -- translate/scale -- pas besoin du détour par canvas de draw_faded_card
  -- (pensé pour un fondu uniforme, pas une mise à l'échelle) puisque cette
  -- carte reste à pleine opacité pendant tout le zoom.
  local function draw_card_at(def, cx, cy, w, h)
    local scale = w / UI.CARD_W
    love.graphics.push()
    love.graphics.translate(cx - w / 2, cy - h / 2)
    love.graphics.scale(scale, scale)
    CardUI.draw_card_face(def, UI.CARD_W, UI.CARD_H, tostring(def.cost or 0), def.desc, Theme.muted, false, false, false, false)
    love.graphics.pop()
  end

  local function draw_power_well(controller)
    local pw = controller.power_well
    if not pw then return end
    UI.set(Theme.black, 0.75); love.graphics.rectangle("fill", 0, 0, UI.W, UI.H)

    local p = View.power_well_panel_rect
    UI.panel(p.x, p.y, p.w, p.h, Theme.panel)
    UI.set(Theme.accent); love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", p.x, p.y, p.w, p.h, 10, 10)
    love.graphics.setLineWidth(1)
    UI.text("Choisis un pouvoir à oublier à jamais", p.x + 20, p.y + 16, p.w - 130, 18, Theme.text, "left")

    if not pw.anim then
      local cb = View.power_well_back_button
      UI.set(Theme.panel_light); love.graphics.rectangle("fill", cb.x, cb.y, cb.w, cb.h, 8, 8)
      UI.set(Theme.muted); love.graphics.setLineWidth(2)
      love.graphics.rectangle("line", cb.x, cb.y, cb.w, cb.h, 8, 8)
      love.graphics.setLineWidth(1)
      UI.text(cb.label, cb.x, cb.y + 6, cb.w, 14, Theme.text, "center")
    end

    local layout = View.power_well_layout(controller)
    local scroll = math.max(0, math.min(layout.max_scroll, pw.scroll or 0))
    local oy = layout.area_y - scroll

    local scissor_x, scissor_y = layout.area_x * SCALE, layout.area_y * SCALE
    local scissor_w, scissor_h = layout.area_w * SCALE, layout.area_h * SCALE
    love.graphics.setScissor(scissor_x, scissor_y, scissor_w, scissor_h)

    UI.card_flight_canvas = UI.card_flight_canvas or love.graphics.newCanvas(UI.CARD_W, UI.CARD_H)
    for i, c in ipairs(layout.cards) do
      -- La carte en cours de zoom/éclatement disparaît de la grille --
      -- redessinée à part, par-dessus tout, voir plus bas.
      if not (pw.anim and pw.anim.uid == c.uid) then
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
        CardUI.draw_card_face(c.def, UI.CARD_W, UI.CARD_H, tostring(c.def.cost or 0), c.def.desc, Theme.muted, false, false, false, false)
        love.graphics.setCanvas(prev_canvas)
        love.graphics.pop()
        love.graphics.setScissor(scissor_x, scissor_y, scissor_w, scissor_h)
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(UI.card_flight_canvas, cx, cy, 0, layout.card_w / UI.CARD_W, layout.card_h / UI.CARD_H)
      end
    end
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setScissor()

    if layout.max_scroll > 0 then
      local track_x = layout.area_x + layout.area_w - POWER_WELL_SCROLLBAR_W
      UI.set(Theme.panel_light)
      love.graphics.rectangle("fill", track_x, layout.area_y, POWER_WELL_SCROLLBAR_W, layout.area_h, 4, 4)
      local thumb_h = math.max(24, layout.area_h * layout.area_h / layout.content_h)
      local thumb_y = layout.area_y + (layout.area_h - thumb_h) * (scroll / layout.max_scroll)
      UI.set(Theme.accent)
      love.graphics.rectangle("fill", track_x, thumb_y, POWER_WELL_SCROLLBAR_W, thumb_h, 4, 4)
    end

    -- Zoom puis éclatement (2026-10-03, demande explicite) : phase "zoom" --
    -- interpole de sa case d'origine (figée au clic, `anim.from`) jusqu'au
    -- centre de l'écran, pleine opacité, ease-out ("lentement" en fin de
    -- course) ; phase "shatter" -- la carte elle-même disparaît, remplacée
    -- par les fragments de Controller:spawn_card_shatter (particules
    -- génériques, voir View.draw_particles, combat.lua).
    if pw.anim then
      if pw.anim.phase == "zoom" then
        local duration = controller.power_well_zoom_duration or 1
        local p2 = math.min(1, pw.anim.t / duration)
        local ease = 1 - (1 - p2) ^ 2
        local to = View.power_well_center_rect()
        local from = pw.anim.from
        local cx = from.x + from.w / 2 + (to.x + to.w / 2 - (from.x + from.w / 2)) * ease
        local cy = from.y + from.h / 2 + (to.y + to.h / 2 - (from.y + from.h / 2)) * ease
        local w = from.w + (to.w - from.w) * ease
        local h = from.h + (to.h - from.h) * ease
        draw_card_at(pw.anim.def, cx, cy, w, h)
      end
      View.draw_particles(controller)
    end
  end
  View.draw_power_well = draw_power_well
end
