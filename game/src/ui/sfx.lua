-- Bibliothèque de sons nommés (2026-08-09, party "son minimaliste façon NES").
-- Chaque son est une recette écrite avec src/ui/chiptune.lua (ondes carrée/
-- triangle/bruit), générée une seule fois puis mise en cache -- même
-- discipline de chargement paresseux que src/ui/sprites.lua. Aucun fichier
-- audio, aucune dépendance externe.

local Chiptune = require("src.ui.chiptune")

local Sfx = { enabled = true }

--- Un seul "temps" de son : forme d'onde + enveloppe de décroissance, rendu
-- en SoundData. `wave` : "square"|"triangle"|"noise". `duty` : ignoré hors "square".
local function note(freq, duration, wave, curve, volume, duty)
  local gen
  if wave == "triangle" then
    gen = function(t) return Chiptune.triangle(freq, t) end
  elseif wave == "noise" then
    gen = function(_) return Chiptune.noise() end
  else
    gen = function(t) return Chiptune.square(freq, t, duty) end
  end
  return Chiptune.render(duration, function(t)
    return gen(t) * Chiptune.decay(t, duration, curve or 1)
  end, volume)
end

-- Fréquences (tempérament égal, La4 = 440Hz) pour les fanfares.
local G3, C4, E4, G4, C5 = 196.00, 261.63, 329.63, 392.00, 523.25

local BUILDERS = {}

-- "flush" -- pioche de carte ET retournement au loot (même son, demandé
-- explicitement identique) : glissando carré aigu -> grave, très court.
BUILDERS.flush = function()
  return Chiptune.render(0.10, function(t)
    return Chiptune.sweep_square(1600, 500, t, 0.10, 0.3) * Chiptune.decay(t, 0.10, 1.5)
  end, 0.5)
end

-- "plarf" -- dégâts physiques : bruit + thump carré grave, percussif.
BUILDERS.hit_physical = function()
  return Chiptune.render(0.15, function(t)
    return (Chiptune.noise() * 0.6 + Chiptune.square(90, t, 0.5) * 0.4) * Chiptune.decay(t, 0.15, 2)
  end, 0.55)
end

-- "waof" -- dégâts magiques : triangle avec un vibrato descendant, plus aérien.
BUILDERS.hit_magic = function()
  return Chiptune.render(0.25, function(t)
    local freq = 500 + (250 - 500) * math.min(1, t / 0.25) + 15 * math.sin(t * 40)
    return Chiptune.triangle(freq, t) * Chiptune.decay(t, 0.25, 1)
  end, 0.5)
end

-- "shting" -- gain de bouclier ET dégâts intégralement absorbés (même son,
-- demandé explicitement identique) : deux notes carrées brillantes.
BUILDERS.shield = function()
  return Chiptune.concat({
    note(1200, 0.08, "square", 1.8, 0.5, 0.4),
    note(1600, 0.10, "square", 1.5, 0.5, 0.4),
  })
end

-- "roar" -- avant qu'un ennemi n'agisse : grondement grave, bruit + trémolo.
BUILDERS.enemy_telegraph = function()
  return Chiptune.render(0.4, function(t)
    local tremolo = 0.6 + 0.4 * math.sin(t * 18)
    return (Chiptune.noise() * 0.5 + Chiptune.square(70, t, 0.5) * 0.5) * tremolo * Chiptune.decay(t, 0.4, 0.7)
  end, 0.45)
end

-- "amah" -- concentration : triangle chaud, montée douce, volume bas.
BUILDERS.concentrate = function()
  return Chiptune.render(0.3, function(t)
    local freq = 300 + (420 - 300) * math.min(1, t / 0.3)
    return Chiptune.triangle(freq, t) * Chiptune.decay(t, 0.3, 0.8)
  end, 0.35)
end

-- "essor" -- soin/résurrection au feu de camp (2026-08-10) : glissando
-- triangle montant, plus ample que "concentrate" (celui-ci referme un état
-- de combat entier, pas un simple +1 énergie).
BUILDERS.heal = function()
  return Chiptune.render(0.42, function(t)
    local freq = 260 + (520 - 260) * math.min(1, t / 0.42)
    return Chiptune.triangle(freq, t) * Chiptune.decay(t, 0.42, 0.9)
  end, 0.45)
end

-- "eclat" -- amélioration de carte au feu de camp (2026-08-10) : deux notes
-- carrées aiguës qui montent, distinct de "flush" (plus haut, decay plus lent --
-- une carte qui monte en puissance, pas qui se déplace).
BUILDERS.upgrade = function()
  return Chiptune.concat({
    note(1046.50, 0.06, "square", 1.6, 0.4, 0.3),
    note(1318.51, 0.16, "square", 1.2, 0.45, 0.3),
  })
end

-- Fanfare de victoire : arpège carré montant + note tenue.
BUILDERS.victory = function()
  return Chiptune.concat({
    note(C4, 0.12, "square", 1, 0.5, 0.5),
    note(E4, 0.12, "square", 1, 0.5, 0.5),
    note(G4, 0.12, "square", 1, 0.5, 0.5),
    note(C5, 0.4, "square", 0.6, 0.55, 0.5),
  })
end

-- Fanfare de défaite : triangle descendant, plus lent, note grave tenue.
BUILDERS.defeat = function()
  return Chiptune.concat({
    note(G4, 0.18, "triangle", 1, 0.45),
    note(E4, 0.18, "triangle", 1, 0.45),
    note(C4, 0.22, "triangle", 1, 0.45),
    note(G3, 0.55, "triangle", 0.8, 0.5),
  })
end

local cache = {}

local function get(name)
  local sd = cache[name]
  if not sd then
    local builder = BUILDERS[name]
    if not builder then return nil end
    sd = builder()
    cache[name] = sd
  end
  return sd
end

--- Joue un son nommé -- crée une nouvelle Source à chaque appel (le SoundData
-- en cache est réutilisé, immuable) pour que deux occurrences puissent se
-- superposer sans se couper. Silencieux si `Sfx.enabled` est faux ou si le
-- nom n'existe pas -- jamais une erreur qui interromprait le jeu.
function Sfx.play(name)
  if not Sfx.enabled then return end
  local ok, sd = pcall(get, name)
  if not ok or not sd then return end
  local source = love.audio.newSource(sd, "static")
  source:play()
end

return Sfx
