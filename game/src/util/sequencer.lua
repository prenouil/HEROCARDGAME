-- Petit ordonnanceur d'actions temporisées : remplace les chaînes async/await +
-- setTimeout du prototype JS (pulses, pauses d'1s entre chaque ennemi, etc.) par
-- une file d'étapes consommée à chaque love.update(dt). Écrit pour ce port —
-- ce n'est pas une bibliothèque tierce vendue telle quelle.
--
-- Usage :
--   local seq = Sequencer.new()
--   seq:push(function() ... end, 1.0)  -- exécute, puis attend 1s avant l'étape suivante
--   -- dans love.update(dt) : seq:update(dt)

local Sequencer = {}
Sequencer.__index = Sequencer

function Sequencer.new()
  return setmetatable({ queue = {}, timer = 0, busy = false }, Sequencer)
end

--- Ajoute une étape : run_fn s'exécute quand son tour vient ; wait_after (secondes,
-- optionnel) retarde le passage à l'étape suivante d'autant.
function Sequencer:push(run_fn, wait_after)
  self.queue[#self.queue + 1] = { run = run_fn, wait = wait_after or 0 }
end

--- Vrai quand plus rien n'est en attente ni en cours.
function Sequencer:is_idle()
  return #self.queue == 0 and not self.busy
end

function Sequencer:update(dt)
  if self.busy then
    self.timer = self.timer - dt
    if self.timer <= 0 then self.busy = false end
    return
  end
  local step = table.remove(self.queue, 1)
  if not step then return end
  step.run()
  if step.wait and step.wait > 0 then
    self.busy = true
    self.timer = step.wait
  end
end

function Sequencer:clear()
  self.queue = {}
  self.busy = false
  self.timer = 0
end

return Sequencer
