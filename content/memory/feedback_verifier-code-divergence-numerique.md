---
name: verifier-code-divergence-numerique
description: Quand le porteur de projet énonce un changement numérique de structure ("le Boss arrive au combat 9 au lieu de 10"), vérifier la valeur réelle dans le code avant de conclure — ne jamais deviner si c'est une vraie divergence ou juste une confirmation.
metadata:
  type: feedback
---

Le porteur de projet a explicitement demandé (2026-09-01, retours sur le bestiaire des 4 biomes) de ne pas trancher à l'aveugle une affirmation numérique sur la structure du jeu sans aller lire le code correspondant — il peut se tromper sur ce qu'il croit être la valeur actuelle, et le contenu proposé doit refléter la réalité du code, pas la mémoire du porteur de projet.

**Pourquoi :** sur ce cas précis, le porteur de projet pensait que le Boss arrivait "au combat 10", alors que le code (`BOUNDED_COMBAT_COUNT = 9` dans `controller.lua`/`view.lua`) fait déjà arriver le Boss juste après le 9ᵉ combat classique — mais la nouvelle structure demandée (2 biomes × 4 combats = 8 combats classiques) réduit quand même réellement ce nombre de 9 à 8, donc il y avait malgré tout un vrai changement à appliquer, juste pas celui que le porteur de projet imaginait au premier abord.

**Comment l'appliquer :** avant de conclure qu'un chiffre annoncé par le porteur de projet correspond ou diverge de l'existant, lire le fichier source concerné (grep la constante/le comportement décrit), comparer précisément, puis expliquer la réconciliation dans la proposition (ce qui est déjà vrai vs. ce qui doit vraiment changer) plutôt que de simplement reprendre le chiffre donné ou de l'ignorer.
