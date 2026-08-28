---
name: cout-variable-ressource
description: Conventions établies pour toute valeur de carte qui varie avec une ressource/un statut propre au héros — coût auto-ajusté format "X (a-b)" en pastille ovale, MAIS AUSSI tout montant d'effet qui scale avec une ressource (bonus Inspiration compris) : recalcul et affichage temps réel dès la sélection de la carte, pas seulement au moment de jouer. Inclut aussi la notation numérique à utiliser dans les textes de carte ("*", pas "×").
metadata:
  type: reference
---

Sur le Nécromancien (Corruption), une carte peut avoir un coût auto-ajusté plutôt que fixe : "1 (+X, 0-3)" = 1 énergie fixe + jusqu'à 3 Corruption dépensée automatiquement selon ce qui est disponible (X = montant réellement dépensé, plafonné), l'effet de la carte scale avec X (ex. "Se soigne de 2*X").

**Convention d'affichage retenue (2026-08-28) :**
- La pastille de coût reste fixe et lisible d'un coup d'œil : "1" dans la pastille énergie ronde habituelle, "X (0-3)" dans une pastille de ressource **ovale** (pas ronde comme les coûts fixes de ressource, ex. `mana_cost` du Mage) — la forme différente signale immédiatement "ce coût s'auto-ajuste" avant même de lire le détail.
- Toute valeur variable dans le TEXTE de la carte (ex. "se soigne de 2*X" du Nécromancien, mais aussi le "+6 par charge" que le statut Inspiration du Barde ajoute au prochain effet d'une cible) doit être recalculée et affichée EN TEMPS RÉEL, **dès la sélection de la carte par le joueur** — pas seulement au moment de la jouer, et jamais une formule brute laissée telle quelle à l'affichage. Cette exigence de temps réel n'est donc pas limitée aux coûts en ressource : elle s'applique à TOUTE valeur d'effet qui dépend d'un état variable du héros/de la cible.
- **Notation numérique dans les textes de carte** : utiliser `*` pour une multiplication (ex. "2*X"), jamais `×` — cohérent avec le principe déjà en place ailleurs dans le jeu de préférer des caractères ASCII simples dans le texte affiché (voir la normalisation du glossaire, `game/src/data/glossary.lua`).

**Pourquoi :** évite la confusion entre coût fixe et coût variable dans un même kit — si une classe adopte ce format, l'utilisateur a tranché que TOUTES ses cartes à coût en ressource propre doivent l'adopter (pas de mélange fixe/variable dans un même kit, voir le Nécromancien où Rite mineur/Servant d'os/Communion des morts sont toutes passées au format X(a-b), plus aucune carte à coût de Corruption fixe). L'exigence de temps réel généralisée (pas juste les coûts) vient du Barde : le bonus d'Inspiration doit être aussi clair pour le joueur qu'un coût variable, dès la sélection de la carte.

**Comment l'appliquer :** pour toute future classe à ressource-monnaie, si une carte a un coût qui scale avec la ressource, considérer d'emblée d'appliquer CE format à toutes les cartes de la classe qui dépensent cette ressource plutôt qu'un mélange fixe/variable — poser la question explicitement si ce n'est pas encore tranché. Pour toute carte (coût OU effet) dont un nombre dépend d'un état variable du héros/de la cible, prévoir un recalcul/affichage temps réel dès la sélection, et écrire les formules avec `*` dans le texte proposé.
