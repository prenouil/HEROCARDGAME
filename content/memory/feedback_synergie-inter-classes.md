---
name: synergie-inter-classes
description: Quand l'utilisateur demande une "synergie" pour une classe support (ex. Barde), ça désigne par défaut une synergie INTER-classes dans le même tour (buffer une classe, puis une AUTRE classe en profite) — pas un stacking de plusieurs cartes de la MÊME classe. Vérifier laquelle est voulue plutôt que de supposer.
metadata:
  type: feedback
---

Une demande de "synergie" sur le Barde (inciter à jouer plusieurs cartes dans le même tour) a été mal interprétée comme "jouer plusieurs cartes du Barde d'affilée" — corrigé explicitement (2026-08-28) : le but était "jouer une carte du Barde puis une/des cartes d'une AUTRE classe pendant le même tour" (ex. Barde puis Guerrier puis Guerrier), pas empiler les cartes d'une classe support sur elle-même.

**Pourquoi :** une classe de type enabler/support (comme le Barde) a pour vocation de rendre les AUTRES classes meilleures dans le même tour, pas de créer son propre mini-jeu interne isolé du reste du groupe — le stacking intra-classe passe à côté de ce rôle.

**Comment l'appliquer :** avant d'implémenter une clause "synergie" sur une classe (surtout un buffeur/enabler), clarifier explicitement laquelle des deux lectures est voulue : intra-classe (plusieurs cartes de LA MÊME classe se renforcent) ou inter-classes (une classe prépare le terrain pour qu'une AUTRE classe en profite dans le même tour). Pour un buffeur pur, la lecture inter-classes est la plus probable par défaut, mais vérifier plutôt que supposer.
