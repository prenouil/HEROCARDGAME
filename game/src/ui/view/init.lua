-- Assemblage de l'UI (2026-09-25, découpage de l'ex-monolithe view.lua --
-- 5252 lignes, 179 locales de premier niveau, à deux doigts de la limite dure
-- de Lua de 200 locales par chunk, LUAI_MAXVARS -- déjà heurtée deux fois
-- cette session). Chaque écran vit maintenant dans son propre fichier, donc
-- son propre chunk (son propre budget de 200 remis à zéro) : ce mur ne revient
-- plus JAMAIS, quel que soit le nombre d'écrans/mécaniques ajoutés plus tard.
--
-- Sûr par construction : LÖVE et Busted (.busted: lpath contient
-- "game/?/init.lua") résolvent tous deux `require("src.ui.view")` vers CE
-- fichier -- aucun changement dans les 3 seuls appelants
-- (main.lua/controller.lua/input.lua), qui continuent de voir exactement la
-- même table publique `View` (mêmes noms de champs, même forme -- input.lua
-- lit ~50 champs `View.xxx` différents pour le hit-testing des clics).
--
-- Chaque écran reçoit LA MÊME table `View` (mutée en place, `function
-- View.foo(...)` exactement comme avant) et l'utilitaire partagé `UI`
-- (src/ui/view/common.lua, primitives génériques sans état d'écran). Un seul
-- écran (`combat.lua`) porte le grand aiguillage `View.draw` : les autres
-- exposent juste leurs `View.draw_xxx`, appelés d'ici.
local Background = require("src.ui.background")

local View = {}
local UI = require("src.ui.view.common")

-- `input.lua` appelle `View.point_in` directement (~90 sites, hit-testing de
-- tous les écrans) -- jamais renommé/déplacé par ce découpage, juste
-- réexposé depuis UI.point_in (common.lua), sa seule implémentation réelle.
View.point_in = UI.point_in

require("src.ui.view.cards") -- pas de champs View.* ; requis par combat/forge/deck_view/deck_builder/victory directement
require("src.ui.view.tooltip")(View, UI)
require("src.ui.view.menu")(View, UI)
require("src.ui.view.boss_select")(View, UI)
require("src.ui.view.deck_view")(View, UI)
require("src.ui.view.deck_builder")(View, UI)
require("src.ui.view.campfire")(View, UI)
require("src.ui.view.refuge")(View, UI)
require("src.ui.view.temple")(View, UI)
require("src.ui.view.forge")(View, UI)
require("src.ui.view.team_select")(View, UI)
require("src.ui.view.victory")(View, UI)
require("src.ui.view.combat")(View, UI)

View.W, View.H = UI.W, UI.H

--- Aiguillage par écran (ex-view.lua:4935-5252) : chaque branche appelle les
-- fonctions désormais réparties dans les fichiers ci-dessus. Menu pause
-- (2026-09-02, ESC depuis N'IMPORTE quel écran) : `View.draw_pause_menu`
-- vérifie elle-même `controller.pause_menu_open` et ne fait rien sinon --
-- appelée à chaque point de sortie, même schéma déjà en place pour
-- `View.draw_deck_view`.
function View.draw(controller)
  if controller.screen == "menu" then View.draw_menu(controller); View.draw_pause_menu(controller); return end
  if controller.screen == "options" then View.draw_options(controller); View.draw_pause_menu(controller); return end
  if controller.screen == "boss_select" then View.draw_boss_select(controller); View.draw_tooltip(controller); View.draw_pause_menu(controller); return end
  if controller.screen == "deck_builder" then
    View._deck_builder_fx.draw(controller); View.draw_card_flights(controller); View.draw_tooltip(controller); View.draw_pause_menu(controller)
    return
  end
  if controller.screen == "bossVictory" then View.draw_boss_victory(controller); View.draw_pause_menu(controller); return end
  if controller.screen == "biome_intro" then View.draw_biome_intro(controller); View.draw_pause_menu(controller); return end
  if controller.screen == "team_select" then View.draw_team_select(controller); View.draw_deck_view(controller); View.draw_pause_menu(controller); return end

  -- Écrans "camp" (2026-08-30 -- "quand on passe sur un évènement, c'est un
  -- changement de contexte, il ne faut montrer que l'évènement") : dispatchés
  -- à PART, comme team_select ci-dessus -- AUCUN élément de la scène de
  -- combat n'est dessiné en dessous. Le décor d'ambiance (Background.draw)
  -- reste affiché -- ce n'est pas "un reste du combat", juste la toile de
  -- fond du donjon.
  if controller.screen == "campfire" or controller.screen == "forge"
    or controller.screen == "temple" or controller.screen == "refuge" then
    Background.draw(controller.state.enemies, UI.W, UI.H)
    if controller.screen == "campfire" and controller.campfire then View.draw_campfire(controller)
    elseif controller.screen == "forge" and controller.forge then View.draw_forge(controller)
    elseif controller.screen == "temple" and controller.temple then View.draw_temple(controller)
    elseif controller.screen == "refuge" and controller.refuge then View.draw_refuge(controller)
    end
    -- Infobulles : seuls Forge/Temple en ont une (Campfire/Refuge n'en ont
    -- jamais eu, aucune régression à corriger là).
    if controller.screen == "forge" or controller.screen == "temple" then
      View.draw_tooltip(controller)
    end
    View.draw_deck_view(controller)
    View.draw_pause_menu(controller)
    love.graphics.setColor(1, 1, 1, 1)
    return
  end

  -- "playing"/"defeat"/"victory" : seuls écrans restants, gérés par la scène
  -- de combat elle-même (voir view/combat.lua -- inclut son propre
  -- affichage des overlays de défaite/victoire).
  View.draw_combat(controller)
end

return View
