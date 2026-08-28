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
Heroes.defs = {
  { id = "guerrier", class_id = "guerrier", name = "Guerrier", icon = "\u{2694}\u{FE0F}", label = "GUE", max_hp = 36 },
  { id = "paladin", class_id = "paladin", name = "Paladin", icon = "\u{1F6E1}\u{FE0F}", label = "PAL", max_hp = 28 },
  { id = "mage", class_id = "mage", name = "Mage", icon = "\u{1F52E}", label = "MAG", max_hp = 20 },
  { id = "assassin", class_id = "assassin", name = "Assassin", icon = "\u{1F5E1}\u{FE0F}", label = "ASS", max_hp = 24 },
}

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

-- Nécromancien/Barde (2026-08-29, 2 classes conçues avec agent_content --
-- design finalisé après plusieurs tours de retours, voir
-- content/memory/MEMORY.md) : def complètes, codées et testées (voir
-- tests/game_spec.lua/combat_spec.lua), mais délibérément PAS ajoutées à
-- `Heroes.defs` ci-dessus (2026-08-29, décision explicite -- `Heroes.defs`
-- EST le roster actif de chaque run, aucune sélection d'équipe n'existe
-- encore dans le jeu ; les ajouter là ferait passer TOUTE run de 4 à 6 héros
-- sans que ce soit tranché). Table à part, jamais lue par Game.reset_run/
-- Game.start_boss_test -- seul point d'entrée pour ces defs aujourd'hui :
-- les tests, qui construisent leurs propres héros directement depuis cette
-- table. À fusionner dans Heroes.defs (ou une future logique de sélection)
-- le jour où le roster est tranché -- pas avant.
Heroes.pending_defs = {
  { id = "necromancien", class_id = "necromancien", name = "Nécromancien", icon = "\u{1F480}", label = "NEC", max_hp = 24 },
  { id = "barde", class_id = "barde", name = "Barde", icon = "\u{1F3B5}", label = "BAR", max_hp = 24 },
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
