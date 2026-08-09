---
title: Hero Card Game - Game Design Document
game_type: Roguelike / Card Game (hybride)
platforms: PC (souris, manette), smartphone (tactile)
created: 2026-08-04
updated: 2026-08-09
status: draft
---

# Hero Card Game - Game Design Document

**Author:** Zgrubulu
**Game Type:** Roguelike / Card Game (hybride)
**Target Platform(s):** PC (souris, manette), smartphone (tactile), à parité

---

## Executive Summary

### Core Concept

Deck-building roguelike. Le joueur mène une troupe de 4 aventuriers (choisis parmi une collection qui grandit au fil des runs) à travers une carte de quêtes à embranchements jusqu'à un combat de boss, puis retourne au village pour dépenser les ressources accumulées avant de relancer un run. Chaque aventurier possède sa propre réserve d'énergie, sa propre carte de classe et son propre passif — ce n'est pas un deck générique piloté par un seul pool de ressources, mais 4 identités individuelles qui composent un deck de run commun.

### Target Audience

Joueurs de jeux de cartes roguelike qui recherchent un système lisible plutôt qu'une originalité mécanique : règles intuitives sans courbe d'apprentissage cachée, monde heroic fantasy classique (AD&D — guerrier, mage, voleur, paladin ; gobelins, squelettes, trolls) comme repère de compréhension immédiate, cartes et VFX explicites. Points d'ancrage : fans de *Pokémon* (ampleur de la collection), joueurs de *Sims*/*Animal Crossing* (le village), JRPGistes (collecte de personnages façon *Suikoden*, déblocages façon *FF7*).

### Unique Selling Points (USPs)

1. **Énergie individuelle par aventurier** plutôt qu'un pool global — la décision tactique porte sur *qui* agit, pas seulement sur *combien* dépenser.
2. **Les ennemis télégraphient leurs actions et leur cible** avant que le joueur ne joue — élimine la punition perçue comme injuste (réponse directe à *Slay the Spire*).
3. **Déblocage significatif et permanent garanti à chaque run** — élimine le vide ressenti une fois l'objectif principal atteint.
4. **Troupe de 4 héros à identité individuelle non interchangeable** (PV, énergie, carte de classe propres ; les ennemis ciblent un héros précis, pas "le groupe").

Différenciateurs secondaires (non-pilliers mais notables) : narration qui monte en puissance avec la progression plutôt qu'absente ou imposée d'entrée ; village à déplacement physique plutôt que menu.

---

## Goals and Context

### Project Goals

- **Équipe :** 2 personnes, temps personnel, aucun financement externe.
- **Mois 1 :** Prototype Minimaliste V1 (usage interne) — voir Development Epics.
- **Mois 2 :** boucle jouable minimale (combat + run + quêtes de déblocage).
- **Monétisation :** achat unique. Pas de packs de cartes, pas de gacha — la collection se débloque exclusivement par le jeu, jamais par l'achat.

### Background and Rationale

Le genre deck-building roguelike (*Slay the Spire* en tête) est démocratisé mais laisse trois frustrations récurrentes, documentées par un comparatif de 9 titres mené par le porteur de projet (`addendum.md`) : le chaos perçu comme injuste (aléa des ennemis), le vide ressenti une fois l'objectif de run atteint, et l'absence ou la lourdeur de la narration. Les 4 pillars ci-dessous répondent chacun directement à l'une de ces frustrations plutôt que de réinventer la formule.

---

## Core Gameplay

### Game Pillars

Pression-testés ("si on coupe ce pilier, que reste-t-il ?") lors de la Discovery :

1. **Énergie individuelle par aventurier, pas un pool global.** Chaque personnage a sa propre réserve d'énergie ; retirer ce pilier ramène le jeu à un deck-builder générique à pool unique — perd la lecture tactique "qui agit maintenant" qui différencie le jeu.
2. **Les ennemis annoncent leurs actions et leur cible à l'avance.** Retirer ce pilier réintroduit le chaos perçu comme injuste de *Slay the Spire*, la frustration n°1 identifiée dans le comparatif concurrentiel.
3. **Chaque run débloque quelque chose de significatif et permanent.** Retirer ce pilier réintroduit le vide de fin de run ("pourquoi relancer ?"), frustration n°2 identifiée.
4. **Une troupe de 4 héros à identité individuelle et non interchangeable.** PV, énergie et carte de classe propres à chacun ; les ennemis ciblent un héros précis, jamais "le groupe" en abstrait. Retirer ce pilier réduit la troupe à un skin cosmétique sur un deck générique — perd l'investissement individuel qui motive la collection de 40 héros.

*(Le pilier initial du brief "un monde familier plutôt qu'original" a été pressure-testé et rétrogradé : c'est une direction de contenu/vision, pas un pilier de gameplay — il ne pilote aucune décision mécanique. Il reste documenté dans Target Audience et Art Style.)*

### Core Gameplay Loop

**Boucle de run (niveau macro) :**
Choisir 4 aventuriers parmi les débloqués (1-2 parfois imposés selon le type de quête) → sélectionner une quête sur la carte → traverser combats et événements → vaincre un boss → débloquer une récompense significative et permanente → retour au village pour dépenser les ressources accumulées → relancer un run.

**Retour au village (confirmé) :** automatique et instantané (« Pierre de Foyer »), sans retraverser le chemin. Les éléments temporaires du run (deck, potions, objets spécifiques) sont perdus au retour — seules les ressources de village sont ramenées (« Transport par Tunnel des Taupes »). Impossible d'enchaîner directement sur une autre quête sans repasser par le village et réinitialiser son deck — référence explicite du porteur de projet à la mort inéluctable de *Slay the Spire* face à l'Architecte en fin de run : le même type d'artifice est recherché ici.

**Boucle de combat (sous-boucle, imbriquée dans "traverser combats") :**
Début de tour (chaque héros vivant gagne +1 énergie ; la main est complétée jusqu'à 5 cartes ; chaque ennemi vivant télégraphie son action et sa cible) → phase joueur (le joueur assigne des cartes de sa main aux héros disponibles, dans la limite de leur énergie) → fin de tour (les cartes non jouées de la main sont défaussées) → phase ennemie (chaque ennemi résout son action telegraphée contre sa cible déclarée) → tour suivant, jusqu'à victoire ou défaite du combat.

**Règle "un héros, une carte par tour" (confirmée) :** un aventurier ne peut recevoir qu'une seule carte assignée par tour de joueur — une fois qu'il a agi, il n'est plus éligible pour une autre carte ce tour-ci, quelle que soit son énergie restante (l'énergie non consommée reste banquée pour un tour futur). **Exception : Clairvoyance** (carte Paladin, voir Card Types and Effects) — l'aventurier qui la joue n'est pas considéré avoir agi, et peut donc recevoir une autre carte le même tour. Ceci referme l'ambiguïté précédemment signalée sur "cet aventurier peut agir à nouveau" : ce n'est pas un remboursement d'énergie, c'est un contournement de cette règle.

### Win/Loss Conditions

- **Victoire de combat :** tous les ennemis à 0 PV → passage au combat/événement suivant.
- **Défaite de combat :** tous les héros de la troupe à 0 PV → le run s'arrête, le joueur est renvoyé au village.
- **Égalités** (victoire et défaite au même tour) : à trancher au cas par cas — non spécifié plus précisément dans les sources. `[NOTE FOR DESIGNER]`
- **Victoire de run :** boss de fin de run vaincu → épilogue narratif + déblocage majeur + ressources de village importantes.
- **Mission Secours (optionnelle, confirmée par le document source) :** en cas de défaite, une quête spéciale apparaît temporairement, permettant à une autre équipe de tenter de rejoindre l'équipe vaincue. Si elle y parvient, le run vaincu reprend dans l'état où il a été perdu ; sinon, il est perdu définitivement.
- `[NOTE FOR DESIGNER]` **Justification narrative du retour au village après défaite** (résurrection façon *Dead Cells* — malédiction, réincarnation) : demandée explicitement par le porteur de projet mais **non tranchée à sa propre demande** (voir Risks du brief). Ne pas inventer de réponse ici — décision à prendre séparément, probablement au passage `gds-create-narrative`.

---

## Game Mechanics

### Primary Mechanics

**Énergie :** individuelle par héros vivant. Démarre à 0, +1 par tour, **sans plafond** (décision du porteur de projet — l'énergie peut se banquer indéfiniment si le joueur choisit de ne pas la dépenser). Les 3 prototypes de code implémentent actuellement un plafond de 3 ; c'est une divergence à corriger dans le code, pas la règle canon.

**Défense (nouvelle ressource, confirmée par la liste de cartes du porteur de projet) :** en plus des PV, un héros peut accumuler de la Défense — un pool qui absorbe les dégâts entrants. Remplace le modèle binaire "Esquive annule tout" documenté précédemment à partir des prototypes de code. `[NOTE FOR DESIGNER] La formule exacte d'absorption (soustraction un-pour-un aux dégâts reçus, ou autre) n'est pas précisée dans la source — à confirmer avant implémentation.`

**Deck, main et défausse (mis à jour 2026-08-06 avec le mode Run Infini — voir Run Infini pour le détail complet) :** chaque classe du MVP n'a désormais qu'**1 seule carte de palier "Départ"** (les 3 autres de ses 4 cartes sont "Avancé") — le deck de départ d'un run est construit à partir de 3× Coup direct + 3× Encaisser (génériques, coût 0) + 1 carte "Départ" par héros sélectionné (×4 héros) = **10 cartes**. Les cartes "Avancé" ne sont plus débloquées hors run : elles s'ajoutent au deck par le draft de fin de combat (voir Run Infini), à raison d'1 carte choisie parmi 3 après chaque victoire. **Le chiffre "deck de 12 cartes" reste caduc**, remplacé par cette décomposition. Main commune de 5 cartes, piochée en début de tour jusqu'à ce seuil. Les cartes non jouées en fin de tour sont défaussées. Quand le deck est vide, la défausse est remélangée en nouveau deck.

**Cartes génériques et cartes de classe :** liste complète (palier, coût, catégorie, effet exact) pour les 2 cartes génériques et les 4 classes du MVP dans Card Types and Effects, ci-dessous — remplace les cartes de classe précédemment documentées (issues des prototypes de code : Frappe Puissante, Éclair en Chaîne, Coup Sournois, Soin), qui n'existent plus dans le canon. Toute carte de classe reste jouable par n'importe quel héros disposant de l'énergie requise ; jouer une carte sur son propre aventurier d'origine déclenche généralement (pas systématiquement) sa Transcendance — voir Character Selection.

**Mots-clés / statuts (nouveau, confirmé par la liste de cartes) :** Saignements (dégâts continus, en stacks — ex. "Saignements 3"), Esquive (stacks d'esquive accordés par certaines cartes — distinct de l'ancienne carte de base du même nom, abandonnée), Incapacité (-25% dégâts infligés par la cible affectée), Vulnérabilité (+25% dégâts reçus par la cible affectée), Camouflé (ne peut être ciblé — **statut actuellement inaccessible en jeu depuis le retrait du Pouvoir de Classe de l'Assassin le 2026-08-09, plus aucune source ne l'accorde** ; la carte "Assassinat", voir Card Types and Effects, ne peut donc plus jamais résoudre sa branche Camouflé tant que ça n'est pas repensé), Concentration (action générique déjà documentée : place une carte sans résoudre son effet, gagne 1 énergie à la place). Referme la `[NOTE FOR DESIGNER]` précédente sur l'absence de système de mots-clés.

**Ciblage :** ennemi unique, tous les ennemis (AoE), soi-même, allié — selon le type de carte. Certaines actions ennemies sont ciblées sur un héros précis et affichées comme telles ("vise [Nom]"), d'autres sont aléatoires.

**Télégraphie ennemie :** chaque ennemi vivant tire indépendamment, en début de tour, une action pondérée (ex. Gobelin Maraudeur : Griffure 4 dégâts poids 2, Charge Brutale 7 dégâts poids 1) et une cible parmi les héros vivants ; affichée avec icône, nom, valeur et cible avant que le joueur ne joue.

**Retenir/défausser manuellement :** une carte de la main peut être glissée à gauche de l'écran pour être retenue, ou à droite pour être défaussée volontairement.

**Durée de combat :** 2 à 5 tours pour un combat normal ; plus long pour les boss d'étape et de fin de run (durée exacte non spécifiée). `[NOTE FOR DESIGNER]`

### Controls and Input

*(Réécrit le 2026-08-09 : un spike de ciblage dynamique, testé en jeu et validé par le porteur de projet, remplace le Drag & Drop comme cible de design finale. Voir `decision-log.md` pour la décision et son origine — spike inspiré de *Slay the Spire*, proposé en réponse au retour du porteur de projet : "notre jeu est une série de clics peu engageant".)*

**Design cible (jeu final) — ciblage dynamique à la flèche :** la carte ne suit pas la souris (contrairement au Drag & Drop précédemment documenté ci-dessous, abandonné) — c'est une ligne dessinée entre elle et le curseur qui porte l'intention du joueur.
1. **Survol d'une carte en main :** elle grossit immédiatement (pas de délai, contrairement à l'infobulle standard).
2. **Clic sur la carte :** elle se sélectionne et reste posée en avant (agrandie), le temps de la suite de la séquence.
3. **Flèche 1, de la carte vers l'aventurier survolé :** courbe légère avec un balancement continu (façon chaîne qui pend), composée de petits maillons plutôt qu'un trait droit — jamais un simple segment. Couleur : verte si la zone survolée est valide, rouge sinon. Chaque encart d'aventurier porte deux zones de clic : 3/4 haut = jouer la carte (VFX + petite animation au survol), 1/4 bas = se concentrer (VFX + animation distincte). Un clic sur une zone invalide **annule tout** — retour à la main, pas de retour en arrière d'un cran.
4. **Flèche 2 (si la carte a besoin d'une cible supplémentaire), de l'aventurier choisi vers la cible survolée :** même traitement visuel que la flèche 1. Cible valide (ennemi ou allié selon le type de carte) = verte ; invalide = rouge. Un clic sur une cible invalide annule tout, retour à la main — jamais plus d'une cible après le choix de l'aventurier.

**Mode alterné (prototype) — séquence à 3 taps :** conservée dans le code comme second mode, basculable à tout moment, pour continuer à jouer/tester pendant que d'autres chantiers avancent en parallèle :
1. Toucher/cliquer une carte de la main → la carte passe "en attente".
2. Toucher/cliquer le bouton "Jouer" ou "Se concentrer" sur l'encart d'un aventurier éligible.
3. Toucher/cliquer la cible valide → surbrillance des cibles éligibles selon le type de ciblage de la carte ; les cibles `self` et `all-enemies` se résolvent automatiquement sans ce troisième temps.

Annulation dans le mode à 3 taps : bouton "Annuler" dédié (pas de retour en arrière automatique sur cible/zone invalide, contrairement au mode flèche). `[NOTE FOR DESIGNER] Équivalent tactile des deux modes (survol n'existe pas nativement au toucher) encore à définir — le prototype actuel n'a été testé qu'à la souris.`

**Disposition et animation pioche/main/défausse (confirmée) :** la pioche est affichée à gauche de la main, la défausse à droite. Piocher anime les cartes depuis la pioche vers la main ; défausser les anime depuis la main vers la défausse. Quand un même tour enchaîne une défausse puis une pioche (fin de tour → tour suivant), une pause d'**1 seconde** sépare les deux animations pour que le joueur ait le temps de voir chacune distinctement.

---

## Roguelike / Card Game Specific Design

*Genre hybride confirmé : le jeu est autant un roguelike (structure de run, méta-progression permanente, sélection de personnages) qu'un deck-builder (cartes, ressource d'énergie, structure de tour). Les deux jeux de conventions genre sont documentés ci-dessous plutôt qu'un seul, pour éviter les angles morts de production identifiés par `genre-complexity.csv` pour chaque genre.*

### Run Structure

Durée d'un run : de ~20 minutes en début de campagne à ~1 heure en fin de campagne. Conditions de départ : 4 aventuriers choisis parmi les débloqués (1-2 parfois imposés selon le type de quête — voir Quêtes ci-dessous). Montée en difficulté intra-run : la rareté du loot augmente avec la progression du run ; le système de l'Astronome (voir Difficulty Modifiers) peut ajouter des contraintes globales. Condition de victoire de run : boss de fin de run vaincu.

**Biomes :** chaque biome apporte un bestiaire dédié, des règles de déplacement sur la carte et des règles de combat propres, pour poser des contraintes que le joueur peut anticiper sur ses prochains runs. Une encyclopédie se remplit progressivement (par biome, monstre, événement, boss…) à mesure que le joueur passe du temps avec chaque élément.

### Procedural Generation

Carte de quêtes à embranchements — mécanisme de génération non détaillé dans les sources actuelles (aléatoire, semi-aléatoire ou construite à la main : non tranché). `[NOTE FOR DESIGNER]` Distribution du loot : voir Card Collection and Progression ci-dessous.

### Permadeath and Progression

Pas de permadeath au sens strict d'un personnage supprimé : une défaite met fin au run en cours et renvoie le joueur au village (voir Win/Loss Conditions) — l'équivalent fonctionnel du "game over" roguelike porte sur le run, pas sur les héros eux-mêmes. Persiste entre les runs : héros débloqués, cartes débloquées, améliorations de village, ressources non dépensées. Méta-progression pilotée par les quêtes (classe, narrative, spéciale, multiple — voir Quêtes) et par les upgrades de village.

### Item and Upgrade System

- **Transcendance :** système chiffré et confirmé pour les 4 classes du MVP — voir Character Selection. *(Le Pouvoir de Classe, qui accompagnait la Transcendance jusqu'au 2026-08-06, a été retiré le 2026-08-09 — voir Character Selection.)* `[NOTE FOR DESIGNER] Les 36 héros restants du roster cible (40 total) auront chacun besoin de leur propre Transcendance — dépendance de contenu majeure, hors MVP.`
- **Rareté des cartes :** commune, rare, légendaire — la probabilité augmente avec la progression du run. Un taux exact n'est pas spécifié. `[NOTE FOR DESIGNER]`
- **Cartes épiques :** spécifiques à une ou plusieurs classes, s'intègrent temporairement au deck pour la durée du run (distinctes des 3 paliers de rareté ci-dessus — c'est un type de carte, pas un palier de rareté).
- **Loot complémentaire :** potions, objets magiques (effets puissants et/ou insolites), ressources de village.
- **Risque/récompense (Astronome) :** voir Difficulty Modifiers.

### Character Selection

**MVP (Mois 1) :** 4 héros — Guerrier, Paladin, Mage, Assassin *(le Paladin remplace le Clerc initialement prévu — décision du porteur de projet)*. Chacun : 1 skin avec animations idle (2 frames), action, coup reçu, KO ; 1 Transcendance ; 1 carte de classe ; 2 cartes de base communes partagées par tous. Chaque aventurier porte aussi un passé, un but dans la vie, et des interactions particulières avec les éléments du jeu — contenu narratif, à développer avec `gds-create-narrative` (`needs_narrative` déjà signalé, voir Finalize).

**Cible long terme :** 40 héros débloquables au total (4 au départ, 36 à débloquer). Chaque héros possède au maximum **15 cartes propres** : 5 "cartes de départ" (1 initiale + 4 à débloquer — 1 seule utilisée dans le deck au lancement d'un run) et 10 "cartes spéciales" (2 initiales + 8 à débloquer, toutes rencontrables au loot une fois débloquées), soit 12 cartes à débloquer par héros. Sur 40 héros : **~480 cartes à débloquer** (12×40) pour **~600 cartes distinctes au total** sur l'ensemble du roster (15×40), plus **40 améliorations de passifs** (Transcendance, 1 par héros × 40). *(Le chiffre "80 améliorations" utilisé jusqu'au 2026-08-06 comptait aussi le Pouvoir de Classe, retiré depuis — voir la note ci-dessous. Séparément, corrige le chiffre "~640 améliorations" utilisé jusqu'au 2026-08-06 pour les cartes — erreur de transcription du document source, 15×40 fait 600, pas 640.)* Ce périmètre complet est délibérément hors du MVP — voir Out of Scope.

**Contrôle en village :** n'importe quel aventurier de la troupe active peut être déplacé physiquement pour interagir avec les PNJ — pas limité à un "chef de groupe" fixe (voir Level Design Framework pour le rôle du chef de groupe dans le choix des quêtes).

*(Section Pouvoir de Classe retirée le 2026-08-09 — décision radicale du porteur de projet : « ça ne marche pas pour l'instant, je les remettrai peut-être plus tard, repensés. » Couvrait jusque-là un pouvoir par classe (coups gratuits du Guerrier, réanimation du Paladin, garder une carte pour le Mage, Camouflage + Puissance en Concentration pour l'Assassin). La Transcendance individuelle ci-dessous n'est pas concernée par ce retrait. Voir `decision-log.md` pour la décision complète et son impact chiffré.)*

#### Transcendance

Pouvoir spécial propre à chaque **aventurier individuel** (par opposition à un pouvoir partagé au niveau de la classe entière, tel qu'était le Pouvoir de Classe avant son retrait le 2026-08-09 — voir la note ci-dessus) — qui se déclenche sur une condition particulière, presque toujours le fait de jouer une carte assignée à cet aventurier lui-même. `[NOTE FOR DESIGNER] Le MVP n'a qu'un héros par classe, donc la distinction individu/classe n'est pas encore testable : dès qu'un 2ᵉ Guerrier sera débloqué, il faudra lui définir sa propre Transcendance, potentiellement différente de celle ci-dessous.`

**Règle générale (confirmée 2026-08-06) : la Transcendance se déclenche sur le mot-clé/la catégorie de la carte, jamais sur sa classe d'origine.** Elle s'applique dès que l'aventurier de la classe concernée joue **n'importe quelle carte** remplissant la condition — y compris une carte générique ou une carte d'une autre classe (ex. le Guerrier qui joue Coup direct générique, le Mage qui joue un sort d'une autre classe si un jour cela existe, le Paladin qui joue Encaisser générique ou Stratégie de l'Assassin). Restreindre le bonus aux seules cartes de la classe de l'aventurier est une règle incorrecte : c'était un bug du prototype (corrigé le 2026-08-06 pour les 4 classes), pas la règle canon.

| Classe (1 héros par classe dans le MVP) | Transcendance |
|---|---|
| Guerrier | +50% dégâts sur toute carte "épée" (⚔️, dégâts physique de mêlée) qu'il joue lui-même. |
| Paladin | +50% sur toute carte "bouclier" (défense) et/ou "soin" qu'il joue lui-même. |
| Mage | -2 coût en énergie sur toute carte "sort" (🪄) qu'il joue lui-même. |
| Assassin | Toute carte "épée" qu'il joue lui-même inflige en plus Incapacité 1 (-25% dégâts infligés par la cible touchée) et Vulnérabilité 1 (+25% dégâts reçus par la cible touchée). |

**Rapport entre carte de classe et Transcendance — et conséquence sur le verrouillage de carte :** les cartes de classe d'un aventurier sont *majoritairement* compatibles avec sa propre Transcendance (pas systématiquement), ce qui incite à assigner la bonne carte au bon héros sans jamais l'imposer, l'interdire, ni même l'indiquer à l'écran. Certaines classes proches sont conçues pour bien fonctionner ensemble, multipliant les déclenchements croisés de Transcendance entre plusieurs héros. **En conséquence, l'association carte↔aventurier d'origine n'est plus une contrainte de gameplay** : toute carte de classe peut être jouée par tout héros disposant de l'énergie requise. Cette association reste affichée comme repère de lore et de collection (voir Primary Mechanics), mais son rôle mécanique est entièrement repris par la Transcendance. Ceci remplace et referme la question ouverte "verrouillage strict vs. libre + synergie" soulevée en `bmad-party-mode` : c'était bien la piste "libre" qui était la bonne, portée un cran plus loin par la Transcendance.

### Difficulty Modifiers

**Système de l'Astronome :** débloqué en cours de progression, permet de changer la position des étoiles pour activer des règles globales de run — d'abord aléatoires, puis avec un contrôle croissant du joueur. Chaque modificateur combine un bonus et une contrainte de combat. Deux modificateurs sont documentés à ce stade (système présumé extensible au-delà) :
- **Lune d'Or :** +50% de gain de ressources de village, +1 dégât subi.
- **Lune Vermeille :** plus de chances d'obtenir des cartes rares au loot, plus de chances de rencontrer des élites en combat.

`[NOTE FOR DESIGNER] L'Astronome n'apparaît pas dans le périmètre MVP défini (Scope & MVP du brief) — traité ici comme un système post-MVP, voir Out of Scope et Development Epics.`

**Malédictions (système distinct de l'Astronome, confirmé par le document source) :** déclenchées par certaines quêtes, biomes, monstres ou événements. Deux formes : cartes supplémentaires ajoutées au deck avec un effet négatif (à l'utilisation ou à la non-utilisation), ou passifs qui modifient une règle générale de combat pour un personnage ou pour l'équipe.

**Règles spécifiques de quête :** certaines quêtes imposent des règles particulières qui durent tout le run (venant de la narration ou liées à la récompense de la quête — référence *Final Fantasy 8* Triple Triad). De nouvelles mécaniques inédites apparaissent au fil de la progression, pour limiter la répétition jusqu'au 100%.

**Difficulté des quêtes :** la quête principale d'un run a une difficulté fixe, non modifiable. Les autres quêtes ont une difficulté ajustable par le joueur, qui affecte le loot méta mais jamais le déblocage final — rien n'empêche de jouer systématiquement en facile ; des incentives de déblocage (non chiffrées) doivent inciter à monter en difficulté. `[NOTE FOR DESIGNER]`

**Challenge hard :** débloqué à un moment donné de la progression, un palier de difficulté supplémentaire nettement plus exigeant. En cas de victoire, débloque un skin cosmétique différent pour les cartes utilisées dans le run (référence *Monster Train*), et parfois des skins pour les héros ou les villageois selon la quête.

---

### Card Types and Effects

*(Mise à jour 2026-08-06 : le tableur des cartes a été entièrement refait par le porteur de projet — Coup mortel passe de la classe Assassin à la classe Guerrier, une nouvelle carte Assassin "Blessure ouverte" apparaît, et plusieurs coûts/effets changent. Correction du même jour : Coup Brutal retiré du Guerrier — laissé par erreur lors de la refonte, il faisait doublon avec Blessure ouverte de l'Assassin, effet strictement identique. Le deck du MVP reste donc à 18 cartes : 2 génériques + 4 par classe × 4 classes.)*

La table ci-dessous est la liste **MVP** telle qu'implémentée dans le prototype (18 cartes fixes, 4 par héros). Elle est une instanciation simplifiée de la structure long terme décrite en Character Selection (5 "cartes de départ" + 10 "cartes spéciales" par héros, débloquées progressivement sur les 40 héros) — les deux ne se contredisent pas : celle-ci est le sous-ensemble jouable dès aujourd'hui, l'autre la cible complète du jeu fini.

| Carte | Classe | Palier | Coût | Catégorie | Effet |
|---|---|---|---|---|---|
| Coup direct | Générique | Départ | 0 | épée | Inflige 4 dégâts. |
| Encaisser | Générique | Départ | 0 | bouclier | Gagne 4 défense. |
| Coup d'estoc | Guerrier | Départ | 0 | épée | Inflige 4 dégâts. Inflige 4 dégâts de plus si la cible a de la défense. |
| Coup de taille | Guerrier | Avancé | 1 | épée | Inflige 4 dégâts à tous les ennemis. |
| Coup mortel | Guerrier | Avancé | 0 | épée | Inflige 4 dégâts. Si tue sa cible, l'aventurier n'est pas considéré avoir agi et la carte retourne en main (au lieu de la défausse). |
| Riposte | Guerrier | Avancé | 3 | bouclier + épée | Si l'aventurier est la cible de l'attaque ennemie, annule cette attaque et inflige 4 dégâts. |
| Rempart | Paladin | Départ | 1 | bouclier | Cet aventurier et un autre gagnent 4 en défense chacun (6 chacun si joué par le Paladin — Transcendance s'applique aux deux gains). |
| Provocation | Paladin | Avancé | 0 | bouclier | Gagne 6 défense (9 si joué par le Paladin — Transcendance). Un ennemi change sa cible pour cet aventurier. |
| Clairvoyance | Paladin | Avancé | 0 | sort | Pioche une carte. Un autre aventurier se concentre. Cet aventurier n'est pas considéré avoir agi (voir la règle "un héros, une carte par tour" dans Core Gameplay Loop) — il peut recevoir une autre carte ce tour-ci. |
| Lumière divine | Paladin | Avancé | 2 | sort | Gagne 4 défense (6 si joué par le Paladin). Restaure 2 PV à tous les aventuriers (3 si joué par le Paladin — Transcendance s'applique aux deux effets). |
| Missile magique | Mage | Départ | 2 | sort, distance | Inflige 5 dégâts magiques. |
| Image miroir | Mage | Avancé | 3 | sort, défense | Gagne Esquive 2. |
| Tornade de feu | Mage | Avancé | 6 | sort, distance, feu | Inflige 5 dégâts magiques de feu à tous les ennemis. |
| Boule de feu | Mage | Avancé | 8 | sort, distance, feu | Inflige 15 dégâts magiques de feu. |
| Stratégie | Assassin | Départ | 0 | épée + bouclier | S'il est ciblé par un ennemi, gagne 4 en défense ; sinon, inflige 4 dégâts. |
| Blessure ouverte | Assassin | Avancé | 2 | épée | Inflige 6 dégâts et Saignements 3. |
| Assassinat | Assassin | Avancé | 4 | épée, brut | Si camouflé : inflige 10 dégâts bruts et perd le Camouflage. Sinon : se concentre (+1 énergie) et la carte retourne au sommet du deck au lieu d'être jouée. |
| Lâcheté | Assassin | Avancé | 1 | — | Change la cible pour un autre aventurier. L'ennemi gagne Incapacité 1. |

**Coût de Stratégie confirmé à 0** par le porteur de projet (2026-08-06) — le tableur refait fait foi, la valeur 1 d'une itération précédente est abandonnée.

**Glossaire de mots-clés :** un glossaire de 23 termes (icône, mot-clé lié, explication) a été fourni par le porteur de projet et implémenté dans le prototype — les mots-clés entre guillemets dans le texte des cartes sont automatiquement remplacés par leur icône (ex. "épée" → ⚔️, "bouclier" → 🛡️, "brut" → 💥, "soin" → 💚) quand le glossaire indique une icône, ou laissés en texte sinon (ex. Esquive, Saignements, Incapacité, Vulnérabilité, Camouflage, Puissance, Pioche). Une infobulle au survol (1s de délai), déjà en place pour les aventuriers et ennemis, liste désormais aussi les mots-clés présents sur chaque carte avec leurs mots-clés liés et explications. Le mot-clé "soin" (employé par Lumière divine) a été ajouté au glossaire le 2026-08-06 avec une icône (💚, choisie par distinction avec ❤️ de "pv") — la lacune précédemment signalée est comblée.

Catégories confirmées : cartes génériques (communes, coût 0), cartes de classe (palier Départ = deck de run initial, palier Avancé = débloqué), cartes épiques (spécifiques à une ou plusieurs classes, intégration temporaire au deck pendant un run — non détaillées carte par carte à ce stade). Paliers de rareté (au-delà de Départ/Avancé, pour la collection long terme) : commune, rare, légendaire. **Coût du Mage (2 à 8, contre 0 à 2 ailleurs) confirmé intentionnel par le porteur de projet** — équilibré par la Transcendance du Mage (-2 sur le coût de tout sort qu'il joue lui-même), qui ramène ses coûts effectifs dans la norme des autres classes tout en gardant des effets nettement plus puissants (dégâts et portée) que le reste du roster ; pas un oubli d'équilibrage.

**"Coup de taille" cible tous les ennemis, sans notion d'adjacence :** confirmé par le porteur de projet (2026-08-06) — la notion de ligne/adjacence entre ennemis est abandonnée à ce stade du prototype, pas seulement simplifiée temporairement.

**Chaque classe n'a plus qu'une seule carte Départ** (Coup d'estoc, Rempart, Missile magique, Stratégie) — Coup de taille, Coup mortel, Provocation et Image miroir sont passées en palier Avancé le 2026-08-06, en cohérence avec le deck de départ du mode Run Infini ci-dessous (une carte Départ par classe).

### Run Infini (mode de prototype, implémenté 2026-08-06)

Amélioration du prototype de combat existant (le continue, ne le remplace pas) — implémentée dans `proto-cartes-completes` suite à une session de party mode dédiée aux "nouveaux objectifs". Fonctionnement :

- **Deck de départ (10 cartes) :** 3 Coup direct, 3 Encaisser, 1 carte Départ par classe (Coup d'estoc, Rempart, Missile magique, Stratégie).
- **Progression :** à la fin de chaque combat gagné, le joueur choisit 1 carte parmi 3 (draft) qui s'ajoute à son deck. Entre deux combats d'un même run, **le deck et les PV des aventuriers persistent** (blessures non soignées d'un combat à l'autre — un héros tombé à 0 PV le reste tant qu'il n'est pas soigné) ; tout le reste repart à zéro à chaque nouveau combat : énergie, Défense, Esquive, Incapacité, Vulnérabilité, Camouflage, Puissance, Saignements. Le run est **infini** — pas encore de condition de victoire ni de récompense de fin de run ; il s'arrête à la défaite (tous les héros à 0 PV), l'écran de fin indiquant le nombre de combats remportés.
- **Difficulté :** chaque combat reçoit un budget fixe, totalement indépendant de l'état du groupe joueur (`20 × 1.22^(N-1)`, croissance exponentielle à +22%/combat — remplace la version linéaire initiale du 2026-08-06, jugée trop lente en playtest ; base relevée et courbe ralentie le 2026-08-09, demande explicite du porteur de projet ; valeurs placeholder, à tester). Le moteur traduit ce budget en un nombre d'ennemis (jusqu'à 4, pour la lisibilité) et leur niveau, tirés dans un bestiaire de 10 types.
- **Bestiaire (10 ennemis, niveau 1, comportement fixe — seules les valeurs scalent avec le niveau, +20 %/niveau) :** Gobelin Maraudeur, Squelette Archer, Troll des Marais (régénération annulée par des dégâts de feu subis pendant la phase joueur), Gobelourd (attaque toujours, dégâts réduits en défense), Loup Enragé, Araignée Venimeuse (dégâts brut + Saignement), Nécromancien Novice (Vulnérabilité 3, pas de dégât direct), Golem de Pierre (ne fait rien sauf s'il est touché pendant la phase joueur, auquel cas il riposte), Bandit Fourbe (cible toujours le héros au moins de PV), Chaman Gobelin (soigne un allié blessé s'il y en a un, sinon attaque).
- **Variance aléatoire :** chaque montant ennemi (dégâts, soin, bouclier, PV max) est tiré dans une fourchette ±20 % autour d'une valeur centrale — le télégraphe affiche toujours le montant réel déjà tiré (jamais la fourchette), qui n'apparaît qu'à titre informatif dans l'infobulle de l'ennemi.
- **Écran de fin de combat :** les 3 cartes du draft apparaissent face cachée, se retournent une par une après 2 s, sont survolables (même infobulle que la main) ; le choix ajoute la carte au deck, les 2 autres sont détruites visuellement. Règles de tirage : pool = génériques + classes présentes dans le groupe ; une carte Départ ne peut être que celle déjà dans le deck ; probabilité de doublon par slot 100 % / 25 % / 50 % ; jamais deux fois la même carte parmi les 3 ; pool de cartes inédites épuisé → retombe simplement sur un doublon.
- **"Recommencer" relance le combat en cours**, pas toute la run (mêmes ennemis, mêmes niveaux/PV déjà tirés, même deck) — une sauvegarde de l'état est prise au tout début de chaque combat. Le "Rejouer" affiché sur l'écran de défaite, lui, relance bien une run entière depuis le combat 1.

Hors scope de cette implémentation : le scaling comportemental des ennemis (nouveaux patterns à des paliers de puissance, prévu plus tard) et la récompense de fin de run garantie (pilier 3) — testé via Playwright (chargement sans erreur, boucle combat→draft→combat suivant→défaite jouée sur un run réel).

Mots-clés/statuts : voir Primary Mechanics.

### Deck Building

Le deck n'est pas construit librement par le joueur avant un run : il est assemblé automatiquement à partir des 4 héros sélectionnés — 2 cartes génériques (3 exemplaires chacune) + 1 carte de classe "Départ" par héros (voir Card Types and Effects pour la liste complète et Run Infini pour le detail du deck de départ), les cartes "Avancé" s'ajoutant par le draft de fin de combat plutôt que par un déblocage classique dans ce mode de prototype. `[NOTE FOR DESIGNER] Nombre de copies par carte au-delà du deck de départ non précisé par la source — voir Primary Mechanics.` Le document source mentionne que les upgrades de village peuvent porter sur "les possibilités de deckbuilding" — un système de personnalisation du deck plus poussé est donc envisagé mais non détaillé. `[NOTE FOR DESIGNER]`

### Mana/Resource System

Voir Primary Mechanics — énergie individuelle par héros, +1/tour, sans notion de couleur de mana ni de rampe.

### Turn Structure

Alternée (jamais simultanée) : phase joueur libre (toutes les cartes jouables sont assignables dans l'ordre voulu par le joueur) puis phase ennemie (résolution séquentielle des actions telegraphées). Pas de fenêtre de réponse/priorité façon jeu de cartes à combat. Durée cible : voir Primary Mechanics (2-5 tours en combat normal).

### Card Collection and Progression

Acquisition exclusivement par le jeu : loot de run (choix de 1 carte parmi 3, la carte du milieu ayant plus de chances d'être spéciale/épique), la proportion cartes neutres/cartes de classe déblocables augmente avec le niveau des héros (pourcentage non chiffré). Une carte déjà présente dans le deck du joueur peut malgré tout réapparaître au loot ; elle se retrouve alors en plusieurs exemplaires dans le deck. Monnaie de progression = ressources de village (voir Economy and Resources), jamais d'achat direct — cohérent avec le modèle "achat unique" (pas de packs, pas de gacha).

Chaque aventurier possède jusqu'à 15 cartes propres à débloquer sur sa durée de vie (voir Character Selection) — au lancement d'un run, seule 1 de ses "cartes de départ" débloquées entre dans le deck ; ses "cartes spéciales" débloquées sont, elles, toutes rencontrables en loot pendant le run. Chaque carte peut être améliorée 1 fois (amélioration non détaillée par les sources actuelles). `[NOTE FOR DESIGNER]`

### Game Modes

MVP et cible Mois 2 : un seul mode, le run solo. Aucun mode compétitif, coopératif ou multijoueur n'apparaît dans les sources — traité comme hors périmètre (voir Out of Scope) plutôt que supposé.

---

## Progression and Balance

### Player Progression

Quatre axes persistants entre les runs : héros débloqués (cible 40, dont 36 à débloquer), cartes débloquées (cible ~480 sur ~600 cartes distinctes au total, voir Character Selection), améliorations de passifs débloquées (cible 40 : 1 par héros × 40 — Transcendance seule, le Pouvoir de Classe étant retiré, voir Character Selection), et upgrades de village. Le déblocage passe par les quêtes (voir Level Design Framework) et par les upgrades de village achetées avec les ressources accumulées.

### Difficulty Curve

Intra-run : rareté du loot croissante avec la progression, modificateurs de l'Astronome en risque/récompense. Inter-run (méta) : les premiers runs se jouent avec 4 héros et un village "abandonné, bâtisses délabrées et vides" ; les runs suivants élargissent le roster et le village au fil des déblocages. Durée de run croissante (20 min → 1h) comme proxy indirect de montée en complexité.

### Economy and Resources

Ressources de village : **métaux** (dépensés chez le forgeron), **plantes** (chez l'herboriste), **pierres précieuses** (chez le magicien), et d'autres non encore nommées (le document source indique "etc.") ; plus une ressource **argent** générique. Dépensées pour : améliorer les decks, étendre les possibilités de deckbuilding, les avantages de début de run, et les bonus rencontrables en run. Chaque villageois peut être upgradé plusieurs fois pour débloquer plus d'options dans sa spécialité ; réussir une quête d'amélioration fait évoluer son échoppe/skin.

---

## Level Design Framework

### Level Types

- **Village (hub) :** déplacement physique actif d'un aventurier (pas de point-and-click contemplatif) entre les maisons des villageois, initialement délabrées/vides, débloquées et upgradées au fil de la progression. Détail du rôle de chef de groupe : voir Village ci-dessous.
- **Carte de quêtes :** structure à embranchements menant à un boss (génération non détaillée — voir Procedural Generation).
- **Combats :** 2 à 5 tours pour un combat normal ; MVP = 3 combats avec 5 types de monstres différents.
- **Événements (confirmé par le document source) :** 1 à 3 événements espacent chaque combat le long d'une quête — rencontre narrative avec choix bonus/malus, gain de loot, bénédiction/malédiction, entre autres.
- **Durée par quête :** les premières quêtes sont courtes (quelques combats, 1 seul boss) ; les dernières sont beaucoup plus longues (jusqu'à ~1h, jusqu'à 3 boss). Précise le chiffre "20 min → 1h" ci-dessus, qui décrit la durée d'un run entier, pas d'une quête individuelle.

### Village

Un aventurier est désigné **chef de groupe** pour chaque quête ; c'est lui qui apparaît en portrait dans les dialogues, et la quête le concerne au minimum (même si elle implique plusieurs aventuriers). Une fois le run terminé (réussi ou échoué), c'est ce même aventurier que le joueur continue de contrôler librement dans le village — le joueur peut changer de chef de groupe en parlant à un autre aventurier ; l'option reste disponible à tout moment. Un nouveau chef de groupe est désigné au lancement de chaque nouvelle quête.

Chaque aventurier possède un ou plusieurs lieux dédiés où il apparaît en train d'effectuer une activité liée à sa classe, avec un dialogue le plus souvent générique — pour donner l'impression d'un village de plus en plus vivant à mesure qu'il se peuple.

### Level Progression

**Quêtes de classe :** imposent de désigner au moins 1 héros "chef de groupe", puis liberté de choisir les 3 autres. **Quêtes narratives :** peuvent imposer plusieurs héros spécifiques selon la narration, en échange de rebondissements narratifs pendant le run. **Quêtes spéciales :** aucun chef imposé, liberté totale de composition. **Quêtes multiples/liées :** demandent de coordonner plusieurs groupes sur plusieurs runs différents pour accomplir des actions simultanées sur la carte ; le village reste dépeuplé des aventuriers engagés pendant ce temps, et le joueur peut interrompre ce type de quête à tout moment pour récupérer sa troupe.

**Arbre de quêtes :** les quêtes narratives sont chaînées pour offrir une histoire suivie ; de nombreuses quêtes sans narration de quête principale sont reliées à un déblocage (personnage, villageois, carte), formant des arcs indépendants. Certaines quêtes spéciales répondent à des compteurs cachés au joueur (amitié/animosité entre 2 aventuriers, présence d'un aventurier dans un biome donné, conditions spéciales façon Gogo dans *Final Fantasy 6*).

### Narrative Delivery

**Présence de la narration :** quasi absente en début de campagne (le joueur doit apprendre les règles vite), elle monte progressivement avec les déblocages de héros et de villageois.

**Déclenchement :** un compteur d'événements (invisible au joueur) rend un dialogue disponible une fois un seuil atteint, si le joueur se rend au bon endroit et effectue la bonne action. Cinq contextes de déclenchement : parler à un PNJ générique au village, parler à un PNJ lié à un aventurier spécifique (visible seulement avec le bon aventurier contrôlé), entrer dans une zone de dialogue entre 2 personnages au village, pendant un événement ou combat spécifique en run, ou à la résolution d'une quête. Suivi via un journal PNJ (voir Development Epics → Epic 7).

**Non-obligation :** dialogues courts, aucun narrateur ni narration environnementale — tout passe par le dialogue entre personnages. Un joueur qui saute systématiquement les dialogues perd le message mais jamais de progression : pas d'indices cachés ni de choix de dialogue (sauf rares exceptions), les quêtes qui en découlent restent listées automatiquement. Le jeu est finissable à 100% sans jamais prêter attention à la narration.

Contenu narratif (histoires, personnages, dialogues eux-mêmes) toujours hors périmètre de ce document — voir `needs_narrative` en Character Selection.

---

## Art and Audio Direction

### Art Style

Designs de héros "ultra classiques, stéréotypés et reconnaissables" — choix assumé au service de l'accessibilité par la familiarité (monde heroic fantasy AD&D). Mise en scène de combat : ennemis grands, de face (façon *Final Fantasy Mystic Quest*) ; troupe du joueur en ligne, vue de dos (façon *Knight of Pen & Paper*). Le village démarre visuellement à l'abandon et se régénère visuellement à mesure que les villageois sont débloqués/upgradés. Besoins d'asset MVP : voir Technical Specifications.

**Pipeline de génération d'assets par IA (verrouillé le 2026-08-07) :** style **pixel art rétro**, deux paliers de grille — **32×32** pour les icônes/objets simples (armes, boucliers, mots-clés), **64×64** pour les aventuriers/ennemis/portraits (une grille pleine 32×32 s'est révélée trop abstraite pour rester lisible sur un personnage posé). Génération via Cloudflare Workers AI (gratuit, modèle `@cf/black-forest-labs/flux-1-schnell`), qui ne produit pas d'image cohérente en dessous de ~128px nativement — le pipeline génère donc en pleine résolution avec un prompt pixel art, puis force la grille par downscale/upscale (nearest-neighbor) via le script `tools/generate-image.js`. Références de style validées : `game/assets/style-reference/reference-icon-epee-32.png`, `reference-icon-bouclier-32.png`, `reference-character-guerrier-64.png`. **Point d'intégration technique à ne pas oublier** : le rendu en jeu doit utiliser un filtre "nearest" (pas de lissage) sur ces images, sinon l'effet pixel art est invisible à l'écran.

### Combat Feedback (VFX)

*(Ajouté le 2026-08-09.)* Retours visuels de combat, tous procéduraux (aucun nouvel asset généré) :
- **Nombres de dégâts/soin flottants :** montent et s'estompent au-dessus de l'unité touchée. Les dégâts sont affichés en plus gros, avec un effet de zoom qui dépasse légèrement sa taille finale avant de se stabiliser (~0,22s) ; le soin reste discret (taille standard, simple montée + fondu).
- **Burst de pixels à l'impact :** une poignée de petits carrés giclent depuis l'unité touchée et retombent légèrement avant de s'estomper (~0,45s) — délibérément simple, pas un système de particules complet, pour rester dans l'esprit pixel art plutôt que le noyer sous des effets.
- **Pop d'échelle sur un statut appliqué :** le badge du statut concerné (bouclier, esquive, camouflage, puissance, saignements, incapacité, vulnérabilité) part agrandi et retombe à sa taille normale (~0,35s) au moment où il s'applique.
- **Grand bouclier en fondu :** silhouette de bouclier surdimensionnée sur l'unité, fondu entrant/sortant sur 1 seconde, déclenchée par un gain de Défense ou par des dégâts intégralement absorbés par la Défense existante.
- **Bordure dorée en écran de draft :** les cartes de palier "Avancé" proposées au choix de fin de combat (voir Run Infini) sont encadrées d'une bordure dorée, pour les distinguer d'un coup d'œil des cartes "Départ".

### Audio and Music

*(Mis à jour le 2026-08-09 — premier jalon concret sur une question jusque-là "entièrement à définir", voir `decision-log.md`. Reste listé aussi en Assumptions and Dependencies tant que le porteur de projet n'a pas validé le rendu à l'oreille — pas encore promu au canon complet.)*

**Direction retenue : synthèse audio procédurale façon puce sonore NES.** Ondes carrée/triangle/bruit générées directement en mémoire au lancement (aucun fichier audio, aucune dépendance externe, aucun service à payer) — le même principe que la console elle-même, qui ne jouait pas de samples enregistrés. 9 sons nommés : pioche d'une carte et retournement d'une carte au loot (même son), dégâts physiques, dégâts magiques (deux sons distincts), gain de bouclier ou dégâts intégralement bloqués par un bouclier (même son), un ennemi qui s'apprête à résoudre son action télégraphiée, résolution d'une Concentration, fanfare de victoire, fanfare de défaite. `[NOTE FOR DESIGNER] Un seul son joué par résolution même si une carte touche plusieurs cibles (pas de salve superposée) ; bibliothèque volontairement scopée à ces 9 événements pour l'instant, à étendre seulement après validation du style.`

---

## Technical Specifications

### Performance Requirements

Non spécifiées par le porteur de projet à ce stade. `[NOTE FOR DESIGNER] Cible de performance, moteur et contraintes de certification relèvent de gds-game-architecture, pas de ce document — à lever avant cette phase suivante.`

### Platform-Specific Details

PC (souris et manette) et smartphone (tactile), à parité dès le départ — argument explicite du porteur de projet : un jeu de cartes sans exigence de dextérité doit être aussi confortable sur les deux, ergonomie tactile pensée dès la conception plutôt qu'adaptée après coup (voir Controls and Input).

### Asset Requirements

**MVP (Mois 1) :** 4 skins de héros (Guerrier, Clerc, Mage, Assassin) avec animations idle (2 frames), action, coup reçu, KO ; 5 designs de monstres ; art du village en état "abandonné" de départ. **Cible long terme :** jusqu'à 40 skins de héros, ~600 illustrations de cartes (une par carte du roster complet, voir Character Selection), art du village évolutif par villageois upgradé, skins cosmétiques additionnels pour le mode Challenge hard (voir Difficulty Modifiers).

---

## Development Epics

### Epic Structure

| # | Épic | Pilier(s) servis | Statut |
|---|------|-------------------|--------|
| 1 | Boucle de combat centrale (énergie individuelle, deck/main/défausse, ciblage, télégraphie ennemie) | 1, 2 | Prototypé sur 4 itérations de code ; `proto-cartes-completes` (mode **Run Infini**, voir Run Infini) est le modèle canonique, les 3 précédentes restent des jalons historiques non mis à jour |
| 2 | Identité de classe (4 héros MVP, Transcendance, cartes de classe libres) | 4 | Prototypé — `proto-cartes-completes` est aligné sur le canon (Paladin, Assassin, cartes libres + Transcendance déclenchée par mot-clé, pas par classe d'origine) ; les 3 prototypes plus anciens restent en divergence (historique, non mis à jour). Le Pouvoir de Classe, qui faisait partie de cette epic jusqu'au 2026-08-06, en a été retiré le 2026-08-09 (voir Character Selection) |
| 3 | Lisibilité du premier combat / onboarding | 1, 2 | Non démarré — flaggé prioritaire par la séance `bmad-party-mode` |
| 4 | Structure de run et déblocage garanti (carte de quêtes, boss, récompense de fin de run) | 3 | Non démarré — cible Mois 2 |
| 5 | Village (déplacement physique, économie de ressources, upgrades de villageois) | 3 | Non démarré — cible Mois 2 |
| 6 | Système de l'Astronome (modificateurs globaux) | — | Post-MVP, hors Mois 1/2 |
| 7 | Narration par dialogues (journal PNJ, déclencheurs par compteurs d'événements) | — | Post-MVP, dépend d'une décision narrative encore ouverte |

Détail complet par epic (mécaniques précises, découpage en stories) : voir `epics.md` dans ce même dossier.

---

## Success Metrics

### Technical Metrics

Non définies — dépendent des cibles de performance encore à fixer (voir Technical Specifications). `[NOTE FOR DESIGNER]`

### Gameplay Metrics

- **Taux de déblocage garanti :** 100% des runs complétés jusqu'au boss produisent au moins un déblocage permanent significatif (pilier 3 — objectif de conception, pas encore instrumenté).
- **Durée de run :** ~20 minutes en début de campagne, jusqu'à ~1 heure en fin de campagne (cible déclarée, à valider en playtest).
- **Lisibilité du premier combat :** aucune métrique chiffrée définie à ce stade, mais signalé comme le risque d'onboarding le plus urgent (séance `bmad-party-mode`, plus urgent que la question narrative de résurrection). `[NOTE FOR DESIGNER] Proposer un playtest dédié dès que l'Epic 3 est jouable.`

---

## Out of Scope

Explicitement hors du Prototype Minimaliste V1 (Mois 1) :
- Les 36 héros restants au-delà des 4 du MVP (cible 40), les ~476 cartes restantes du MVP vers la cible ~480 à débloquer (~600 cartes distinctes au total sur les 40 héros), les 40 améliorations de passifs (Transcendance, 1 par héros × 40).
- Le système de l'Astronome (modificateurs globaux).
- La boucle complète de dépense de ressources au village (le MVP valide la boucle de combat, pas l'économie de village).
- La carte de quêtes à embranchements complète et les 4 types de quêtes (classe/narrative/spéciale/multiple) — ciblés Mois 2.
- Tout mode compétitif, coopératif ou multijoueur — non mentionné dans aucune source, traité comme non prévu plutôt que différé.

Hors périmètre du jeu en général (aucune source ne l'évoque) :
- Achat de cartes ou de contenu (packs, gacha) — contraire au modèle "achat unique" déclaré.

---

## Assumptions and Dependencies

**Décisions actées cette session (à ne pas re-demander) :**
- Type de jeu hybride Roguelike + Card Game confirmé par le porteur de projet.
- Modèle de main/défausse confirmé : main commune de 5 cartes, piochée en début de tour, défausse en fin de tour, remélange à vide (mécanique du prototype `proto-deck-main-defausse`, cohérente avec le "main de 5 cartes" déjà écrit dans le brief). **Le chiffre "deck de 12 cartes" est caduc** — remplacé par la liste de cartes réelle (2 génériques + 2 "Départ" par héros, voir Primary Mechanics et Card Types and Effects), nombre de copies par carte encore à confirmer pour le jeu final.
- **Taille de deck du prototype (temporaire, pas le canon final) :** 18 cartes (mise à jour 2026-08-06 : brièvement passée à 19, puis Coup Brutal retiré du Guerrier le même jour — doublon avec Blessure ouverte — ramenant le total à 18), 1 exemplaire de chacune. Scope explicitement limité au prototype pour permettre de tester le système complet tout de suite ; le nombre de copies pour les versions ultérieures reste ouvert.
- Coût de la carte Assassin "Stratégie" **confirmé à 0** par le porteur de projet (2026-08-06), tranchant le conflit avec la valeur 1 fixée lors d'une session précédente (abandonnée).
- Coûts de cartes du Mage (2 à 8) confirmés intentionnels, aucune correction nécessaire.
- **PV des héros — aucun montant fixé pour le moment, tout est temporaire** (précision du porteur de projet, 2026-08-06). PV de départ du Guerrier un temps noté "fixé à 18" ; cette formulation est retirée, la valeur redevient provisoire comme celle des 3 autres classes. Le prototype `proto-cartes-completes` utilise actuellement Guerrier 18, Paladin 14, Mage 10, Assassin 12 — à traiter comme des repères de test, pas comme le canon final.
- **Nom canonique du jeu : "Hero Card Game"** — tranché par le porteur de projet. Les variantes "Heroic Card Game" (ancien titre du GDD source) et "HERO CARD GAME" (nom de dossier/projet BMad, casse infrastructure uniquement) sont abandonnées comme noms du jeu ; le nom de dossier/dépôt technique reste inchangé, c'est une question d'infrastructure distincte du titre créatif.
- **Pas de plafond d'énergie** — l'énergie individuelle par héros se banque indéfiniment si non dépensée. Les 3 prototypes de code (plafond à 3) sont désormais en divergence avec le canon et à corriger.
- **Contrôles : ciblage dynamique à la flèche confirmé comme cible de design du jeu final (2026-08-09), remplace le Drag & Drop** — voir Controls and Input. Spike testé en jeu et validé par le porteur de projet avant d'être promu au canon. La séquence à 3 taps reste un mode alterné du prototype `proto-cartes-completes`, jamais le canon.
- **Économie de cartes long terme corrigée (2026-08-06) :** 15 cartes propres par héros (5 "cartes de départ" + 10 "cartes spéciales", 12 à débloquer), soit ~480 cartes à débloquer et ~600 cartes distinctes au total sur 40 héros — remplace le chiffre "~640 améliorations" utilisé jusqu'ici, qui provenait d'une erreur de transcription du document source (15×40 = 600, pas 640). *(Le volet "améliorations de passifs" de cette même décision, alors 80 = Pouvoir de Classe + Transcendance × 2 par héros, est retombé à 40 = Transcendance seule le 2026-08-09 avec le retrait du Pouvoir de Classe — voir ci-dessous.)*
- **Pouvoir de Classe retiré (2026-08-09), décision radicale du porteur de projet** : « ça ne marche pas pour l'instant, je les remettrai peut-être plus tard, repensés. » Les 4 pouvoirs (coups gratuits du Guerrier, réanimation du Paladin, garder 1 carte du Mage, Camouflage + Puissance 2 en Concentration de l'Assassin) disparaissent du canon — voir Character Selection. La Transcendance individuelle n'est pas concernée. Conséquence mécanique non demandée mais directe, signalée plutôt que corrigée sans accord : la carte Assassinat ("Si Camouflé...") ne peut plus jamais résoudre sa branche Camouflé, plus aucune source n'accordant ce statut.
- **Le Paladin remplace le Clerc dans le roster MVP** (Guerrier, Paladin, Mage, Assassin).
- **Nom de classe canonique : Assassin**, pas "Voleur" — le prototype `proto-deck-main-defausse` a dérivé sur ce nom, à corriger.
- **Verrouillage de carte par classe abandonné** : toute carte de classe est jouable par tout héros ayant l'énergie requise. Le mécanisme de synergie réel est la Transcendance (voir Character Selection), pas une restriction d'accès. Referme la question ouverte débattue en `bmad-party-mode` — c'est bien la piste "libre" qui était juste, affinée par la Transcendance plutôt que par un simple bonus de passif.
- **Système de ligne Front/Back abandonné** : absent du tableur des classes refait le 2026-08-06, remplacé à l'époque par le pouvoir de réanimation du Paladin (lui-même retiré depuis le 2026-08-09 avec tout le Pouvoir de Classe — voir Character Selection). Retiré du prototype `proto-cartes-completes` (CSS + logique + bonus de dégâts par ligne).
- **Relecture complète du GDD source (Google Doc), 2026-08-06 :** le porteur de projet a fourni un export PDF intégral (la lecture web précédente ne renvoyait qu'un résumé automatique tronqué, jugé peu fiable et écarté). Contenu significativement plus riche que l'extraction du 2026-08-04 sur Win/Loss (Mission Secours), Core Gameplay Loop (retour au village), Controls and Input (Drag & Drop vs prototype), Difficulty Modifiers (Malédictions, règles spécifiques de quête, difficulté ajustable, Challenge hard), Run Structure (Biomes), Level Design Framework (événements, durée par quête, Village, arbre de quêtes, Narrative Delivery) et Character Selection/Card Collection (économie de cartes par héros). Toutes ces sections ont été mises à jour en conséquence — voir chacune pour le détail.

**État du prototype `proto-cartes-completes` (le plus à jour) — canon désormais appliqué en code, plus seulement documenté :**
- Pas de `MAX_ENERGY` : l'énergie se banque indéfiniment.
- Aucun verrouillage de carte par classe : toute carte de classe est assignable à tout héros ; la Transcendance s'applique dès que la classe concernée joue une carte portant le mot-clé requis, quelle que soit la classe d'origine de cette carte — **corrigé le 2026-08-06** : une version antérieure du prototype restreignait par erreur le bonus aux seules cartes de la classe de l'aventurier, un bug de code plutôt qu'une règle de canon.
- Classe renommée "Assassin" (plus de "Voleur").
- Clerc retiré, remplacé par le Paladin (Rempart, Provocation, Clairvoyance, Lumière divine).
- **Pouvoir de Classe retiré du code le 2026-08-09** (voir Character Selection) — plus de coups gratuits du Guerrier, de réanimation du Paladin, de "garder 1 carte" pour le Mage, ni de Camouflage/Puissance automatiques en Concentration pour l'Assassin.
- **Ciblage dynamique à la flèche implémenté le 2026-08-09** (voir Controls and Input), en mode alterné avec la séquence à 3 taps — bascule possible à tout moment en jeu.
- **VFX de combat et son chiptune procédural implémentés le 2026-08-09** — voir Combat Feedback (VFX) et Audio and Music.
- Ressource Défense et statuts (Saignements — désormais aussi côté héros —, Esquive en stacks, Incapacité, Vulnérabilité, Camouflage, Puissance) implémentés.
- Liste de cartes alignée sur le tableur refait (18 cartes, voir Card Types and Effects) — Coup mortel déplacé vers le Guerrier (inflige 4, pas 3), Blessure ouverte ajoutée à l'Assassin, Assassinat révisé (branche Camouflé/non-Camouflé), Coup Brutal retiré du Guerrier (doublon avec Blessure ouverte). **Répartition des paliers revue le 2026-08-06 : chaque classe n'a plus qu'1 carte "Départ" (les 3 autres passent "Avancé")** — Coup de taille, Coup mortel, Provocation et Image miroir sont repassées en "Avancé" pour s'aligner sur le deck de départ à 10 cartes du mode Run Infini (voir Run Infini).
- Glossaire de mots-clés (icônes + infobulles au survol) implémenté.
- **Mode Run Infini implémenté (2026-08-06)** — boucle de combats enchaînés avec draft de carte après chaque victoire, bestiaire à 10 ennemis, budget de difficulté croissant, PV/deck persistants entre combats d'un même run. Détail complet : voir Run Infini, sous Roguelike / Card Game Specific Design. C'est un harnais de test pour l'Epic 1 (boucle de combat), pas une redéfinition de la structure de run finale (carte de quêtes/village/biomes, toujours visée à terme — voir Run Structure et Development Epics → Epic 4).

**Prototypes plus anciens (`mini-proto-2-cartes`, `proto-4-heros-2-ennemis`, `proto-deck-main-defausse`), conservés comme jalons historiques, non mis à jour — toujours en divergence avec le canon** (plafond d'énergie à 3, verrouillage de carte par classe, nom "Voleur", Clerc/Soin, pas de ressource Défense ni de statuts, coût de "Coup direct" à 1 au lieu de 0).

**Questions ouvertes signalées mais explicitement non tranchées ici (à la demande du porteur de projet) :**
- Justification narrative du retour au village après défaite (façon *Dead Cells*).
- Nom du mécanisme de rétention/défausse de fin de tour.
- **Direction sonore :** premier jalon posé le 2026-08-09 (synthèse audio procédurale façon NES, voir Audio and Music), pas encore promu au canon complet — en attente de validation du porteur de projet à l'oreille.
- Rythme exact du loot (pourcentages de drop, taux de rareté par palier de run).
- **Variété d'ennemis :** le prototype ne contient que des ennemis placeholder (dont le Gobelourd). Le porteur de projet prévoit d'ajouter de nouveaux ennemis au tableur, avec une échelle de puissance permettant de rendre un même ennemi plus faible ou plus fort selon la composition du groupe d'aventuriers — mécanique encore à chiffrer, non implémentée.
- Formule exacte d'absorption de la Défense (voir Primary Mechanics).
- Nombre de copies par carte dans le deck final (au-delà du prototype).

*(Retirées le 2026-08-06, rouvertes trop longtemps par erreur de tenue à jour : "carte de classe du Paladin" — résolue depuis Rempart/Provocation/Clairvoyance/Lumière divine ; "commande UI de changement de ligne du Paladin" — n'a plus d'objet depuis l'abandon du système Front/Back ; "condition du bonus Camouflé de l'Assassin" — résolue par le Pouvoir de Classe chiffré, Puissance 2. Retirée le 2026-08-09, sans objet depuis : "commande UI de sélection de la carte gardée par le Pouvoir de Classe du Mage" — le Pouvoir de Classe du Mage lui-même a été retiré.)*

**Dépendances de contenu :**
- Le tableur des classes ne documente pour l'instant qu'1 classe sur les 40 héros prévus (Paladin) — mais sa Transcendance est maintenant définie directement par le porteur de projet, indépendamment du tableur (le Pouvoir de Classe qui l'accompagnait jusqu'au 2026-08-06 a été retiré le 2026-08-09, voir Character Selection). La dépendance bloquante porte sur les 36 héros restants, pas sur le Paladin du MVP.
- Le mécanisme de génération de la carte de quêtes (aléatoire/semi-aléatoire/manuel) n'est pas spécifié.
- Le système de deckbuilding déblocable au village (mentionné dans le document source parmi les dépenses de ressources possibles) n'est pas détaillé.
