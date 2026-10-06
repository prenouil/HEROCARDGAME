# Menu principal et modes de jeu

Reconstruit depuis le code le 2026-09-03 (`game/src/ui/view.lua` — `View.menu_buttons` —, `game/src/ui/input.lua` — `menu_click` —, `game/src/ui/controller.lua`, `game/src/rules/game.lua`), **mis à jour le 2026-10-06** suite à la refonte de l'écran de choix d'équipe et à l'ajout du mode "Aventure" (voir sections dédiées). Absent des deux anciens documents (Google Doc, GDD BMAD), rédigés avant l'existence de cet écran de menu et de la plupart de ces modes. Premier document de `docs/design/` à couvrir la boucle de jeu au niveau "menu" — la boucle interne d'un combat (résolution, ressources, ordre de calcul) reste hors périmètre, à couvrir par un futur `regles.md`.

**Correction apportée le 2026-10-06** : le chapeau ci-dessus citait encore `game/src/ui/view.lua` comme fichier source — ce monolithe a depuis été scindé en un dossier `game/src/ui/view/` (un fichier par écran : `menu.lua`, `team_select.lua`, `quest_select.lua`, `quest_reward.lua`, `prediction.lua`, `puits.lua`, `power_well.lua`, `victory.lua`, etc., assemblés par `game/src/ui/view/init.lua`). Les références ci-dessous citent désormais le fichier précis du dossier plutôt que l'ancien monolithe.

## Écran "Menu"

6 boutons, dans cet ordre (`View.menu_buttons`, `game/src/ui/view/menu.lua`) : **Aventure** (2026-10-05, ajouté en tête), **Jouer un run**, **Run Solo**, **Tester un boss**, Options, Quitter. Un 4ᵉ mode de jeu, "Mode infini", a existé mais a été retiré de cet écran le 2026-09-02 (annoncé par le porteur de projet comme "bientôt retiré") — son code (`run_mode == "infini"` : pool d'ennemis non filtré par biome, pas de boss, pas de fin) reste intact dans `game.lua`/`encounter.lua` mais n'est plus atteignable depuis l'interface.

Les 4 modes accessibles passent tous d'abord par le même écran de **choix d'équipe** (`Controller:enter_team_select(mode)`, "Choisis ton équipe", `game/src/ui/view/team_select.lua`) : le joueur y sélectionne des aventuriers parmi les 6 classes du roster (voir `docs/design/classes.md`). Le nombre requis dépend du mode (`ts.max_team_size`) : **4** pour "Jouer un run"/"Tester un boss"/"Aventure", **1 seul** pour "Run Solo". Un bouton "Auto-fill" choisit aussitôt une sélection aléatoire de la bonne taille et lance directement la suite, sans passer par les clics un par un — en mode "Aventure", il respecte l'éventuel aventurier déjà imposé par une "Quête pour le <classe>" (voir plus bas) et ne tire que parmi les classes débloquées.

## Écran "Choisis ton équipe" : onglets Départ/Trépas, Avancé, Artefact

Refonte du 2026-10-03 (demande explicite), **commune aux 4 modes** (pas une mécanique propre au mode "Aventure", même si c'est ce dernier qui l'exploite le plus — voir plus bas) : quand un aventurier est mis en avant (portrait au "projecteur"), 3 boutons d'onglet apparaissent juste à côté de son portrait (`View.team_select_tab_button_rects`, `team_select.lua`) :

- **"Départ / Trépas"** (actif par défaut à chaque nouveau focus, et PERSISTE d'un aventurier à l'autre si le joueur change de focus sans revenir dessus manuellement) : 2 lignes fixes — les **2 cartes de départ** de la classe (ligne 1, réduites de 3 à 2 le 2026-10-03, voir `docs/design/cartes.md`), puis le **trio Legs/Héritage/Écho** du pilier du sacrifice (ligne 2, toujours la version DE BASE de l'Écho, jamais `-ameliore` — voir `docs/design/sacrifice.md`).
- **"Avancé"** : la carte **"Mise à mort"** de la classe toujours en 1ʳᵉ position, puis le reste des cartes "avance" de la classe (hors Legs/Héritage/Écho/Mise à mort, Enchantements inclus), groupées par lignes de 4 maximum (`TEAM_TAB_ADVANCE_ROW_MAX`, `controller.lua`). Ne montre que les cartes **débloquées** — voir "Statut débloqué/verrouillé" dans `docs/design/cartes.md`, qui détaille aussi un écart de code repéré à cette occasion. En mode "Aventure" uniquement, une ligne de texte sous les cartes indique "X cartes restantes à débloquer." (ou "Toutes les cartes de cette classe sont débloquées." à 0) — absente des 3 autres modes, qui n'ont aucune notion de déblocage à montrer.
- **"Artefact"** : toujours vide pour l'instant (`team_select_tab_rows` renvoie `{}`) — "ce sera le prochain chantier" (commentaire du code). **Aucun lien** avec le type de carte "Enchantement" déjà existant, qui reste une carte "avance" normale listée dans l'onglet "Avancé".

Cliquer "Valider" pour **ajouter** un aventurier à l'équipe (`Controller:team_select_confirm`/`team_select_confirm_gather`) : l'écran repasse d'abord sur l'onglet "Départ / Trépas" si un autre était affiché (même transition visuelle qu'un changement d'onglet manuel), PUIS seules les 2 cartes de départ s'envolent vers le compteur "DECK" (coin bas-gauche), tandis que le trio Legs/Héritage/Écho s'envole vers le portrait de l'aventurier lui-même — ces 3 cartes ne sont pas dans le deck de départ, elles sont liées à l'aventurier (voir `docs/design/sacrifice.md`). Le libellé "Ton équipe" affiché jusque-là sous la rangée d'équipe confirmée a été supprimé le même jour (la rangée de cases vertes se lit déjà sans légende).

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

## Aventure (nouveau mode, 2026-10-05 à 2026-10-07)

Mode de jeu **persistant** (sauvegardes sur disque), le plus gros chantier depuis la refonte du menu. Lance toujours un run "bounded" classique (mêmes 8 combats + boss que "Jouer un run" — "adventure" ne décrit qu'un écran de sélection d'équipe filtré en amont, jamais un `run_mode` à part entière côté règles), mais avec une couche de méta-progression entre les runs : sauvegardes à 3 emplacements, écran de sélection de quête, classes/cartes à débloquer, difficulté qui suit la progression du joueur. Détail complet (schéma de sauvegarde, formules de difficulté, écran de récompense) dans `docs/design/aventure.md` — résumé ci-dessous.

**1. Écran "Choisis ta sauvegarde"** (`game/src/ui/view/menu.lua`, `draw_adventure_slots`, `game/src/ui/save.lua`) : 3 emplacements fixes, 1 fichier LÖVE (`love.filesystem`) par emplacement. Un emplacement vide affiche "Nouvelle partie", un emplacement entamé affiche "Partie X" et gagne une croix rouge qui le supprime définitivement (`Save.delete_slot`, sans confirmation supplémentaire).

**2. Écran "Sélection de quête"** (`game/src/ui/view/quest_select.lua`, `game/src/rules/quests.lua`) : affiché juste après le choix d'emplacement, avant le choix d'équipe. 4 bandeaux horizontaux toujours dans le même ordre : "Histoire principale", 2× "Quête pour le \<classe\>", "Recherche de compagnon" (silhouette noire tant que le compagnon n'est pas débloqué). Chaque quête choisie fige une **difficulté** transmise au run — voir `docs/design/aventure.md` pour le détail des formules et des règles de reroll.

**3. Choix d'équipe filtré** : seul ce mode restreint le roster du choix d'équipe aux classes débloquées pour cette sauvegarde (`Quests.unlocked_class_set`) — voir `docs/design/classes.md` ("Statut débloqué/verrouillé"). Une "Quête pour le \<classe\>" impose en plus automatiquement cette classe dans l'équipe (pré-remplie, bouton "Retirer" grisé/inerte).

**4. Difficulté branchée sur le budget de rencontre réel** (`game/src/rules/game.lua`, `budget_for_run_combat`) : la difficulté figée au choix de la quête décale la courbe de budget de (difficulté − 1) combats (`Encounter.budget_for_combat(n + difficulté − 1)`) et sert aussi de niveau au combat de Boss (`Encounter.boss_encounter(..., level)`). Aucun impact sur "Jouer un run"/"Run Solo"/"Tester un boss", qui restent tous à difficulté 1 implicite (`state.run.difficulty` absent ou nil → défaut 1).

**5. Écran "Félicitations"** (`game/src/ui/view/quest_reward.lua`, `Controller:enter_quest_reward_screen`) : affiché juste après la victoire du Boss SI cette victoire vient de rapporter une récompense de quête (carte débloquée ou compagnon débloqué) — montre l'image de la carte (×1.5) ou le portrait du compagnon désormais révélé (plus de silhouette), message "\<Nom\> est désormais disponible pour les prochains runs.", bouton "Continuer" vers le menu. N'apparaît jamais pour "Histoire principale" (aucune récompense visuelle, juste la difficulté qui augmente) ni pour "Jouer un run"/"Tester un boss" (jamais de récompense, `save_slot` absent).

**6. Écran de défaite spécifique** (`game/src/ui/view/victory.lua`, `draw_defeat_overlay`) : en mode Aventure (`controller.save_slot` posé), **pas d'option "Rejouer avec la même équipe"** (qui existe pour les 3 autres modes) — seul "Retourner au menu" reste (recentré), plus un petit bouton discret "Admin : rejouer le dernier combat" en bas à droite (style volontairement effacé, outil de test qui restaure directement la photo du combat perdu).

**7. Conséquences d'un run terminé** (`Controller:resolve_adventure_quest`) : une **victoire** accorde la récompense de la quête choisie (incrément de difficulté pour "Histoire principale", carte aléatoire parmi les verrouillées de la classe pour une quête de classe, déblocage du compagnon pour "Recherche de compagnon") ; une **défaite** n'accorde jamais rien. Dans les deux cas, les 2 "Quêtes pour le \<classe\>" sont retirées au hasard pour le prochain passage par cet écran — seule "Recherche de compagnon" reste fixe tant qu'elle n'est pas obtenue.

## Écarts avec les anciens documents

Aucun — le Google Doc et le GDD BMAD ont été rédigés avant que cet écran de menu et ces 4 modes n'existent ; ils ne décrivent qu'un unique mode de jeu ("le run"), aujourd'hui "Jouer un run". Idem pour la méta-progression du mode "Aventure" (sauvegardes, quêtes, déblocages) : absente des deux anciens documents.
