-- Héros MVP et texte du Pouvoir de Classe / Transcendance par classe.
-- Port fidèle de HERO_DEFS / CLASS_POWERS depuis proto-cartes-completes/index.html.
-- PV : aucun montant n'est fixé au canon (gdd.md, 2026-08-06) — ces valeurs restent
-- les repères de test du prototype, pas des chiffres définitifs.
--
-- `icon` reste la vraie donnée de design (emoji, fidèle au tableur) ; `label`/
-- `class_label` sont le repli texte utilisé par la UI LÖVE, dont la police par
-- défaut ne contient pas ces glyphes (voir README du dossier game/). Les textes
-- de pouvoir/transcendance ci-dessous n'utilisent que ce repli directement,
-- pour rester lisibles sans dépendre d'aucune police.

local Heroes = {}

Heroes.class_powers = {
  guerrier = {
    pouvoir = "Pouvoir de Classe — Au début de chaque tour, inflige aléatoirement 2 (épée) pour chaque carte contenant \"épée\" en main.",
    transcendance = "Transcendance — +50% dégâts \"épée\" (mêlée physique).",
  },
  paladin = {
    pouvoir = "Pouvoir de Classe — La première fois que le Paladin ou un allié tombe à 0 PV (une fois par combat), il se relève avec 1 PV.",
    transcendance = "Transcendance — +50% sur le bouclier gagné ET sur le soin prodigué.",
  },
  mage = {
    pouvoir = "Pouvoir de Classe — En fin de tour, peut garder 1 carte en main au lieu de la défausser.",
    transcendance = "Transcendance — -2 coût en énergie sur tout \"sort\", pas seulement les sorts offensifs.",
  },
  assassin = {
    pouvoir = "Pouvoir de Classe — En se concentrant, devient Camouflé (jusqu'à sa prochaine attaque, ne peut être ciblé) et gagne Puissance 2 (+25% dégâts physiques par stack, -1/tour).",
    transcendance = "Transcendance — Les attaques de mêlée infligent Incapacité 1 et Vulnérabilité 1.",
  },
}

Heroes.defs = {
  { id = "guerrier", class_id = "guerrier", name = "Guerrier", icon = "\u{2694}\u{FE0F}", label = "GUE", max_hp = 18 },
  { id = "paladin", class_id = "paladin", name = "Paladin", icon = "\u{1F6E1}\u{FE0F}", label = "PAL", max_hp = 14 },
  { id = "mage", class_id = "mage", name = "Mage", icon = "\u{1F52E}", label = "MAG", max_hp = 10 },
  { id = "assassin", class_id = "assassin", name = "Assassin", icon = "\u{1F5E1}\u{FE0F}", label = "ASS", max_hp = 12 },
}

-- Guerrier : dégâts du coup gratuit du Pouvoir de Classe, en début de tour, par carte
-- "epee" en main — chiffré par le tableur des classes refait (pas un placeholder).
Heroes.GUERRIER_FREE_HIT_DMG = 2

Heroes.class_icon = {
  generic = "\u{26AA}",
  guerrier = "\u{2694}\u{FE0F}",
  paladin = "\u{1F6E1}\u{FE0F}",
  mage = "\u{1F52E}",
  assassin = "\u{1F5E1}\u{FE0F}",
}

Heroes.class_label = {
  generic = "GEN",
  guerrier = "GUE",
  paladin = "PAL",
  mage = "MAG",
  assassin = "ASS",
}

return Heroes
