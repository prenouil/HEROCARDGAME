-- Écran "Sélection de quête" (2026-10-06, demande explicite -- "chaque quête
-- est un bandeau horizontal indépendant") : intermédiaire entre le choix
-- d'emplacement de sauvegarde et le choix d'équipe en mode "Aventure", voir
-- Controller:enter_quest_select/choose_quest. 4 bandeaux toujours dans le même
-- ordre (Histoire principale, 2 quêtes de classe, Recherche de compagnon) --
-- un bandeau sans quête valide ("Pas de quête de ...") reste affiché, juste
-- grisé et non cliquable, plutôt que de disparaître (la mise en page des 4
-- emplacements ne bouge jamais).
local Theme = require("src.ui.theme")
local Background = require("src.ui.background")
local Sprites = require("src.ui.sprites")
local Heroes = require("src.data.heroes")
local Quests = require("src.rules.quests")

return function(View, UI)
  local BANNER_W, BANNER_H, BANNER_GAP = 820, 96, 20
  local BANNER_X = (UI.W - BANNER_W) / 2
  local BANNER_Y0 = 120

  View.quest_banners = {}
  for i = 1, 4 do
    View.quest_banners[i] = { x = BANNER_X, y = BANNER_Y0 + (i - 1) * (BANNER_H + BANNER_GAP), w = BANNER_W, h = BANNER_H }
  end
  View.quest_back_button = { x = UI.W / 2 - 90, y = UI.H - 64, w = 180, h = 40, label = "Retour" }

  --- Un bandeau : fond/bordure selon `active`, icône carrée optionnelle à
  -- gauche (silhouette comprise -- `draw_icon` reçoit juste un rayon et
  -- dessine depuis (0, 0), déjà translaté au centre de son carré) puis le
  -- titre, vertical-centré sur toute la hauteur.
  local function draw_banner(r, title, active, draw_icon)
    UI.set(active and Theme.panel_light or Theme.panel)
    love.graphics.rectangle("fill", r.x, r.y, r.w, r.h, 10, 10)
    UI.set(active and Theme.accent or Theme.muted)
    love.graphics.setLineWidth(active and 3 or 2)
    love.graphics.rectangle("line", r.x, r.y, r.w, r.h, 10, 10)
    love.graphics.setLineWidth(1)
    if draw_icon then
      love.graphics.push()
      love.graphics.translate(r.x + r.h / 2, r.y + r.h / 2)
      draw_icon(r.h * 0.38)
      love.graphics.pop()
      love.graphics.setColor(1, 1, 1, 1)
    end
    local text_x = r.x + (draw_icon and r.h or 0) + 28
    local text_w = r.w - (draw_icon and r.h or 0) - 56
    UI.text(title, text_x, r.y + r.h / 2 - 10, text_w, 20, active and Theme.text or Theme.muted, "left")
  end

  local function draw_hero_icon(class_id, radius, silhouette)
    local sprite = Sprites.hero(class_id)
    if not sprite then return end
    if silhouette then
      love.graphics.setColor(0, 0, 0, 1)
    else
      love.graphics.setColor(1, 1, 1, 1)
    end
    Sprites.draw_centered(sprite, 0, 0, radius)
  end

  local function draw_quest_select(controller)
    Background.draw(nil, UI.W, UI.H)
    UI.text("Sélection de quête", 0, 60, UI.W, 24, Theme.text)
    local qs = controller.quest_select
    local data = qs and qs.data
    if not data then return end

    -- 1. "Histoire principale" -- toujours disponible, jamais "Pas de quête",
    -- aucun aventurier imposé.
    draw_banner(View.quest_banners[1],
      "Histoire principale : Run difficulté " .. (data.main_story_difficulty or 1), true, nil)

    -- 2-3. Quêtes de classe -- icône du héros bien visible (déjà débloqué,
    -- rien à cacher), son nom complet et la difficulté de CE run dans le
    -- titre (2026-10-07, demande explicite -- même gabarit "Run difficulté X"
    -- que "Histoire principale" -- voir Quests.class_quest_difficulty, PROPRE
    -- À CHAQUE CLASSE -- corrigé le jour même, "seulement les cartes
    -- débloquées dans cette classe" -- donc recalculée séparément pour
    -- chacune des 2, jamais une valeur unique partagée).
    for i = 1, 2 do
      local class_id = data.class_quest_ids and data.class_quest_ids[i]
      local r = View.quest_banners[i + 1]
      if class_id then
        draw_banner(r, "Quête pour le " .. (Heroes.class_name[class_id] or class_id)
          .. " : Run difficulté " .. Quests.class_quest_difficulty(class_id, data), true,
          function(radius) draw_hero_icon(class_id, radius, false) end)
      else
        draw_banner(r, "Pas de quête de classe", false, nil)
      end
    end

    -- 4. "Recherche de compagnon" -- silhouette noire (2026-10-06, demande
    -- explicite -- "en ombre noire") : identité volontairement cachée tant
    -- que la récompense n'est pas obtenue -- la difficulté, elle, reste
    -- affichée (2026-10-07, voir Quests.companion_quest_difficulty).
    local companion_id = data.companion_quest_class_id
    if companion_id then
      draw_banner(View.quest_banners[4],
        "Recherche de compagnon : Run difficulté " .. Quests.companion_quest_difficulty(data), true,
        function(radius) draw_hero_icon(companion_id, radius, true) end)
    else
      draw_banner(View.quest_banners[4], "Pas de quête de compagnon", false, nil)
    end

    UI.draw_menu_style_button(View.quest_back_button)
  end
  View.draw_quest_select = draw_quest_select
end
