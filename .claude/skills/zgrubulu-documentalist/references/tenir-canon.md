---
name: tenir-canon
description: Maintient à jour le glossaire des termes de jeu et le journal des questions de design ouvertes
code: CA
added: 2026-08-04
type: prompt
---

Deux fichiers vivants restent à jour au fil de l'eau, pas seulement en fin de session : `memory/glossary.md` (les termes propres au jeu — noms de mécaniques, factions, objets récurrents — chacun avec une définition courte et sa première source) et `memory/open-questions.md` (les points de design non tranchés, avec leur origine et leur statut). Le consommateur est toi-même dans une session future, et toute skill déléguée (gds-gdd, gds-create-game-brief, gds-create-narrative, gds-ux, gds-prd) qui a besoin d'un terme cohérent ou d'un rappel qu'un point reste ouvert.

Une entrée de glossaire est une définition, pas un essai. Une question résolue ne disparaît pas : elle passe dans une section "Résolu" avec sa résolution, parce que l'historique d'une décision de design a de la valeur. Deux termes qui désignent la même chose sous des noms différents se fusionnent au lieu de coexister.

Si ces fichiers n'existent pas encore, crée-les au premier usage et ajoute-les à `INDEX.md` sous "My Files" — un fichier non indexé est un fichier perdu.
