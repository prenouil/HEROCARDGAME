---
name: ennemis-elite-mecanique
description: La variante "Élite" d'un ennemi est une mécanique transversale générique (n'importe quel template) qui augmente PV/dégâts sans jamais coûter plus cher dans le budget de rencontre.
metadata:
  type: project
---

N'importe quel ennemi du bestiaire (tous biomes, actuels ou futurs) peut être instancié en variante "Élite" : mêmes comportements/attaques que sa version normale, mais des statistiques augmentées (proposition actée le 2026-09-01 : ×1.6 sur PV/Bouclier, ×1.3 sur tout montant porté par un coup — dégâts/soin/ampleur de statut). Identification visuelle : nom entouré de 2 étoiles, cadre doré et scintillant, sprite plus grand.

**Pourquoi :** le porteur de projet veut pouvoir rendre un combat ponctuellement plus dur (ex. le 4ᵉ combat d'un biome, voir `reference_structure-run-biomes.md`) sans que le système de génération de rencontre (budget) "paie" cette difficulté supplémentaire par un ennemi en moins ou plus faible ailleurs — la règle est explicitement "un ennemi Élite ne coûte pas plus cher dans le budget".

**Comment l'appliquer :**
- Les multiplicateurs Élite s'appliquent APRÈS que `level`/le coût budget aient été déterminés par `Encounter.generate_encounter` — jamais en augmentant `level` lui-même (ça remonterait aussi `Enemies.cost_at_level`, ce qui romprait la règle "gratuit en budget").
- Un ennemi de base ne doit plus être étiqueté "élite" dans sa fiche/son flavor text une fois cette mécanique en place (revirement 2026-09-01, appliqué à "Chef de Bande" et "Vouivre des Cendres" qui portaient ce mot en v1 du bestiaire biomes) — le mot "élite" est réservé à la mécanique transversale, pas un adjectif de puissance générique. Un ennemi notable/costaud du roster se distingue par ses propres PV/coût, pas par ce mot.
