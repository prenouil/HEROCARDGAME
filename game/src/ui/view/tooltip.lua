-- Infobulle générique (héros/ennemi/carte/mot-clé/pioche/défausse/effet du
-- Temple/aventurier à l'écran d'équipe/aperçu de boss) -- partagée par tous
-- les écrans qui en affichent une (2026-09-25, extrait de l'ex-monolithe
-- view.lua -- voir src/ui/view/init.lua pour le contexte du découpage).
local Theme = require("src.ui.theme")
local Fonts = require("src.ui.fonts")
local Icons = require("src.ui.icons")
local Sprites = require("src.ui.sprites")
local Glossary = require("src.data.glossary")
local Enemies = require("src.data.enemies")
local Heroes = require("src.data.heroes")
local Combat = require("src.rules.combat")
local Temple = require("src.rules.temple")
local Deck = require("src.rules.deck")
local Encounter = require("src.rules.encounter")
local SCALE = require("src.ui.layout_scale")

return function(View, UI)
  local STATUS_TOOLTIP_FIELDS = {
    { field = "defense", glossary_key = "bouclier", label = "Bouclier", explain = "Absorbe les prochains dégâts avant les PV." },
    { field = "esquive", glossary_key = "esquive" },
    { field = "camoufle", glossary_key = "camoufle", hide_value = true },
    { field = "puissance", glossary_key = "puissance" },
    -- Incandescence (2026-09-02, statut Volcan) : même mécanisme que Puissance
    -- ci-dessus, sa propre entrée de glossaire (voir glossary.lua).
    { field = "incandescence", glossary_key = "incandescence", label = "Incandescence" },
    { field = "saignements", glossary_key = "saignement" },
    { field = "brulure", glossary_key = "brulure", label = "Brûlure" },
    { field = "incapacite", glossary_key = "incapacite" },
    { field = "vulnerabilite", glossary_key = "vulnerabilite" },
    { field = "provocation", glossary_key = "provocation" },
    -- "Vol" (2026-08-30, second boss -- Aigle Géant) : `hide_value` (toujours
    -- 1, jamais un compteur qui empile -- même traitement que Camouflé).
    { field = "vol", glossary_key = "vol", label = "Vol", hide_value = true },
    -- Inspiration/Encore (2026-08-29, Barde) : même mécanisme générique,
    -- glossary_key pointe vers les entrées ajoutées dans glossary.lua.
    { field = "inspiration", glossary_key = "inspiration" },
    { field = "encore_extra_plays", glossary_key = "encore", label = "Encore" },
  }

  -- `seen` (optionnel, 2026-08-30, demande explicite -- "Tous les mots clés
  -- présents dans l'info bulle doivent être expliqués au moins 1 fois DANS
  -- CETTE MÊME INFOBULLE") : table PARTAGÉE avec le reste de tooltip_lines
  -- (clé = g.key), déjà marquée par toute ligne de description libre affichée
  -- AVANT ce statut -- si ce mot-clé est déjà expliqué ailleurs dans la MÊME
  -- infobulle, cette ligne garde son nom + sa valeur mais N'Y RÉPÈTE PAS
  -- l'explication.
  local function active_status_lines(unit, seen)
    local lines = {}
    for _, spec in ipairs(STATUS_TOOLTIP_FIELDS) do
      local value = unit[spec.field]
      local active = type(value) == "number" and value > 0
      if active then
        local g = Glossary.find_term(spec.glossary_key)
        local label = spec.label or (g and (g.label or g.icon)) or spec.field
        local explain = spec.explain or (g and g.explain ~= "" and g.explain) or ""
        local already_explained = seen and g and seen[g.key]
        if seen and g then seen[g.key] = true end
        local line_text = label .. (spec.hide_value and "" or (" " .. value))
          .. ((explain ~= "" and not already_explained) and (" — " .. explain) or "")
        -- Sprites.status (pas Sprites.keyword/le has_icon du glossaire, qui ne
        -- couvre que le texte de carte) -- ce sont les mêmes icônes déjà
        -- visibles sur les badges de statut de l'encart.
        local icon = Sprites.status(spec.field)
        lines[#lines + 1] = icon and { text = line_text, icon = icon } or line_text
      end
    end
    return lines
  end

  --- Ligne d'explication pour UN terme du glossaire -- même format que le cas
  -- "card" de tooltip_lines ci-dessous : une seule façon de présenter un
  -- mot-clé dans toute l'UI, jamais un texte ad hoc différent par écran.
  local function keyword_explanation_line(g)
    local label = g.has_icon and ((g.label or g.key) .. " (" .. g.key .. ")") or g.key
    local related = g.related ~= "" and (" — " .. g.related) or ""
    local line_text = label .. related .. (g.explain ~= "" and (" : " .. g.explain) or "")
    return g.has_icon and { text = line_text, icon = Sprites.keyword(g.key) } or line_text
  end

  --- Ajoute à `lines` la version affichable de `raw_text` (guillemets des
  -- mots-clés retirés) précédée de `prefix` (optionnel), PUIS l'explication de
  -- chaque mot-clé qu'elle cite mais qui n'a pas déjà été expliqué DANS CETTE
  -- INFOBULLE. `seen` : table PARTAGÉE par tout l'appel à tooltip_lines.
  local function add_described_line(lines, raw_text, seen, prefix)
    lines[#lines + 1] = (prefix or "") .. Glossary.render_card_text(raw_text)
    for _, g in ipairs(Glossary.keywords_present(raw_text)) do
      if not seen[g.key] then
        seen[g.key] = true
        lines[#lines + 1] = keyword_explanation_line(g)
      end
    end
  end

  local function tooltip_lines(controller)
    local h = controller.hover
    if h.kind == "hero" then
      local hero = Combat.hero_by_id(controller.state, h.target)
      if not hero then return nil end
      -- Description de classe (2026-08-24, demande explicite) : en tête de
      -- l'infobulle, avant les statuts actifs.
      local lines = {}
      local seen = {}
      local desc = Heroes.class_description[hero.class_id]
      if desc then add_described_line(lines, desc, seen) end
      -- Bénédiction/malédiction du Temple (2026-08-28/29, demande explicite) :
      -- juste après la description de classe, avant les statuts de combat.
      if hero.blessing then
        local blessing = Temple.by_id(hero.blessing)
        if blessing then add_described_line(lines, blessing.desc, seen, blessing.name .. " — ") end
      end
      if hero.curse then
        local curse = Temple.by_id(hero.curse)
        if curse then add_described_line(lines, curse.desc, seen, curse.name .. " — ") end
      end
      for _, l in ipairs(active_status_lines(hero, seen)) do lines[#lines + 1] = l end
      return hero.name, lines
    elseif h.kind == "enemy" then
      local e = Combat.enemy_by_id(controller.state, h.target)
      if not e then return nil end
      local template = Enemies.by_id(e.template_id)
      local lines = {}
      local seen = {}
      -- "Action en cours" (2026-08-27, demande explicite) : juste sous le
      -- titre nom/niveau -- le nom du coup déjà télégraphié sur le cadre.
      if e.next_move then
        lines[#lines + 1] = "Action en cours : " .. e.next_move.name
      end
      -- Sensibilité au feu de l'Homme Arbre (2026-08-24, demande explicite).
      if e.template_id == "homme-arbre" then
        lines[#lines + 1] = "Sensible au feu : les dégâts de feu infligent +50%."
      end
      for _, m in ipairs(template.moves_info(e.level)) do
        add_described_line(lines, m.text, seen, m.name .. " — ")
      end
      for _, l in ipairs(active_status_lines(e, seen)) do lines[#lines + 1] = l end
      lines[#lines + 1] = "PV max " .. e.max_hp
      -- Élite (2026-09-01, demande explicite -- "nom entouré de 2 étoiles") :
      -- draw_tooltip dessine une vraie icône vectorielle de part et d'autre du
      -- titre (voir Icons.draw_status("elite", ...)).
      return e.name .. " Nv." .. e.level, lines
    elseif h.kind == "card" then
      local def = h.target
      local terms = Glossary.keywords_present(def.desc)
      if #terms == 0 then return def.name, { "Aucun mot-clé de glossaire sur cette carte." } end
      local lines = {}
      for _, g in ipairs(terms) do lines[#lines + 1] = keyword_explanation_line(g) end
      return def.name .. " — mots-clés", lines
    elseif h.kind == "deck" then
      return "Pioche", { "Cartes piochées par tour : " .. Deck.HAND_SIZE .. "." }
    elseif h.kind == "discard" then
      return "Défausse", { "Quand la pioche est vide, les cartes de la défausse sont remélangées dans la pioche." }
    elseif h.kind == "end_turn" then
      return "Fin de tour", { "Les cartes restantes en main seront défaussées et cela passe au tour des ennemis." }
    elseif h.kind == "temple_effect" then
      -- Écran "Le Temple" (2026-08-29, demande explicite) : le descriptif
      -- complet vit UNIQUEMENT ici.
      local effect = h.target
      local lines = {}
      add_described_line(lines, effect.desc, {})
      return effect.name, lines
    elseif h.kind == "team_hero" then
      -- Écran "Choisis ton équipe" (2026-08-29) : contrairement au cas "hero"
      -- ci-dessus, aucun héros réel n'existe encore dans controller.state à ce
      -- stade (avant Game.reset_run) -- `h.target` porte directement l'ID du
      -- def (Heroes.by_id), pas un héros de state.heroes.
      local def = Heroes.by_id(h.target)
      if not def then return nil end
      local desc = Heroes.class_description[def.class_id]
      if not desc then return def.name, {} end
      local lines = {}
      add_described_line(lines, desc, {})
      return def.name, lines
    elseif h.kind == "boss_preview" then
      -- Écran "Choisis un boss" (2026-09-02, demande explicite) : `h.target`
      -- porte le biome (pas un ennemi réel, aucune instance n'existe encore).
      local biome = h.target
      local template = Enemies.by_id(Encounter.BOSS_BY_BIOME[biome])
      if not template then return nil end
      local level = (controller.boss_select and controller.boss_select.level) or 1
      local lines = {}
      local seen = {}
      if template.id == "homme-arbre" then
        lines[#lines + 1] = "Sensible au feu : les dégâts de feu infligent +50%."
      end
      for _, m in ipairs(template.moves_info(level)) do
        add_described_line(lines, m.text, seen, m.name .. " — ")
      end
      local lo, hi = Enemies.scaled_range(template.hp_base, level)
      lines[#lines + 1] = "PV max " .. lo .. "-" .. hi
      return template.name .. " Nv." .. level, lines
    end
    return nil
  end

  -- Nombre de lignes VISUELLES (après retour à la ligne automatique de printf)
  -- qu'occupera `str` dans une largeur `avail_w` -- indispensable pour ne pas
  -- superposer deux entrées du tooltip quand l'une d'elles est longue et wrap.
  local function wrapped_line_count(str, avail_w, size)
    local _, wrapped = Fonts.get(size):getWrap(str, avail_w)
    return math.max(1, #wrapped)
  end

  local function draw_tooltip(controller)
    -- Retour du porteur de projet (2026-08-09) : la fenêtre d'infobulle
    -- gâchait la lecture du combat pendant le ciblage -- une carte sélectionnée
    -- suspend l'infobulle entièrement, quel que soit le mode d'entrée.
    if controller.state.pending then return end
    if not controller:hover_ready() then return end
    local title, lines = tooltip_lines(controller)
    if not title then return end
    -- Position figée dès l'apparition (2026-08-30, demande explicite) :
    -- capturée une seule fois, à la toute première frame où hover_ready() est
    -- vrai (Controller:set_hover les remet à nil dès que kind/target change).
    local hover = controller.hover
    if not hover.frozen_x then
      local raw_x, raw_y = love.mouse.getPosition()
      hover.frozen_x, hover.frozen_y = raw_x / SCALE, raw_y / SCALE
    end
    local mx, my = hover.frozen_x, hover.frozen_y
    local w = 240
    local line_h = 14

    local wrapped_counts = {}
    for i, line in ipairs(lines) do
      local str, avail_w
      if type(line) == "table" then
        str, avail_w = line.text, w - (line.icon and 24 or 8) - 8
      else
        str, avail_w = line, w - 16
      end
      wrapped_counts[i] = wrapped_line_count(str, avail_w, 9)
    end
    local total_lines = 0
    for _, c in ipairs(wrapped_counts) do total_lines = total_lines + c end

    local h2 = 20 + line_h * total_lines
    local x = math.min(mx + 14, UI.W - w - 8)
    local y = math.max(8, my - h2 - 10)
    UI.panel(x, y, w, h2, Theme.panel_light)
    UI.set(Theme.status); love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", x, y, w, h2, 8, 8)
    -- Élite (2026-09-02, correctif) : étoiles vectorielles de part et d'autre
    -- du titre, remplace le "\u{2605}" texte qui ne s'affichait jamais.
    local hover_enemy = hover.kind == "enemy" and Combat.enemy_by_id(controller.state, hover.target)
    if hover_enemy and hover_enemy.elite then
      love.graphics.setColor(1, 1, 1, 1)
      Icons.draw_status("elite", x + 14, y + 11, 7, Theme.accent)
      Icons.draw_status("elite", x + w - 14, y + 11, 7, Theme.accent)
      UI.text(title, x + 22, y + 6, w - 44, 10, Theme.status, "center")
    else
      UI.text(title, x + 8, y + 6, w - 16, 10, Theme.status, "left")
    end
    local ly = y + 20
    for i, line in ipairs(lines) do
      if type(line) == "table" then
        local text_x = x + 8
        if line.icon then
          love.graphics.setColor(1, 1, 1, 1)
          Sprites.draw_centered(line.icon, x + 14, ly + 5, 7)
          text_x = x + 24
        end
        UI.text(line.text, text_x, ly, w - (text_x - x) - 8, 9, Theme.text, "left")
      else
        UI.text(line, x + 8, ly, w - 16, 9, Theme.text, "left")
      end
      ly = ly + line_h * wrapped_counts[i]
    end
  end
  View.draw_tooltip = draw_tooltip
end
