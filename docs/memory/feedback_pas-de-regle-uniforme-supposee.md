---
name: pas-de-regle-uniforme-supposee
description: Ne jamais supposer qu'un comportement observé sur une ressource/mécanique s'applique uniformément à ses voisines proches (ex. "Mana" traité comme "Discrétion"/"Corruption") sans vérifier chacune individuellement dans le code.
metadata:
  type: feedback
---

Erreur commise le 2026-08-30 : après avoir vérifié que `carried_hero` (game.lua) remet bien Discrétion et Corruption à 0 entre deux combats, j'ai supposé sans le revérifier ligne à ligne que le Mana suivait la même règle — alors que le code (une fois corrigé par la session principale) traite le Mana différemment : remise à un niveau FIXE non nul (`MAGE_MANA_START = 2`) à chaque combat, pas un reset à 0. Corrigé après retour explicite de l'utilisateur.

**Pourquoi :** trois champs qui se ressemblent dans le code (`mana`/`discretion`/`corruption`, tous des "ressources propres à une classe", souvent traités dans le même bloc de commentaires) peuvent avoir des règles de reset ou de valeur de départ différentes. Le code fait foi ligne par ligne, jamais par généralisation depuis un champ voisin, même quand un commentaire semble les regrouper.

**Comment l'appliquer :** avant d'écrire une règle générale ("toute ressource propre fait X"), relire l'instruction exacte pour CHAQUE champ concerné (ici : chaque `if n.xxx ~= nil then n.xxx = ... end` séparément dans `carried_hero`), plutôt que d'extrapoler depuis 1 ou 2 cas vérifiés vers les autres. Vaut pour toute future section de `docs/design/` touchant plusieurs ressources/mécaniques similaires (ex. futur `regles.md`).
