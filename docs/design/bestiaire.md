# Bestiaire

**Reconstruit intégralement le 2026-09-01** (`game/src/data/enemies.lua`, `game/src/rules/encounter.lua`, `game/src/rules/game.lua` pour la structure de run, `game/src/rules/combat.lua` pour la Brûlure/le multiplicateur de dégâts). Le bestiaire a été **entièrement refondu** depuis la dernière passe (2026-08-30) : le mode "Run Infini" à 10 ennemis + 2 boss tirés 50/50 documenté alors n'existe plus tel quel — remplacé par un **système de 4 biomes**, 20 ennemis communs (5 par biome) et 4 boss (1 par biome). Tout ce qui suit remplace intégralement la version précédente de ce document.

Toutes les valeurs ci-dessous sont celles de **niveau 1**. Chaque ennemi scale avec son niveau (voir Scaling, en bas de page) : les PV et les montants de coups affichés en jeu sont donc plus élevés dans un combat avancé.

> **Mise à jour du 2026-09-02 — "Puissance" renommée "Incandescence" sur les 4 coups du Volcan concernés.** Les 4 coups qui posaient auparavant "Puissance" sur Salamandre de Lave (Surchauffe), Golem de Magma (Cœur en Fusion), Vouivre des Cendres (Montée en Cendres) et le boss Élémentaire de Feu (coup renommé "Montée en Incandescence", ex-"Montée en Puissance") posent désormais un statut distinct, "Incandescence" — voir le paragraphe Volcan ci-dessous et le Glossaire pour le détail du mécanisme (bonus flat, pas +25%/stack). Aucun ennemi de ce document ne porte plus la vraie Puissance.

## Le système de biomes

Un run "bounded" (celui joué normalement, voir plus bas) tire **2 des 4 biomes sans remise** (`foret`/`catacombes`/`canyon`/`volcan`, `pick_run_biomes` dans `game.lua`) au tout début du run. Chaque combat commun est désormais **confiné à un seul biome** (`Encounter.generate_encounter(budget, rng, biome)`, filtré via `random_pool` dans `encounter.lua`) — fini le pool plat unique d'avant.

Chaque biome porte **une mécanique de gameplay lisible**, pas seulement un thème visuel :

- **Forêt Sauvage** — biome du Saignement : 3 de ses 5 ennemis (Loup, Araignée, Gobelourd en mode agressif) posent du "Saignement", punissant les combats qui traînent plutôt que les gros coups ponctuels. Le Troll est le seul ennemi du jeu à pouvoir se soigner (Régénération), mais perd cette option **définitivement** dès qu'il subit ne serait-ce qu'un seul point de dégâts "feu" au cours du combat (`e.fire_touched_ever`, posé une fois pour toutes dans `Combat.deal_damage`, jamais réinitialisé) — apporter une source de feu neutralise durablement sa seule capacité de sustain.
- **Catacombes** — biome de la résurrection : le Prêtre Déchu relève les Squelette Archer/Garde-Ossements tombés au combat (`kind = "revive"`, généralisé via `move.revive_template_ids`, résolu dans `Game.resolve_enemy_action`) — laisser un squelette "mort" sur le champ ne suffit pas, il faut soit l'achever pour de bon en abattant le Prêtre en premier, soit accepter qu'il revienne. Le Golem de Pierre y ajoute une mécanique de soutien à part (voir encadré ci-dessous).
- **Canyon des Brigands** — biome du focus-fire : 4 de ses 5 ennemis (Bandit, Éclaireuse, Chef de Bande, Tireuse) ciblent systématiquement le héros au moins de PV (`target_mode = "lowest-hp"`, déterministe) plutôt que le tirage pondéré aléatoire des autres biomes — un héros déjà blessé y reste une cible prioritaire tant qu'il n'est pas soigné ou Camouflé, et Provocation/Discrétion n'y ont aucune prise sur ces 4 ennemis (elles ne jouent qu'en mode "random").
- **Volcan** — biome de l'escalade : plusieurs ennemis (Salamandre, Golem de Magma, Vouivre, et le boss) gagnent régulièrement "Incandescence" (`kind = "buff-self"`, `status_key = "incandescence"`) — un statut **distinct de Puissance** (2026-09-02, renommé depuis un ancien détournement de Puissance sur ces 4 mêmes coups) : bonus **flat** (+X dégâts physiques, X = valeur actuelle, additionné avant tout multiplicateur — voir Glossaire), pas +25%/stack multiplicatif comme Puissance, et qui **ne redescend jamais tout seule** (même famille que Vol/Brûlure, volontairement absente de `Game.decay_end_of_turn_statuses`) — contrairement à Puissance elle-même, qui décroît désormais de 1 en fin de tour, symétriquement côté héros et côté ennemi. Cracheur de Braise et Élémentaire de Cendre posent en plus "Brûlure" (voir Glossaire), qui elle non plus ne décroît jamais seule. Un combat de Volcan qui s'éternise devient strictement plus dangereux à chaque tour — biome qui punit la lenteur, contrairement à la Forêt qui punit surtout l'absence de soin.

Le mode "Infini" (hors périmètre de la mécanique de biomes, signalé dans le code comme "bientôt retiré du jeu") et "Tester le boss" au menu continuent d'utiliser le pool complet non filtré par biome — voir Composition de rencontre plus bas.

### Encadré — Golem de Pierre : "Protection", une exception au moteur

Le Golem de Pierre (Catacombes) porte une capacité, "Protection", qui **ne vit pas dans `choose_move`/`Game.resolve_enemy_action`** comme tout le reste du bestiaire : c'est un hook inconditionnel posé directement dans `Game.start_turn` (`game.lua`), après `Encounter.roll_telegraphs`. À **chaque** début de tour, chaque Golem de Pierre vivant donne 2 "bouclier" à **tous les autres ennemis vivants** du combat — indépendamment du coup qu'il télégraphie ce tour-là (qui reste uniquement Poing de Pierre). Plusieurs Golems dans un même combat déclenchent chacun leur propre distribution (cumulable).

## Forêt Sauvage

| Ennemi | Icône | PV (Nv.1) | Coût (budget) | Ciblage | Coups |
|---|---|---|---|---|---|
| Gobelin Maraudeur | 👺 | 15 | 8 | Aléatoire | Griffure (épée, 4 dégâts, fréquent ~2/3) · Charge Brutale (💥, 7 dégâts, rare ~1/3) |
| Troll des Marais | 🧌 | 28 | 14 | Aléatoire | Coup de Massue (épée, 8 dégâts, fréquent ~2/3) · Régénération (+15 PV, rare ~1/3 — indisponible à PV pleins, **définitivement** indisponible dès la 1ʳᵉ brûlure subie ce combat) |
| Gobelourd | 🗿 | 20 | 12 | Aléatoire | Coup de Gourdin, alterne à chaque tour : mode agressif (8 dégâts + "Saignement" 1) / mode défensif (3 dégâts + 3 bouclier ce tour) — attaque toujours, quel que soit le mode. 3 bouclier passif permanent (`shield_base`). |
| Loup Enragé | 🐺 | 10 | 9 | Aléatoire | Morsure (épée, 7 dégâts + "Saignement" 2, toujours) — peu de PV, glass cannon |
| Araignée Venimeuse | 🕷️ | 12 | 7 | Aléatoire | Piqûre (☠️, 2 dégâts brut + "Saignement" 3, toujours) |

## Catacombes

| Ennemi | Icône | PV (Nv.1) | Coût (budget) | Ciblage | Coups |
|---|---|---|---|---|---|
| Squelette Archer | 💀 | 12 | 6 | Aléatoire | Tir à l'Arc (arc, 4 dégâts, toujours) |
| Nécromancien Novice | 🧙 | 10 | 9 | Aléatoire | Malédiction ("Vulnérabilité" 3 **et** "Incapacité" 3, aucun dégât direct, fréquent ~2/3) · Toucher Nécrotique (magique, 3 dégâts, rare ~1/3) — règle cachée ci-dessous |
| Golem de Pierre | 🪨 | 35 | 20 | Aléatoire | Poing de Pierre (épée, 7 dégâts, seulement s'il a subi des dégâts pendant la phase joueur de ce tour, sinon ne fait rien). 3 bouclier passif permanent. **+ "Protection"** (voir encadré ci-dessus). |
| Garde-Ossements | 💀 | 18 | 10 | Aléatoire | Coup de Bouclier (🛡️, 5 dégâts, fréquent ~2/3) · Brise-Volonté ("Incapacité" 2, aucun dégât, rare ~1/3). 2 bouclier passif permanent. |
| Prêtre Déchu | 🧟 | 16 | 13 | Aléatoire | Rituel de Rappel (relève tous les Squelette Archer/Garde-Ossements tombés, ~2/5 si au moins un est mort) · sinon Toucher Flétrissant (magique, 4 dégâts) |

**Règle cachée du Nécromancien Novice** (volontairement absente de tout texte affiché au joueur) : si aucun ennemi vivant n'inflige de dégâts directs ce tour une fois tous les télégraphes tirés, chaque Nécromancien Novice présent échange sa Malédiction contre Toucher Nécrotique — jamais un tour entièrement inoffensif côté monstres.

## Canyon des Brigands

| Ennemi | Icône | PV (Nv.1) | Coût (budget) | Ciblage | Coups |
|---|---|---|---|---|---|
| Bandit Fourbe | 🔪 | 14 | 9 | **PV le plus bas** (déterministe) | Coup Sournois (épée, 6 dégâts, toujours) |
| Chaman Gobelin | 🪄 | 12 | 9 | Aléatoire | Chant Rituel (soigne un allié blessé de 10 PV s'il y en a un) · sinon Chant Rituel (repli) (magique, 3 dégâts) |
| Éclaireuse des Sables | 🏹 | 13 | 10 | **PV le plus bas** | Flèche Barbelée (arc, 4 dégâts, fréquent ~2/3) · Tir Perçant (arc, 7 dégâts, rare ~1/3) |
| Chef de Bande | 👑 | 22 | 14 | **PV le plus bas** | Charge de groupe (épée, 7 dégâts **+ 2 par autre ennemi vivant**, recalculé à chaque tirage, toujours). 1 bouclier passif permanent. |
| Tireuse Embusquée | 🏹 | 11 | 7 | **PV le plus bas** | Tir Ajusté (arc, 5 dégâts, toujours) |

Charge de groupe du Chef de Bande n'est **pas** mise à l'échelle du niveau sur son bonus "+2 par autre ennemi vivant" (flat) — seule sa base de 7 dégâts scale ; un Chef de Bande seul face à 3 autres ennemis vivants inflige donc 7+6=13 dégâts avant scaling/variance.

## Volcan

| Ennemi | Icône | PV (Nv.1) | Coût (budget) | Ciblage | Coups |
|---|---|---|---|---|---|
| Salamandre de Lave | 🦎 | 14 | 10 | Aléatoire | Griffure Ardente (feu, 5 dégâts, fréquent ~2/3) · Surchauffe (gagne "Incandescence" 2, aucun dégât, rare ~1/3 — ne redescend jamais seule) |
| Cracheur de Braise | 🌫️ | 12 | 8 | Aléatoire | Jet de Braise (magique, 3 dégâts + "Brûlure" 1, toujours — la Brûlure ne décroît jamais seule) |
| Élémentaire de Cendre | 🌫️ | 11 | 8 | Aléatoire | Souffle Étouffant ("Vulnérabilité" 2 + "Brûlure" 1, aucun dégât direct, 1/2) · Éclat Brûlant (magique, 4 dégâts, 1/2) |
| Golem de Magma | 🪨 | 32 | 15 | Aléatoire | Poing Incandescent (feu, 7 dégâts, fréquent ~2/3) · Cœur en Fusion (gagne "Incandescence" 2, aucun dégât, rare ~1/3 — ne redescend jamais seule). 2 bouclier passif permanent. |
| Vouivre des Cendres | 🐉 | 20 | 17 | Aléatoire | Griffure de Braise (feu, 6 dégâts, 2 tours sur 3) · Montée en Cendres (gagne "Incandescence" 2, aucun dégât — **garanti, automatique tous les 3 tours**, pas aléatoire — ne redescend jamais seule) |

## Mécanique transversale : Élite

N'importe quel ennemi commun ou boss peut être tiré comme variante **Élite** (`Encounter.promote_to_elite`) :

- **×1.6** sur PV max et bouclier passif.
- **×1.3** sur tout montant porté par un coup une fois télégraphié : dégâts, saignement, brûlure, dégâts-à-tous, 2ᵉ statut d'une debuff double, gain de bouclier ponctuel.
- **Gratuit dans le budget de rencontre** — `Enemies.cost_at_level` ne lit jamais le flag `elite`, la promotion se fait sur une instance déjà créée, après que le budget a déjà été calculé.
- Visuel (revu le 2026-09-02, revirement explicite — "le cadre doré et scintillant... n'est pas bon, il ne faut pas mettre de cadre, comme pour un ennemi normal") : cadre strictement identique à un ennemi normal, ~+18% de taille de rendu inchangé (zone cliquable inchangée) — le signal "doré et scintillant" se lit désormais sur la **barre de PV elle-même**. Nom entouré de 2 étoiles au survol (icône vectorielle dédiée depuis le 2026-09-02 — le caractère Unicode "★" utilisé avant ne s'affichait jamais, absent de la police pixel-art du jeu).

**Déclenchement** : un ennemi tiré au hasard parmi ceux du combat devient Élite au **4ᵉ combat de chaque biome** — `combat_index == 4` (fin du 1ᵉʳ biome) et `combat_index == 8` (fin du 2ᵉ, juste avant le Refuge puis le Boss), uniquement en mode "bounded". Jamais en mode "Infini", jamais sur un Boss (le tirage se fait sur `enemies[]` du combat courant, jamais appliqué dans `Encounter.boss_encounter`).

## Boss

Rencontre fixe, jamais mêlée à la génération aléatoire des combats communs (`boss_only = true`, exclus du pool de `random_pool`). **Le boss final est désormais choisi par le dernier biome traversé** (`Encounter.boss_encounter(uid_gen, rng, biome)`) plutôt que par un tirage 50/50 entre 2 boss fixes comme dans la version précédente de ce document :

| Biome | Boss |
|---|---|
| Forêt Sauvage | Homme Arbre (inchangé) |
| Canyon des Brigands | Aigle Géant (inchangé) |
| Catacombes | **Roi Squelette** (nouveau) |
| Volcan | **Élémentaire de Feu** (nouveau) |

"Tester le boss" au menu (aucun biome connu à ce stade) retombe sur un tirage aléatoire uniforme parmi les 4. Toujours niveau 1.

### Homme Arbre 🌳 — avec 4 Pousses d'Arbre 🌱

Composition fixe : 2 Pousses d'Arbre, Homme Arbre (centre), 2 Pousses d'Arbre.

**Pousse d'Arbre** — 3 PV, coût 3, ciblage aléatoire.
- Griffure de Ronce (🌿, 2 dégâts, toujours)

**Homme Arbre** — 80 PV, coût 60, ciblage aléatoire. Sensible au feu : tout coup portant le tag "feu" lui inflige +50% de dégâts (`Combat.damage_multiplier`).
- Coup de Branche (🦴, épée, 8 dégâts à un aventurier — ~1/2 chance hors invocation)
- Onde Sylvestre (🍃, magique, 3 dégâts à tous les aventuriers — l'autre ~1/2 chance)
- Renaissance Sylvestre (🌱, ramène les Pousses d'Arbre vaincues à pleine vie — seulement possible si au moins une Pousse est morte, ~1/3 chance dans ce cas)

### Aigle Géant 🦅

Seul, aucun sbire — tout son budget de PV/tours est porté par lui seul.

**Aigle Géant** — 95 PV, coût 65, ciblage aléatoire.

Cycle à 2 temps :
- **Au sol** (`vol` = 0) : ~35% de chance de choisir Envol plutôt qu'attaquer ; sinon 50/50 entre Coup de Bec et Serres Tranchantes.
  - Coup de Bec (🦅, épée, 6 dégâts à un aventurier)
  - Serres Tranchantes (🦅, épée, 9 dégâts à un aventurier)
  - Envol (🩶, gagne "Vol" + inflige 2 dégâts faibles à TOUS les aventuriers)
- **En vol** (`vol` > 0) : forcé sur Charge en Piqué, sa seule attaque disponible tant qu'il vole.
  - Charge en Piqué (🦅, épée, 14 dégâts à un aventurier — le ramène au sol, retire "Vol")

"Vol" réduit à 0 tout dégât de type physique ("épée") pendant qu'il est actif — contraint le joueur à garder une source de dégâts magique/nécrotique sous la main. Ne décroît jamais seul — seule sa propre Charge en Piqué le retire.

### Roi Squelette 💀 (nouveau) — avec 4 Squelette Archer 💀

Composition fixe : 2 Squelette Archer, Roi Squelette (centre), 2 Squelette Archer — même structure "boss + sbires déjà présents dès le début" que l'Homme Arbre, mais réutilise le template **commun** "Squelette Archer" comme sbires (pas un minion dédié), pour faire directement écho au Prêtre Déchu du même biome.

**Roi Squelette** — 75 PV, coût 58, ciblage aléatoire.
- Coup Royal (⚔️, épée, 9 dégâts à un aventurier — ~1/2 chance hors résurrection)
- Décret Funeste (💀, magique, 3 dégâts à tous les aventuriers — l'autre ~1/2 chance)
- Rituel de Réveil (💀, relève tous les Squelette Archer vaincus, s'il y en a — ~1/3 chance si au moins un est mort)

Même mécanique que le Prêtre Déchu (Catacombes), portée à l'échelle du boss : laisser les Squelette Archer "morts" sur le champ ne suffit pas tant que le Roi Squelette est vivant.

### Élémentaire de Feu 🔥 (nouveau)

Seul, comme l'Aigle Géant — aucun sbire.

**Élémentaire de Feu** — 95 PV, coût 66, ciblage aléatoire. Réunit les 2 mécaniques du Volcan sur un seul ennemi :
- Montée en Incandescence (🔥, gagne "Incandescence" 2, aucun dégât — ~25% de chance, ne redescend jamais seule — coup renommé depuis "Montée en Puissance" le 2026-09-02, même mécanique du Volcan renommée pour tout le biome)
- Éruption (🌋, magique, 3 dégâts à tous les aventuriers — ~19% de chance)
- Griffe Ardente (🔥, épée, 7 dégâts à un aventurier — ~28% de chance)
- Souffle Incandescent (🔥, magique, 5 dégâts + "Brûlure" 2 à un aventurier — ~28% de chance)

## Structure d'un run et sélection du boss

- Un run "bounded" tire **2 des 4 biomes sans remise** au tout début (`pick_run_biomes`), **4 combats classiques par biome** (`BOUNDED_COMBAT_COUNT = 8`, était 9 avec un seul biome implicite dans la version précédente de ce document).
- `Game.current_biome(state)` : combats 1-4 → 1ᵉʳ biome tiré, combats 5-8 → 2ᵉ biome.
- Un écran d'annonce de biome (`biome_intro`) s'affiche **2 fois par run** : au tout début, puis juste après le 4ᵉ combat (transition vers le 2ᵉ biome).
- Après le 8ᵉ combat classique, Le Refuge est forcé (voir `docs/design/evenements.md`), puis le Boss — choisi par le **dernier** biome traversé (voir table ci-dessus).

## Composition de rencontre et courbe de difficulté

- **Taille** : 1 à 4 ennemis par combat (`MAX_ENEMIES_PER_COMBAT = 4`).
- **Budget du combat n** : `round(20 × 1.12^(n-1))` (`BUDGET_BASE = 20`, `BUDGET_GROWTH = 0.12`) — inchangé depuis la dernière passe, toujours un placeholder à ajuster en playtest.
- **Génération** : 40 tentatives (nombre d'ennemis 1-4, puis un ennemi au hasard dans le pool **confiné au biome du combat** pour chaque emplacement, niveau = `round((budget/nb d'emplacements) / coût de l'ennemi)`, minimum 1) — la composition dont le coût total colle le mieux au budget est retenue. Le mode "Infini" (pool complet, non filtré par biome) et "Tester le boss" (rencontre fixe, hors budget) restent les deux exceptions à ce filtrage par biome.
- **Scaling par niveau** : `LEVEL_GROWTH = 0.20` (+20% par niveau) appliqué à toute valeur de base ; `VALUE_VARIANCE = 0.20` (±20%) ajoute une variance aléatoire à chaque tirage.
- **Ciblage** (`Encounter.pick_hero_target`) :
  - Un héros Camouflé est exclu du pool de cibles tant qu'un autre héros vivant non-Camouflé existe.
  - Mode "lowest-hp" (Bandit, Éclaireuse, Chef de Bande, Tireuse — tout le Canyon sauf le Chaman) : déterministe, cible toujours le héros au moins de PV parmi les visibles.
  - Mode "random" (tous les autres) : pondéré — chaque point de Discrétion du candidat retire 10% de poids relatif (jamais négatif) ; "Provocation" (Paladin) et la malédiction du Temple "Le Martyr" appliquent chacun ×1.5 au poids, cumulables entre eux.

## Illustrations

Tous les 20 ennemis communs et les 4 boss ont désormais une illustration réelle dans `game/assets/characters/enemies/<template_id>.png` (25 fichiers — l'Aigle Géant en a 2, `aigle.png`/`aigle-vol.png`, au sol et en vol). Plus aucun ennemi ne retombe sur un emoji/une silhouette générique.

## Écart avec les anciens documents

- Le bestiaire précédemment reconstruit par ce document (2026-08-30 : 10 ennemis "Run Infini" sans biome + 2 boss tirés 50/50) est **entièrement obsolète** — refonte complète du 2026-09-01, pas une simple mise à jour incrémentale.
- Le système de biomes (4 biomes, 20 ennemis, 4 boss choisis par biome, mécanique Élite) ne figure dans AUCUN des deux anciens documents de référence (Google Doc, GDD BMAD) — absence totale, ce système a été construit bien après leur rédaction.
- "Incandescence" (2026-09-02) : ce document lui-même documentait à tort "Puissance" sur les 4 coups du Volcan concernés jusqu'à cette passe — corrigé, voir encadré en tête de page.
