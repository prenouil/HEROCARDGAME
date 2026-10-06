-- Quêtes du mode "Aventure" (2026-10-06, demande explicite -- fenêtre
-- intermédiaire "Sélection de quête") : module pur (aucune dépendance LÖVE,
-- comme tout src/rules -- voir .busted) qui calcule QUOI proposer à partir
-- d'une save déjà chargée (une table simple, voir src/ui/save.lua pour son
-- schéma exact) -- ne lit/écrit jamais de fichier lui-même, ni n'appelle
-- Controller -- entièrement testable par Busted hors LÖVE.
local Heroes = require("src.data.heroes")
local Cards = require("src.data.cards")

local Quests = {}

Quests.CLASS_QUEST_COUNT = 2

--- Classes débloquées pour CETTE save (2026-10-06) : union des classes
-- débloquées de base (Heroes.DEFAULT_UNLOCKED_CLASS_IDS, voir son commentaire)
-- et de celles débloquées PENDANT cette partie via "Recherche de compagnon"
-- (save_data.unlocked_classes) -- seul point de vérité, utilisé aussi bien
-- par Controller:enter_team_select (mode "adventure") que par les quêtes de
-- classe ci-dessous, pour ne jamais diverger entre "qui est jouable" et "qui
-- peut avoir une quête".
function Quests.unlocked_class_set(save_data)
  local set = {}
  for id in pairs(Heroes.DEFAULT_UNLOCKED_CLASS_IDS) do set[id] = true end
  for id in pairs((save_data and save_data.unlocked_classes) or {}) do set[id] = true end
  return set
end

--- Cartes "avance" encore verrouillées de `class_id` pour CETTE save
-- (2026-10-06) : même filtre que Draft.pick_cards/l'onglet "Avancé" du choix
-- d'équipe (exclut Legs/Héritage/Écho/Mise à mort, jamais concernés par le
-- système de verrouillage -- voir leurs commentaires respectifs dans
-- controller.lua/draft.lua) -- dupliqué plutôt que partagé (fonctions
-- locales, non exportées, dans ces 2 fichiers), même raisonnement qu'eux :
-- besoin différent (celui-ci doit en plus croiser les déblocages DE CETTE
-- SAVE, que ni Draft ni l'onglet Avancé ne connaissent).
function Quests.locked_cards_for_class(class_id, save_data)
  local unlocked_cards = (save_data and save_data.unlocked_cards) or {}
  local out = {}
  for _, def in ipairs(Cards.list) do
    if def.class_id == class_id and def.tier == "avance"
      and not def.code:match("^legs%-") and not def.code:match("^heritage%-")
      and not def.code:match("^echo%-") and not def.code:match("^mise%-a%-mort%-")
      and not Cards.is_unlocked_by_default(def) and not unlocked_cards[def.code] then
      out[#out + 1] = def
    end
  end
  return out
end

--- Classes éligibles à une "Quête pour le <classe>" (2026-10-06, demande
-- explicite) : débloquées pour cette save (jouables, donc assignables
-- automatiquement à la team) ET avec au moins 1 carte "avance" encore à
-- débloquer -- "si la classe n'a plus de carte à débloquer, on ne génère plus
-- de quête pour cette classe".
function Quests.eligible_class_quest_classes(save_data)
  local unlocked = Quests.unlocked_class_set(save_data)
  local out = {}
  for _, def in ipairs(Heroes.defs) do
    if unlocked[def.id] and #Quests.locked_cards_for_class(def.id, save_data) > 0 then
      out[#out + 1] = def.id
    end
  end
  return out
end

--- Reroll des 2 quêtes de classe (2026-10-06, demande explicite -- "les 2
-- quêtes suivantes changent à chaque fois que le joueur finit un run [gagné
-- ou perdu]") : jusqu'à Quests.CLASS_QUEST_COUNT classes DISTINCTES tirées au
-- hasard parmi les éligibles -- moins si l'éligible en a moins (0, 1 ou 2) --
-- voir draw_quest_select (vue) pour l'affichage "Pas de quête de classe" dans
-- ce cas. Mute `save_data.class_quest_ids` directement (appelé juste avant
-- Save.write_slot, jamais de valeur de retour à propager) -- `math.random`
-- (pas un flux state.rng dédié) : pur confort de méta-progression hors run,
-- même convention que Controller:team_select_autofill.
function Quests.reroll_class_quests(save_data)
  local pool = Quests.eligible_class_quest_classes(save_data)
  local picked = {}
  for _ = 1, math.min(Quests.CLASS_QUEST_COUNT, #pool) do
    local idx = math.random(#pool)
    picked[#picked + 1] = table.remove(pool, idx)
  end
  save_data.class_quest_ids = picked
end

--- Classes éligibles à "Recherche de compagnon" (2026-10-06) : tout
-- aventurier du catalogue (Heroes.defs) PAS ENCORE débloqué pour cette save.
function Quests.eligible_companion_classes(save_data)
  local unlocked = Quests.unlocked_class_set(save_data)
  local out = {}
  for _, def in ipairs(Heroes.defs) do
    if not unlocked[def.id] then out[#out + 1] = def.id end
  end
  return out
end

--- Assigne une cible à "Recherche de compagnon" si elle n'en a pas déjà une
-- (2026-10-06, demande explicite) : CONTRAIREMENT aux quêtes de classe, ne
-- change PAS à chaque run -- reste fixe (le joueur la voit "en ombre noire",
-- toujours la même, d'un run à l'autre) jusqu'à ce qu'elle soit effectivement
-- obtenue (voir Controller:resolve_adventure_quest, qui remet alors ce champ
-- à nil pour qu'une nouvelle cible soit choisie ici au prochain écran de
-- quête). No-op silencieux si plus aucun aventurier à débloquer --
-- `save_data.companion_quest_class_id` reste nil, voir draw_quest_select pour
-- l'affichage "Pas de quête de compagnon" dans ce cas.
function Quests.ensure_companion_quest(save_data)
  if save_data.companion_quest_class_id then return end
  local pool = Quests.eligible_companion_classes(save_data)
  if #pool > 0 then
    save_data.companion_quest_class_id = pool[math.random(#pool)]
  end
end

-- Difficulté des runs de quête (2026-10-07, demande explicite -- "il faut les
-- brancher sur le budget de rencontre réel") : voir Game.reset_run/
-- budget_for_run_combat (game.lua) et Controller:choose_quest, seuls lecteurs
-- de la valeur calculée ici. "Histoire principale" garde sa propre règle
-- inchangée (+1 par VICTOIRE de cette quête précise, comptée à part dans
-- save_data.main_story_difficulty) -- les 2 constantes/fonctions ci-dessous
-- ne la concernent pas.
Quests.CLASS_QUEST_BASE_DIFFICULTY = 3
Quests.COMPANION_QUEST_BASE_DIFFICULTY = 5
Quests.COMPANION_QUEST_DIFFICULTY_STEP = 3

local function count_keys(set)
  local n = 0
  for _ in pairs(set or {}) do n = n + 1 end
  return n
end

--- Cartes de `class_id` déjà débloquées via une "Quête pour le <classe>"
-- (2026-10-07) : complémentaire de Quests.locked_cards_for_class -- même
-- filtre (tier "avance", hors Legs/Héritage/Écho/Mise à mort, hors débloquées
-- DE BASE), mais celles qui SONT dans `save_data.unlocked_cards`, pas celles
-- qui n'y sont pas.
local function unlocked_quest_cards_for_class(class_id, save_data)
  local unlocked_cards = (save_data and save_data.unlocked_cards) or {}
  local n = 0
  for _, def in ipairs(Cards.list) do
    if def.class_id == class_id and def.tier == "avance"
      and not def.code:match("^legs%-") and not def.code:match("^heritage%-")
      and not def.code:match("^echo%-") and not def.code:match("^mise%-a%-mort%-")
      and not Cards.is_unlocked_by_default(def) and unlocked_cards[def.code] then
      n = n + 1
    end
  end
  return n
end

--- Difficulté de la PROCHAINE "Quête pour le <classe>" (2026-10-07, demande
-- explicite, CORRIGÉE le jour même -- "seulement les cartes débloquées dans
-- cette classe", pas toutes classes confondues) : +1 par carte DÉJÀ débloquée
-- via une quête de CETTE MÊME classe -- deux classes progressent donc de
-- façon complètement indépendante.
function Quests.class_quest_difficulty(class_id, save_data)
  return Quests.CLASS_QUEST_BASE_DIFFICULTY + unlocked_quest_cards_for_class(class_id, save_data)
end

--- Difficulté de la PROCHAINE "Recherche de compagnon" (2026-10-07, demande
-- explicite -- "pour chaque classe débloquée, la difficulté de la suivante
-- augmente de 3, débute à difficulté 5") : +3 par compagnon DÉJÀ débloqué
-- (save_data.unlocked_classes -- jamais Heroes.DEFAULT_UNLOCKED_CLASS_IDS,
-- qui ne compte pas comme "débloqué PAR une quête").
function Quests.companion_quest_difficulty(save_data)
  return Quests.COMPANION_QUEST_BASE_DIFFICULTY
    + Quests.COMPANION_QUEST_DIFFICULTY_STEP * count_keys(save_data and save_data.unlocked_classes)
end

return Quests
