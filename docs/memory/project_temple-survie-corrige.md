---
name: temple-survie-corrige
description: "La Renaissante" (Statue du Temple) corrigée le 2026-10-02 pour refléter le mot-clé "Survie" (10% PV max, rechargé chaque combat jusqu'à la 1ère sauvegarde réelle, puis jamais). Audit complet des 15 autres bénédictions/malédictions sans autre écart trouvé.
metadata:
  type: project
---

Le 2026-10-02, correction ciblée de `docs/design/temple.md` + l'onglet "Statues de Temple" du Codex, suite à l'écart signalé (mais laissé hors périmètre) lors de la synchronisation du Glossaire du 2026-09-30 (voir `project_glossaire-synchronise-pilier-sacrifice.md`).

**Ce qui était faux** : "La Renaissante" était encore documentée avec l'ancien mécanisme (`hero.death_ward`, remontée fixe à 1 PV, 1 seule fois pour tout le run). Le code l'a depuis harmonisée avec le mot-clé "Survie" du pilier du sacrifice.

**Mécanisme réel** (relu dans `game/src/rules/temple.lua`, `game/src/rules/game.lua` — `apply_combat_start_temple_effects`, champ `hero.renaissante_used` — et `game/src/rules/combat.lua`/`game.lua` pour la consommation, tick_bleed/tick_burn compris) :
- "La Renaissante" donne le mot-clé "Survie" au porteur.
- "Survie" : la prochaine fois que l'aventurier doit mourir, il reste en vie à **10% de ses PV max** (jamais 1 PV fixe) — sauf une carte "Mise à mort", à laquelle rien n'échappe (garanti par construction : `Game.kill_hero` ne passe jamais par `Combat.deal_damage`).
- La bénédiction **recharge** Survie à **chaque** entrée en combat, **mais seulement jusqu'à ce qu'elle ait réellement sauvé le personnage une fois** : `hero.renaissante_used` est posé à `true` au moment de la consommation réelle et persiste tout le run (jamais remis à nil) — une fois vrai, `apply_combat_start_temple_effects` ne recharge plus jamais `hero.survie`. Au final "1 fois par run", pas "1 fois par combat".
- "Survie" peut aussi être accordée par une carte (Barde, "Célébration Finale") : charge indépendante, sans lien avec `renaissante_used`.

**Fichiers modifiés** : `docs/design/temple.md` (ligne du tableau Bénédictions + nouveau paragraphe détaillé + nouvelle section "Correction interne du 2026-10-02" avant "Écart avec les anciens documents"), `docs/design/glossaire.md` (note d'historique du 2026-09-30 mise à jour pour ne plus signaler le point comme ouvert, ligne "Survie" du tableau précisée, note de fin de section marquée corrigée). Artifact "Codex Hero Card Game" republié sur la même URL (version 21, label "temple-survie-2026-10-02") : onglet Statues de Temple (note de correction, ligne "La Renaissante", paragraphe détaillé, section d'audit), onglet Glossaire (note #4, ligne Survie, note de fin), en-tête de page et footer mis à jour.

**Audit complet de `temple.lua` fait à cette occasion** (pas seulement "La Renaissante") : les 7 autres bénédictions et les 8 malédictions correspondent toujours exactement à `docs/design/temple.md` — aucun autre écart trouvé. Vérifications ciblées au-delà de la simple lecture déclarative : "Le Rancunier" (`hero.thorns`, dégâts `brut`) confirmé ignorer le bouclier de la cible dans `combat.lua` ; "Le Martyr" (`hero.targeting_bonus`) confirmé cumulable multiplicativement avec la Provocation du Paladin dans `encounter.lua` (`w = w * 1.5` puis `w = w * (1 + targeting_bonus)`) ; "Le Maladroit" (`discard_on_draw_chance`) confirmé se déclencher bien à la pioche (`game.lua`, filtrage de `drawn_uids`) ; "Le Blessé" (`self_damage_on_hit`) confirmé ne se déclencher que sur une attaque qui inflige réellement des dégâts à un ennemi (jamais sur un coup entièrement paré, jamais sur un allié touché par erreur).

**Pourquoi** : demande explicite du porteur de projet suite au signalement laissé ouvert par la passe Glossaire du 2026-09-30 — l'utilisateur voulait l'onglet Temple fiable dans son ensemble, pas rapiécé au cas par cas, d'où l'audit complet plutôt qu'une correction de la seule ligne "La Renaissante".

**Comment l'appliquer** : `docs/design/temple.md` et l'onglet Statues de Temple sont désormais à jour et fiables dans leur ensemble — pour une future demande sur le Temple, repartir de ce document + une relecture ciblée du code concerné, pas d'un nouvel audit complet.

**URL de l'Artifact** : https://claude.ai/code/artifact/7554fe23-0c31-4dfb-b10d-cc589dfc1345 (même URL que d'habitude) — version 21, label "temple-survie-2026-10-02".
