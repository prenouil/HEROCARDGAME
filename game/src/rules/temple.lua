-- Écran "Le Temple" (Run Infini, 2026-08-28, demande explicite -- refonte
-- complète du 2026-08-29 : liste complète de 8 bénédictions + 8 malédictions
-- fournie par l'utilisateur). À chaque visite, un TYPE est tiré au hasard
-- (bénédiction OU malédiction, jamais les deux), puis jusqu'à
-- Temple.CHOICE_COUNT (3) effets DISTINCTS de ce type sont proposés, montrés
-- en ligne au-dessus des aventuriers (voir draw_temple, view.lua). Le joueur
-- choisit 1 aventurier ET 1 effet puis confirme -- AUCUN "Passer" sur cet
-- écran (2026-08-29, demande explicite -- "il ne peut pas ne pas choisir") :
-- si aucun type n'a ni effet disponible ni aventurier éligible, l'écran
-- n'apparaît simplement pas du tout (voir Controller:enter_temple_screen).
--
-- Chaque héros ne peut porter QU'UNE bénédiction et QU'UNE malédiction à la
-- fois (2 champs indépendants, hero.blessing/hero.curse -- un aventurier PEUT
-- cumuler les deux) : "on ne peut pas choisir un aventurier qui possède déjà
-- la bénédiction/malédiction" -- interprété comme "qui a déjà CE TYPE
-- d'effet", pas seulement ce même id précis (le champ est un scalaire, pas un
-- ensemble). Chaque bénédiction/malédiction n'est PAS retirée du pool après
-- avoir été attribuée à un aventurier -- rien n'empêche qu'elle réapparaisse
-- et soit donnée à un AUTRE aventurier plus tard dans le même run.
--
-- Effets déclaratifs (2026-08-29) : chaque entrée porte directement les
-- champs que game.lua/combat.lua/encounter.lua/deck.lua savent déjà lire
-- (combat_start_heal, combat_start_damage, combat_start_status, etc.) --
-- voir Game.apply_combat_start_temple_effects, seul endroit qui les
-- retranscrit en CHAMPS SIMPLES sur le héros (hero.thorns, hero.card_cost_delta,
-- ...), copiés UNE FOIS à chaque entrée en combat. Les autres modules ne
-- connaissent donc jamais "Temple"/"blessing"/"curse" -- seulement ces champs
-- simples, exactement comme hero.discretion/hero.camoufle déjà avant eux.

local Temple = {}

Temple.CHOICE_COUNT = 3

-- `color` : couleur de la statue (voir draw_temple_statue, view.lua) -- purement
-- visuelle, jamais lue par les règles.
Temple.effects = {
  -- ---------- Bénédictions ----------
  {
    id = "guerisseuse", type = "blessing", name = "La Guérisseuse", color = "vert",
    desc = "Soin 5 à chaque début de combat.",
    combat_start_heal = 5,
  },
  {
    id = "illusionniste", type = "blessing", name = "L'Illusionniste", color = "bleu",
    desc = "Esquive 1 au début de chaque combat.",
    combat_start_status = { esquive = 1 },
  },
  {
    id = "puissant", type = "blessing", name = "Le Puissant", color = "rouge",
    desc = "Puissance 3 au début de chaque combat.",
    combat_start_status = { puissance = 3 },
  },
  {
    id = "renaissante", type = "blessing", name = "La Renaissante", color = "blanc",
    desc = "À la place de mourir, reste vivant à 1 PV, 1 seule fois.",
    death_ward = true,
  },
  {
    id = "archiviste", type = "blessing", name = "L'Archiviste", color = "violet",
    desc = "Pioche une carte en plus à chaque tour.",
    extra_draw = 1,
  },
  {
    id = "reserviste", type = "blessing", name = "Le Réserviste", color = "noir",
    desc = "L'énergie non dépensée reste pour le tour suivant, 1 fois par combat.",
    reserviste = true,
  },
  {
    id = "protecteur", type = "blessing", name = "Le Protecteur", color = "orange",
    desc = 'Gagne 4 "bouclier" au début de chaque tour.',
    turn_start_shield = 4,
  },
  {
    id = "rancunier", type = "blessing", name = "Le Rancunier", color = "gris",
    desc = "Renvoie 2 dégâts à chaque coup reçu.",
    thorns = 2,
  },

  -- ---------- Malédictions ----------
  {
    id = "maudit", type = "curse", name = "Le Maudit", color = "vert",
    desc = "Perd 2 PV à chaque début de combat.",
    combat_start_damage = 2,
  },
  {
    id = "corrompu", type = "curse", name = "Le Corrompu", color = "bleu",
    desc = "Les cartes de cet aventurier coûtent 1 énergie de plus.",
    card_cost_delta = 1,
  },
  {
    id = "maladroit", type = "curse", name = "Le Maladroit", color = "rouge",
    desc = "Les cartes de cet aventurier ont 50% de chances d'être défaussées de suite.",
    discard_on_draw_chance = 0.5,
  },
  {
    id = "martyr", type = "curse", name = "Le Martyr", color = "blanc",
    desc = "Chances d'être pris pour cible : +50%.",
    targeting_bonus = 0.5,
  },
  {
    id = "vulnerable", type = "curse", name = "Le Vulnérable", color = "violet",
    desc = "Vulnérable 3 au début de chaque combat.",
    combat_start_status = { vulnerabilite = 3 },
  },
  {
    id = "faible", type = "curse", name = "Le Faible", color = "noir",
    desc = "Incapacité 3 au début de chaque combat.",
    combat_start_status = { incapacite = 3 },
  },
  {
    id = "blesse", type = "curse", name = "Le Blessé", color = "orange",
    desc = "Perd 1 PV à chaque attaque faisant des dégâts.",
    self_damage_on_hit = 1,
  },
  {
    id = "amnesique", type = "curse", name = "L'Amnésique", color = "gris",
    desc = 'Les cartes de cet aventurier gagnent "Amnesie".',
    force_amnesie = true,
  },
}

function Temple.by_id(id)
  for _, e in ipairs(Temple.effects) do
    if e.id == id then return e end
  end
  return nil
end

local function by_type(t)
  local out = {}
  for _, e in ipairs(Temple.effects) do
    if e.type == t then out[#out + 1] = e end
  end
  return out
end
Temple.by_type = by_type

--- Champ hero portant CE type ("blessing" -> hero.blessing, "curse" -> hero.curse).
local FIELD_BY_TYPE = { blessing = "blessing", curse = "curse" }

--- Aventuriers vivants qui n'ont pas encore d'effet de ce type -- même
-- principe que l'ancien Temple.eligible_heroes, paramétré par type.
function Temple.eligible_heroes(state, t)
  local field = FIELD_BY_TYPE[t]
  local out = {}
  for _, h in ipairs(state.heroes) do
    if h.hp > 0 and not h[field] then out[#out + 1] = h end
  end
  return out
end

--- Vrai s'il existe au moins un effet de ce type ET au moins un aventurier
-- éligible pour au moins un d'entre eux -- un type "vide" (aucun effet
-- restant ou personne d'éligible) ne doit jamais être proposé, voir
-- Temple.roll_type ci-dessous.
local function type_is_viable(state, t)
  return #by_type(t) > 0 and #Temple.eligible_heroes(state, t) > 0
end

--- Tire le type de cette visite (2026-08-29, demande explicite -- "on choisit
-- aléatoirement bénédiction ou malédiction") PARMI LES TYPES VIABLES
-- seulement : si un seul type a quelque chose à proposer, ce sera toujours
-- lui (jamais un écran vide/impossible à résoudre) ; si aucun des deux ne
-- l'est, renvoie nil -- Controller:enter_temple_screen doit alors passer
-- directement à l'étape suivante, jamais afficher cet écran.
function Temple.roll_type(state, rng)
  local candidates = {}
  for _, t in ipairs({ "blessing", "curse" }) do
    if type_is_viable(state, t) then candidates[#candidates + 1] = t end
  end
  if #candidates == 0 then return nil end
  return candidates[rng:random(#candidates)]
end

--- Vrai si AU MOINS UN type (bénédiction OU malédiction) a quelque chose à
-- proposer (2026-08-30, écran "camp" -- Controller:enter_post_combat_sequence
-- doit savoir SANS consommer `state.rng.temple` si le Temple peut faire
-- partie des candidats de ce combat-ci, avant même de le choisir) : pure,
-- même logique que Temple.roll_type mais sans tirage -- les deux ne peuvent
-- jamais diverger puisqu'ils appellent le même type_is_viable local.
function Temple.any_type_viable(state)
  return type_is_viable(state, "blessing") or type_is_viable(state, "curse")
end

--- Tire jusqu'à Temple.CHOICE_COUNT effets DISTINCTS du type donné, sans
-- remise -- même idiome que Forge.pick_choices : une liste plus courte si le
-- type n'a pas assez d'entrées, jamais un filet de sécurité qui repasserait
-- sur un effet déjà vu.
function Temple.pick_choices(t, rng)
  local pool = by_type(t)
  local n = math.min(Temple.CHOICE_COUNT, #pool)
  local chosen = {}
  for _ = 1, n do
    local idx = rng:random(#pool)
    chosen[#chosen + 1] = table.remove(pool, idx)
  end
  return chosen
end

--- Attribue `effect` à `hero` sur le champ correspondant à son type -- accepté
-- même si l'aventurier porte déjà un effet de L'AUTRE type (bénédiction et
-- malédiction coexistent), jamais s'il porte déjà CE type (Temple.eligible_heroes
-- filtre déjà ce cas côté UI/contrôleur, mais cette fonction ne le revérifie
-- pas -- appelant responsable, même contrat que Temple.bless avant elle).
function Temple.assign(hero, effect)
  hero[FIELD_BY_TYPE[effect.type]] = effect.id
end

return Temple
