-- Écran "Prédiction de la Mort" (2026-10-03, demande explicite -- "on
-- présente les 4 aventuriers comme pour les temples. Au-dessus d'eux, à la
-- place des temples, on présente les cartes de mise à mort") : réutilise
-- View.temple_hero_rects (temple.lua, générique -- ne lit que
-- controller.state.heroes, jamais controller.temple) pour la rangée de 4
-- aventuriers, EXACTEMENT la même disposition que Le Temple. Au-dessus de
-- chaque héros, sa carte "Mise à mort" si elle est éligible (voir
-- Prediction.eligible_cards), sinon une carte de dos non interactive -- pour
-- un héros déjà mort OU dont la carte est déjà prise ("remplacé par une
-- carte de dos non interactive dans les 2 cas", demande explicite).
local Theme = require("src.ui.theme")
local CardUI = require("src.ui.view.cards")

return function(View, UI)
  -- Au-dessus de TEMPLE_HERO_Y (320, voir temple.lua) : même esprit que
  -- TEMPLE_EFFECT_Y (statues), mais une carte entière (184 de haut) a besoin
  -- de plus de place qu'une statue (150) -- 90 plutôt que 120 pour garder un
  -- peu d'air avant la rangée de héros.
  local PREDICTION_CARD_Y = 90

  --- Un rect PAR héros (même ordre que View.temple_hero_rects), centré sur
  -- la case de CE héros -- pas une rangée indépendante : la carte "Mise à
  -- mort" d'un aventurier doit rester directement au-dessus de lui.
  function View.prediction_card_rects(controller)
    local hero_rects = View.temple_hero_rects(controller)
    local out = {}
    for _, h in ipairs(controller.state.heroes) do
      local hr = hero_rects[h.id]
      out[h.id] = { x = hr.x + (hr.w - UI.CARD_W) / 2, y = PREDICTION_CARD_Y, w = UI.CARD_W, h = UI.CARD_H }
    end
    return out
  end

  View.prediction_sacrifice_button = {
    x = UI.W / 2 - 120, y = 320 + 198 + 20, w = 240, h = 40, label = "Sacrifier un pouvoir à la place",
  }

  --- Carte de dos simple, non interactive (2026-10-03) : héros déjà mort OU
  -- carte "Mise à mort" déjà prise -- aucune couleur de classe ni compteur
  -- (contrairement à l'ancienne carte de dos "cartes Avancées" de l'écran de
  -- choix d'équipe, retirée le 2026-10-03 -- besoin différent, pas de valeur
  -- à afficher ici, juste "rien à choisir là").
  local function draw_prediction_card_back(x, y, alpha)
    alpha = alpha or 1
    UI.panel(x, y, UI.CARD_W, UI.CARD_H, Theme.panel, alpha)
    UI.set(Theme.muted, alpha); love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", x, y, UI.CARD_W, UI.CARD_H, 10, 10)
    love.graphics.setLineWidth(1)
    UI.set(Theme.muted, alpha * 0.4)
    for i = -3, 3 do
      love.graphics.line(x + UI.CARD_W / 2 + i * 12, y + 8, x + UI.CARD_W / 2 + i * 12 + 26, y + UI.CARD_H - 8)
      love.graphics.line(x + UI.CARD_W / 2 + i * 12 + 26, y + 8, x + UI.CARD_W / 2 + i * 12, y + UI.CARD_H - 8)
    end
  end

  local function draw_prediction(controller)
    local p = controller.prediction
    UI.set(Theme.black, 0.75); love.graphics.rectangle("fill", 0, 0, UI.W, UI.H)
    UI.draw_camp_entrance(controller, "Prédiction de la Mort", 26, function()

    local anim = controller.prediction_choice_anim
    local duration = controller.prediction_choice_anim_duration or 1
    local card_rects = View.prediction_card_rects(controller)
    local hero_rects = View.temple_hero_rects(controller)

    if anim then
      local def = p.eligible[anim.chosen_hero_id]
      UI.text((def and def.name or "?") .. " ajoutée au deck !", 0, PREDICTION_CARD_Y + UI.CARD_H + 14, UI.W, 13, Theme.accent)
    else
      UI.text("Choisis le prochain à se sacrifier, ou renonce à un pouvoir à la place.",
        0, PREDICTION_CARD_Y + UI.CARD_H + 14, UI.W, 12, Theme.muted)
    end

    for _, h in ipairs(controller.state.heroes) do
      local hr = hero_rects[h.id]
      local cr = card_rects[h.id]
      local def = p.eligible[h.id]
      local selected = anim and anim.chosen_hero_id == h.id
      local alpha = 1
      if anim and not selected then
        alpha = 1 - math.min(1, anim.t / duration)
      end
      if alpha > 0 then
        -- Carte "Mise à mort" si éligible, sinon dos non interactif (héros
        -- mort OU carte déjà prise -- "dans les 2 cas", demande explicite).
        if def then
          CardUI.draw_faded_card(def, cr.x, cr.y, alpha)
        else
          draw_prediction_card_back(cr.x, cr.y, alpha)
        end
        if not anim and def then
          love.graphics.push()
          love.graphics.translate(cr.x, cr.y)
          UI.draw_tooltip_hint(UI.CARD_W, UI.CARD_H)
          love.graphics.pop()
        end

        local palette = Theme.card_class[h.class_id] or Theme.card_class.generic
        UI.panel(hr.x, hr.y, hr.w, hr.h, Theme.panel_light, alpha)
        UI.set(selected and Theme.accent or palette.border, alpha)
        love.graphics.setLineWidth(selected and 4 or 2)
        love.graphics.rectangle("line", hr.x, hr.y, hr.w, hr.h, 10, 10)
        love.graphics.setLineWidth(1)
        local portrait_size = 112
        UI.draw_class_icon(h.class_id, h.icon, h.label,
          hr.x + (hr.w - portrait_size) / 2, hr.y + 8, portrait_size, portrait_size, Theme.text, alpha)
        if h.hp <= 0 then
          UI.text("Mort", hr.x, hr.y + 122, hr.w, 14, Theme.muted)
        else
          UI.hp_bar(hr.x + 6, hr.y + 122, hr.w - 12, 14, h.hp / h.max_hp, h.hp / h.max_hp, Theme.hp)
          UI.text_v_centered(math.max(0, h.hp) .. "/" .. h.max_hp, hr.x, hr.y + 122, hr.w, 14, 9, Theme.text)
        end
        UI.name_badge(h.name, hr.x + 8, hr.y + 140, hr.w - 16, 12, palette.border, Theme.bg, 2, 3)
      end
    end

    if not anim then
      local b = View.prediction_sacrifice_button
      UI.set(Theme.panel_light)
      love.graphics.rectangle("fill", b.x, b.y, b.w, b.h, 8, 8)
      UI.set(Theme.accent); love.graphics.setLineWidth(2)
      love.graphics.rectangle("line", b.x, b.y, b.w, b.h, 8, 8)
      love.graphics.setLineWidth(1)
      UI.text(b.label, b.x, b.y + 13, b.w, 14, Theme.text, "center")
    end
    end)
  end
  View.draw_prediction = draw_prediction
end
