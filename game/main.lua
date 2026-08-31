-- Point d'entrée LÖVE. Ne contient aucune règle de jeu — juste le branchement
-- entre les callbacks love.* et src/ui/controller.lua.

local Controller = require("src.ui.controller")
local View = require("src.ui.view")
local Input = require("src.ui.input")
local SCALE = require("src.ui.layout_scale")

local controller
local hand_cursor, arrow_cursor

function love.load()
  love.math.setRandomSeed(os.time())
  math.randomseed(os.time())
  controller = Controller.new()
  hand_cursor = love.mouse.getSystemCursor("hand")
  arrow_cursor = love.mouse.getSystemCursor("arrow")
end

function love.update(dt)
  controller:update(dt)
  local mx, my = love.mouse.getPosition()
  local hovering = Input.is_hovering_clickable(controller, mx / SCALE, my / SCALE)
  love.mouse.setCursor(hovering and hand_cursor or arrow_cursor)
end

function love.draw()
  love.graphics.push()
  love.graphics.scale(SCALE, SCALE)
  View.draw(controller)
  love.graphics.pop()
end

-- Les callbacks souris de LÖVE donnent des coordonnées fenêtre réelle ; tout le
-- layout (view.lua, input.lua) raisonne dans l'espace logique 1280x720 mis à
-- l'échelle par love.graphics.scale() ci-dessus -- on convertit ici, une seule
-- fois, plutôt que de propager SCALE dans chaque calcul de rectangle.
function love.mousepressed(x, y, button)
  Input.mousepressed(controller, x / SCALE, y / SCALE, button)
end

function love.mousemoved(x, y)
  Input.mousemoved(controller, x / SCALE, y / SCALE)
end

-- Molette (2026-08-30, demande explicite -- défilement de la fenêtre "voir
-- le deck") : dx/dy pas convertis par SCALE, contrairement aux positions --
-- Input.wheelmoved n'en a pas besoin, ce sont de simples crans de molette,
-- pas des coordonnées écran.
function love.wheelmoved(dx, dy)
  Input.wheelmoved(controller, dx, dy)
end

function love.keypressed(key)
  if key == "escape" then love.event.quit() end
end
