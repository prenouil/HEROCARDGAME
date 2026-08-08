-- Point d'entrée LÖVE. Ne contient aucune règle de jeu — juste le branchement
-- entre les callbacks love.* et src/ui/controller.lua.

local Controller = require("src.ui.controller")
local View = require("src.ui.view")
local Input = require("src.ui.input")
local SCALE = require("src.ui.layout_scale")

local controller

function love.load()
  love.math.setRandomSeed(os.time())
  math.randomseed(os.time())
  controller = Controller.new()
end

function love.update(dt)
  controller:update(dt)
end

function love.draw()
  love.graphics.push()
  love.graphics.scale(SCALE, SCALE)
  View.draw(controller)
  love.graphics.pop()
end

-- Les callbacks souris de LÖVE donnent des coordonnées fenêtre réelle ; tout le
-- layout (view.lua, input.lua) raisonne dans l'espace logique 960x700 mis à
-- l'échelle par love.graphics.scale() ci-dessus -- on convertit ici, une seule
-- fois, plutôt que de propager SCALE dans chaque calcul de rectangle.
function love.mousepressed(x, y, button)
  Input.mousepressed(controller, x / SCALE, y / SCALE, button)
end

function love.mousemoved(x, y)
  Input.mousemoved(controller, x / SCALE, y / SCALE)
end

function love.keypressed(key)
  if key == "escape" then love.event.quit() end
end
