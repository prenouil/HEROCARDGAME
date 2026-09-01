---
name: mode-infini-retrait
description: Le mode "Infini" (illimité, sans Boss) va bientôt disparaître du jeu — ne pas concevoir de contenu/mécanique spécifique à sa cadence.
metadata:
  type: project
---

Le porteur de projet a annoncé (2026-09-01, retours sur le bestiaire des 4 biomes v3) que le mode "Infini" (course illimitée, sans combat de Boss, distinct du mode "bounded" à `BOUNDED_COMBAT_COUNT` combats + Boss) va bientôt être retiré du jeu.

**Pourquoi :** évite de perdre du temps de conception sur une question devenue caduque — une question ouverte sur "la cadence des biomes en mode Infini" a été explicitement retirée pour cette raison plutôt que tranchée.

**Comment l'appliquer :** toute mécanique de progression par tronçons (biomes, chapitres, cadence d'apparition d'un Élite, etc.) ne doit être pensée/documentée que pour le mode "bounded" désormais. Ne pas proposer de contenu ou de réglage pensé spécifiquement pour un run infini/sans fin, et signaler si une demande semble en dépendre encore.
