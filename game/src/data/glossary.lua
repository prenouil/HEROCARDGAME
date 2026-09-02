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
  -- "PO" (or, 2026-09-02, nouvelle ressource persistante -- voir state.gold
  -- dans game.lua) : contrairement à l'énergie/le mana, jamais remise à 0 en
  -- cours de run -- gagnée à chaque victoire (Game.compute_gold_reward).
  { key = "or", icon = "\u{1FA99}", label = "or", has_icon = true, related = "or", explain = "Ressource persistante de l'équipe, gagnée à chaque victoire. Ne se réinitialise jamais en cours de run." },
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
  -- "-1 Puissance au début de chaque tour, aventurier seulement" (2026-09-02,
  -- 1ère correction -- contredisait la description de "Cœur en Fusion"/
  -- "Surchauffe"/etc., "ne redescend jamais seule") : reformulé pour ne plus
  -- affirmer une règle universelle qui n'était pas vraie à l'époque (seuls
  -- les aventuriers décroissaient alors, voir l'ancien Game.start_turn).
  -- 2ᵉ correction, MÊME JOUR (demande explicite -- "la puissance descend à la
  -- fin de chaque tour, que ce soit pour les aventuriers ou les ennemis") :
  -- cette 1ère reformulation elle-même n'a jamais été remise à jour après ce
  -- changement de règle -- Puissance décroît désormais en FIN de tour, de
  -- façon SYMÉTRIQUE (voir Game.decay_end_of_turn_statuses, SEUL endroit du
  -- code qui la décrémente maintenant) -- la mention "certains ennemis n'en
  -- perdent jamais seuls" décrit en réalité Incandescence (voir son entrée
  -- ci-dessous), plus Puissance, qui n'a plus cette exception.
  { key = "puissance", icon = nil, has_icon = false, related = "", explain = "Les attaques physiques gagnent +25% par charge. -1 en fin de tour, pour les aventuriers comme pour les ennemis." },
  -- "Incandescence" (2026-09-02, demande explicite -- remplace l'ancien
  -- détournement de Puissance sur les ennemis du Volcan, "marche comme la
  -- puissance sauf qu'elle ne descend pas") : REVIREMENT le même jour --
  -- "plutôt que +25% de dégâts, donne +X aux dégâts, X étant la valeur
  -- d'Incandescence actuelle" -- bonus FLAT (voir Combat.incandescence_flat),
  -- pas multiplicatif comme Puissance, additionné AVANT tout multiplicateur
  -- (même étage que Inspiration, voir Combat.deal_damage) -- ne décroît
  -- JAMAIS toute seule, ça, en revanche, inchangé -- même famille que
  -- Vol/Brûlure.
  { key = "incandescence", icon = nil, has_icon = false, related = "", explain = "Les attaques physiques gagnent +X dégâts, X étant la valeur actuelle. Ne perd jamais de charge automatiquement." },
  -- "Vol" (2026-08-30, second boss -- l'Aigle Géant, voir enemies.lua) : ne
  -- décroît PAS tout seul (contrairement à Incapacité/Vulnérabilité
  -- ci-dessus) -- seule "Charge en Piqué" le retire, voir Game.resolve_enemy_action.
  { key = "vol", icon = nil, has_icon = false, related = "", explain = "Les dégâts de type \"épée\" (physique) sont réduits à 0. Retiré par Charge en Piqué." },
  -- "Brûlure" (2026-09-01, nouveau statut transversal, Volcan) : ne décroît
  -- JAMAIS toute seule (contrairement à Saignement ci-dessus, -1/tour) --
  -- reste à sa valeur tant que rien ne la retire explicitement (rien ne le
  -- fait pour l'instant, voir Game.tick_burn).
  { key = "brulure", icon = nil, has_icon = false, related = "", explain = "Inflige X dégâts brut à la fin du tour. Ne perd jamais de charge automatiquement (contrairement à Saignement).", aliases = { "brulures" } },
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
  { key = "furtif", icon = nil, has_icon = false, related = "", explain = "Donne 2 Discrétion si défaussée sans avoir été jouée." },
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
  -- voir content/memory/ -- sélectionnables à l'écran de choix d'équipe, voir
  -- Heroes.defs/Controller:enter_team_select). "necrose" : dégâts
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
  -- porteur (quelle que soit sa classe) -- ne se perd plus en fin de tour
  -- (2026-09-02, simplification explicite, voir Game.decay_end_of_turn_statuses).
  { key = "encore", icon = nil, has_icon = false, related = "", explain = "La prochaine carte jouée par le porteur ce tour se déclenche des fois supplémentaires." },
  -- Gratuite (2026-09-02, statut GÉNÉRIQUE -- carte "Bis" du Barde,
  -- hero.gratuite) : voir Combat.effective_cost/Game.on_card_played.
  { key = "gratuite", icon = nil, has_icon = false, related = "", explain = "Tant que Gratuite > 0, toutes les cartes de l'aventurier coûtent et affichent 0 en énergie. -1 à chaque utilisation." },
}

-- Repli ASCII des lettres accentuées françaises (2026-08-30, bug signalé --
-- "L'Amnésique stipule que les cartes gagnent Amnésie, mais rien n'explique
-- son fonctionnement", voir tooltip_lines/append_missing_keyword_explanations
-- dans view.lua) : un texte libre (description de bénédiction/malédiction du
-- Temple, description de classe...) doit pouvoir citer un mot-clé "Vulnérabilité"
-- ou "Discrétion" ENTRE GUILLEMETS avec ses accents normaux, pour un affichage
-- naturel une fois passé par Glossary.render_card_text -- sans repli, un simple
-- gsub("[^a-z]","") supprimait les OCTETS UTF-8 des lettres accentuées au lieu
-- de les convertir (ex. "Vulnérabilité" -> "vulnrabilit", jamais égal à la clé
-- "vulnerabilite") : ce mot-clé pourtant bien écrit entre guillemets n'était
-- alors JAMAIS reconnu par Glossary.keywords_present. Table bornée aux lettres
-- réellement utilisées dans ce jeu (pas un vrai NFD Unicode général, inutile
-- ici) ; :lower() en tête ne convertit QUE l'ASCII (É/È/... restent tels quels,
-- byte-based) -- d'où les entrées majuscules explicites ci-dessous.
local ACCENT_FOLD = {
  ["à"] = "a", ["â"] = "a", ["ä"] = "a", ["À"] = "a", ["Â"] = "a", ["Ä"] = "a",
  ["é"] = "e", ["è"] = "e", ["ê"] = "e", ["ë"] = "e",
  ["É"] = "e", ["È"] = "e", ["Ê"] = "e", ["Ë"] = "e",
  ["î"] = "i", ["ï"] = "i", ["Î"] = "i", ["Ï"] = "i",
  ["ô"] = "o", ["ö"] = "o", ["Ô"] = "o", ["Ö"] = "o",
  ["ù"] = "u", ["û"] = "u", ["ü"] = "u", ["Ù"] = "u", ["Û"] = "u", ["Ü"] = "u",
  ["ç"] = "c", ["Ç"] = "c",
}
local function normalize_kw(w)
  w = w:lower()
  for accented, plain in pairs(ACCENT_FOLD) do
    w = w:gsub(accented, plain)
  end
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
