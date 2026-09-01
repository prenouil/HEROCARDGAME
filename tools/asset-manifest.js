// Liste complète des assets à générer, alignée sur les IDs de game/src/data/*.lua
// (heroes.lua, enemies.lua, glossary.lua) pour un branchement direct côté LÖVE.
module.exports = [
  // ---- Héros (character, 64x64) ----
  { id: 'guerrier', grid: 'character', out: 'game/assets/characters/heroes/guerrier.png',
    subject: 'a fantasy warrior hero character, sword and shield, medium armor, standing pose' },
  { id: 'paladin', grid: 'character', out: 'game/assets/characters/heroes/paladin.png',
    subject: 'a fantasy paladin hero character, holy knight, holding one solid one-piece mace (head firmly fused to the handle, not separate pieces) and a shield, plate armor with a cross emblem, standing pose' },
  { id: 'mage', grid: 'character', out: 'game/assets/characters/heroes/mage.png',
    subject: 'a fantasy mage hero character, wizard robe, pointed hat, holding a staff, standing pose' },
  { id: 'assassin', grid: 'character', out: 'game/assets/characters/heroes/assassin.png',
    subject: 'a fantasy rogue assassin hero character, hooded cloak, gripping one dagger firmly in each hand, both daggers clearly held, standing pose' },
  // Nécromancien/Barde (2026-08-29, 2 nouvelles classes) : tient un bâton
  // surmonté d'un crâne plutôt qu'un crâne nu en main (distinct de l'ennemi
  // "necromancien" existant plus bas, qui tient juste un crâne) -- lecture de
  // classe immédiate malgré la thématique proche.
  { id: 'necromancien-hero', grid: 'character', out: 'game/assets/characters/heroes/necromancien.png',
    subject: 'a fantasy necromancer hero character, dark hooded robe with purple trim, holding a gnarled bone staff topped with a glowing skull, standing pose' },
  { id: 'barde-hero', grid: 'character', out: 'game/assets/characters/heroes/barde.png',
    subject: 'a fantasy bard hero character, feathered cap, colorful traveling cloak, holding a lute, standing pose' },

  // ---- Ennemis (character, 64x64) ----
  { id: 'gobelin', grid: 'character', out: 'game/assets/characters/enemies/gobelin.png',
    subject: 'a goblin marauder enemy character, small green creature, crude weapon, standing pose' },
  { id: 'squelette', grid: 'character', out: 'game/assets/characters/enemies/squelette.png',
    subject: 'a skeleton archer enemy character, holding a bow, standing pose' },
  // Formulation revue le 2026-08-10 (trop "mignon"/petit à l'essai initial, jugé par le porteur
  // de projet) : plus massif, plus menaçant, plein cadre sans être rogné.
  { id: 'troll', grid: 'character', out: 'game/assets/characters/enemies/troll.png',
    subject: 'a swamp troll enemy character, large hunched green creature, bulky and muscular but hunched over, menacing snarling expression with visible fangs, angry eyes, sharp claws, intimidating, not cute or childlike, full body clearly visible with head and feet inside the frame, not cropped, viewed from the front' },
  { id: 'gobelourd', grid: 'character', out: 'game/assets/characters/enemies/gobelourd.png',
    subject: 'a stocky armored goblin-bear hybrid enemy character holding a shield, standing pose' },
  // Formulation revue le 2026-08-10 : l'essai initial (juste "standing pose") ressortait
  // bipède/humanoïde à cause du suffixe de style partagé (CHARACTER_STYLE_SUFFIX, pensé pour
  // des personnages humanoïdes) -- contredit explicitement ici.
  { id: 'loup', grid: 'character', out: 'game/assets/characters/enemies/loup.png',
    subject: 'a rabid feral wolf enemy character, on all four legs, quadruped animal stance, no human-like posture, no hands, no held weapon, viewed from the front' },
  { id: 'araignee', grid: 'character', out: 'game/assets/characters/enemies/araignee.png',
    subject: 'a venomous giant spider enemy character, eight legs, arachnid body low to the ground, no human-like posture, no hands, no held weapon, viewed from the front' },
  { id: 'necromancien', grid: 'character', out: 'game/assets/characters/enemies/necromancien.png',
    subject: 'a novice necromancer enemy character, dark hooded robe, holding a skull, standing pose' },
  // Formulation revue le 2026-08-10 (trop petit à l'essai initial, jugé par le porteur de projet).
  { id: 'golem', grid: 'character', out: 'game/assets/characters/enemies/golem.png',
    subject: 'a stone golem enemy character, large hunched rock creature, hulking and massive, character fills the frame edge to edge, imposing scale, bulky heavy body, viewed from the front' },
  { id: 'bandit', grid: 'character', out: 'game/assets/characters/enemies/bandit.png',
    subject: 'a sneaky bandit enemy character, hood, holding a dagger, standing pose' },
  { id: 'chaman', grid: 'character', out: 'game/assets/characters/enemies/chaman.png',
    subject: 'a goblin shaman enemy character, tribal robe, holding a totem staff, standing pose' },
  // Aigle Géant, 2ᵉ boss (2026-08-31) : 2 illustrations (sol/vol, voir enemies.lua "vol").
  // Prompts plus détaillés ("bird of prey", "sharp talons extended", "wings spread wide")
  // rejetés par le filtre NSFW de Workers AI (faux positif, code 8007) -- formulation
  // minimale retenue après plusieurs essais, seule à passer le filtre.
  { id: 'aigle', grid: 'character', out: 'game/assets/characters/enemies/aigle.png',
    subject: 'a giant eagle enemy character, bird of prey, standing pose, wings folded' },
  { id: 'aigle-vol', grid: 'character', out: 'game/assets/characters/enemies/aigle-vol.png',
    subject: 'a giant eagle enemy character, bird of prey, flying, wings open, mid-air' },

  // Extension biomes (2026-09-01), 10 nouveaux ennemis -- voir enemies.lua pour le détail
  // de chacun. Golem de Magma a d'abord été rejeté par le filtre NSFW avec une formulation
  // plus détaillée ("imposing scale, bulky heavy body" façon Golem de Pierre) -- même
  // schéma que l'Aigle Géant ci-dessus, formulation simplifiée retenue.
  { id: 'garde-ossements', grid: 'character', out: 'game/assets/characters/enemies/garde-ossements.png',
    subject: 'an undead skeleton guard enemy character, holding a shield, armored, standing pose' },
  { id: 'pretre-dechu', grid: 'character', out: 'game/assets/characters/enemies/pretre-dechu.png',
    subject: 'a corrupted priest enemy character, tattered holy robe, broken halo, standing pose' },
  { id: 'eclaireuse', grid: 'character', out: 'game/assets/characters/enemies/eclaireuse.png',
    subject: 'a desert scout enemy character, holding a bow, sand-colored cloak, standing pose' },
  { id: 'chef-de-bande', grid: 'character', out: 'game/assets/characters/enemies/chef-de-bande.png',
    subject: 'a bandit leader enemy character, holding a sword, rugged clothing, standing pose' },
  { id: 'tireuse', grid: 'character', out: 'game/assets/characters/enemies/tireuse.png',
    subject: 'a desert sniper enemy character, holding a crossbow, hooded, standing pose' },
  { id: 'salamandre', grid: 'character', out: 'game/assets/characters/enemies/salamandre.png',
    subject: 'a lava salamander enemy character, reptilian creature, glowing molten skin, on all four legs, quadruped animal stance, no human-like posture, no hands, no held weapon, viewed from the front' },
  { id: 'cracheur', grid: 'character', out: 'game/assets/characters/enemies/cracheur.png',
    subject: 'a small fire imp enemy character, glowing ember body, standing pose' },
  { id: 'elementaire-cendre', grid: 'character', out: 'game/assets/characters/enemies/elementaire-cendre.png',
    subject: 'an ash elemental enemy character, swirling grey smoke and ember body, floating, no human-like posture, viewed from the front' },
  { id: 'golem-magma', grid: 'character', out: 'game/assets/characters/enemies/golem-magma.png',
    subject: 'a magma golem enemy character, large rock creature, glowing lava cracks, standing pose' },
  { id: 'vouivre', grid: 'character', out: 'game/assets/characters/enemies/vouivre.png',
    subject: 'an ash wyvern enemy character, small dragon with wings, no human-like posture, no hands, no held weapon, viewed from the front' },

  // Boss choisis par biome (2026-09-02) : Roi Squelette (Catacombes), Élémentaire
  // de Feu (Volcan) -- voir enemies.lua/Encounter.boss_encounter.
  { id: 'roi-squelette', grid: 'character', out: 'game/assets/characters/enemies/roi-squelette.png',
    subject: 'an undead skeleton king enemy character, wearing a crown, holding a sword, royal tattered robe, standing pose' },
  { id: 'elementaire-feu', grid: 'character', out: 'game/assets/characters/enemies/elementaire-feu.png',
    subject: 'a fire elemental enemy character, humanoid body made of flames and embers, glowing, no clothing, standing pose' },

  // ---- Icônes de mots-clés (icon, 32x32) ----
  { id: 'energie', grid: 'icon', out: 'game/assets/icons/keywords/energie.png',
    subject: 'a lightning bolt icon, energy symbol' },
  // "PO" (or, 2026-09-02, demande explicite -- nouvelle ressource persistante).
  { id: 'or', grid: 'icon', out: 'game/assets/icons/keywords/or.png',
    subject: 'a gold coin icon, single object' },
  { id: 'epee', grid: 'icon', out: 'game/assets/icons/keywords/epee.png',
    subject: 'a straight medieval sword icon, single object' },
  { id: 'arc', grid: 'icon', out: 'game/assets/icons/keywords/arc.png',
    subject: 'a crossbow icon, single object' },
  { id: 'brut', grid: 'icon', out: 'game/assets/icons/keywords/brut.png',
    subject: 'an impact burst icon, spiky explosion symbol' },
  { id: 'bouclier', grid: 'icon', out: 'game/assets/icons/keywords/bouclier.png',
    subject: 'a round wooden shield with metal rim, no emblem, single object' },
  { id: 'barriere', grid: 'icon', out: 'game/assets/icons/keywords/barriere.png',
    subject: 'a blue hexagon icon, protective energy shield symbol' },
  { id: 'concentration', grid: 'icon', out: 'game/assets/icons/keywords/concentration.png',
    subject: 'a spiral swirl icon, focus symbol' },
  { id: 'epeefeu', grid: 'icon', out: 'game/assets/icons/keywords/epeefeu.png',
    subject: 'a sword icon with a plain handle, and the blade itself engulfed in flames' },
  { id: 'fireball', grid: 'icon', out: 'game/assets/icons/keywords/fireball.png',
    subject: 'a fireball icon, single flame symbol' },
  { id: 'etincelle', grid: 'icon', out: 'game/assets/icons/keywords/etincelle.png',
    subject: 'a magic sparkle icon, star spark symbol' },
  { id: 'poison', grid: 'icon', out: 'game/assets/icons/keywords/poison.png',
    subject: 'a skull and crossbones icon, poison symbol' },
  { id: 'sort', grid: 'icon', out: 'game/assets/icons/keywords/sort.png',
    subject: 'a magic wand icon with a glowing orb of light at its tip' },
  { id: 'pv', grid: 'icon', out: 'game/assets/icons/keywords/pv.png',
    subject: 'a red heart icon, health symbol' },
  { id: 'soin', grid: 'icon', out: 'game/assets/icons/keywords/soin.png',
    subject: 'a green heart icon, healing symbol' },
  { id: 'cibleennemi', grid: 'icon', out: 'game/assets/icons/keywords/cibleennemi.png',
    subject: 'a warning target crosshair icon' },
  { id: 'alliecible', grid: 'icon', out: 'game/assets/icons/keywords/alliecible.png',
    subject: 'a handshake icon, alliance symbol' },

  // ---- Icônes de statuts (icon, 32x32) ----
  { id: 'pioche', grid: 'icon', out: 'game/assets/icons/status/pioche.png',
    subject: 'a stack of playing cards icon, draw symbol' },
  { id: 'esquive', grid: 'icon', out: 'game/assets/icons/status/esquive.png',
    subject: 'a wind swirl icon, speed and agility symbol' },
  { id: 'saignement', grid: 'icon', out: 'game/assets/icons/status/saignement.png',
    subject: 'a single red teardrop shape icon' },
  { id: 'incapacite', grid: 'icon', out: 'game/assets/icons/status/incapacite.png',
    subject: 'a wilted flower icon' },
  { id: 'vulnerabilite', grid: 'icon', out: 'game/assets/icons/status/vulnerabilite.png',
    subject: 'a cracked shield icon, vulnerability debuff symbol' },
  { id: 'camoufle', grid: 'icon', out: 'game/assets/icons/status/camoufle.png',
    subject: 'a hooded ninja mask icon, stealth symbol' },
  { id: 'puissance', grid: 'icon', out: 'game/assets/icons/status/puissance.png',
    subject: 'a clenched fist icon, strength buff symbol' },
  // "Furtif" (2026-08-28, refonte des cartes Assassin) : mot-clé sans icône
  // pour l'instant (has_icon=false dans glossary.lua, faute de pouvoir
  // générer d'assets IA dans l'environnement où ce mot-clé a été ajouté --
  // voir la note sur temple-statue plus haut) -- entrée gardée prête, à
  // brancher (has_icon=true) une fois ce fichier généré ailleurs.
  { id: 'furtif', grid: 'icon', out: 'game/assets/icons/keywords/furtif.png',
    subject: 'a pair of soft footprints fading into shadow, stealth movement symbol' },

  // ---- Décors (grid personnalisée, plus grande qu'un portrait) ----
  // Écran "Le Temple" (2026-08-28, demande explicite -- "une statue d'un dieu
  // en forme de fleur dans un pot difforme") : remplace le placeholder
  // procédural dessiné à la main dans game/src/ui/view.lua (draw_temple_statue,
  // faute de pouvoir générer d'assets IA dans l'environnement où ce module a
  // été écrit -- aucun .env/identifiants Cloudflare présents). Grille 128 (ni
  // 'icon' 32x32 ni 'character' 64x64, taille custom) : élément de décor plus
  // grand qu'un portrait de personnage, pas un petit symbole d'icône.
  { id: 'temple-statue', grid: 128, out: 'game/assets/scenes/temple_statue.png',
    subject: 'a stone statue of a flower deity, a humanoid figure sculpted like a blossoming flower with petal-like features, standing rooted in a large lopsided misshapen clay pot, fantasy temple altar centerpiece, viewed from the front' },
];
