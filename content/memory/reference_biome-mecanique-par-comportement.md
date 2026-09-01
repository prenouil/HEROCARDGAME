---
name: biome-mecanique-par-comportement
description: Un biome d'ennemis doit porter une mécanique de gameplay qui se lit dans le comportement des ennemis eux-mêmes, pas une simple teinte visuelle — et réutiliser/réassigner le bestiaire existant avant d'en créer un parallèle.
metadata:
  type: reference
---

Quand on conçoit des biomes d'ennemis (mode Infini), chaque biome doit porter **une seule mécanique claire et lisible dans le comportement des 5 ennemis** (ex. la majorité pose un statut particulier, cible tous le même type de héros, ou une variante de règle transverse comme une sensibilité) — jamais juste une couleur de fond différente sans rien qui en dépende. Le joueur doit sentir la différence en jouant, pas seulement à l'écran de chargement.

**Pourquoi :** avant la proposition du 2026-09-01, un système de "biome" existait déjà (`game/src/ui/background.lua`, table `ENEMY_BIOME`) mais était PUREMENT visuel — "aucune règle n'en dépend" (commentaire du fichier). Le porteur de projet a explicitement demandé qu'une mécanique de gameplay "se dégage du comportement des ennemis" pour que combattre dans un biome donné se sente différent d'un autre.

**Comment l'appliquer :**
- Avant de proposer un bestiaire par biome, vérifier si des ennemis existants peuvent être réassignés/réutilisés dans la nouvelle structure plutôt que doubler le bestiaire avec un jeu parallèle — voir `game/src/data/enemies.lua` pour ce qui existe.
- Préférer des mécaniques qui se posent avec les hooks déjà génériques du moteur (kinds `dmg`/`debuff`/`heal-self`/`heal-ally`/`revive`/`dmg-all`/`conditional-retaliate`/`buff-self`, statuts déjà génériques comme Saignement/Incapacité/Vulnérabilité/Puissance, `target_mode` random/lowest-hp) plutôt que d'inventer un nouveau statut à chaque fois — voir `game/src/rules/combat.lua` (`Combat.damage_multiplier`) et `game/src/rules/game.lua` (`Game.resolve_enemy_action`) pour ce qui est déjà générique vs. câblé en dur sur un `template_id` précis (ex. la sensibilité au feu de l'Homme Arbre, le `kind == "revive"` câblé sur "pousse", le `conditional-retaliate` câblé sur "golem" — toute extension à un nouvel ennemi qui réutilise ces kinds nécessite de généraliser ce câblage, à signaler explicitement).
- Signaler clairement si la mécanique proposée suppose qu'un combat reste confiné à UN SEUL biome à la fois (pool d'ennemis restreint pendant le combat/le tronçon de run) — ce n'est PAS le cas par défaut : `Encounter.generate_encounter` pioche aujourd'hui dans tout le bestiaire commun sans distinction de biome, un filtrage explicite est nécessaire pour que l'identité de biome ne se dilue pas dans une rencontre mixte.
