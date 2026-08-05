---
title: Game Brief — HERO CARD GAME
status: draft
created: 2026-08-04
updated: 2026-08-04
---

# Game Brief : Hero Card Game

## Executive Summary

Hero Card Game est un deck-building roguelike où le joueur mène une troupe de 4 aventuriers — piochés parmi une collection qui grandit au fil des runs — à travers des quêtes à embranchements, jusqu'à un boss, avant de rentrer au village pour dépenser ses ressources. Sur le fond, la formule est familière (on doit beaucoup à *Slay the Spire*) ; la spécificité tient à des choix précis et assumés : une énergie de combat individuelle par aventurier plutôt qu'un pool global, des ennemis qui annoncent leurs actions au lieu de punir par surprise, et un déblocage significatif garanti à chaque run plutôt qu'un sentiment de vacuité une fois l'objectif atteint.

Le jeu vise un public qui ne cherche pas l'originalité à tout prix : un monde heroic fantasy classique et rassurant, un système intuitif sans règles obscures à apprendre, et une ampleur de contenu pensée pour créer un vrai réflexe de collection (détails du public visé en section suivante).

Porté par une équipe de 2 personnes sur leur temps personnel, sans financement externe, le projet avance en deux étapes resserrées : un prototype minimaliste interne en un mois, puis une boucle jouable minimale (combat + run + quêtes de déblocage) le mois suivant.

## Vision

**Core fantasy :** Devenir le meneur d'une troupe de héros archétypaux qu'on voit grandir, combat après combat, dans un monde de fantasy classique et rassurant — jusqu'à ce que la collection tout entière porte sa marque.
*(Première version validée par le porteur du projet — à raffiner si l'expérience de jeu la fait bouger.)*

**Pitch :** Un roguelike de deck-building où l'on ne cherche pas à réinventer la formule, mais à corriger ce qui frustre dans les meilleurs titres du genre — l'injustice du chaos, le vide après la victoire, l'absence de narration — tout en habillant le tout d'un monde heroic fantasy que le joueur reconnaît dès la première seconde.

## Target Players & Market

**Public cible :** des joueurs de jeux de cartes roguelike qui ne veulent pas s'investir dans quelque chose de trop original. Ce que ça implique concrètement :
- Système intuitif sans besoin de comprendre des règles complexes en amont : les personnages lancent des sorts, les monstres annoncent clairement leurs actions.
- Un monde heroic fantasy classique façon AD&D comme valeur sûre de compréhension (guerrier, mage, voleur, paladin ; gobelins, squelettes, trolls).
- Cartes lisibles, VFX explicites et agréables.

**Points d'ancrage identifiés par le porteur du projet :**
- Fans de *Pokémon* → attirés par l'ampleur de la collection (40 aventuriers, ~480 cartes).
- Joueurs de *Sims* / *Animal Crossing* → le village mignon, à parcourir physiquement.
- Vieux JRPGistes → réminiscence de *Suikoden* (collecte de personnages), du déblocage de Yuffie/Vincent dans *FF7*, des combats vus de dos.

**Plateformes :** PC (souris et manette) et smartphone, à parité — argument du projet : un jeu de cartes ne demandant aucune dextérité doit être aussi confortable sur les deux, avec une ergonomie tactile pensée dès le départ plutôt qu'adaptée après coup.

## Core Fundamentals

**Genre :** Deck-building roguelike.

**Boucle de jeu :** Choisir 4 aventuriers (1 ou 2 parfois imposés) → sélectionner une quête sur la carte → traverser combats et événements → vaincre un boss → débloquer une récompense significative → retour au village pour dépenser les ressources accumulées → relancer un run.

**Piliers de gameplay (différenciants, pas des platitudes) :**
1. **Énergie individuelle par aventurier**, pas un pool global — chaque personnage a sa propre réserve, ce qui change la lecture tactique de « combien j'ai à dépenser » à « qui je fais agir maintenant ».
2. **Les ennemis annoncent leurs actions à l'avance** — réponse directe à la frustration du chaos de *Slay the Spire*, où la punition peut sembler injuste.
3. **Chaque run débloque quelque chose de significatif et permanent** — réponse directe au vide ressenti dans *Slay the Spire* une fois l'objectif atteint (« pourquoi relancer une partie ? »).
4. **Un monde familier plutôt qu'original** — pari assumé que l'accessibilité et le confort priment sur la nouveauté, pour ce public précis.

**Mécaniques principales :** main de 5 cartes, glisser-déposer, coût en énergie par carte, synergie de classe (une carte de la classe de l'aventurier déclenche son passif), village à déplacement physique avec boutiques et PNJ.

**Objectifs d'expérience joueur :** la fierté de surmonter un combat par la stratégie plutôt que par la chance ou la mémorisation méta ; le confort d'un monde reconnaissable ; la certitude de toujours repartir avec quelque chose, même après une défaite.

## References & Differentiation

Comparatif construit par le porteur du projet lui-même contre plusieurs titres du genre — version condensée ci-dessous, détail complet forces/faiblesses par titre dans `addendum.md` :

| Jeu | Ce qui est pris |
|---|---|
| *Slay the Spire* | Structure de run, feux de camp, adversité aléatoire |
| *Monster Train* | Personnages en ligne façon petite armée, phase de préparation calme entre combats |
| *Tainted Grail* | Diversité du loot, déplacement physique au village entre PNJ |
| *Dead Cells* | Idée d'une justification narrative à la résurrection *(encore non résolue — voir Risques)* |
| *Final Fantasy Mystic Quest* (SNES) | Mise en scène de combat : ennemis grands et de face, groupe en ligne à l'arrière |
| *Knight of Pen & Paper* | Référence de positionnement d'équipe en ligne |

Au-delà des piliers déjà cités en Core Fundamentals (énergie individuelle, ennemis qui télégraphient, déblocage garanti), deux différenciateurs supplémentaires ressortent du comparatif : une narration qui monte en puissance avec la progression, plutôt qu'absente (*Wildfrost*) ou imposée d'entrée (*Griftlands*) ; et une construction d'équipe à 4 compagnons (1-2 parfois imposés), qui crée un investissement à la fois individuel et collectif.

## Scope & MVP

**Équipe :** 2 personnes, sur leur temps personnel — pas d'apport financier externe.

**Timeline :**
- **Mois 1 :** Prototype Minimaliste V1 (usage interne).
- **Mois 2 :** Jeu jouable au minimum — combat + run + quêtes de déblocage.

**Monétisation :** achat unique.

**MVP — Prototype Minimaliste V1 (déjà défini par le porteur du projet) :**
- 4 aventuriers : guerrier, clerc, mage, assassin.
- 1 skin représentatif par classe, avec animations idle (2 frames), action, coup reçu, KO.
- 8 passifs (2 par aventurier) et 4 cartes spéciales (1 par aventurier).
- 2 cartes de départ communes : Coup direct (attaque), Esquive (défense).
- 5 monstres différents répartis sur 3 combats.
- Boucle de combat complète : pioche → le joueur joue ses cartes → résolution des ennemis → tour suivant → victoire (combat suivant) ou défaite (recommencer).
- Interactions de carte : défausse, réserve, concentration (gain d'énergie), ciblage (ennemi/allié/effet global) ; carte de classe déclenchant le passif.

Ce périmètre est délibérément resserré : il valide la boucle de combat et la lisibilité de l'énergie individuelle avant tout investissement dans les 40 aventuriers, les ~480 cartes ou les ~640 améliorations prévus à terme.

**Au-delà du MVP (cible Mois 2) :** structure de run complète, carte de quêtes, boucle de progression pilotée par les déblocages.

## Content & Direction

**Monde :** heroic fantasy classique — forêts, marais, montagnes, gobelins, squelettes, trolls en début de jeu ; classes, lieux et monstres plus exotiques débloqués plus tard, une fois le joueur familiarisé avec les règles du monde.

**Narration :** entièrement portée par les dialogues entre personnages — pas de narrateur, pas de narration environnementale. Non bloquante et skippable, elle monte en présence avec la progression (peu présente au début pour laisser jouer, plus présente ensuite pour relancer l'intérêt). Suivie via un journal PNJ, déclenchée par des compteurs d'événements.

**Ampleur de contenu :** 40 aventuriers (4 au départ), environ 480 cartes et 640 améliorations à débloquer sur la durée complète ; runs de ~20 minutes en début de campagne à ~1 heure en fin de campagne ; plusieurs centaines d'heures pour une collection à 100 %.

**Direction artistique :** designs d'aventuriers « ultra classiques, stéréotypés et reconnaissables » — choix assumé, cohérent avec la thèse d'accessibilité par la familiarité. Mise en scène de combat façon *Final Fantasy Mystic Quest* (ennemis grands, de face) et *Knight of Pen & Paper* (groupe du joueur en ligne, de dos).

**Direction sonore :** non définie dans les sources actuelles — voir Risques.

## Risks & Open Questions

- **Justification narrative de la résurrection** encore non tranchée — le porteur du projet souhaite un ressort scénaristique façon *Dead Cells* (malédiction, réincarnation).
- **Rythme du loot** sur un run entier reste à ajuster.
- **Nom du mécanisme de rétention/défausse des cartes** en fin de tour — à trouver, cohérent avec l'univers.
- **Direction sonore** entièrement à définir.
- ~~**Incohérence de nom** entre les documents sources~~ — **Résolu** : le nom canonique du jeu est **« Hero Card Game »** (tranché par le porteur de projet lors de la GDD). Le nom de dossier/dépôt « HERO CARD GAME » reste une question d'infrastructure distincte, non affectée.
- **Discipline de scope après le Mois 2** : le plein périmètre (40 aventuriers, ~480 cartes, ~640 améliorations) reste très large pour une équipe de 2 — la rigueur du Prototype Minimaliste V1 (voir Scope & MVP) doit se maintenir au-delà.
- **Double plateforme dès le départ** (PC souris/manette *et* smartphone tactile) double la surface de design d'interface pour une équipe de 2 — à confirmer si les deux sortent simultanément ou si l'une précède l'autre.
