---
name: ressource-carte-depart
description: La règle "1 carte Départ doit dépenser la ressource" ne s'applique qu'aux ressources de type MONNAIE (Mana, Corruption). Pour une ressource de type SEUIL (Discrétion), le but est d'atteindre/lire le seuil, jamais de la dépenser — distinction à faire systématiquement pour toute future classe à ressource propre.
metadata:
  type: reference
---

Deux familles de ressources propres à une classe, à ne pas traiter pareil :

- **Ressource-monnaie** (Mana du Mage, Corruption du Nécromancien) : on accumule pour PAYER un coût explicite (`mana_cost`/`corruption_cost`) qui débloque un effet. Ici, la règle s'applique : au moins une des 3 cartes Départ doit dépenser la ressource pour de vrai — un coût explicite payé pour un effet, pas juste un gain. Sinon le joueur peut accumuler sans jamais pouvoir dépenser avant de tomber sur la bonne carte Avancée en tirage/draft.
- **Ressource-seuil** (Discrétion de l'Assassin → Camouflé) : le but n'est PAS de la dépenser, mais de l'accumuler jusqu'à un seuil qui débloque un état (ex. Camouflé à 10). Une carte qui lit cet état dérivé (ex. "si Camouflé, inflige plus") est le fonctionnement NORMAL et voulu de ce type de ressource, pas un défaut à corriger. Exiger une carte qui "dépense" la Discrétion n'a pas de sens pour ce modèle — confirmé explicitement par l'utilisateur (2026-08-28) après une fausse alerte sur l'Assassin.

**Pourquoi la distinction :** une remarque appliquant la règle "monnaie" à l'Assassin (ressource-seuil) a été signalée comme fausse alerte — l'Assassin "cherche juste à atteindre le seuil de Camouflage, sans plus", et c'est un design valide, pas un trou à combler.

**Comment l'appliquer :** avant de vérifier ou d'exiger une carte de dépense sur une classe à ressource propre, d'abord identifier à quelle famille elle appartient (monnaie ou seuil). N'appliquer la vérification "au moins 1 carte Départ dépense la ressource" qu'aux ressources-monnaie. Pour une ressource-seuil, vérifier plutôt qu'au moins 1 carte (Départ de préférence, cf. `feedback_depart-cards-flexibles.md`) lit/exploite l'état dérivé qu'elle débloque. Pour toute classe déjà en jeu, ne pas relire cette mémoire pour son état — relire `game/src/data/cards.lua` directement à chaque fois (ça peut changer).
