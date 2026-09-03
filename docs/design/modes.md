# Menu principal et modes de jeu

Reconstruit depuis le code le 2026-09-03 (`game/src/ui/view.lua` — `View.menu_buttons` —, `game/src/ui/input.lua` — `menu_click` —, `game/src/ui/controller.lua`, `game/src/rules/game.lua`). Absent des deux anciens documents (Google Doc, GDD BMAD), rédigés avant l'existence de cet écran de menu et de la plupart de ces modes. Premier document de `docs/design/` à couvrir la boucle de jeu au niveau "menu" — la boucle interne d'un combat (résolution, ressources, ordre de calcul) reste hors périmètre, à couvrir par un futur `regles.md`.

## Écran "Menu"

5 boutons, dans cet ordre (`View.menu_buttons`) : **Jouer un run**, **Run Solo**, **Tester un boss**, Options, Quitter. Un 4ᵉ mode de jeu, "Mode infini", a existé mais a été retiré de cet écran le 2026-09-02 (annoncé par le porteur de projet comme "bientôt retiré") — son code (`run_mode == "infini"` : pool d'ennemis non filtré par biome, pas de boss, pas de fin) reste intact dans `game.lua`/`encounter.lua` mais n'est plus atteignable depuis l'interface.

Les 3 modes accessibles passent tous d'abord par le même écran de **choix d'équipe** (`Controller:enter_team_select(mode)`, "Choisis ton équipe") : le joueur y sélectionne des aventuriers parmi les 6 classes du roster (voir `docs/design/classes.md`). Le nombre requis dépend du mode (`ts.max_team_size`) : **4** pour "Jouer un run"/"Tester un boss", **1 seul** pour "Run Solo". Un bouton "Auto-fill" choisit aussitôt une sélection aléatoire de la bonne taille et lance directement la suite, sans passer par les clics un par un.

## Jouer un run (mode "bounded")

Le mode principal du jeu. Sélection de 4 aventuriers puis lancement direct (`Game.reset_run("bounded", selected_ids)`) : 8 combats classiques répartis sur 2 biomes (4 combats chacun, un ennemi promu "Élite" au 4ᵉ combat de chaque biome) puis un combat de boss fixe déterminé par le dernier biome traversé. Entre chaque combat classique, une séquence d'évènements post-combat (écran de victoire avec gains d'or et draft de carte, puis Feu de camp/Forge/Temple, Refuge forcé avant le boss) — voir `docs/design/evenements.md` pour le détail de cette séquence et `docs/design/bestiaire.md` pour le système de biomes/Élite. Seul mode qui enchaîne draft et évènements de camp entre les combats.

## Run Solo (mode "solo_test")

Ajouté le 2026-09-02, retravaillé le 2026-09-03 pour enchaîner indéfiniment (voir plus bas). Permet de jouer une seule classe avec un deck entièrement construit à la main, en enchaînant des combats aléatoires à difficulté croissante sans jamais s'arrêter.

**1. Sélection** : l'écran "Choisis ton équipe" n'accepte qu'**1 seul** aventurier (`max_team_size = 1`).

**2. Construction du deck** (`Controller:enter_deck_builder`, écran "Construis ton deck") :
- Panneau du **haut** : toutes les cartes de la classe choisie (départ ET avancées confondues, jamais leurs versions déjà améliorées) — cliquer une carte en ajoute une copie de sa version de base en bas.
- Panneau du **bas** : le deck en construction, **pré-rempli** avec les 3 cartes "Départ" normales de la classe (`Deck.starting_cards_for_class`, comme au démarrage d'un run classique) — le joueur ajoute/retire librement à partir de là. Cliquer une carte du bas la retire. **Clic droit** sur une carte du bas bascule sa version base ↔ améliorée sur place (même carte, pas un remplacement).
- Les 2 panneaux défilent indépendamment (molette).
- Bouton **"Tester"** : inerte tant que le deck compte moins de **12 cartes** (`View.DECK_BUILDER_MIN_CARDS`) — aucun autre plafond haut, aucune contrainte de doublons au-delà de ce qui est physiquement cliquable dans le panneau du haut.

**3. Premier combat** (`Game.start_solo_run`) : rencontre aléatoire tirée avec le même budget que le tout premier combat d'un run classique (`Encounter.budget_for_combat(1)`), aucun biome (les ennemis ne sont pas filtrés par biome — juste "des monstres normaux").

**4. Enchaînement** (retravaillé le 2026-09-03, demande explicite — "il faut enchainer les combats à la suite avec la difficulté qui augmente [...] sans évènements ni draft entre chaque combat. Pas de fin, le joueur quitte quand il veut") : chaque victoire affiche le même écran bref que "Tester un boss" ("Combat remporté !", `Controller:enter_solo_victory`) puis enchaîne directement sur `Controller:advance_to_next_combat`, qui appelle `Game.start_next_combat` — la même fonction qu'un run classique entre 2 combats (héros/ressources reportés via `carried_hero`, budget croissant selon `Encounter.budget_for_combat(combat_index)`) — mais sans jamais promouvoir d'Élite ni tirer de boss, ces 2 mécaniques étant conditionnées à `state.run.mode == "bounded"` (jamais le cas ici). **Aucun évènement de camp, aucun draft, aucune Forge/Temple/Feu de camp/Refuge** entre 2 combats — le joueur enchaîne directement. **Aucune fin prévue** : la boucle continue tant que le joueur ne quitte pas volontairement (menu pause).

**5. Défaite** : le bouton "Rejouer" relance un nouveau test depuis le premier combat, avec exactement le même aventurier et le même deck (mémorisés dans `self.solo_test_hero_id`/`self.solo_test_deck_defs`) — pas un retour au menu ni une nouvelle sélection.

## Tester un boss (mode "boss_test")

Un combat de boss isolé, pour tester un affrontement précis sans faire tout un run. Sélection de 4 aventuriers (comme "Jouer un run"), puis un écran dédié **"Choisis un boss"** :
- 4 cartes, une par biome (`Encounter.BOSS_BY_BIOME`), chacune avec portrait et infobulle ("?") détaillant le kit du boss.
- Cliquer une carte la **sélectionne** (surbrillance) sans lancer le combat.
- Un réglage de **niveau unique**, partagé par les 4 boss (boutons "-"/"+", de **1 à 9**), affiché entre les boutons "Retour" et "Combattre".
- Le bouton **"Combattre"** lance le combat avec le boss et le niveau choisis (`Game.start_boss_test`) — grisé/inerte tant qu'aucun boss n'est sélectionné.

Combat isolé sans suite : une victoire ramène directement au menu (`Controller:enter_boss_victory`), une défaite propose "Rejouer" qui relance exactement le même combat (même équipe, même boss, même niveau, mémorisés).

## Écarts avec les anciens documents

Aucun — le Google Doc et le GDD BMAD ont été rédigés avant que cet écran de menu et ces 3 modes n'existent ; ils ne décrivent qu'un unique mode de jeu ("le run"), aujourd'hui "Jouer un run".
