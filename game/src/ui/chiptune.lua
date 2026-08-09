-- Synthèse audio procédurale façon NES : ondes carrée/triangle/bruit générées
-- échantillon par échantillon dans un SoundData LÖVE, comme le faisait le
-- chip audio de la console (pas de sample enregistré, aucun fichier). Module
-- pur -- ne connaît rien du jeu, juste des générateurs de formes d'onde et
-- d'enveloppes que src/ui/sfx.lua compose en sons nommés.

local Chiptune = {}

local SAMPLE_RATE = 22050 -- suffisant pour du 8-bit, plus léger que 44100

--- Onde carrée à `duty` variable (0.5 = carrée symétrique, plus bas = plus nasillard).
function Chiptune.square(freq, t, duty)
  local phase = (t * freq) % 1
  return phase < (duty or 0.5) and 1 or -1
end

function Chiptune.triangle(freq, t)
  local phase = (t * freq) % 1
  return 4 * math.abs(phase - 0.5) - 1
end

function Chiptune.noise()
  return math.random() * 2 - 1
end

--- Glissando : interpole la fréquence entre f0 et f1 sur `duration`, en carré.
function Chiptune.sweep_square(f0, f1, t, duration, duty)
  local freq = f0 + (f1 - f0) * math.min(1, t / duration)
  return Chiptune.square(freq, t, duty)
end

--- Enveloppe de décroissance : 1 au départ, 0 à `duration`. `curve` > 1 =
-- attaque franche puis chute rapide (percussif) ; `curve` < 1 = plus doux.
function Chiptune.decay(t, duration, curve)
  return (1 - math.min(1, math.max(0, t / duration))) ^ (curve or 1)
end

--- Construit un SoundData mono à partir d'une fonction `fn(t) -> [-1, 1]`.
-- `volume` (0..1, défaut 0.6) évite la saturation quand plusieurs sons se
-- superposent.
function Chiptune.render(duration, fn, volume)
  volume = volume or 0.6
  local n = math.max(1, math.floor(SAMPLE_RATE * duration))
  local sd = love.sound.newSoundData(n, SAMPLE_RATE, 16, 1)
  for i = 0, n - 1 do
    local t = i / SAMPLE_RATE
    local v = math.max(-1, math.min(1, fn(t) * volume))
    sd:setSample(i, v)
  end
  return sd
end

--- Concatène plusieurs SoundData (même format) bout à bout -- pour les
-- fanfares en une seule source jouable plutôt qu'un séquenceur de sons.
function Chiptune.concat(pieces)
  local total = 0
  for _, sd in ipairs(pieces) do total = total + sd:getSampleCount() end
  local out = love.sound.newSoundData(total, SAMPLE_RATE, 16, 1)
  local offset = 0
  for _, sd in ipairs(pieces) do
    local n = sd:getSampleCount()
    for i = 0, n - 1 do out:setSample(offset + i, sd:getSample(i)) end
    offset = offset + n
  end
  return out
end

return Chiptune
