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

-- "woosh" -- le gros chiffre d'énergie qui chute sur sa pastille en début de
-- tour (2026-08-21, demande explicite) : bruit sous une enveloppe en cloche
-- (monte puis retombe, façon d'air qui passe -- pas de filtre passe-bande
-- disponible dans ce synthé minimaliste, l'enveloppe fait l'essentiel du
-- travail) doublé d'une tonalité carrée qui descend en hauteur, comme un
-- objet qui tombe.
BUILDERS.woosh = function()
  return Chiptune.render(0.45, function(t)
    local p = math.min(1, t / 0.45)
    local swell = math.sin(p * math.pi) -- 0 -> 1 -> 0
    local tone_freq = 700 - 500 * p
    return (Chiptune.noise() * 0.7 + Chiptune.square(tone_freq, t, 0.35) * 0.3) * swell
  end, 0.4)
end

-- "flup" -- déplacement de cartes entre piles (2026-08-21, demande explicite --
-- pioche -> main, main -> défausse, défausse -> pioche) : bruit filtré avec un
-- souffle triangle grave en dessous. Volume et durée relevés (2026-08-21,
-- signalé inaudible -- 0.4/0.14s à l'origine, noyé notamment par le son de
-- dégâts qui joue quasi simultanément quand une carte jouée part en défausse,
-- voir Controller:select_card -- react_to_diff puis maybe_animate_played_discard
-- dans la foulée) : 0.65/0.20s désormais, volume comparable à "plarf" (0.55)
-- plutôt qu'en retrait, pour percer même superposé à un autre son.
BUILDERS.flup = function()
  return Chiptune.render(0.20, function(t)
    return (Chiptune.noise() * 0.55 + Chiptune.triangle(180, t) * 0.45) * Chiptune.decay(t, 0.20, 1.4)
  end, 0.65)
end

-- "hop" -- un aventurier prêt à jouer en début de tour (2026-08-21, demande
-- explicite) : blip carré très court, aigu, énergique -- un par héros, au
-- rythme du saut échelonné (voir Controller:play_hero_ready_hops).
BUILDERS.hop = function()
  return Chiptune.render(0.09, function(t)
    return Chiptune.square(700, t, 0.4) * Chiptune.decay(t, 0.09, 1.8)
  end, 0.35)
end

-- "roar" -- avant qu'un ennemi n'agisse : grondement grave, bruit + trémolo.
BUILDERS.enemy_telegraph = function()
  return Chiptune.render(0.4, function(t)
    local tremolo = 0.6 + 0.4 * math.sin(t * 18)
    return (Chiptune.noise() * 0.5 + Chiptune.square(70, t, 0.5) * 0.5) * tremolo * Chiptune.decay(t, 0.4, 0.7)
  end, 0.45)
end

-- "essor" -- soin/résurrection au feu de camp (2026-08-10) : glissando
-- triangle montant, ample et chaud -- referme un état de combat entier,
-- pas un petit geste ponctuel.
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

-- "cendre" -- carte "Amnésie" qui se disperse en cendres au lieu de partir en
-- défausse (2026-08-28, demande explicite) : bruit sec sans hauteur, decay
-- rapide -- un "pfft" de matière qui s'effrite, distinct de "flup"
-- (déplacement de carte) et "eclat" (amélioration).
BUILDERS.ash = function()
  return Chiptune.render(0.28, function(t)
    return Chiptune.noise() * Chiptune.decay(t, 0.28, 2.2)
  end, 0.5)
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
