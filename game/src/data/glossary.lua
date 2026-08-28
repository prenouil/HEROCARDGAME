-- Glossaire de mots-clés (tableur "Système de jeu", 23 termes).
-- Port fidèle de GLOSSARY / GLOSSARY_INDEX / renderCardText / cardKeywordsPresent
-- depuis prototype/proto-cartes-completes/index.html.
-- hasIcon = colonne "Icone" = "yes" dans le tableur source. Les entrées "no" restent
-- en texte (juste débarrassées des guillemets par render_card_text).
--
-- `label` : repli texte utilisé par la UI LÖVE, dont la police par défaut ne
-- contient pas ces glyphes emoji (ils ne s'affichent pas du tout sinon). `icon`
-- reste la vraie donnée de design (fidèle au tableur) pour une police/un rendu
-- capable de les afficher plus tard (voir README du dossier game/).

local Glossary = {}

Glossary.terms = {
  { key = "energie", icon = "\u{26A1}", label = "énergie", has_icon = true, related = "énergie", explain = "" },
  { key = "mana", icon = "\u{1F535}", label = "mana", has_icon = true, related = "mana", explain = "Ressource propre au Mage : ne se régénère jamais seule, seules des cartes peuvent l'augmenter." },
  { key = "epee", icon = "\u{2694}\u{FE0F}", label = "épée", has_icon = true, related = "dégats physique de mélée", explain = "" },
  { key = "arc", icon = "\u{1F3F9}", label = "arc", has_icon = true, related = "dégats physique à distance", explain = "" },
  { key = "brut", icon = "\u{1F4A5}", label = "brut", has_icon = true, related = "dégats brut", explain = "Ne tient pas compte des boucliers ou barrières." },
  { key = "bouclier", icon = "\u{1F6E1}\u{FE0F}", label = "bouclier", has_icon = true, related = "défense physique", explain = "" },
  { key = "barriere", icon = "\u{1F538}", label = "barrière", has_icon = true, related = "défense magique", explain = "" },
  { key = "concentration", icon = "\u{1F300}", label = "concentration", has_icon = true, related = "concentration", explain = "", aliases = { "concentre" } },
  { key = "epeefeu", icon = "\u{1F525}\u{2694}\u{FE0F}", label = "épée de feu", has_icon = true, related = "dégâts physique feu", explain = "" },
  { key = "fireball", icon = "\u{1F525}", label = "feu", has_icon = true, related = "dégâts magique feu", explain = "" },
  { key = "etincelle", icon = "\u{2728}", label = "magie", has_icon = true, related = "dégâts magique", explain = "" },
  { key = "poison", icon = "\u{2620}\u{FE0F}", label = "poison", has_icon = true, related = "dégat brut", explain = "" },
  { key = "sort", icon = "\u{1FA84}", label = "sort", has_icon = true, related = "sort", explain = "" },
  { key = "pv", icon = "\u{2764}\u{FE0F}", label = "PV", has_icon = true, related = "", explain = "Point de vie." },
  { key = "soin", icon = "\u{1F49A}", label = "soin", has_icon = true, related = "soin", explain = "" },
  { key = "cibleennemi", icon = "\u{26A0}\u{FE0F}", label = "[ciblé]", has_icon = true, related = "", explain = "Ciblé par un ennemi.", aliases = { "cibleenemi", "ennemicible" } },
  { key = "alliecible", icon = "\u{1F91D}", label = "[allié]", has_icon = true, related = "", explain = "Cible un allié." },
  -- Toujours au pluriel, jamais "(s)" (2026-08-21, demande explicite -- accord
  -- fautif accepté à X=1 plutôt que la parenthèse, voir decision-log/mémoire).
  { key = "pioche", icon = nil, has_icon = false, related = "", explain = "Pioche X cartes." },
  { key = "esquive", icon = nil, has_icon = false, related = "", explain = "Ne subit aucun dégât des X prochaines attaques (-1 Esquive à chaque attaque esquivée)." },
  { key = "saignement", icon = nil, has_icon = false, related = "", explain = "Inflige X dégâts brut à la fin du tour, -1 Saignement au début de chaque tour.", aliases = { "saignements" } },
  { key = "incapacite", icon = nil, has_icon = false, related = "", explain = "Inflige -25% de dégâts, -1 Incapacité au début de chaque tour." },
  { key = "vulnerabilite", icon = nil, has_icon = false, related = "", explain = "Reçoit +25% de dégâts, -1 Vulnérabilité au début de chaque tour." },
  { key = "camoufle", icon = nil, has_icon = false, related = "", explain = "Ne peut pas être ciblé par un ennemi. Reste tant qu'un allié est en vie et jusqu'à jouer une carte." },
  { key = "puissance", icon = nil, has_icon = false, related = "", explain = "Les attaques physiques gagnent +25%, -1 Puissance au début de chaque tour." },
  -- Discrétion (2026-08-24, ressource propre à l'Assassin, DISTINCTE de
  -- Camouflé -- voir hero.discretion/Game.gain_discretion dans game.lua) :
  -- pas un statut de combat classique (pas de décroissance de fin de tour),
  -- affichée en gros sous le portrait de l'Assassin comme la mana du Mage
  -- (voir draw_hero dans view.lua), pas via ce badge -- entrée gardée pour
  -- que les mentions "Discrétion" entre guillemets sur les cartes
  -- (toutes les cartes de l'Assassin, voir cards.lua) restent reconnues par RichText.
  { key = "discretion", icon = nil, has_icon = false, related = "", explain = "Ressource propre à l'Assassin (0 à 10) : +1 quand un autre héros joue une carte, +5 s'il termine le tour sans en avoir joué. À 10, devient Camouflé. Repart à 0 dès que l'Assassin joue une carte non-Furtif, ou dès qu'il reçoit des dégâts." },
  -- "Furtif" (2026-08-28, ajouté après coup -- l'utilisateur a d'abord donné
  -- les cartes/la description de classe, puis précisé ce mot-clé séparément) :
  -- porté par toutes les cartes de l'Assassin (voir cards.lua) -- Icone/Statut
  -- "no" dans le tableur source : jamais de pastille dédiée sur le cadre du
  -- héros (contrairement à Discrétion, affichée sous le portrait), juste ce
  -- texte entre guillemets sur la carte elle-même. Effet réel implémenté dans
  -- Game.on_card_played (pas de perte de Discrétion/Camouflé en la jouant) et
  -- Game.grant_furtif_discard_discretion (+2 Discrétion si défaussée non
  -- jouée) -- cette entrée ne sert qu'à l'explication affichée, jamais une
  -- deuxième source de vérité sur l'effet.
  { key = "furtif", icon = nil, has_icon = false, related = "", explain = "Ne fait pas perdre de Discrétion en la jouant. Donne 2 Discrétion si défaussée sans avoir été jouée." },
  -- Provocation (2026-08-28, statut propre au Paladin, clarifié après coup) :
  -- vrai statut de combat contrairement à Discrétion -- badge sur le cadre du
  -- héros comme Puissance/Esquive (voir STATUS_TOOLTIP_FIELDS dans view.lua),
  -- décroissance -1/tour gérée par Game.start_turn (pas
  -- Game.decay_end_of_turn_statuses, voir son commentaire).
  { key = "provocation", icon = nil, has_icon = false, related = "", explain = "Le personnage a +50% de chances d'être ciblé par les ennemis. -1 Provocation au début de chaque tour." },
  -- Amnésie (2026-08-28, carte Clairvoyance du Paladin) : Icone/Statut "no"
  -- dans le tableur source -- jamais de badge sur un héros (ce n'est pas un
  -- statut de personnage, juste une propriété de LA CARTE), texte entre
  -- guillemets sur la carte elle-même. Effet réel implémenté dans
  -- Game.finish_card (zone `state.exhausted`, repêchée au combat suivant par
  -- Game.start_next_combat/start_boss_combat) -- cette entrée ne sert qu'à
  -- l'explication affichée, jamais une deuxième source de vérité.
  { key = "amnesie", icon = nil, has_icon = false, related = "", explain = "Après utilisation, la carte disparaît pour le reste du combat (elle revient au combat suivant)." },
  -- Nécromancien/Barde (2026-08-29, 2 classes conçues avec agent_content --
  -- voir memory/ -- codées et testées via busted, mais PAS encore ajoutées à
  -- Heroes.defs/au roster actif : une vraie run reste à 4 héros tant qu'une
  -- décision de sélection d'équipe n'est pas prise). "necrose" : dégâts
  -- magiques nécrotiques, se comporte exactement comme "etincelle" (Vulnérabilité
  -- s'applique, Puissance non -- réservée aux dégâts "physique", voir
  -- Combat.damage_multiplier) -- seul le nom/la thématique diffèrent.
  { key = "necrose", icon = nil, has_icon = false, related = "dégâts magique nécrotique", explain = "" },
  -- Corruption (ressource propre au Nécromancien, DISTINCTE d'un statut de
  -- combat classique comme Puissance -- voir hero.corruption dans game.lua) :
  -- gagnée automatiquement à toute VRAIE perte de PV (Combat.deal_damage/
  -- Game.tick_bleed), jamais posée directement par une carte. Repart à 0 à
  -- chaque nouveau combat (contrairement à Mana/Discrétion, qui ont un bug
  -- connu de non-reset -- voir reference_reset-ressource-par-combat.md côté
  -- agent_content -- Corruption doit s'en affranchir dès le départ).
  { key = "corruption", icon = nil, has_icon = false, related = "", explain = "Ressource propre au Nécromancien : +1 par PV perdu (dégâts subis ou PV sacrifiés par ses propres cartes), repart à 0 à chaque nouveau combat. Certaines cartes en dépensent jusqu'à un plafond pour amplifier leur effet." },
  -- Inspiration (statut GÉNÉRIQUE, pas propre au Barde -- n'importe quel héros
  -- peut le recevoir, voir hero.inspiration dans game.lua) : contrairement à
  -- Puissance/Vulnérabilité (qui modifient un CALCUL), Inspiration ajoute un
  -- montant FLAT au premier effet de dégâts/soin/bouclier que son porteur
  -- déclenche en jouant une carte, quelle que soit sa classe -- c'est le coeur
  -- de la synergie inter-classes du Barde (voir feedback_synergie-inter-classes.md).
  { key = "inspiration", icon = nil, has_icon = false, related = "", explain = "+6 flat au premier effet de dégâts/soin/bouclier que le porteur déclenche en jouant une carte (quelle que soit sa classe). -1 charge à cette utilisation, ET -1 automatique à la fin de chaque tour (les deux peuvent se cumuler le même tour)." },
  -- Encore (statut secondaire de la carte "Bis" du Barde -- hero.encore_extra_plays) :
  -- généré par Bis, consommé par le PROCHAIN effet de carte joué par le
  -- porteur (quelle que soit sa classe), ou perdu en fin de tour si inutilisé.
  { key = "encore", icon = nil, has_icon = false, related = "", explain = "La prochaine carte jouée par le porteur ce tour se déclenche des fois supplémentaires. Perdu en fin de tour si aucune carte n'est jouée avant." },
}

-- Lowercase + strip everything but a-z. Le jeu de cartes source n'utilise que des
-- mots-clés déjà non-accentués entre guillemets (ex. "epee", pas "épée"), donc une
-- normalisation ASCII simple reproduit fidèlement le comportement de l'original
-- (qui passait par un NFD Unicode plus général, inutile ici).
local function normalize_kw(w)
  w = w:lower()
  w = w:gsub("[^a-z]", "")
  return w
end
Glossary.normalize_kw = normalize_kw

local index = {}
for _, g in ipairs(Glossary.terms) do
  index[normalize_kw(g.key)] = g
  for _, alias in ipairs(g.aliases or {}) do
    index[normalize_kw(alias)] = g
  end
end
Glossary.index = index

function Glossary.find_term(word)
  return index[normalize_kw(word)]
end

-- Remplace les mots-clés entre guillemets par leur repli texte (si le glossaire
-- en indique un — la police par défaut de LÖVE ne rend pas les icônes emoji,
-- voir l'en-tête du fichier), ou dégrafe simplement les guillemets sinon.
function Glossary.render_card_text(text)
  return (text:gsub('"([^"]+)"', function(inner)
    local g = Glossary.find_term(inner)
    if g and g.has_icon then return g.label or g.icon end
    return inner
  end))
end

-- Mots-clés du glossaire réellement présents (entre guillemets) dans un texte de carte,
-- dans l'ordre, sans doublon.
function Glossary.keywords_present(text)
  local found, seen = {}, {}
  for inner in text:gmatch('"([^"]+)"') do
    local g = Glossary.find_term(inner)
    if g and not seen[g.key] then
      seen[g.key] = true
      found[#found + 1] = g
    end
  end
  return found
end

function Glossary.has_keyword(text, key)
  for _, g in ipairs(Glossary.keywords_present(text)) do
    if g.key == key then return true end
  end
  return false
end

return Glossary
