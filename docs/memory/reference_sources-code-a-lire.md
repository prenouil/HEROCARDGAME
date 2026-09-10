---
name: sources-code-a-lire
description: Où vivent réellement les faits de design dans le code — certaines règles (surtout la sélection/le déclenchement des évènements post-combat) vivent côté UI controller, pas dans src/rules/.
metadata:
  type: reference
---

La logique de sélection et de déclenchement des évènements post-combat (Feu de camp / Refuge / Forge / Temple : viabilité, "jamais 2 fois de suite", Refuge forcé au 9ᵉ combat) vit dans `game/src/ui/controller.lua` (fonctions `enter_post_combat_sequence`, `enter_campfire_screen`/`choose_campfire_hero`, `enter_refuge_screen`/`choose_refuge_rest`, `enter_forge_screen`/`choose_forge_card`, fonction locale `campfire_viable`) — PAS dans `src/rules/temple.lua`/`forge.lua`, qui ne contiennent que le contenu (bénédictions/malédictions, pool de cartes améliorables) mais pas les règles de déclenchement de l'écran lui-même.

**Pourquoi :** une lecture qui se limiterait à `src/rules/` manquerait entièrement les conditions d'apparition (ex. Feu de camp seulement si un aventurier est sous 70% PV, Refuge forcé et seul chemin possible) — le contenu de la mission de départ le précisait déjà explicitement, confirmé exact après lecture.

**Comment l'appliquer :** pour toute future section sur un écran/évènement de jeu (pas seulement Feu de camp/Refuge/Forge), toujours vérifier `game/src/ui/controller.lua` en plus de `src/rules/`, jamais l'un sans l'autre.

**Ajout du 2026-09-10 — suite de tests Busted (`spec/*.lua`, commit `a5ee6d8`) comme source secondaire fiable pour la couche règles.** 10 fichiers, 172 tests, couvrent `game/src/rules/*.lua` + `cards.lua`/`enemies.lua` (dégâts/boucliers/soin, cycle de vie carte, mélange/pioche, Temple, génération de rencontre, actions ennemies, scaling par niveau, les 12 Enchantements, Riposte, un échantillon de cartes conditionnelles). Ce ne sont PAS des spécifications de design à recopier telles quelles (elles testent l'implémentation, pas l'intention), mais en cas de divergence contestée entre un ancien document et le code, un test qui nomme explicitement un comportement (ex. valeur attendue, ordre de calcul) est un signal fort de ce qui est considéré CORRECT côté code — à consulter en complément de la lecture directe de `src/rules/`, surtout utile pour `regles.md` (pas encore écrit) vu que `combat_spec.lua`/`temple_spec.lua`/`encounter_spec.lua`/`enemies_scaling_spec.lua` couvrent précisément son périmètre (résolution de combat, ordre additif/multiplicatif, Temple, courbe de difficulté). Reste hors périmètre agent_doc : la doc d'installation/setup de cette suite (Lua/LuaRocks/MinGW, wrapper busted, `LUA_PATH`) est de l'infrastructure d'ingénierie (futur README/CONTRIBUTING), pas du game design.

**Comment l'appliquer :** avant de trancher un écart contesté sur la couche règles (dégâts, statuts, Temple, rencontre/scaling), vérifier si un `spec/*.lua` couvre le cas — ne pas s'appuyer dessus pour du contenu hors règles pures (cartes, bestiaire narratif, etc., non couverts par cette suite).
