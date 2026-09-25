-- Menu principal, Options, intro de biome et menu pause (2026-09-25, extrait
-- de l'ex-monolithe view.lua -- voir src/ui/view/init.lua pour le contexte).
local Theme = require("src.ui.theme")
local Background = require("src.ui.background")
local Sprites = require("src.ui.sprites")
local Heroes = require("src.data.heroes")
local Enemies = require("src.data.enemies")

return function(View, UI)
  -- Menu pause (2026-09-02, demande explicite -- ESC) : 2 options empilées,
  -- centrées -- même gabarit que View.back_button/l'écran Options.
  View.pause_menu_continue_button = { x = UI.W / 2 - 100, y = UI.H / 2 - 4, w = 200, h = 44, label = "Continuer" }
  View.pause_menu_return_button = { x = UI.W / 2 - 100, y = UI.H / 2 + 50, w = 200, h = 44, label = "Revenir au menu" }

  -- Menu principal (2026-08-21, demande explicite) : 5 boutons empilés,
  -- centrés -- même geste que les autres écrans à bouton unique (Rejouer,
  -- Forge/Temple) : un id sur chaque rect, lu par Input.mousepressed pour savoir
  -- quelle action déclencher, jamais une deuxième liste dupliquée côté input.lua.
  local MENU_BTN_W, MENU_BTN_H, MENU_BTN_GAP = 300, 48, 18
  -- 220 -> 250 (2026-08-30, bug signalé -- "descendre tous les boutons qui sont
  -- trop près du titre") : laisse un peu plus d'air sous la bannière des 6
  -- aventuriers (MENU_HERO_ROW_Y + MENU_HERO_R, voir draw_menu_flourish),
  -- ajoutée juste avant ce même écran.
  local MENU_BTN_Y0 = 270 -- 250->270 (2026-08-31, passage 1280x720)
  View.menu_buttons = {}
  do
    -- Ordre demandé explicitement (2026-08-30) : Jouer un run -> Mode infini ->
    -- Tester le boss -> Options -> Quitter (avant : boss en premier).
    -- "Mode infini" retiré du menu (2026-09-02, demande explicite -- annoncé
    -- comme "bientôt retiré" par le porteur de projet) : le code du mode
    -- "infini" reste intact, juste devenu inaccessible depuis l'UI.
    -- "Run Solo" (2026-09-02, demande explicite, sous "Jouer un run") : un
    -- seul aventurier, deck personnalisé construit à la main -- voir
    -- Controller:enter_deck_builder.
    local defs = {
      { id = "run", label = "Jouer un run" },
      { id = "solo", label = "Run Solo" },
      { id = "boss", label = "Tester un boss" },
      { id = "options", label = "Options" },
      { id = "quit", label = "Quitter" },
    }
    for i, d in ipairs(defs) do
      View.menu_buttons[i] = {
        id = d.id, label = d.label,
        x = UI.W / 2 - MENU_BTN_W / 2, y = MENU_BTN_Y0 + (i - 1) * (MENU_BTN_H + MENU_BTN_GAP),
        w = MENU_BTN_W, h = MENU_BTN_H,
      }
    end
  end

  -- Écran "Options" (2026-08-21, demande explicite) : bouton "Retour" vers le
  -- menu. Servait aussi à l'écran "En travaux" du boss/fin de run borné,
  -- retiré depuis que l'Homme Arbre existe pour de vrai -- gardé nommé
  -- génériquement au cas où un futur écran à bouton unique en ait besoin.
  View.back_button = { x = UI.W / 2 - 90, y = UI.H / 2 + 40, w = 180, h = 40, label = "Retour" }

  -- Écran d'accueil stylé (2026-08-30, demande explicite -- "une image
  -- d'accueil, avec le titre actuel du jeu et quelques éléments graphiques
  -- stylés") : fond PROCÉDURAL (gratuit, cohérent avec Background.draw/le son
  -- chiptune du projet) plutôt qu'une illustration générée par IA. Halo doré +
  -- diamants + bannière des 6 aventuriers, purement décoratifs (aucun n'est
  -- cliquable).
  local MENU_HERO_ROW_Y = 188
  local MENU_HERO_R = 22

  local function draw_menu_diamond(x, y, size, alpha)
    UI.set(Theme.accent, alpha)
    love.graphics.polygon("fill", x, y - size, x + size, y, x, y + size, x - size, y)
  end

  local function draw_menu_flourish()
    -- Halo doré derrière le titre : cercles concentriques à alpha décroissante --
    -- LÖVE n'offre pas de flou/shader ici, cette accumulation de formes
    -- semi-transparentes en simule un à moindre coût.
    local cx, cy = UI.W / 2, 100
    for i = 4, 1, -1 do
      UI.set(Theme.accent, 0.05 * i)
      love.graphics.ellipse("fill", cx, cy, 60 + i * 40, 30 + i * 14)
    end

    -- Diamants encadrant "Rogue Adventure" + ligne de séparation, diamant
    -- central -- vocabulaire visuel déjà utilisé par le cadre doré des
    -- boutons/cartes sélectionnées (Theme.accent), jamais une nouvelle teinte.
    draw_menu_diamond(UI.W / 2 - 100, 137, 5, 0.8)
    draw_menu_diamond(UI.W / 2 + 100, 137, 5, 0.8)
    UI.set(Theme.accent, 0.5); love.graphics.setLineWidth(1)
    love.graphics.line(UI.W / 2 - 170, 155, UI.W / 2 - 14, 155)
    love.graphics.line(UI.W / 2 + 14, 155, UI.W / 2 + 170, 155)
    draw_menu_diamond(UI.W / 2, 155, 6, 0.8)

    -- Bannière des 6 aventuriers (2026-08-30) : silhouettes semi-transparentes,
    -- teintées de leur couleur de classe -- pure ambiance "constitue ton
    -- équipe", jamais interactif (contrairement à l'écran de choix d'équipe).
    local n = #Heroes.defs
    local spacing = 70
    local x0 = UI.W / 2 - (n - 1) * spacing / 2
    for i, def in ipairs(Heroes.defs) do
      local x = x0 + (i - 1) * spacing
      local palette = Theme.card_class[def.class_id] or Theme.card_class.generic
      UI.set(palette.border, 0.25)
      love.graphics.circle("fill", x, MENU_HERO_ROW_Y, MENU_HERO_R + 4)
      local sprite = Sprites.hero(def.class_id)
      if sprite then
        love.graphics.setColor(1, 1, 1, 0.55)
        Sprites.draw_centered(sprite, x, MENU_HERO_ROW_Y, MENU_HERO_R)
      end
    end
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setLineWidth(1)
  end

  -- Menu principal (2026-08-21, demande explicite) : pas de fond dédié pour
  -- l'instant -- même dégradé procédural par défaut que le combat (voir
  -- Background.draw, `enemies = nil` retombe sur BIOMES.defaut).
  local function draw_menu(controller)
    Background.draw(nil, UI.W, UI.H)
    draw_menu_flourish()
    UI.text("Hero Card Game", 0, 90, UI.W, 30, Theme.text)
    -- "Run Infini" retiré (2026-08-30, demande explicite) : remplacé par
    -- "Rogue Adventure".
    UI.text("Rogue Adventure", 0, 130, UI.W, 14, Theme.muted)
    for _, b in ipairs(View.menu_buttons) do UI.draw_menu_style_button(b) end
  end
  View.draw_menu = draw_menu

  local function draw_options(controller)
    Background.draw(nil, UI.W, UI.H)
    UI.text("Pas d'options pour le moment", 0, UI.H / 2 - 60, UI.W, 20, Theme.text)
    UI.draw_menu_style_button(View.back_button)
  end
  View.draw_options = draw_options

  -- Écran d'annonce de biome (2026-09-01, demande explicite) : "petite fenêtre
  -- intermédiaire pour annoncer le lieu" avant le début/la reprise des combats
  -- dans ce biome -- réutilise draw_camp_entrance (même animation de titre que
  -- les 4 écrans "camp") et Background.draw avec un biome explicite (pas
  -- encore de state.enemies à ce stade, voir son 4ᵉ paramètre dans
  -- background.lua).
  local function draw_biome_intro(controller)
    local bi = controller.biome_intro
    if not bi then return end
    Background.draw(nil, UI.W, UI.H, bi.biome)
    local name = Enemies.BIOME_NAMES[bi.biome] or bi.biome
    UI.draw_camp_entrance(controller, name, UI.H / 2 - 20, function()
      UI.text("Nouvelle zone…", 0, UI.H / 2 + 14, UI.W, 14, Theme.muted)
    end)
  end
  View.draw_biome_intro = draw_biome_intro

  -- Menu pause (2026-09-02, demande explicite) : overlay par-dessus l'écran
  -- courant (jamais dessiné en dessous n'est effacé) -- réutilise
  -- draw_menu_style_button tel quel, ne fait rien si l'overlay n'est pas
  -- ouvert (voir Controller.pause_menu_open).
  local function draw_pause_menu(controller)
    if not controller.pause_menu_open then return end
    UI.set(Theme.black, 0.75)
    love.graphics.rectangle("fill", 0, 0, UI.W, UI.H)
    UI.text("Pause", 0, UI.H / 2 - 60, UI.W, 24, Theme.text)
    UI.draw_menu_style_button(View.pause_menu_continue_button)
    UI.draw_menu_style_button(View.pause_menu_return_button)
  end
  View.draw_pause_menu = draw_pause_menu
end
