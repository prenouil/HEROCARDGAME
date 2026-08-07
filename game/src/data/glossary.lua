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
  { key = "pioche", icon = nil, has_icon = false, related = "", explain = "Pioche X carte(s)." },
  { key = "esquive", icon = nil, has_icon = false, related = "", explain = "Ne subit aucun dégât des X prochaines attaques (-1 Esquive à chaque attaque esquivée)." },
  { key = "saignement", icon = nil, has_icon = false, related = "", explain = "Inflige X dégâts brut à la fin du tour, -1 Saignement au début de chaque tour.", aliases = { "saignements" } },
  { key = "incapacite", icon = nil, has_icon = false, related = "", explain = "Inflige -25% de dégâts, -1 Incapacité au début de chaque tour." },
  { key = "vulnerabilite", icon = nil, has_icon = false, related = "", explain = "Reçoit +25% de dégâts, -1 Vulnérabilité au début de chaque tour." },
  { key = "camoufle", icon = nil, has_icon = false, related = "", explain = "Ne peut pas être ciblé par un ennemi tant qu'un autre allié est présent, jusqu'à la prochaine attaque." },
  { key = "puissance", icon = nil, has_icon = false, related = "", explain = "Les attaques physiques gagnent +25%, -1 Puissance au début de chaque tour." },
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
