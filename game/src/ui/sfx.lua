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
local C3, G3, C4, E4, G4, C5 = 130.81, 196.00, 261.63, 329.63, 392.00, 523.25

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

-- "shting" -- coup qui vient buter dans un bouclier déjà là, dégâts absorbés
-- en tout ou partie (2026-09-02, revirement -- servait AUSSI au gain de
-- bouclier jusqu'ici, "demandé explicitement identique" à l'époque -- voir
-- BUILDERS.shield_gain ci-dessous pour le nouveau son dédié au gain) : deux
-- notes carrées brillantes, façon impact métallique.
BUILDERS.shield = function()
  return Chiptune.concat({
    note(1200, 0.08, "square", 1.8, 0.5, 0.4),
    note(1600, 0.10, "square", 1.5, 0.5, 0.4),
  })
end

-- "wouch" -- gain de bouclier (2026-09-02, demande explicite -- "le son est
-- un 'wouch' montant") : désormais DISTINCT de "shting" ci-dessus, réservé au
-- coup qui absorbe -- même famille que "woosh" plus bas (bruit sous
-- enveloppe en cloche + tonalité carrée), mais la tonalité MONTE au lieu de
-- descendre, et beaucoup plus courte (accompagne juste le bouclier qui
-- "monte légèrement" à l'écran, pas une chute pleine largeur comme le chiffre
-- d'énergie).
BUILDERS.shield_gain = function()
  return Chiptune.render(0.28, function(t)
    local p = math.min(1, t / 0.28)
    local swell = math.sin(p * math.pi) -- 0 -> 1 -> 0
    local tone_freq = 500 + 700 * p
    return (Chiptune.noise() * 0.4 + Chiptune.square(tone_freq, t, 0.35) * 0.6) * swell
  end, 0.35)
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

-- "fluf" -- départ des pièces de l'écran de victoire (2026-09-02, demande
-- explicite -- "un bruit de fluf au départ") : simple souffle de bruit très
-- doux et court, DISTINCT de "woosh" (bien plus long/appuyé, pensé pour la
-- chute du gros chiffre d'énergie) -- volume bas façon "hover", jamais un
-- signal marquant, juste un souffle léger.
BUILDERS.fluf = function()
  return Chiptune.render(0.12, function(t)
    return Chiptune.noise() * Chiptune.decay(t, 0.12, 2.2)
  end, 0.25)
end

-- "cling" -- arrivée de CHAQUE pièce sur la bourse (2026-09-02, demande
-- explicite -- "un bruit... de cling à l'arrivée") : DISTINCT de "shting"
-- (BUILDERS.shield -- pensé pour un bouclier, plus grave/large) -- deux notes
-- carrées très aiguës et brèves, plus métallique/cristallin, à l'échelle
-- d'une seule pièce plutôt que d'un impact de bouclier.
BUILDERS.cling = function()
  return Chiptune.concat({
    note(2200, 0.05, "square", 2.2, 0.35, 0.25),
    note(2800, 0.07, "square", 1.8, 0.3, 0.2),
  })
end

-- "hover" -- survol d'un aventurier à l'écran de choix d'équipe (2026-08-30,
-- bug signalé -- "le son choisi pour le survol d'un aventurier est trop
-- agressif, il faut en choisir un beaucoup plus étouffé, plus neutre, plus
-- discret") : DISTINCT de "flush" (glissando carré aigu -> grave, pensé pour
-- un déplacement de carte -- bien trop tranchant pour un survol qui peut se
-- déclencher à chaque passage de souris) -- triangle grave, volume très bas,
-- très court : un clic sourd et neutre, jamais un signal marquant. Voir
-- Controller:team_select_hover, seul appelant.
BUILDERS.hover = function()
  return Chiptune.render(0.06, function(t)
    return Chiptune.triangle(220, t) * Chiptune.decay(t, 0.06, 2.5)
  end, 0.18)
end

-- "hop" -- un aventurier prêt à jouer en début de tour (2026-08-21, demande
-- explicite) : blip carré très court, aigu, énergique -- un par héros, au
-- rythme du saut échelonné (voir Controller:play_hero_ready_hops).
BUILDERS.hop = function()
  return Chiptune.render(0.09, function(t)
    return Chiptune.square(700, t, 0.4) * Chiptune.decay(t, 0.09, 1.8)
  end, 0.35)
end

-- "enemy_death" -- un ennemi vaincu qui se fissure puis explose en particules
-- (2026-08-30, demande explicite -- "il se fissure puis explose en
-- particules qui vanish") : 2 craquements secs (bruit très court, attaque
-- immédiate, comme une fissure qui cède) suivis d'un souffle grave qui
-- s'éteint (l'explosion elle-même) -- distinct de hit_physical/hit_magic, qui
-- couvrent déjà le COUP qui l'a achevé, pas ce qui suit une fois à 0 PV.
BUILDERS.enemy_death = function()
  return Chiptune.concat({
    note(0, 0.04, "noise", 3, 0.5),
    note(0, 0.05, "noise", 3, 0.5),
    Chiptune.render(0.5, function(t)
      return (Chiptune.noise() * 0.7 + Chiptune.square(60, t, 0.5) * 0.3) * Chiptune.decay(t, 0.5, 1.2)
    end, 0.55),
  })
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

-- "downgrade" -- écran "Construis ton deck" (2026-09-02, demande explicite --
-- clic droit sur une carte améliorée pour repasser en version normale, "un
-- petit son qui descend") : miroir exact de "upgrade" ci-dessus, mêmes 2
-- notes carrées mais dans l'ordre inverse (aiguë -> grave).
BUILDERS.downgrade = function()
  return Chiptune.concat({
    note(1318.51, 0.06, "square", 1.6, 0.4, 0.3),
    note(1046.50, 0.16, "square", 1.2, 0.45, 0.3),
  })
end

-- "forge_impact" -- conclusion de la fusion base -> améliorée à la Forge
-- (2026-08-30, demande explicite -- "le mouvement de carte ... se conclue par
-- un effet ou une animation") : DISTINCT de "eclat"/upgrade ci-dessus (joué
-- au CLIC, annonce le choix) -- ici, un éclat bref au moment précis où la
-- carte de base finit sa chute et fusionne dans l'améliorée, accent carré
-- suivi d'un scintillement triangle plus aigu.
BUILDERS.forge_impact = function()
  return Chiptune.concat({
    note(1568.00, 0.05, "square", 1.6, 0.45, 0.3),
    note(2093.00, 0.16, "triangle", 1.1, 0.4),
  })
end

-- "jingle" -- accueil au lancement du jeu (2026-08-30, demande explicite --
-- "un petit jingle d'accueil") : arpège carré vif jusqu'à une note tenue,
-- puis un scintillement triangle aigu à l'octave -- DISTINCT de "victory"
-- ci-dessous (notes bien plus courtes, attaque plus vive : un clin d'oeil de
-- bienvenue, pas une célébration de fin de combat). Joué une seule fois, à
-- l'ouverture de l'application -- voir Controller.new, seul appelant.
BUILDERS.jingle = function()
  return Chiptune.concat({
    note(C4, 0.08, "square", 1.6, 0.45, 0.4),
    note(E4, 0.08, "square", 1.6, 0.45, 0.4),
    note(G4, 0.08, "square", 1.6, 0.45, 0.4),
    note(C5, 0.22, "square", 1.0, 0.5, 0.4),
    note(C5 * 2, 0.28, "triangle", 1.2, 0.35), -- scintillement final à l'octave (C6)
  })
end

-- "run_start" -- lancement d'une nouvelle run (2026-08-30, demande explicite --
-- "un autre petit jingle, un peu plus grave, plus solennel") : DISTINCT de
-- "jingle" ci-dessus (accueil, aigu et vif) -- ici un impact grave (bruit +
-- carré bas, comme un coup de gong/tambour) suivi de 2 notes triangle
-- GRAVES et tenues, tempo bien plus lent : un début de quête qui s'annonce,
-- pas un logo qui scintille. Joué au lancement d'une run réelle -- voir
-- Controller:reset_run, seul appelant ("Tester le boss" reste un raccourci
-- technique, jamais concerné).
BUILDERS.run_start = function()
  return Chiptune.concat({
    Chiptune.render(0.22, function(t)
      return (Chiptune.noise() * 0.5 + Chiptune.square(70, t, 0.5) * 0.5) * Chiptune.decay(t, 0.22, 1.6)
    end, 0.55),
    note(C3, 0.35, "triangle", 0.9, 0.5),
    note(G3, 0.55, "triangle", 0.7, 0.55),
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

-- "hero_death" -- un aventurier tombe au combat (2026-08-30, demande
-- explicite -- "un son grave, déprimant, caractéristique de la mort") :
-- glissando triangle qui plonge lentement vers le grave sur toute sa durée,
-- doublé d'un souffle de bruit sourd au tout début (le coup qui l'achève) --
-- DISTINCT de "defeat" ci-dessus (fanfare complète de fin de RUN, plusieurs
-- notes qui descendent) : ici un seul ton qui s'éteint, pour UN aventurier
-- qui tombe, pas toute l'équipe qui est vaincue.
BUILDERS.hero_death = function()
  return Chiptune.render(1.3, function(t)
    local p = math.min(1, t / 1.3)
    local freq = 220 - 160 * p
    local thud = t < 0.12 and Chiptune.noise() * (1 - t / 0.12) * 0.5 or 0
    return Chiptune.triangle(freq, t) * Chiptune.decay(t, 1.3, 0.6) * 0.7 + thud
  end, 0.5)
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

-- ---------- Entrée en combat -- descente des ennemis (2026-08-30) ----------
-- "Un son caractéristique pour chaque ennemi" (demande explicite) : un
-- atterrissage synthétique DISTINCT par gabarit d'ennemi (léger/lourd/
-- discret/magique), pas une seule et même chute générique -- voir
-- Controller:play_enemy_entrance_sequence, seul appelant (clé
-- "enemy_land_" .. e.template_id, silencieux via Sfx.play si un futur
-- template n'a pas encore son entrée ici).

--- Atterrissage "physique" générique (gobelins, troll, golem...) : bruit +
-- tonalité carrée grave, percussif -- même famille que "plarf" (hit_physical)
-- mais SANS attaque immédiate au tout début (pas une morsure), pour ne
-- jamais se confondre avec un coup encaissé. `freq`/`duration` fixent le
-- gabarit (aigu-court = léger, grave-long = lourd) ; `noise_mix` la part de
-- bruit (sol/impact) contre la tonalité (corps qui résonne).
local function thud(freq, duration, noise_mix, curve, volume)
  return function()
    return Chiptune.render(duration, function(t)
      return (Chiptune.noise() * noise_mix + Chiptune.square(freq, t, 0.5) * (1 - noise_mix)) * Chiptune.decay(t, duration, curve)
    end, volume)
  end
end

BUILDERS.enemy_land_gobelin = thud(170, 0.18, 0.5, 1.6, 0.5)
BUILDERS.enemy_land_gobelourd = thud(100, 0.28, 0.55, 1.3, 0.55)
BUILDERS.enemy_land_troll = thud(45, 0.5, 0.6, 0.8, 0.65)
BUILDERS.enemy_land_golem = thud(35, 0.55, 0.65, 0.7, 0.68)
BUILDERS.enemy_land_loup = thud(230, 0.14, 0.35, 2.0, 0.45)
BUILDERS.enemy_land_bandit = thud(300, 0.10, 0.25, 2.4, 0.4)
BUILDERS.enemy_land_pousse = thud(550, 0.08, 0.25, 2.6, 0.28)
-- Homme Arbre (boss) : le plus grave, le plus long, le plus fort -- doit se
-- reconnaître à l'oreille avant même de voir le sprite descendre.
BUILDERS["enemy_land_homme-arbre"] = thud(26, 0.75, 0.6, 0.55, 0.75)

--- 3 courts claquements d'os secs, espacés de silence -- pas un "thud" du
-- tout (2026-08-30) : un squelette n'a rien de charnu pour faire résonner un
-- impact, juste un cliquetis à l'arrivée.
BUILDERS.enemy_land_squelette = function()
  local function clack(vol) return Chiptune.render(0.045, function(t) return Chiptune.noise() * Chiptune.decay(t, 0.045, 3) end, vol) end
  local function gap(dur) return Chiptune.render(dur, function() return 0 end, 0) end
  return Chiptune.concat({ clack(0.4), gap(0.03), clack(0.35), gap(0.03), clack(0.3) })
end

--- Skitter rapide de 4 blips aigus -- pas un atterrissage unique (2026-08-30) :
-- une araignée arrive en courant sur ses pattes, jamais en tombant lourdement.
BUILDERS.enemy_land_araignee = function()
  local function tick(freq, vol) return Chiptune.render(0.03, function(t) return Chiptune.square(freq, t, 0.3) * Chiptune.decay(t, 0.03, 3) end, vol) end
  local function gap(dur) return Chiptune.render(dur, function() return 0 end, 0) end
  return Chiptune.concat({ tick(900, 0.3), gap(0.02), tick(1100, 0.28), gap(0.02), tick(950, 0.26), gap(0.02), tick(1200, 0.24) })
end

--- Tonalité descendante inquiétante, pas percussive -- une apparition
-- magique, pas une chute (2026-08-30).
BUILDERS.enemy_land_necromancien = function()
  return Chiptune.render(0.5, function(t)
    local freq = 380 - 220 * math.min(1, t / 0.5)
    return (Chiptune.triangle(freq, t) * 0.7 + Chiptune.noise() * 0.25) * Chiptune.decay(t, 0.5, 1)
  end, 0.45)
end

--- Tremolo ASCENDANT (2026-08-30, distinct du Nécromancien -- direction et
-- rythme opposés pour ne jamais les confondre à l'oreille) : incantation
-- tribale plutôt qu'apparition sépulcrale.
BUILDERS.enemy_land_chaman = function()
  return Chiptune.render(0.45, function(t)
    local freq = 260 + 30 * math.sin(t * 26) + 140 * math.min(1, t / 0.45)
    return Chiptune.triangle(freq, t) * Chiptune.decay(t, 0.45, 0.9)
  end, 0.45)
end

-- Filet de sécurité (2026-08-30) : gabarit neutre si un futur template
-- d'ennemi n'a pas encore sa propre entrée ci-dessus -- Sfx.play resterait de
-- toute façon silencieux sans erreur, mais autant avoir un son plutôt que rien.
BUILDERS.enemy_land_default = thud(140, 0.2, 0.5, 1.6, 0.5)

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
