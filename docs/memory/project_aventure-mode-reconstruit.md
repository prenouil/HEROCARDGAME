---
name: aventure-mode-reconstruit
description: Mode "Aventure" (sauvegardes, quêtes, déblocages classes/cartes), refonte de l'écran de choix d'équipe (3 onglets) et 2 nouveaux évènements post-combat (Prédiction de la Mort, Le Puit de l'Oubli) — reconstruits le 2026-10-06 depuis le code implémenté du 2026-10-03 au 2026-10-07.
metadata:
  type: project
---

Le 2026-10-06, demande explicite du porteur de projet (liste de tous les changements de code depuis la dernière mise à jour de la doc, le 2026-10-02) : relecture fraîche de `game/src/ui/view/team_select.lua`, `controller.lua` (team_select_tab_rows/switch_tab/confirm_gather, enter_post_combat_camp_choice, prediction/puits/power_well), `game/src/rules/prediction.lua`, `game/src/ui/view/prediction.lua`/`puits.lua`/`power_well.lua`, `game/src/data/cards.lua` (`DEFAULT_UNLOCKED_AVANCE_CODES`), `game/src/data/heroes.lua` (`DEFAULT_UNLOCKED_CLASS_IDS`), `game/src/rules/draft.lua`, `game/src/ui/save.lua`, `game/src/rules/quests.lua`, `game/src/ui/view/quest_select.lua`/`quest_reward.lua`/`menu.lua`, `game/src/ui/view/victory.lua`, `game/src/rules/game.lua` (`budget_for_run_combat`).

**Documents modifiés** :
- `docs/design/modes.md` : correction du chapeau (`game/src/ui/view.lua` → dossier `game/src/ui/view/`, confirmé scindé) ; menu 5→6 boutons (Aventure en tête) ; nouvelle section "Écran Choisis ton équipe : onglets Départ/Trépas, Avancé, Artefact" (commune aux 4 modes, pas propre à Aventure) ; nouvelle section "Aventure" (résumé, renvoi vers `aventure.md`).
- **Nouveau fichier `docs/design/aventure.md`** : sauvegardes (schéma, 3 slots), écran "Sélection de quête" (Histoire principale/2 Quêtes de classe/Recherche de compagnon, formules de difficulté, règles de reroll), difficulté branchée sur `budget_for_run_combat`, écran "Félicitations", écran de défaite spécifique, conclusion de run (`resolve_adventure_quest`). Choix éditorial : document séparé plutôt que tout mettre dans `modes.md` (volume comparable à Run Solo en son temps).
- `docs/design/classes.md` : section "Statut débloqué/verrouillé" (4 classes débloquées de base — Guerrier/Paladin/Mage/Assassin —, Nécromancien/Barde verrouillés ; seul le mode Aventure filtre).
- `docs/design/cartes.md` : section "Statut débloqué/verrouillé" (18 cartes "avance" débloquées de base sur 36, 3/classe, liste complète ; Mise à mort/Legs/Héritage/Écho exemptés ; lu par Draft ET onglet Avancé).
- `docs/design/evenements.md` : 4→6 évènements ; tirage "camp" 3→5 issues ; nouvelles sections Prédiction de la Mort / Le Puit de l'Oubli / Fenêtre partagée "Choisis un pouvoir à oublier à jamais".

**Écart de code signalé (pas corrigé, documenté comme tel)** : `Draft.pick_cards(state)` ne reçoit jamais `save_data` et ne filtre que sur `Cards.is_unlocked_by_default` (les 18 cartes de base) — une carte débloquée PENDANT une sauvegarde Aventure via une "Quête pour le <classe>" (`save_data.unlocked_cards`) est donc visible dans l'aperçu de l'onglet "Avancé" du choix d'équipe mais **jamais réellement proposée par le Draft** pendant le run qui suit. Documenté dans `aventure.md` ("Point ouvert") et rappelé dans `cartes.md` — ne jamais documenter cette carte comme "obtenable au Draft" tant que ce n'est pas corrigé côté code.

**Pourquoi** : demande explicite listant chronologiquement tous les changements de code depuis le 2026-10-02 (dernière entrée de mémoire avant celle-ci) — vérifié intégralement contre le code réel plutôt que recopié depuis le résumé fourni (conforme à la méthodologie habituelle), aucun écart trouvé entre le résumé et le code sauf celui signalé ci-dessus (non mentionné dans le résumé fourni, trouvé en creusant `draft.lua`).

**Comment l'appliquer** : pour toute future demande sur le mode Aventure/les quêtes/les déblocages, repartir de `docs/design/aventure.md` + relecture ciblée de `game/src/rules/quests.lua`/`save.lua`/`controller.lua` (fonctions citées ci-dessus), pas d'un nouvel audit complet. Pour l'onglet "Avancé" du choix d'équipe ou les 2 nouveaux évènements post-combat, repartir de `modes.md`/`evenements.md` déjà à jour.

**Artifact republié** (même URL qu'avant, voir `project_avancement-reconstruction.md`) : https://claude.ai/code/artifact/7554fe23-0c31-4dfb-b10d-cc589dfc1345 — version 25, label "aventure-mode-2026-10-06". Nouvel onglet "Aventure" ajouté (9 onglets désormais : Classes, Cartes de classes, Glossaire, Bestiaire, Statues de Temple, Événements, Modes de jeu, Aventure, Sacrifice). Onglets Classes/Cartes de classes/Événements/Modes de jeu mis à jour en cohérence avec les 5 .md modifiés/créés.

**Note d'outillage confirmée** : republier cet Artifact (182 Ko, 900 lignes, 18 icônes PNG en base64 lignes 336-353) a exigé de relire l'intégralité du fichier sauvegardé par `action:"read"` — les 18 lignes d'icônes tiennent chacune dans un `Read` à `limit` 1-3 sans dépasser le budget de tokens (même constat que la note du 2026-09-12), aucun découpage plus fin nécessaire.
