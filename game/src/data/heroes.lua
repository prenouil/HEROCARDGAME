-- Héros MVP.
-- Port fidèle de HERO_DEFS depuis proto-cartes-completes/index.html (le Pouvoir
-- de Classe d'origine a été retiré le 2026-08-09, la Transcendance individuelle
-- qui restait ensuite a été retirée à son tour le 2026-08-11 -- plus aucun
-- bonus/malus lié à la classe du héros qui joue une carte, voir combat.lua).
-- PV : aucun montant n'est fixé au canon (gdd.md, 2026-08-06) — ces valeurs restent
-- les repères de test du prototype, pas des chiffres définitifs.
--
-- `icon` reste la vraie donnée de design (emoji, fidèle au tableur) ; `label`/
-- `class_label` sont le repli texte utilisé par la UI LÖVE, dont la police par
-- défaut ne contient pas ces glyphes (voir README du dossier game/).

local Heroes = {}

-- PV doublés (2026-08-28, demande explicite) : 18/14/10/12 -> 36/28/20/24.
-- Nécromancien/Barde (2026-08-29, conçues avec agent_content) fusionnées ici
-- (2026-08-29, écran de sélection d'équipe) : `Heroes.defs` est désormais le
-- CATALOGUE des 6 aventuriers débloqués, plus le roster automatique d'une
-- run -- voir `Heroes.DEFAULT_PARTY_IDS` ci-dessous pour les 4 utilisés par
-- défaut (héros/boss "de test", ou tout appelant qui ne passe pas de
-- `selected_ids` explicite à Game.reset_run/Game.start_boss_test).
Heroes.defs = {
  { id = "guerrier", class_id = "guerrier", name = "Guerrier", icon = "\u{2694}\u{FE0F}", label = "GUE", max_hp = 36 },
  { id = "paladin", class_id = "paladin", name = "Paladin", icon = "\u{1F6E1}\u{FE0F}", label = "PAL", max_hp = 28 },
  { id = "mage", class_id = "mage", name = "Mage", icon = "\u{1F52E}", label = "MAG", max_hp = 20 },
  { id = "assassin", class_id = "assassin", name = "Assassin", icon = "\u{1F5E1}\u{FE0F}", label = "ASS", max_hp = 24 },
  { id = "necromancien", class_id = "necromancien", name = "Nécromancien", icon = "\u{1F480}", label = "NEC", max_hp = 24 },
  { id = "barde", class_id = "barde", name = "Barde", icon = "\u{1F3B5}", label = "BAR", max_hp = 24 },
}

--- Retrouve un def par son id (voir Heroes.defs ci-dessus) -- point d'entrée
-- unique pour l'écran de sélection d'équipe/Game.reset_run, jamais une
-- boucle dupliquée ailleurs.
function Heroes.by_id(id)
  for _, def in ipairs(Heroes.defs) do
    if def.id == id then return def end
  end
  return nil
end

-- Équipe par défaut (2026-08-29) : les 4 héros historiques, utilisés quand
-- aucune sélection explicite n'est fournie (Game.start_boss_test -- "Tester
-- le boss" au menu reste un raccourci fixe, pas concerné par l'écran de
-- sélection -- et tout appel existant qui ne passe pas `selected_ids`, ex.
-- les tests). Écran "team_select" (Controller) : construit sa propre
-- sélection de 4 parmi les 6 `Heroes.defs`, jamais limitée à cette liste.
Heroes.DEFAULT_PARTY_IDS = { "guerrier", "paladin", "mage", "assassin" }

Heroes.class_icon = {
  generic = "\u{26AA}",
  guerrier = "\u{2694}\u{FE0F}",
  paladin = "\u{1F6E1}\u{FE0F}",
  mage = "\u{1F52E}",
  assassin = "\u{1F5E1}\u{FE0F}",
  necromancien = "\u{1F480}",
  barde = "\u{1F3B5}",
}

Heroes.class_label = {
  generic = "GEN",
  guerrier = "GUE",
  paladin = "PAL",
  mage = "MAG",
  assassin = "ASS",
  necromancien = "NEC",
  barde = "BAR",
}

-- Nom complet par classe (2026-08-20, demande explicite -- indiquer sur
-- chaque carte quel aventurier l'a fournie) : une seule classe = un seul
-- héros, donc `def.class_id` d'une carte suffit à retrouver ce nom, pas
-- besoin d'un champ dédié sur chaque carte dans src/data/cards.lua.
Heroes.class_name = {
  guerrier = "Guerrier",
  paladin = "Paladin",
  mage = "Mage",
  assassin = "Assassin",
  necromancien = "Nécromancien",
  barde = "Barde",
}

-- Description de classe (2026-08-24, demande explicite -- affichée en tête de
-- l'infobulle d'un aventurier au survol, voir tooltip_lines dans view.lua) :
-- coquilles corrigées au passage sur l'Assassin ("Devint" -> "Devient",
-- "agit" -> "agi") -- sens inchangé. Un "\n" est un retour à la ligne FORCÉ
-- (LÖVE respecte les "\n" dans Font:getWrap/love.graphics.printf en plus du
-- retour automatique) -- une seule entrée de tableau `lines` par description,
-- pas une par ligne visuelle.
Heroes.class_description = {
  guerrier = "Un combattant qui sait faire des dégâts",
  paladin = "Un défenseur qui aime protéger ses alliés",
  mage = "A besoin de Mana pour lancer de puissants sorts",
  assassin = "Gagne de la Discrétion en laissant ses alliés agir :\n"
    .. "- +1 Discrétion quand un autre allié agit\n"
    .. "- +5 s'il passe son tour sans agir.\n"
    .. "Devient Camouflé avec 10 de Discrétion\n"
    .. "Discrétion revient à 0 après avoir agi",
  necromancien = "Dépense ses propres PV pour amasser de la Corruption, puis la libère dans des rituels :\n"
    .. "- +1 Corruption par PV perdu (dégâts subis ou PV sacrifiés)\n"
    .. "- Repart à 0 Corruption à chaque nouveau combat\n"
    .. "- Certaines cartes en dépensent jusqu'à un plafond pour amplifier leur effet",
  barde = "Insuffle de l'Inspiration à ses alliés pour amplifier leur prochaine carte, quelle que soit leur classe :\n"
    .. "- Inspiration : +6 flat au premier effet de dégâts/soin/bouclier du porteur\n"
    .. "- -1 charge à l'utilisation, -1 automatique en fin de tour\n"
    .. "- Repart à 0 à chaque nouveau combat",
}

return Heroes
