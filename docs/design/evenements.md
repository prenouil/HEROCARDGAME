# Événements post-combat

Reconstruit depuis le code le 2026-08-30 (`game/src/ui/controller.lua`, refonte complète du 2026-08-30 — la logique de sélection/déclenchement de ces écrans vit côté contrôleur UI, pas dans `src/rules/`). Absent des deux anciens documents (Google Doc, GDD BMAD), rédigés avant l'existence de ce système.

Couvre 4 évènements : Feu de camp, la Forge, le Temple et le Refuge. Le Temple n'y est décrit qu'en tant qu'ÉVÈNEMENT (déclenchement, ce que le joueur voit et fait) — le détail des 8 bénédictions et 8 malédictions qu'il propose vit exclusivement dans `docs/design/temple.md` ("Statues de Temple").

## Séquence complète après un combat gagné

1. **Draft** (`Controller:enter_draft_screen`) : le joueur choisit 1 carte parmi 3 à ajouter au deck (ou "Ne rien prendre"). Pas détaillé ici (hors périmètre de cet onglet), mais nécessaire pour comprendre où s'insère la suite.
2. **1 seul évènement "camp"** est ensuite déclenché — Feu de camp, Forge OU Temple, jamais plus d'un par combat, jamais 2 fois le même type d'affilée (sauf l'exception du Refuge forcé, voir plus bas).
3. Le combat suivant démarre (ou le Boss, si c'était le 9ᵉ et dernier combat d'un run "bounded").

## Sélection de l'évènement "camp" (Feu de camp / Forge / Temple)

Un seul tirage à 3 issues (`Controller:enter_post_combat_sequence`), remplaçant un ancien système à 2 probabilités indépendantes.

1. **Viabilité** de chaque candidat :
   - **Feu de camp** : viable seulement si au moins 1 des 4 aventuriers de la run est sous 70% de ses PV max (`CAMPFIRE_VIABLE_HP_FRACTION = 0.70`), vivant ou non — sinon il n'y a personne à soigner utilement.
   - **Temple** : viable seulement s'il existe au moins un type (bénédiction ou malédiction) avec un effet disponible ET un aventurier éligible (`Temple.any_type_viable`, voir `docs/design/temple.md`).
   - **Forge** : toujours viable — même deck entièrement amélioré, l'écran propose "Passer".
2. **Pas 2 fois de suite** : le type du dernier évènement "camp" tiré (`last_post_combat_event`) est retiré des candidats viables — sauf si ça viderait complètement la liste (la Forge, seule immunisée contre les 2 filtres de viabilité ci-dessus, peut alors se répéter plutôt que de planter/retomber sur un mauvais défaut).
3. Tirage aléatoire uniforme parmi les candidats restants.

Ce tirage ne concerne JAMAIS Le Refuge, qui n'en fait jamais partie (voir plus bas).

## Feu de camp

- **Déclenchement** : 1 des 3 issues possibles du tirage "camp" ci-dessus (si viable).
- **Effet** : le joueur choisit **1 seul aventurier** parmi les 4 de la run (vivant ou non), qui se soigne aussitôt de **30% de ses PV max** (`CAMPFIRE_HEAL_FRACTION = 0.30`, arrondi comme tout soin). Résolu en un clic, pas de bouton "Confirmer" séparé.
- **Condition d'apparition** : au moins 1 aventurier sous 70% de ses PV max — sinon jamais tiré (voir Viabilité ci-dessus).

## La Forge

- **Déclenchement** : 1 des 3 issues possibles du tirage "camp" ci-dessus — toujours disponible, aucune condition de viabilité.
- **Effet** : jusqu'à **4 cartes** (`Forge.CHOICE_COUNT = 4`) tirées au hasard parmi toutes les instances du deck du joueur qui ne sont pas déjà améliorées (deck + main + défausse), moins si le deck n'en a pas assez d'améliorables (jusqu'à 0 → l'écran affiche alors "Toutes vos cartes sont déjà améliorées" et propose "Passer"). Le joueur choisit 1 carte parmi les propositions, elle passe à sa version "+" (voir `Cards.upgraded_def` — une seule amélioration possible par carte, jamais de second palier).
- **Exclusion** : la carte tout juste gagnée au Draft du même combat (étape 1 ci-dessus) est exclue des propositions de la Forge qui suit — elle ne peut jamais s'améliorer elle-même au tour où elle vient d'être obtenue.

## Le Temple

- **Déclenchement** : 1 des 3 issues possibles du tirage "camp" ci-dessus (`Controller:enter_temple_screen`) — viable seulement s'il existe au moins un type (bénédiction ou malédiction) avec un effet disponible ET un aventurier éligible pour lui (`Temple.any_type_viable`, voir Viabilité ci-dessus). Si aucun type n'est viable, l'écran n'apparaît simplement pas ce combat-ci — on saute directement à la suite de la file, sans "Passer" à afficher.
- **Ce que voit et fait le joueur**, dans l'ordre :
  1. Un **type** est tiré au sort parmi les types viables (Bénédiction xor Malédiction, jamais les deux à la fois, jamais un mélange dans le même choix) — si un seul type est viable, ce sera toujours lui.
  2. Jusqu'à **3 effets distincts** de ce type sont proposés (`Temple.CHOICE_COUNT`), sans remise, montrés en ligne au-dessus des aventuriers — moins si le pool n'en contient pas assez (jamais le cas en pratique : 8 bénédictions et 8 malédictions disponibles).
  3. La liste des **aventuriers éligibles** est affichée à côté : vivant ET ne portant pas déjà un effet de CE type (un même aventurier peut porter une bénédiction et une malédiction en même temps, jamais 2 du même type) — les inéligibles sont grisés.
  4. Le joueur choisit **1 aventurier ET 1 effet** (les 3 statues proposées sont toujours du même type, donc toujours compatibles avec n'importe quel aventurier éligible — seule l'éligibilité de l'aventurier limite quoi que ce soit), puis clique **Confirmer** : aucune résolution automatique dès le 2ᵉ clic, il faut les deux choix ET le clic. Aucun "Passer" n'est proposé sur cet écran ("il ne peut pas ne pas choisir") — c'est l'absence de viabilité en amont (étape Déclenchement) qui gère le cas où il n'y aurait rien à proposer.
  5. Une courte animation confirme le choix (statues non retenues qui s'estompent, celle choisie qui reste) avant d'enchaîner sur la suite de la file post-combat.
- **Contenu détaillé des 8 bénédictions et 8 malédictions** (nom, couleur de statue, effet précis) : voir `docs/design/temple.md` ("Statues de Temple") — non répété ici.

## Le Refuge

- **Déclenchement** : jamais issu du tirage "camp" ci-dessus — **SEUL et unique chemin** : `Controller:enter_post_combat_sequence` force Le Refuge, sans exception, quand ce combat vient d'être le **9ᵉ et dernier combat classique** d'un run borné (`run_mode == "bounded"`, `BOUNDED_COMBAT_COUNT = 9`) — juste avant le Boss. Cette garantie ("reposé juste avant le Boss") prime même sur la règle "jamais 2 fois de suite" : si Le Refuge était déjà le dernier évènement tiré, il revient quand même.
- **Effet** : soigne **tous les aventuriers d'un coup** de **30% de leurs PV max** chacun (`REFUGE_HEAL_FRACTION = 0.30`, même fraction que le Feu de camp, mais appliquée à toute l'équipe et sans aucun choix). Un clic sur le bouton "Se reposer" déclenche le soin (action requise — avant une correction, le soin s'appliquait automatiquement à l'entrée sur l'écran, avant même que le joueur ne voie ses PV réels).
- Ne peut **jamais** sortir en dehors de ce chemin forcé.

## Écart avec les anciens documents

Aucun — Feu de camp / Refuge / Forge / Temple sont tous postérieurs à la rédaction du Google Doc et du GDD BMAD, qui ne décrivent aucun système d'évènement post-combat de ce type.
