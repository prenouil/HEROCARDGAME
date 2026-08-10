-- Générateur pseudo-aléatoire seedable, indépendant de math.random (2026-08-10,
-- demande explicite : tirages reproductibles à l'identique pour un run donné, même
-- après un redémarrage de combat ou de tour). LCG 32 bits (paramètres Numerical
-- Recipes) : pas de besoin cryptographique ici, juste une séquence déterministe et
-- rapide. Chaque "système" (voir Game.reset_run) porte son propre flux, avec son
-- propre état qui n'avance QUE quand CE système tire un nombre -- rejouer un flux
-- ne dépend jamais de combien de fois les AUTRES ont été sollicités entre-temps.

local Rng = {}
Rng.__index = Rng

function Rng.new(seed)
  local self = setmetatable({}, Rng)
  self.seed = math.floor(seed or os.time())
  self.state = self.seed % 4294967296
  if self.state <= 0 then self.state = self.state + 4294967296 end
  return self
end

--- Flottant dans [0, 1).
function Rng:next_float()
  self.state = (self.state * 1664525 + 1013904223) % 4294967296
  return self.state / 4294967296
end

--- Même interface que math.random : random() -> [0,1) ; random(n) -> entier [1,n] ;
-- random(m,n) -> entier [m,n].
function Rng:random(a, b)
  if a == nil then return self:next_float() end
  if b == nil then a, b = 1, a end
  return a + math.floor(self:next_float() * (b - a + 1))
end

return Rng
