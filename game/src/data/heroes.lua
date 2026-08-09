-- Héros MVP et texte de Transcendance par classe.
-- Port fidèle de HERO_DEFS / CLASS_POWERS depuis proto-cartes-completes/index.html
-- (le Pouvoir de Classe d'origine a été retiré depuis, voir Heroes.class_powers).
-- PV : aucun montant n'est fixé au canon (gdd.md, 2026-08-06) — ces valeurs restent
-- les repères de test du prototype, pas des chiffres définitifs.
--
-- `icon` reste la vraie donnée de design (emoji, fidèle au tableur) ; `label`/
-- `class_label` sont le repli texte utilisé par la UI LÖVE, dont la police par
-- défaut ne contient pas ces glyphes (voir README du dossier game/). Le texte
-- de transcendance ci-dessous n'utilise que ce repli directement, pour rester
-- lisible sans dépendre d'aucune police.

local Heroes = {}

-- Pouvoir de Classe retiré (2026-08-09, décision explicite du porteur de
-- projet -- "ça ne marche pas pour l'instant", à repenser plus tard) : seule
-- la Transcendance individuelle reste. Ne conserve donc plus qu'un champ par
-- classe, pas une table {pouvoir, transcendance}.
Heroes.class_powers = {
  guerrier = { transcendance = "Transcendance — +50% dégâts \"épée\" (mêlée physique)." },
  paladin = { transcendance = "Transcendance — +50% sur le bouclier gagné ET sur le soin prodigué." },
  mage = { transcendance = "Transcendance — -2 coût en énergie sur tout \"sort\", pas seulement les sorts offensifs." },
  assassin = { transcendance = "Transcendance — Double la quantité de tout statut qu'il applique." },
}

Heroes.defs = {
  { id = "guerrier", class_id = "guerrier", name = "Guerrier", icon = "\u{2694}\u{FE0F}", label = "GUE", max_hp = 18 },
  { id = "paladin", class_id = "paladin", name = "Paladin", icon = "\u{1F6E1}\u{FE0F}", label = "PAL", max_hp = 14 },
  { id = "mage", class_id = "mage", name = "Mage", icon = "\u{1F52E}", label = "MAG", max_hp = 10 },
  { id = "assassin", class_id = "assassin", name = "Assassin", icon = "\u{1F5E1}\u{FE0F}", label = "ASS", max_hp = 12 },
}

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
