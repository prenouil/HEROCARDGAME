-- Rendu de la face/du dos d'une carte, partagé par la main (combat.lua), la
-- Forge (forge.lua) et le vol de cartes (2026-09-25, extrait de l'ex-
-- monolithe view.lua -- voir src/ui/view/init.lua pour le contexte). Pas de
-- champs `View.*` ici : ces fonctions ne sont pas exposées publiquement,
-- seulement requises directement par les écrans qui en ont besoin.
local Theme = require("src.ui.theme")
local Fonts = require("src.ui.fonts")
local Sprites = require("src.ui.sprites")
local RichText = require("src.ui.richtext")
local Heroes = require("src.data.heroes")

local UI = require("src.ui.view.common")

local M = {}

--- Dessine le contenu plein d'une carte (fond teinté par classe, double contour,
-- pastille de coût, nom en cadre, description) dans l'espace local [0,0]..[w,h] --
-- l'appelant gère push/translate/scale/pop. Partagé entre la main (combat.lua)
-- et le vol de cartes pioche/défausse : une carte en plein vol doit avoir
-- exactement le même visage qu'immobile en main, jamais un second rendu qui
-- diverge (voir Theme.card_class).
-- `cost_insufficient`/`mana_insufficient` (2026-08-24, demande explicite,
-- optionnels -- seul l'appel depuis la main les renseigne) : pastille
-- d'énergie/mana en rouge (Theme.hp) au lieu de sa couleur normale quand la
-- réserve globale/la mana du propriétaire ne couvrent plus le coût.
-- `owner_defeated` (2026-08-24, demande explicite, optionnel, même
-- provenance) : voile gris sur TOUTE la carte quand le héros propriétaire est
-- vaincu.
function M.draw_card_face(def, w, h, cost_text, desc_text, desc_color, highlight, cost_insufficient, mana_insufficient, owner_defeated)
  local palette = Theme.card_class[def.class_id] or Theme.card_class.generic
  UI.panel(0, 0, w, h, palette.bg)
  UI.set(highlight and Theme.accent or Theme.black)
  love.graphics.setLineWidth(highlight and 3 or 2)
  love.graphics.rectangle("line", 0, 0, w, h, 10, 10)
  UI.set(palette.border)
  love.graphics.setLineWidth(1)
  love.graphics.rectangle("line", 3, 3, w - 6, h - 6, 8, 8)
  love.graphics.setLineWidth(1)

  -- Bas de la bande de type, calculé tôt (2026-09-12) : la description
  -- (plus bas) a besoin de savoir où elle s'arrête AVANT d'être dessinée,
  -- pour rétrécir sa police si besoin plutôt que de chevaucher cette bande.
  local band_y = h - 2 - 11

  -- Illustration (2026-09-12, demande explicite -- "la chose la plus claire
  -- et la plus importante à voir") : dessinée EN PREMIER, quasi plein cadre --
  -- les pastilles de coût et le cartouche nom/classe (plus bas) se posent
  -- PAR-DESSUS elle. `Sprites.card(def.code)` renvoie nil tant qu'aucun
  -- fichier `assets/cards/<code>.png` n'existe (repli déjà géré par
  -- Sprites.load, jamais d'erreur) : simple aplat neutre en attendant.
  -- `Sprites.draw_cover` découpe l'image en Quad pour REMPLIR tout le cadre
  -- façon "cover" CSS (rogne au besoin, jamais de déformation) -- pas de
  -- `love.graphics.setScissor` ici, ses coordonnées sont TOUJOURS en pixels
  -- ÉCRAN absolus, jamais affectées par la transformation en cours (cette
  -- fonction est appelée aussi bien depuis un canvas remis à l'origine QUE
  -- directement sous un translate/scale/rotate).
  local art_x, art_y, art_w, art_h = 4, 4, w - 8, 109
  local art = Sprites.card(def.code)
  if art then
    Sprites.draw_cover(art, art_x, art_y, art_w, art_h)
  else
    UI.set(Theme.panel_light); love.graphics.rectangle("fill", art_x, art_y, art_w, art_h, 4, 4)
  end
  UI.set(palette.border); love.graphics.setLineWidth(1)
  love.graphics.rectangle("line", art_x, art_y, art_w, art_h, 4, 4)

  -- Coûts (2026-09-12, demande explicite -- "les coûts additionnels doivent
  -- être situés en colonne, dessous le coût en énergie") : l'énergie garde sa
  -- position/taille EXACTE d'avant (14,12,r9) ; mana/Corruption (mutuellement
  -- exclusifs en pratique, voir cards.lua -- jamais 2 en même temps sur une
  -- carte) descendent SOUS elle, alignés sur son bord gauche (x=5). Dessinés
  -- APRÈS l'illustration pour rester lisibles par-dessus.
  UI.set(cost_insufficient and Theme.hp or Theme.energy); love.graphics.circle("fill", 14, 12, 9)
  UI.set(Theme.bg or { 0.05, 0.1, 0.1 })
  love.graphics.setFont(Fonts.get(11)); love.graphics.printf(tostring(cost_text), 4, 6, 20, "center")

  if def.mana_cost then
    UI.set(mana_insufficient and Theme.hp or Theme.mana); love.graphics.circle("fill", 14, 33, 7)
    UI.set(Theme.bg or { 0.05, 0.1, 0.1 })
    love.graphics.setFont(Fonts.get(9))
    love.graphics.printf(tostring(def.mana_cost), 8, 29, 12, "center")
  end

  -- Coût variable en Corruption (2026-08-29, Nécromancien -- "1 (+X, 0-N
  -- Corruption)") : pastille OVALE (jamais ronde comme énergie/mana) --
  -- affiche le PLAFOND en dur ("X(0-3)"), jamais la valeur actuellement
  -- disponible -- c'est le TEXTE de la carte (desc_text, substitué par
  -- l'appelant) qui porte le X recalculé en temps réel.
  if def.corruption_cost_cap then
    UI.set(Theme.corruption); love.graphics.ellipse("fill", 22, 33, 16, 8)
    UI.set(Theme.bg or { 0.05, 0.1, 0.1 })
    love.graphics.setFont(Fonts.get(8))
    love.graphics.printf("X(0-" .. def.corruption_cost_cap .. ")", 6, 29, 32, "center")
  end

  -- Nom + classe (2026-09-12, demande explicite) : cartouche à 2 lignes,
  -- fusionnant l'ex-bandeau "nom de l'aventurier" du bas de carte. Nom
  -- JAMAIS sur 2 lignes (4ᵉ demande explicite -- "si cela arrive, on scale
  -- down la taille de la police jusqu'à ce que cela rentre") : cherche la
  -- plus grande taille (16 en partant) qui tient sur UNE ligne dans NAME_W,
  -- jusqu'à un plancher de 7.
  local hero_name = Heroes.class_name[def.class_id]
  local NAME_X = def.corruption_cost_cap and 40 or 26
  local NAME_Y, NAME_W = 3, w - NAME_X - 3
  local name_size = 16
  local name_font = Fonts.get(name_size)
  while name_size > 7 and name_font:getWidth(def.name) > NAME_W do
    name_size = name_size - 1
    name_font = Fonts.get(name_size)
  end
  if name_font:getWidth(def.name) > NAME_W then
    print(("[carte] %s (%s) : nom trop long pour tenir sur 1 ligne meme a taille %d (%dpx > %dpx) -- a raccourcir")
      :format(def.name, def.code, name_size, math.ceil(name_font:getWidth(def.name)), NAME_W))
  end
  -- Classe remontée, plus collée au nom (2026-09-12, demande explicite) :
  -- espace entre les 2 lignes 2px -> 0, la hauteur naturelle de la police
  -- suffit déjà à les distinguer.
  local CLASS_GAP = 0
  local class_font = Fonts.get(7)
  local NAME_H = 3 + name_font:getHeight() + (hero_name and (CLASS_GAP + class_font:getHeight()) or 0) + 3
  UI.set(palette.border)
  love.graphics.rectangle("fill", NAME_X, NAME_Y, NAME_W, NAME_H, 4, 4)
  UI.set(Theme.black); love.graphics.setLineWidth(2)
  love.graphics.rectangle("line", NAME_X, NAME_Y, NAME_W, NAME_H, 4, 4)
  love.graphics.setLineWidth(1)
  -- Carte améliorée : nom en gras + teinte grise distincte plutôt que les
  -- "+" ajoutés autour du texte (2026-09-12, demande explicite -- remplace
  -- le système "+ Nom +", voir Cards.upgraded_def dans cards.lua). Pas de
  -- variante grasse dans la police du jeu (m5x7, voir fonts.lua) : "gras"
  -- simulé en dessinant le texte 2 fois avec 1px de décalage horizontal.
  local name_color = def.is_upgraded and { 0.204, 0.192, 0.227 } or Theme.bg
  UI.text(def.name, NAME_X, NAME_Y + 3, NAME_W, name_size, name_color, "center")
  if def.is_upgraded then
    UI.text(def.name, NAME_X + 1, NAME_Y + 3, NAME_W, name_size, name_color, "center")
  end
  if hero_name then
    UI.text("- " .. hero_name .. " -", NAME_X, NAME_Y + 3 + name_font:getHeight() + CLASS_GAP, NAME_W, 7, Theme.bg, "center")
  end

  -- Description (2026-09-12, sous l'illustration) : rétrécie automatiquement
  -- (5ᵉ/6ᵉ demandes explicites) -- part de 9 (taille normale), essaie des
  -- tailles décroissantes jusqu'à ce que `RichText.measure_height` (mesure
  -- SANS dessiner) tienne dans le budget vertical réel, jusqu'à un plancher
  -- de 6. Si même 6 ne suffit pas, signalé en console.
  local desc_y = art_y + art_h + 4
  local desc_budget_h = band_y - desc_y - 2
  local desc_size = 9
  while desc_size > 6 and RichText.measure_height(desc_text, w - 6, desc_size) > desc_budget_h do
    desc_size = desc_size - 1
  end
  if RichText.measure_height(desc_text, w - 6, desc_size) > desc_budget_h then
    print(("[carte] %s (%s) : description deborde encore a taille %d (%.0fpx > %.0fpx budget) -- a raccourcir")
      :format(def.name, def.code, desc_size, RichText.measure_height(desc_text, w - 6, desc_size), desc_budget_h))
  end
  RichText.draw(desc_text, 3, desc_y, w - 6, desc_size, desc_color or Theme.muted)

  -- Type de carte (2026-09-03, demande explicite -- "Offensive" quand la
  -- carte cible/agit sur des ennemis, "Support" quand elle cible/agit sur des
  -- alliés, exceptionnellement les deux) -- rouge (Theme.offensive) ou bleue
  -- (Theme.support). Tout en bas de la carte (2026-09-12, demande explicite).
  if def.types then
    local band_w = w * 0.9
    local band_x = (w - band_w) / 2
    local has_off, has_sup, has_ench = false, false, false
    for _, t in ipairs(def.types) do
      if t == "offensive" then has_off = true
      elseif t == "support" then has_sup = true
      elseif t == "enchantment" then has_ench = true end
    end
    -- Enchantement (2026-09-03, 3ᵉ type -- jamais combiné à Offensive/Support
    -- par construction, voir cards.lua) : une seule pastille violette, même
    -- traitement que le cas "un seul type" ci-dessous.
    if has_ench then
      UI.set(Theme.enchantment)
      love.graphics.rectangle("fill", band_x, band_y, band_w, 11, 4, 4)
      UI.text_v_centered("ENCHANTEMENT", band_x, band_y, band_w, 11, 7, Theme.bg)
    elseif has_off and has_sup then
      local gap = 2
      local pill_w = (band_w - gap) / 2
      UI.set(Theme.offensive); love.graphics.rectangle("fill", band_x, band_y, pill_w, 11, 4, 4)
      UI.set(Theme.support); love.graphics.rectangle("fill", band_x + pill_w + gap, band_y, pill_w, 11, 4, 4)
      UI.text_v_centered("OFF", band_x, band_y, pill_w, 11, 7, Theme.bg)
      UI.text_v_centered("SUP", band_x + pill_w + gap, band_y, pill_w, 11, 7, Theme.bg)
    elseif has_off or has_sup then
      UI.set(has_off and Theme.offensive or Theme.support)
      love.graphics.rectangle("fill", band_x, band_y, band_w, 11, 4, 4)
      UI.text_v_centered(has_off and "OFFENSIVE" or "SUPPORT", band_x, band_y, band_w, 11, 8, Theme.bg)
    end
  end

  UI.draw_tooltip_hint(w, h)

  -- Voile gris par-dessus tout le contenu déjà dessiné (cadre compris) quand
  -- le propriétaire est vaincu -- chaque élément ci-dessus fixe sa propre
  -- couleur, un voile en overlay évite de les reprendre un par un.
  if owner_defeated then
    UI.set(Theme.black, 0.55)
    love.graphics.rectangle("fill", 0, 0, w, h, 10, 10)
  end
end

--- Même rendu que draw_card_face, mais réinjecté via un canvas partagé
-- (UI.card_flight_canvas) pour pouvoir appliquer un fondu (`alpha`) uniforme
-- à toute la carte (2026-08-30, Forge -- cartes non choisies qui s'effacent ;
-- vol pioche/défausse). `love.graphics.origin()` avant de dessiner dans le
-- canvas : sans ça, l'échelle globale (love.graphics.scale(SCALE,SCALE),
-- main.lua) reste active pendant ce rendu et le contenu déborde du canvas
-- (taille physique fixe), se faisant rogner sur les bords droit/bas.
function M.draw_faded_card(def, x, y, alpha, desc_color, highlight)
  UI.card_flight_canvas = UI.card_flight_canvas or love.graphics.newCanvas(UI.CARD_W, UI.CARD_H)
  love.graphics.push()
  love.graphics.origin()
  local prev_canvas = love.graphics.getCanvas()
  love.graphics.setCanvas(UI.card_flight_canvas)
  love.graphics.clear(0, 0, 0, 0)
  M.draw_card_face(def, UI.CARD_W, UI.CARD_H, def.cost, def.desc, desc_color or Theme.muted, highlight or false)
  love.graphics.setCanvas(prev_canvas)
  love.graphics.pop()
  love.graphics.setColor(1, 1, 1, alpha)
  love.graphics.draw(UI.card_flight_canvas, x, y)
  love.graphics.setColor(1, 1, 1, 1)
end

--- Dos de carte représentant TOUTES les cartes Avancées d'une classe d'un
-- coup (2026-08-30, écran de choix d'équipe, demande explicite -- "à la
-- place de montrer les cartes avancées, on montre 1 seule carte de dos avec
-- le nombre de cartes avancées actuellement débloquées pour ce personnage") :
-- même identité de classe (couleur) que les vraies cartes, mais face cachée
-- (motif croisé, pas de nom/texte/coût) -- seul le NOMBRE change d'une
-- classe à l'autre (dérivé de Cards.list, jamais codé en dur -- voir
-- Controller:team_select_spawn_cards).
function M.draw_card_back_face(w, h, class_id, count)
  local palette = Theme.card_class[class_id] or Theme.card_class.generic
  UI.panel(0, 0, w, h, palette.bg)
  UI.set(Theme.black); love.graphics.setLineWidth(2)
  love.graphics.rectangle("line", 0, 0, w, h, 10, 10)
  UI.set(palette.border); love.graphics.setLineWidth(1)
  love.graphics.rectangle("line", 3, 3, w - 6, h - 6, 8, 8)
  UI.set(palette.border, 0.4)
  love.graphics.setLineWidth(1)
  for i = -3, 3 do
    love.graphics.line(w / 2 + i * 12, 8, w / 2 + i * 12 + 26, h - 8)
    love.graphics.line(w / 2 + i * 12 + 26, 8, w / 2 + i * 12, h - 8)
  end
  love.graphics.setLineWidth(1)
  UI.set(Theme.text)
  love.graphics.setFont(Fonts.get(30))
  love.graphics.printf(tostring(count), 0, h / 2 - 34, w, "center")
  UI.text("cartes avancées\ndébloquées", 3, h / 2 + 2, w - 6, 9, Theme.muted, "center")
end

--- Même détour par canvas que draw_faded_card ci-dessus (fondu uniforme +
-- push/origin()/pop, même correctif).
function M.draw_faded_card_back(class_id, count, x, y, alpha)
  UI.card_flight_canvas = UI.card_flight_canvas or love.graphics.newCanvas(UI.CARD_W, UI.CARD_H)
  love.graphics.push()
  love.graphics.origin()
  local prev_canvas = love.graphics.getCanvas()
  love.graphics.setCanvas(UI.card_flight_canvas)
  love.graphics.clear(0, 0, 0, 0)
  M.draw_card_back_face(UI.CARD_W, UI.CARD_H, class_id, count)
  love.graphics.setCanvas(prev_canvas)
  love.graphics.pop()
  love.graphics.setColor(1, 1, 1, alpha)
  love.graphics.draw(UI.card_flight_canvas, x, y)
  love.graphics.setColor(1, 1, 1, 1)
end

return M
