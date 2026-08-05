---
gdd: gdd.md
created: 2026-08-04
---

# Hero Card Game — Development Epics (detail)

Résumé et séquence : voir `gdd.md` → Development Epics. Détail par epic ci-dessous.

## Epic 1 — Boucle de combat centrale

**Sert les piliers :** 1 (énergie individuelle), 2 (télégraphie ennemie).
**Statut :** déjà prototypé sur 3 itérations de code (`prototype/mini-proto-2-cartes`, `prototype/proto-4-heros-2-ennemis`, `prototype/proto-deck-main-defausse`) — le modèle du 3ᵉ prototype est le modèle canonique retenu pour le GDD.

Stories de haut niveau :
- Système d'énergie individuelle par héros (0 de départ, +1/tour, **sans plafond** — les 3 prototypes actuels plafonnent à 3 et doivent être corrigés pour matcher le canon).
- Deck de run (2 cartes génériques coût 0 + 2 cartes de classe "Départ" par héros, "Avancé" débloquées séparément — liste complète des 18 cartes dans `gdd.md` → Card Types and Effects), pioche jusqu'à 5, défausse de fin de tour, remélange à vide.
- Ressource Défense (pool qui absorbe les dégâts) et statuts (Saignements, Esquive en stacks, Incapacité, Vulnérabilité, Camouflé) — aucun des 3 prototypes ne les implémente actuellement.
- Résolution de télégraphie ennemie : tirage pondéré de l'action + de la cible, affichage avant la phase joueur.
- Séquence d'interaction à 3 temps : carte → héros → cible, avec surbrillances d'éligibilité.
- Conditions de victoire/défaite de combat.

## Epic 2 — Identité de classe (MVP : 4 héros)

**Sert le pilier :** 4 (troupe à identité individuelle).
**Statut :** prototypé partiellement, désormais en divergence sur plusieurs points avec le canon — `proto-4-heros-2-ennemis` et `proto-deck-main-defausse` couvrent Guerrier/Mage/Voleur/Clerc avec verrouillage strict des cartes ; le canon MVP est Guerrier/Paladin/Mage/Assassin (Paladin remplace Clerc ; "Voleur" doit être renommé "Assassin"), avec cartes de classe librement assignables.

Stories de haut niveau :
- 2 cartes de base communes (Coup direct, Esquive) partagées par tous les héros — inchangé.
- 1 carte de classe par héros, jouable par n'importe quel héros ayant l'énergie requise (retirer le verrouillage `owner` actuel du prototype). Carte du Paladin encore à concevoir (celle du Clerc, "Soin", n'a pas d'équivalent confirmé).
- **Pouvoir de Classe** par classe (Guerrier, Paladin, Mage, Assassin — chiffré dans `gdd.md` → Character Selection). Deux commandes UI restent à définir (changement de ligne du Paladin, sélection de carte gardée du Mage).
- **Transcendance** par héros (chiffrée dans `gdd.md`), avec sa condition de déclenchement (généralement : jouer une carte de classe sur son propre aventurier). La condition exacte du bonus Camouflé de l'Assassin reste ambiguë dans la source — à clarifier avant implémentation.
- 1 skin par héros avec animations idle (2 frames), action, coup reçu, KO.

`[NOTE FOR DESIGNER]` Cet epic a grossi significativement depuis sa première estimation (verrouillage simple → Pouvoir de Classe + Transcendance + déverrouillage) — revoir le découpage en stories/sprints en conséquence plutôt que de garder l'ancienne estimation implicite.

## Epic 3 — Lisibilité du premier combat / onboarding

**Sert les piliers :** 1, 2 (l'énergie individuelle et la télégraphie ne servent à rien si le joueur ne les comprend pas dès le premier combat).
**Statut :** non démarré. Signalé comme le risque le plus urgent par la séance `bmad-party-mode` (Samus Shepard, Indie, Sally) — plus urgent que la question narrative de résurrection.

Stories de haut niveau :
- Tutoriel ou premier combat scripté qui introduit énergie individuelle, télégraphie ennemie et ciblage sans texte long.
- Playtest dédié dès que l'Epic 1 est jouable de bout en bout (voir Success Metrics dans `gdd.md`).

## Epic 4 — Structure de run et déblocage garanti

**Sert le pilier :** 3 (déblocage significatif à chaque run).
**Statut :** non démarré, cible Mois 2.

Stories de haut niveau :
- Carte de quêtes à embranchements (génération à spécifier — `[NOTE FOR DESIGNER]`).
- 4 types de quêtes : classe (chef de groupe imposé, 3 autres libres), narrative (héros imposés selon la narration), spéciale (composition totalement libre), multiple (coordination de plusieurs groupes sur plusieurs runs).
- Combat de boss de fin de run (durée non chiffrée, plus long qu'un combat normal).
- Récompense de déblocage permanent et significatif à la victoire du boss.

## Epic 5 — Village (hub, économie, upgrades)

**Sert le pilier :** 3 (dépense des ressources accumulées).
**Statut :** non démarré, cible Mois 2.

Stories de haut niveau :
- Déplacement physique actif d'un héros dans le hub village (pas de point-and-click).
- Maisons de villageois : état délabré/vide par défaut, débloquées et upgradables.
- Ressources : métaux (forgeron), plantes (herboriste), pierres précieuses (magicien), argent, autres non nommées.
- Dépenses : amélioration de deck, possibilités de deckbuilding (système à détailler — `[NOTE FOR DESIGNER]`), avantages de début de run, bonus rencontrables en run.

## Epic 6 — Système de l'Astronome

**Sert :** aucun pilier directement — système de difficulté/risque-récompense transverse.
**Statut :** post-MVP, hors Mois 1/2.

Stories de haut niveau :
- Déblocage de l'Astronome (condition non spécifiée).
- Sélection de "lune" d'abord aléatoire, puis progressivement contrôlable par le joueur.
- Modificateurs : Lune d'Or (+50% ressources de village, +1 dégât subi), Lune Vermeille (plus de cartes rares au loot, plus d'élites en combat) ; système conçu pour être extensible à d'autres lunes.

## Epic 7 — Narration par dialogues

**Sert :** différenciateur secondaire (narration progressive), pas un pilier de gameplay.
**Statut :** post-MVP ; **bloqué** tant que la justification narrative du retour au village après défaite n'est pas tranchée (question explicitement laissée ouverte par le porteur de projet).

Stories de haut niveau :
- Dialogues entre personnages uniquement (pas de narrateur, pas de narration environnementale), non bloquants et skippables.
- Montée en présence avec la progression du joueur (peu présente au début, plus présente ensuite).
- Suivi via un journal PNJ, déclenché par des compteurs d'événements.
- Prérequis : décision sur la justification narrative de la résurrection — recommandé de passer par `gds-create-narrative` une fois cette décision prise.
