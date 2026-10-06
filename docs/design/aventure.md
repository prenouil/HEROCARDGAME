# Aventure — sauvegardes et méta-progression

Nouveau document créé le 2026-10-06, reconstruit depuis le code (`game/src/ui/save.lua`, `game/src/rules/quests.lua`, `game/src/ui/view/quest_select.lua`, `game/src/ui/view/quest_reward.lua`, `game/src/ui/controller.lua` — `enter_adventure_slots`/`choose_adventure_slot`/`enter_quest_select`/`choose_quest`/`resolve_adventure_quest`/`enter_quest_reward_screen`, `game/src/data/heroes.lua`, `game/src/data/cards.lua`, `game/src/rules/game.lua`). Absent des deux anciens documents (Google Doc, GDD BMAD, tous deux rédigés bien avant l'existence de cette fonctionnalité) et du reste de `docs/design/` avant cette date. Détaille le mode "Aventure" présenté en résumé dans `docs/design/modes.md` ("Aventure (nouveau mode...)") — cross-référencé depuis là plutôt que dupliqué.

## Sauvegardes

3 emplacements fixes (`Save.SLOT_COUNT = 3`), 1 fichier LÖVE par emplacement (`adventure_slot_<n>.lua`, `love.filesystem`). Écran "Choisis ta sauvegarde" : un emplacement vide affiche "Nouvelle partie" (clic = `Save.create_slot`, qui génère tout de suite les toutes premières quêtes — voir plus bas) ; un emplacement entamé affiche "Partie X" et gagne une croix rouge (`Save.delete_slot`, suppression définitive et immédiate, aucune confirmation).

**Schéma de la sauvegarde** (table plate, sérialisée en Lua littéral par `Save.write_slot`, relue par `Save.load_slot`) :
- `main_story_difficulty` (nombre, démarre à 1) : difficulté de la prochaine "Histoire principale", +1 à chaque victoire de CETTE quête précise (jamais sur une défaite, jamais pour les 2 autres types de quête).
- `unlocked_classes` (ensemble `{class_id = true}`) : compagnons débloqués PENDANT cette partie via "Recherche de compagnon" — en plus de `Heroes.DEFAULT_UNLOCKED_CLASS_IDS` (jamais dupliqués ici), voir `docs/design/classes.md`.
- `unlocked_cards` (ensemble `{code = true}`) : cartes "avance" débloquées PENDANT cette partie via une "Quête pour le \<classe\>" — en plus de `Cards.DEFAULT_UNLOCKED_AVANCE_CODES`, voir `docs/design/cartes.md`.
- `class_quest_ids` (tableau de 0 à 2 `class_id`) : les 2 "Quêtes pour le \<classe\>" actuellement proposées.
- `companion_quest_class_id` (1 `class_id` ou nil) : la cible actuelle de "Recherche de compagnon".

Toute la logique de GÉNÉRATION de ces valeurs vit dans `game/src/rules/quests.lua` (module pur, testable hors LÖVE) — `save.lua` ne fait que lire/écrire le résultat sur disque, jamais de calcul lui-même.

## Écran "Sélection de quête"

Affiché juste après le choix d'emplacement, avant le choix d'équipe (`Controller:enter_quest_select`). 4 bandeaux horizontaux, toujours dans le même ordre, un bandeau sans quête valide restant affiché mais grisé/non cliquable ("Pas de quête de ...") plutôt que de disparaître — la mise en page ne bouge jamais.

### 1. Histoire principale
Toujours disponible, jamais "Pas de quête", aucun aventurier imposé. Titre : "Histoire principale : Run difficulté X" avec X = `save_data.main_story_difficulty`. Seule quête dont la difficulté progresse par incréments de +1, indéfiniment.

### 2 et 3. Quête pour le \<classe\>
Une classe débloquée (`Quests.eligible_class_quest_classes` : débloquée pour cette save ET ayant encore au moins 1 carte "avance" verrouillée) tirée au hasard pour chacun des 2 bandeaux, jusqu'à 2 classes DISTINCTES. Titre : "Quête pour le \<classe\> : Run difficulté X" avec **X = `Quests.CLASS_QUEST_BASE_DIFFICULTY` (3) + nombre de cartes DÉJÀ débloquées pour CETTE classe précise par une quête de classe** — jamais toutes classes confondues, deux classes progressent donc de façon totalement indépendante (correction apportée le jour même de l'implémentation, 2026-10-07 : une 1ʳᵉ version comptait les cartes débloquées toutes classes confondues).

Choisir cette quête sélectionne **automatiquement** cette classe dans l'équipe (pré-remplie dans `ts.selected_ids` dès l'entrée sur l'écran de choix d'équipe, jamais via l'animation normale) et son bouton "Retirer" reste grisé/inerte (`ts.locked_ids`). Récompense (uniquement si le run est **gagné**) : débloque 1 carte verrouillée AU HASARD de cette classe (`Quests.locked_cards_for_class`).

Les 2 quêtes de classe sont **re-tirées au hasard à la fin de CHAQUE run**, gagné ou perdu (`Quests.reroll_class_quests`, appelé inconditionnellement par `Controller:resolve_adventure_quest`). "Pas de quête de classe" si aucune classe éligible (toutes verrouillées, ou toutes déjà entièrement débloquées).

### 4. Recherche de compagnon
Une classe NON débloquée (`Quests.eligible_companion_classes`) tirée au hasard, affichée en **silhouette noire** (son portrait réel teinté en noir — `draw_hero_icon(..., silhouette=true)` — l'identité reste cachée, mais la difficulté est affichée normalement). Titre : "Recherche de compagnon : Run difficulté X" avec **X = `Quests.COMPANION_QUEST_BASE_DIFFICULTY` (5) + `Quests.COMPANION_QUEST_DIFFICULTY_STEP` (3) × nombre de compagnons déjà débloqués** PAR une quête (jamais les 4 classes débloquées de base).

Ne pré-remplit **personne** dans l'équipe (contrairement aux quêtes de classe). Récompense (uniquement si le run est **gagné**) : débloque ce compagnon pour les runs suivants (`save_data.unlocked_classes[class_id] = true`).

Contrairement aux 2 quêtes de classe, cette cible reste **FIXE** d'un run à l'autre tant qu'elle n'est pas obtenue (`Quests.ensure_companion_quest` : no-op si une cible est déjà posée) — n'est rerollée QUE lorsque sa récompense est effectivement accordée (`companion_quest_class_id` remis à nil dans `resolve_adventure_quest`, jamais sur une défaite). "Pas de quête de compagnon" si tous les aventuriers sont déjà débloqués.

### Garde-fou sur un emplacement jamais revisité
`Controller:enter_quest_select` comble `class_quest_ids`/`companion_quest_class_id` à CHAQUE entrée sur l'écran si la liste de quêtes de classe est vide (jamais un reroll aveugle pour autant — un vrai "0 classe éligible" retombe de toute façon sur une liste vide) : corrige un bug observé le 2026-10-06 sur un emplacement créé par une version antérieure de la fonctionnalité, qui pouvait arriver ici avec 4 bandeaux "Pas de quête de ..." sans que ce soit un tirage légitime.

## Difficulté branchée sur le budget de rencontre réel

La difficulté est **figée au moment du choix de la quête** (`Controller:choose_quest`, jamais recalculée plus tard) et transmise telle quelle à `Game.reset_run(state, seed, selected_ids, "bounded", difficulty)`. Elle décale la courbe de budget de rencontre de (difficulté − 1) combats :

```
budget_for_run_combat(state, n) = Encounter.budget_for_combat(n + (state.run.difficulty or 1) - 1)
```

et sert aussi directement de **niveau du combat de Boss** (`Encounter.boss_encounter(..., state.run.difficulty)`). Absente (nil → défaut 1) pour "Jouer un run"/"Run Solo"/"Tester un boss", qui ne passent jamais par ce champ — **aucun impact** sur ces 3 modes, comportement strictement inchangé.

## Écran "Félicitations"

Affiché juste après la victoire du Boss (`Controller:enter_boss_victory` → `resolve_adventure_quest(true)` → `enter_quest_reward_screen`), SEULEMENT si cette victoire vient d'accorder une récompense de quête. Montre l'image de la carte à 1.5× sa taille canonique (quête de classe) ou le portrait du compagnon désormais révélé — plus de silhouette (quête de compagnon), message "\<Nom\> est désormais disponible pour les prochains runs.", bouton unique "Continuer" vers le menu (jamais de délai automatique, même logique que l'écran "Victoire !" à gains détachés d'un clic). N'apparaît jamais pour "Histoire principale" (rien à montrer, juste un chiffre qui augmente) ni pour "Jouer un run"/"Tester un boss" (`save_slot` absent, `resolve_adventure_quest` renvoie toujours nil).

## Conclusion d'un run (victoire ou défaite)

`Controller:resolve_adventure_quest(won)`, appelé systématiquement en fin de run (`enter_boss_victory` avec `true`, `enter_defeat_screen_now` avec `false`) :
- **Victoire** : accorde la récompense de la quête active (`self.active_quest`, posée par `choose_quest`) — incrément de `main_story_difficulty`, déblocage d'une carte aléatoire de la classe, ou déblocage du compagnon selon le type de quête.
- **Défaite** : **aucune récompense**, quel que soit le type de quête (corrigé explicitement lors de l'implémentation — une 1ʳᵉ version accordait à tort la récompense même sur une défaite).
- Dans les **deux cas** : reroll inconditionnel des 2 quêtes de classe (`Quests.reroll_class_quests`). La quête de compagnon n'est, elle, jamais rerollée par cette étape — seulement consommée (`= nil`) au moment où elle est effectivement obtenue, voir plus haut.

## Écran de défaite spécifique au mode Aventure

Voir `docs/design/modes.md` ("Écarts avec les anciens documents" n'y figure pas car cette section est déjà détaillée là) : pas d'option "Rejouer avec la même équipe", seul "Retourner au menu" + un bouton discret "Admin : rejouer le dernier combat" (outil de test).

## Point ouvert signalé (pas un bug corrigé, un écart de code à surveiller)

**Une carte "avance" débloquée PENDANT la partie via une "Quête pour le \<classe\>" (`save_data.unlocked_cards`) apparaît bien dans l'onglet "Avancé" de l'écran de choix d'équipe (preview avant de lancer un run), mais n'est JAMAIS réellement proposée par le Draft pendant le run lui-même.** Vérifié par lecture directe : `Draft.pick_cards(state)` (`game/src/rules/draft.lua`) ne reçoit jamais `save_data` et filtre uniquement sur `Cards.is_unlocked_by_default(def)` (les 18 cartes débloquées de base) — aucun appelant (`Controller:click_victory_card`) ne lui transmet la sauvegarde. Concrètement : le joueur peut voir la carte dans l'aperçu "Avancé" avant de partir à l'aventure, mais ne pourra jamais effectivement la piocher/l'ajouter à son deck pendant le run qui suit, tant que ce branchement manquant n'est pas comblé côté code. Signalé pour que ce ne soit pas documenté par erreur comme "la carte débloquée devient obtenable au Draft" — ce n'est pas le cas aujourd'hui.
