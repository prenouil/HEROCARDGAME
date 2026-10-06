-- Sauvegardes du mode "Aventure" (2026-10-05, prémices explicitement demandées --
-- "le joueur choisit un slot, ce qui crée un fichier de sauvegarde dédié à ce
-- slot") : dépendance LÖVE explicite (love.filesystem), donc ici plutôt que
-- dans src/rules (modules purs, testés par Busted hors LÖVE -- voir .busted/
-- src/ui/sfx.lua pour la même convention). 3 emplacements fixes, 1 fichier
-- chacun.
--
-- Schéma (2026-10-06, "Sélection de quête" -- demande explicite) : table plate
-- -- `main_story_difficulty` (nombre, démarre à 1, +1 à chaque "Histoire
-- principale" terminée) ; `unlocked_classes`/`unlocked_cards` (ensembles
-- `{id = true}`, déblocages SUPPLÉMENTAIRES de cette partie, en plus des
-- débloqués de base -- voir Heroes.is_unlocked_by_default/
-- Cards.is_unlocked_by_default, jamais dupliqués ici) ; `class_quest_ids`
-- (tableau de 0 à Quests.CLASS_QUEST_COUNT class_id, rerollé après chaque run
-- -- voir Quests.reroll_class_quests) ; `companion_quest_class_id` (1
-- class_id ou nil, stable jusqu'à obtention -- voir Quests.ensure_companion_quest).
-- Toute la LOGIQUE de génération vit dans src/rules/quests.lua (pur, testé par
-- Busted) -- ce fichier-ci ne fait QUE lire/écrire le résultat sur disque.
local Quests = require("src.rules.quests")

local Save = {}

Save.SLOT_COUNT = 3

local function filename(slot)
  return "adventure_slot_" .. tostring(slot) .. ".lua"
end

function Save.slot_exists(slot)
  return love.filesystem.getInfo(filename(slot)) ~= nil
end

--- Sérialise un ensemble `{id = true, ...}` en littéral Lua `[id] = true, ...`
-- (2026-10-06) : schéma assez simple (clés chaînes, valeurs booléennes) pour
-- ne pas justifier un sérialiseur générique -- voir Save.write_slot, seul
-- appelant.
local function serialize_set(set)
  local parts = {}
  for k, v in pairs(set or {}) do
    if v then parts[#parts + 1] = string.format("[%q] = true", k) end
  end
  return table.concat(parts, ", ")
end

local function serialize_array(arr)
  local parts = {}
  for _, v in ipairs(arr or {}) do parts[#parts + 1] = string.format("%q", v) end
  return table.concat(parts, ", ")
end

--- Écrit `data` (table plate, voir le schéma en tête de fichier) sur le disque
-- au format `return {...}`, relisible tel quel par love.filesystem.load
-- (voir Save.load_slot). Écrase systématiquement -- jamais de fusion partielle,
-- l'appelant doit toujours passer la table COMPLÈTE (déjà chargée puis
-- modifiée, voir Controller:resolve_adventure_quest).
function Save.write_slot(slot, data)
  local lines = {
    "return {",
    "  main_story_difficulty = " .. tostring(data.main_story_difficulty or 1) .. ",",
    "  unlocked_classes = {" .. serialize_set(data.unlocked_classes) .. "},",
    "  unlocked_cards = {" .. serialize_set(data.unlocked_cards) .. "},",
    "  class_quest_ids = {" .. serialize_array(data.class_quest_ids) .. "},",
    "  companion_quest_class_id = "
      .. (data.companion_quest_class_id and string.format("%q", data.companion_quest_class_id) or "nil") .. ",",
    "}",
  }
  love.filesystem.write(filename(slot), table.concat(lines, "\n") .. "\n")
end

--- Relit CET emplacement (2026-10-06) : table vide aux valeurs par défaut si
-- le fichier n'existe pas encore ou est corrompu (pcall -- ne devrait jamais
-- arriver en pratique, Save.write_slot est le seul écrivain, mais un fichier
-- à la main par le porteur de projet pendant les tests ne doit jamais planter
-- le jeu) -- jamais nil, pour que les appelants n'aient pas à vérifier.
function Save.load_slot(slot)
  local data
  if Save.slot_exists(slot) then
    local chunk = love.filesystem.load(filename(slot))
    local ok, loaded = pcall(chunk)
    if ok and type(loaded) == "table" then data = loaded end
  end
  data = data or {}
  data.main_story_difficulty = data.main_story_difficulty or 1
  data.unlocked_classes = data.unlocked_classes or {}
  data.unlocked_cards = data.unlocked_cards or {}
  data.class_quest_ids = data.class_quest_ids or {}
  return data
end

--- Crée le fichier de CET emplacement s'il n'existe pas déjà (ne l'écrase
-- jamais -- un emplacement déjà entamé doit continuer EXACTEMENT où il en
-- était, voir Controller:choose_adventure_slot, seul appelant). Génère tout de
-- suite ses toutes premières quêtes (2026-10-06, demande explicite --
-- "Sélection de quête") : sans ça, l'écran de quête d'un emplacement flambant
-- neuf n'aurait rien à proposer pour les 2 quêtes de classe/celle de
-- compagnon -- jamais rerollées une 2ᵉ fois ici après coup, seul
-- Controller:resolve_adventure_quest le fait (après un run).
function Save.create_slot(slot)
  if Save.slot_exists(slot) then return end
  local data = {
    main_story_difficulty = 1,
    unlocked_classes = {},
    unlocked_cards = {},
    class_quest_ids = {},
    companion_quest_class_id = nil,
  }
  Quests.reroll_class_quests(data)
  Quests.ensure_companion_quest(data)
  Save.write_slot(slot, data)
end

--- Supprime définitivement le fichier de CET emplacement (2026-10-05, demande
-- explicite -- bouton croix rouge à côté de chaque slot) : no-op silencieux
-- s'il n'existait pas déjà (voir Controller:delete_adventure_slot, seul
-- appelant -- le bouton n'est de toute façon affiché que pour un emplacement
-- existant, voir draw_adventure_slots).
function Save.delete_slot(slot)
  love.filesystem.remove(filename(slot))
end

return Save
