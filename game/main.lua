-- Point d'entrée LÖVE. Ne contient aucune règle de jeu — juste le branchement
-- entre les callbacks love.* et src/ui/controller.lua.

local Controller = require("src.ui.controller")
local View = require("src.ui.view")
local Input = require("src.ui.input")

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
  View.draw(controller)
end

function love.mousepressed(x, y, button)
  Input.mousepressed(controller, x, y, button)
end

function love.mousemoved(x, y)
  Input.mousemoved(controller, x, y)
end

function love.keypressed(key)
  if key == "escape" then love.event.quit() end
end
