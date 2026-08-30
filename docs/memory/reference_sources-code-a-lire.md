---
name: sources-code-a-lire
description: Où vivent réellement les faits de design dans le code — certaines règles (surtout la sélection/le déclenchement des évènements post-combat) vivent côté UI controller, pas dans src/rules/.
metadata:
  type: reference
---

La logique de sélection et de déclenchement des évènements post-combat (Feu de camp / Refuge / Forge / Temple : viabilité, "jamais 2 fois de suite", Refuge forcé au 9ᵉ combat) vit dans `game/src/ui/controller.lua` (fonctions `enter_post_combat_sequence`, `enter_campfire_screen`/`choose_campfire_hero`, `enter_refuge_screen`/`choose_refuge_rest`, `enter_forge_screen`/`choose_forge_card`, fonction locale `campfire_viable`) — PAS dans `src/rules/temple.lua`/`forge.lua`, qui ne contiennent que le contenu (bénédictions/malédictions, pool de cartes améliorables) mais pas les règles de déclenchement de l'écran lui-même.

**Pourquoi :** une lecture qui se limiterait à `src/rules/` manquerait entièrement les conditions d'apparition (ex. Feu de camp seulement si un aventurier est sous 70% PV, Refuge forcé et seul chemin possible) — le contenu de la mission de départ le précisait déjà explicitement, confirmé exact après lecture.

**Comment l'appliquer :** pour toute future section sur un écran/évènement de jeu (pas seulement Feu de camp/Refuge/Forge), toujours vérifier `game/src/ui/controller.lua` en plus de `src/rules/`, jamais l'un sans l'autre.
