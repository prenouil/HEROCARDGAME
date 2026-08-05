---
title: Hero Card Game - Game Design Document
game_type: Roguelike / Card Game (hybride)
platforms: PC (souris, manette), smartphone (tactile)
created: 2026-08-04
updated: 2026-08-04
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

**Boucle de combat (sous-boucle, imbriquée dans "traverser combats") :**
Début de tour (chaque héros vivant gagne +1 énergie ; la main est complétée jusqu'à 5 cartes ; chaque ennemi vivant télégraphie son action et sa cible) → phase joueur (le joueur assigne des cartes de sa main aux héros disponibles, dans la limite de leur énergie) → fin de tour (les cartes non jouées de la main sont défaussées) → phase ennemie (chaque ennemi résout son action telegraphée contre sa cible déclarée) → tour suivant, jusqu'à victoire ou défaite du combat.

**Règle "un héros, une carte par tour" (confirmée) :** un aventurier ne peut recevoir qu'une seule carte assignée par tour de joueur — une fois qu'il a agi, il n'est plus éligible pour une autre carte ce tour-ci, quelle que soit son énergie restante (l'énergie non consommée reste banquée pour un tour futur). **Exception : Clairvoyance** (carte Paladin, voir Card Types and Effects) — l'aventurier qui la joue n'est pas considéré avoir agi, et peut donc recevoir une autre carte le même tour. Ceci referme l'ambiguïté précédemment signalée sur "cet aventurier peut agir à nouveau" : ce n'est pas un remboursement d'énergie, c'est un contournement de cette règle.

### Win/Loss Conditions

- **Victoire de combat :** tous les ennemis à 0 PV → passage au combat/événement suivant.
- **Défaite de combat :** tous les héros de la troupe à 0 PV → le run s'arrête, le joueur est renvoyé au village.
- **Égalités** (victoire et défaite au même tour) : à trancher au cas par cas — non spécifié plus précisément dans les sources. `[NOTE FOR DESIGNER]`
- **Victoire de run :** boss de fin de run vaincu → épilogue narratif + déblocage majeur + ressources de village importantes.
- `[NOTE FOR DESIGNER]` **Justification narrative du retour au village après défaite** (résurrection façon *Dead Cells* — malédiction, réincarnation) : demandée explicitement par le porteur de projet mais **non tranchée à sa propre demande** (voir Risks du brief). Ne pas inventer de réponse ici — décision à prendre séparément, probablement au passage `gds-create-narrative`.

---

## Game Mechanics

### Primary Mechanics

**Énergie :** individuelle par héros vivant. Démarre à 0, +1 par tour, **sans plafond** (décision du porteur de projet — l'énergie peut se banquer indéfiniment si le joueur choisit de ne pas la dépenser). Les 3 prototypes de code implémentent actuellement un plafond de 3 ; c'est une divergence à corriger dans le code, pas la règle canon.

**Défense (nouvelle ressource, confirmée par la liste de cartes du porteur de projet) :** en plus des PV, un héros peut accumuler de la Défense — un pool qui absorbe les dégâts entrants. Remplace le modèle binaire "Esquive annule tout" documenté précédemment à partir des prototypes de code. `[NOTE FOR DESIGNER] La formule exacte d'absorption (soustraction un-pour-un aux dégâts reçus, ou autre) n'est pas précisée dans la source — à confirmer avant implémentation.`

**Deck, main et défausse (chiffres mis à jour par la liste de cartes fournie par le porteur de projet) :** le deck du joueur est construit à partir de 2 cartes génériques (coût 0, partagées par tous) + 2 cartes de classe de palier "Départ" par héros sélectionné (×4 héros) ; les cartes de palier "Avancé" (2 par héros) s'ajoutent au deck par déblocage plutôt que dès le départ. `[NOTE FOR DESIGNER] Le nombre de copies de chaque carte dans le deck (1 exemplaire ou plusieurs) n'est pas précisé par la source — l'ancien chiffre "deck de 12 cartes" (2 cartes de base × 4 héros + 1 spéciale × 4 héros) est caduc et remplacé par cette décomposition tant que le nombre de copies n'est pas confirmé.` Main commune de 5 cartes, piochée en début de tour jusqu'à ce seuil. Les cartes non jouées en fin de tour sont défaussées. Quand le deck est vide, la défausse est remélangée en nouveau deck.

**Cartes génériques et cartes de classe :** liste complète (palier, coût, catégorie, effet exact) pour les 2 cartes génériques et les 4 classes du MVP dans Card Types and Effects, ci-dessous — remplace les cartes de classe précédemment documentées (issues des prototypes de code : Frappe Puissante, Éclair en Chaîne, Coup Sournois, Soin), qui n'existent plus dans le canon. Toute carte de classe reste jouable par n'importe quel héros disposant de l'énergie requise ; jouer une carte sur son propre aventurier d'origine déclenche généralement (pas systématiquement) sa Transcendance — voir Character Selection.

**Mots-clés / statuts (nouveau, confirmé par la liste de cartes) :** Saignements (dégâts continus, en stacks — ex. "Saignements 3"), Esquive (stacks d'esquive accordés par certaines cartes — distinct de l'ancienne carte de base du même nom, abandonnée), Incapacité (-25% dégâts infligés par la cible affectée), Vulnérabilité (+25% dégâts reçus par la cible affectée), Camouflé (ne peut être ciblé — lié au Pouvoir de Classe de l'Assassin), Concentration (action générique déjà documentée : place une carte sans résoudre son effet, gagne 1 énergie à la place). Referme la `[NOTE FOR DESIGNER]` précédente sur l'absence de système de mots-clés.

**Ciblage :** ennemi unique, tous les ennemis (AoE), soi-même, allié — selon le type de carte. Certaines actions ennemies sont ciblées sur un héros précis et affichées comme telles ("vise [Nom]"), d'autres sont aléatoires.

**Télégraphie ennemie :** chaque ennemi vivant tire indépendamment, en début de tour, une action pondérée (ex. Gobelin Maraudeur : Griffure 4 dégâts poids 2, Charge Brutale 7 dégâts poids 1) et une cible parmi les héros vivants ; affichée avec icône, nom, valeur et cible avant que le joueur ne joue.

**Retenir/défausser manuellement :** une carte de la main peut être glissée à gauche de l'écran pour être retenue, ou à droite pour être défaussée volontairement.

**Durée de combat :** 2 à 5 tours pour un combat normal ; plus long pour les boss d'étape et de fin de run (durée exacte non spécifiée). `[NOTE FOR DESIGNER]`

### Controls and Input

Séquence à 3 étapes (validée par le prototype le plus récent, cohérente avec l'objectif de parité PC/mobile posé dans le brief — une séquence de taps successifs porte mieux sur tactile qu'un glisser-déposer) :
1. Toucher/cliquer une carte de la main → la carte passe "en attente".
2. Toucher/cliquer un héros éligible pour lui assigner la carte (doit avoir l'énergie suffisante et respecter la restriction de propriétaire si la carte est une spéciale) → surbrillance des héros éligibles.
3. Toucher/cliquer la cible valide (ennemi, allié) → surbrillance des cibles éligibles selon le type de ciblage de la carte ; les cibles `self` et `all-enemies` se résolvent automatiquement sans ce troisième temps.

Annulation : clic droit (PC) / à définir pour tactile `[NOTE FOR DESIGNER]`. Séquence à 3 taps confirmée comme schéma de contrôle canon par le porteur de projet — le glisser-déposer des deux prototypes plus anciens est une itération antérieure, abandonnée.

**Disposition et animation pioche/main/défausse (confirmée) :** la pioche est affichée à gauche de la main, la défausse à droite. Piocher anime les cartes depuis la pioche vers la main ; défausser les anime depuis la main vers la défausse. Quand un même tour enchaîne une défausse puis une pioche (fin de tour → tour suivant), une pause d'**1 seconde** sépare les deux animations pour que le joueur ait le temps de voir chacune distinctement.

---

## Roguelike / Card Game Specific Design

*Genre hybride confirmé : le jeu est autant un roguelike (structure de run, méta-progression permanente, sélection de personnages) qu'un deck-builder (cartes, ressource d'énergie, structure de tour). Les deux jeux de conventions genre sont documentés ci-dessous plutôt qu'un seul, pour éviter les angles morts de production identifiés par `genre-complexity.csv` pour chaque genre.*

### Run Structure

Durée d'un run : de ~20 minutes en début de campagne à ~1 heure en fin de campagne. Conditions de départ : 4 aventuriers choisis parmi les débloqués (1-2 parfois imposés selon le type de quête — voir Quêtes ci-dessous). Montée en difficulté intra-run : la rareté du loot augmente avec la progression du run ; le système de l'Astronome (voir Difficulty Modifiers) peut ajouter des contraintes globales. Condition de victoire de run : boss de fin de run vaincu.

### Procedural Generation

Carte de quêtes à embranchements — mécanisme de génération non détaillé dans les sources actuelles (aléatoire, semi-aléatoire ou construite à la main : non tranché). `[NOTE FOR DESIGNER]` Distribution du loot : voir Card Collection and Progression ci-dessous.

### Permadeath and Progression

Pas de permadeath au sens strict d'un personnage supprimé : une défaite met fin au run en cours et renvoie le joueur au village (voir Win/Loss Conditions) — l'équivalent fonctionnel du "game over" roguelike porte sur le run, pas sur les héros eux-mêmes. Persiste entre les runs : héros débloqués, cartes débloquées, améliorations de village, ressources non dépensées. Méta-progression pilotée par les quêtes (classe, narrative, spéciale, multiple — voir Quêtes) et par les upgrades de village.

### Item and Upgrade System

- **Pouvoir de Classe et Transcendance :** système chiffré et confirmé pour les 4 classes du MVP — voir Character Selection. *Remplace* la description informelle "passif/actif" tirée initialement du tableur des classes pour le Paladin ("50% de chances d'attirer les attaques ennemies, dégâts subis réduits de 1" / actif : "cible -1 attaque, 100% de chances d'être attaquée") — une version antérieure et plus simple de ce que couvrent maintenant le Pouvoir de Classe Front/Back Line et la Transcendance +50% défense du Paladin. `[NOTE FOR DESIGNER] Les 36 héros restants du roster cible (40 total) auront chacun besoin de leur propre Pouvoir de Classe et Transcendance — dépendance de contenu majeure, hors MVP.`
- **Rareté des cartes :** commune, rare, légendaire — la probabilité augmente avec la progression du run. Un taux exact n'est pas spécifié. `[NOTE FOR DESIGNER]`
- **Cartes épiques :** spécifiques à une ou plusieurs classes, s'intègrent temporairement au deck pour la durée du run (distinctes des 3 paliers de rareté ci-dessus — c'est un type de carte, pas un palier de rareté).
- **Loot complémentaire :** potions, objets magiques (effets puissants et/ou insolites), ressources de village.
- **Risque/récompense (Astronome) :** voir Difficulty Modifiers.

### Character Selection

**MVP (Mois 1) :** 4 héros — Guerrier, Paladin, Mage, Assassin *(le Paladin remplace le Clerc initialement prévu — décision du porteur de projet)*. Chacun : 1 skin avec animations idle (2 frames), action, coup reçu, KO ; 1 Pouvoir de Classe ; 1 Transcendance ; 1 carte de classe ; 2 cartes de base communes partagées par tous. Chaque aventurier porte aussi un passé, un but dans la vie, et des interactions particulières avec les éléments du jeu — contenu narratif, à développer avec `gds-create-narrative` (`needs_narrative` déjà signalé, voir Finalize).

**Cible long terme :** 40 héros débloquables au total, ~480 cartes, ~640 améliorations. Ce périmètre complet est délibérément hors du MVP — voir Out of Scope.

**Contrôle en village :** n'importe quel aventurier de la troupe active peut être déplacé physiquement pour interagir avec les PNJ — pas limité à un "chef de groupe" fixe (voir Level Design Framework pour le rôle du chef de groupe dans le choix des quêtes).

#### Pouvoir de Classe

Défini au niveau de la classe (partagé par tous les héros de cette classe), un Pouvoir de Classe modifie radicalement une règle du jeu. Volontairement complexe : le joueur le consulte à un moment calme — la composition d'équipe entre deux runs — et son impact sur le run est majeur.

| Classe | Pouvoir de Classe |
|---|---|
| Guerrier | Au début de chaque tour, déclenche gratuitement une attaque aléatoire pour chaque carte d'attaque de mêlée en main. |
| Paladin | Les héros sont répartis en 2 lignes : Front Line (+20% de chances d'être ciblé) et Back Line (-20% dégâts physiques reçus ET infligés). Le Paladin est toujours en Front Line ; les autres héros changent de ligne gratuitement. `[NOTE FOR DESIGNER] Commande de changement de ligne non définie par le porteur de projet.` |
| Mage | En fin de tour, permet de conserver 1 carte en main au lieu de la défausser automatiquement. `[NOTE FOR DESIGNER] Commande de sélection de la carte gardée non définie.` |
| Assassin | Quand il joue Concentration (l'action générique de gain d'énergie), devient Camouflé jusqu'à sa prochaine attaque. Camouflé : ne peut pas être ciblé ; +50% de dégâts. `[NOTE FOR DESIGNER] Formulation source ambiguë sur la condition exacte du bonus de dégâts ("+50% aux dégâts si la cible attaque") — à clarifier avec le porteur de projet avant implémentation.` |

#### Transcendance

Pouvoir spécial supplémentaire, propre à chaque **aventurier individuel** (contrairement au Pouvoir de Classe, partagé par classe) — qui se déclenche sur une condition particulière, presque toujours le fait de jouer une carte assignée à cet aventurier lui-même. `[NOTE FOR DESIGNER] Le MVP n'a qu'un héros par classe, donc la distinction individu/classe n'est pas encore testable : dès qu'un 2ᵉ Guerrier sera débloqué, il faudra lui définir sa propre Transcendance, potentiellement différente de celle ci-dessous.`

| Classe (1 héros par classe dans le MVP) | Transcendance |
|---|---|
| Guerrier | +50% dégâts d'attaque de mêlée. |
| Paladin | +50% défense pour protéger un autre aventurier. |
| Mage | -2 coût en énergie si le sort lancé est un sort d'attaque. |
| Assassin | Les attaques de mêlée infligent Incapacité 1 (-25% dégâts infligés par la cible touchée) et Vulnérabilité 1 (+25% dégâts reçus par la cible touchée). |

**Rapport entre carte de classe et Transcendance — et conséquence sur le verrouillage de carte :** les cartes de classe d'un aventurier sont *majoritairement* compatibles avec sa propre Transcendance (pas systématiquement), ce qui incite à assigner la bonne carte au bon héros sans jamais l'imposer, l'interdire, ni même l'indiquer à l'écran. Certaines classes proches sont conçues pour bien fonctionner ensemble, multipliant les déclenchements croisés de Transcendance entre plusieurs héros. **En conséquence, l'association carte↔aventurier d'origine n'est plus une contrainte de gameplay** : toute carte de classe peut être jouée par tout héros disposant de l'énergie requise. Cette association reste affichée comme repère de lore et de collection (voir Primary Mechanics), mais son rôle mécanique est entièrement repris par la Transcendance. Ceci remplace et referme la question ouverte "verrouillage strict vs. libre + synergie" soulevée en `bmad-party-mode` : c'était bien la piste "libre" qui était la bonne, portée un cran plus loin par la Transcendance.

### Difficulty Modifiers

**Système de l'Astronome :** débloqué en cours de progression, permet de changer la position des étoiles pour activer des règles globales de run — d'abord aléatoires, puis avec un contrôle croissant du joueur. Chaque modificateur combine un bonus et une contrainte de combat. Deux modificateurs sont documentés à ce stade (système présumé extensible au-delà) :
- **Lune d'Or :** +50% de gain de ressources de village, +1 dégât subi.
- **Lune Vermeille :** plus de chances d'obtenir des cartes rares au loot, plus de chances de rencontrer des élites en combat.

`[NOTE FOR DESIGNER] L'Astronome n'apparaît pas dans le périmètre MVP défini (Scope & MVP du brief) — traité ici comme un système post-MVP, voir Out of Scope et Development Epics.`

---

### Card Types and Effects

Liste complète du deck du joueur pour le MVP, fournie par le porteur de projet (2 cartes génériques + 4 cartes par classe × 4 classes = 18 cartes) :

| Carte | Classe | Palier | Coût | Catégorie | Effet |
|---|---|---|---|---|---|
| Coup direct | Générique | Départ | 0 | dégâts mêlée physique | Inflige 4 dégâts. |
| Encaisser | Générique | Départ | 0 | défense physique | Gagne 4 défense. |
| Coup d'estoc | Guerrier | Départ | 1 | dégâts mêlée physique | Inflige 4 dégâts. Inflige 4 dégâts de plus si l'ennemi se défend. |
| Coup de taille | Guerrier | Départ | 1 | dégâts mêlée physique | Inflige 4 dégâts à 3 ennemis adjacents. |
| Coup Brutal | Guerrier | Avancé | 2 | dégâts mêlée physique | Inflige 6 dégâts et Saignements 3. |
| Riposte | Guerrier | Avancé | 1 | défense + dégâts mêlée physique | Si l'aventurier est la cible de l'attaque ennemie, annule cette attaque et inflige 4 dégâts. |
| Rempart | Paladin | Départ | 1 | défense physique | Cet aventurier et un autre gagnent 4 en défense. |
| Provocation | Paladin | Départ | 1 | défense physique | Gagne 6 défense. Un ennemi change sa cible pour cet aventurier. |
| Clairvoyance | Paladin | Avancé | 0 | deck / concentration | Pioche une carte. Un autre aventurier se concentre. Cet aventurier n'est pas considéré avoir agi (voir la règle "un héros, une carte par tour" dans Core Gameplay Loop) — il peut recevoir une autre carte ce tour-ci. |
| Lumière divine | Paladin | Avancé | 2 | défense + magie + soin | Gagne 4 défense. Restaure 2 PV à tous les aventuriers. |
| Missile magique | Mage | Départ | 2 | dégâts distance magique | Inflige 5 dégâts magiques. |
| Image miroir | Mage | Départ | 3 | défense magique | Gagne Esquive 2. |
| Tornade de feu | Mage | Avancé | 6 | dégâts distance feu | Inflige 3 dégâts magiques à tous les ennemis. |
| Boule de feu | Mage | Avancé | 8 | dégâts distance feu | Inflige 10 dégâts magiques. |
| Stratégie | Assassin | Départ | 1 | dégâts mêlée physique + défense | S'il est ciblé, gagne 4 en défense ; sinon, inflige 4 dégâts. |
| Coup mortel | Assassin | Départ | 1 | dégâts mêlée physique | Inflige 2 dégâts. Si tue sa cible, peut agir à nouveau. |
| Assassinat | Assassin | Avancé | 6 | dégâts mêlée physique | Ne peut être joué que Camouflé. Inflige 10 dégâts. |
| Lâcheté | Assassin | Avancé | 1 | — | Change la cible pour un autre aventurier. L'ennemi gagne Incapacité 1. |

Catégories confirmées : cartes génériques (communes, coût 0), cartes de classe (palier Départ = deck de run initial, palier Avancé = débloqué), cartes épiques (spécifiques à une ou plusieurs classes, intégration temporaire au deck pendant un run — non détaillées carte par carte à ce stade). Paliers de rareté (au-delà de Départ/Avancé, pour la collection long terme) : commune, rare, légendaire. Coût du Mage (2 à 8, contre 0 à 2 ailleurs) confirmé intentionnel par le porteur de projet — archétype lent et puissant assumé, pas un oubli d'équilibrage.

Mots-clés/statuts : voir Primary Mechanics.

### Deck Building

Le deck n'est pas construit librement par le joueur avant un run : il est assemblé automatiquement à partir des 4 héros sélectionnés — 2 cartes génériques + 2 cartes de classe "Départ" par héros (voir Card Types and Effects pour la liste complète), les cartes "Avancé" s'ajoutant par déblocage. `[NOTE FOR DESIGNER] Nombre de copies par carte non précisé par la source — voir Primary Mechanics.` Le document source mentionne que les upgrades de village peuvent porter sur "les possibilités de deckbuilding" — un système de personnalisation du deck plus poussé est donc envisagé mais non détaillé. `[NOTE FOR DESIGNER]`

### Mana/Resource System

Voir Primary Mechanics — énergie individuelle par héros, +1/tour, sans notion de couleur de mana ni de rampe.

### Turn Structure

Alternée (jamais simultanée) : phase joueur libre (toutes les cartes jouables sont assignables dans l'ordre voulu par le joueur) puis phase ennemie (résolution séquentielle des actions telegraphées). Pas de fenêtre de réponse/priorité façon jeu de cartes à combat. Durée cible : voir Primary Mechanics (2-5 tours en combat normal).

### Card Collection and Progression

Acquisition exclusivement par le jeu : loot de run (choix de 1 carte parmi 3, la carte du milieu ayant plus de chances d'être spéciale/épique), la proportion cartes neutres/cartes de classe déblocables augmente avec le niveau des héros (pourcentage non chiffré). Monnaie de progression = ressources de village (voir Economy and Resources), jamais d'achat direct — cohérent avec le modèle "achat unique" (pas de packs, pas de gacha).

### Game Modes

MVP et cible Mois 2 : un seul mode, le run solo. Aucun mode compétitif, coopératif ou multijoueur n'apparaît dans les sources — traité comme hors périmètre (voir Out of Scope) plutôt que supposé.

---

## Progression and Balance

### Player Progression

Trois axes persistants entre les runs : héros débloqués (cible 40), cartes débloquées (cible ~480), améliorations débloquées (cible ~640). Le déblocage passe par les quêtes (voir Level Design Framework) et par les upgrades de village achetées avec les ressources accumulées.

### Difficulty Curve

Intra-run : rareté du loot croissante avec la progression, modificateurs de l'Astronome en risque/récompense. Inter-run (méta) : les premiers runs se jouent avec 4 héros et un village "abandonné, bâtisses délabrées et vides" ; les runs suivants élargissent le roster et le village au fil des déblocages. Durée de run croissante (20 min → 1h) comme proxy indirect de montée en complexité.

### Economy and Resources

Ressources de village : **métaux** (dépensés chez le forgeron), **plantes** (chez l'herboriste), **pierres précieuses** (chez le magicien), et d'autres non encore nommées (le document source indique "etc.") ; plus une ressource **argent** générique. Dépensées pour : améliorer les decks, étendre les possibilités de deckbuilding, les avantages de début de run, et les bonus rencontrables en run. Chaque villageois peut être upgradé plusieurs fois pour débloquer plus d'options dans sa spécialité ; réussir une quête d'amélioration fait évoluer son échoppe/skin.

---

## Level Design Framework

### Level Types

- **Village (hub) :** déplacement physique actif d'un aventurier (pas de point-and-click contemplatif) entre les maisons des villageois, initialement délabrées/vides, débloquées et upgradées au fil de la progression.
- **Carte de quêtes :** structure à embranchements menant à un boss (génération non détaillée — voir Procedural Generation).
- **Combats :** 2 à 5 tours pour un combat normal ; MVP = 3 combats avec 5 types de monstres différents.
- **Événements :** mentionnés dans la boucle de run du brief mais non détaillés dans les sources actuelles. `[NOTE FOR DESIGNER]`

### Level Progression

**Quêtes de classe :** imposent de désigner au moins 1 héros "chef de groupe", puis liberté de choisir les 3 autres. **Quêtes narratives :** peuvent imposer plusieurs héros spécifiques selon la narration, en échange de rebondissements narratifs pendant le run. **Quêtes spéciales :** aucun chef imposé, liberté totale de composition. **Quêtes multiples/liées :** demandent de coordonner plusieurs groupes sur plusieurs runs différents pour accomplir des actions simultanées sur la carte.

---

## Art and Audio Direction

### Art Style

Designs de héros "ultra classiques, stéréotypés et reconnaissables" — choix assumé au service de l'accessibilité par la familiarité (monde heroic fantasy AD&D). Mise en scène de combat : ennemis grands, de face (façon *Final Fantasy Mystic Quest*) ; troupe du joueur en ligne, vue de dos (façon *Knight of Pen & Paper*). Le village démarre visuellement à l'abandon et se régénère visuellement à mesure que les villageois sont débloqués/upgradés. Besoins d'asset MVP : voir Technical Specifications.

### Audio and Music

Non définie dans les sources actuelles. `[NOTE FOR DESIGNER] Signalé comme trou ouvert dans le brief (Risks & Open Questions) — à ne pas combler par supposition.`

---

## Technical Specifications

### Performance Requirements

Non spécifiées par le porteur de projet à ce stade. `[NOTE FOR DESIGNER] Cible de performance, moteur et contraintes de certification relèvent de gds-game-architecture, pas de ce document — à lever avant cette phase suivante.`

### Platform-Specific Details

PC (souris et manette) et smartphone (tactile), à parité dès le départ — argument explicite du porteur de projet : un jeu de cartes sans exigence de dextérité doit être aussi confortable sur les deux, ergonomie tactile pensée dès la conception plutôt qu'adaptée après coup (voir Controls and Input).

### Asset Requirements

**MVP (Mois 1) :** 4 skins de héros (Guerrier, Clerc, Mage, Assassin) avec animations idle (2 frames), action, coup reçu, KO ; 5 designs de monstres ; art du village en état "abandonné" de départ. **Cible long terme :** jusqu'à 40 skins de héros, ~480 illustrations de cartes, art du village évolutif par villageois upgradé.

---

## Development Epics

### Epic Structure

| # | Épic | Pilier(s) servis | Statut |
|---|------|-------------------|--------|
| 1 | Boucle de combat centrale (énergie individuelle, deck/main/défausse, ciblage, télégraphie ennemie) | 1, 2 | Prototypé (3 prototypes de code existants) |
| 2 | Identité de classe (4 héros MVP, Pouvoir de Classe, Transcendance, cartes de classe libres) | 4 | Prototypé partiellement — le verrouillage de carte, le Clerc, et le nom "Voleur" du proto sont désormais en divergence avec le canon |
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
- Les 36 héros restants au-delà des 4 du MVP (cible 40), les ~476 cartes restantes (cible ~480), les ~640 améliorations.
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
- **Taille de deck du prototype (temporaire, pas le canon final) :** 18 cartes, 1 exemplaire de chacune des 18 cartes du MVP (génériques + Départ + Avancé confondus). Scope explicitement limité au prototype pour permettre de tester le système complet tout de suite ; le nombre de copies pour les versions ultérieures reste ouvert.
- Coût de la carte Assassin "Stratégie" confirmé à 1 (notée "—" dans le tableur source, clarifié directement par le porteur de projet).
- Coûts de cartes du Mage (2 à 8) confirmés intentionnels, aucune correction nécessaire.
- PV de départ du Guerrier fixé à 18 (aligné sur les 2 prototypes les plus récents).
- **Nom canonique du jeu : "Hero Card Game"** — tranché par le porteur de projet. Les variantes "Heroic Card Game" (ancien titre du GDD source) et "HERO CARD GAME" (nom de dossier/projet BMad, casse infrastructure uniquement) sont abandonnées comme noms du jeu ; le nom de dossier/dépôt technique reste inchangé, c'est une question d'infrastructure distincte du titre créatif.
- **Pas de plafond d'énergie** — l'énergie individuelle par héros se banque indéfiniment si non dépensée. Les 3 prototypes de code (plafond à 3) sont désormais en divergence avec le canon et à corriger.
- **Contrôles : séquence à 3 taps confirmée** comme schéma canon (carte → héros → cible), le glisser-déposer des deux premiers prototypes est abandonné.
- **Le Paladin remplace le Clerc dans le roster MVP** (Guerrier, Paladin, Mage, Assassin).
- **Nom de classe canonique : Assassin**, pas "Voleur" — le prototype `proto-deck-main-defausse` a dérivé sur ce nom, à corriger.
- **Verrouillage de carte par classe abandonné** : toute carte de classe est jouable par tout héros ayant l'énergie requise. Le mécanisme de synergie réel est la Transcendance (voir Character Selection), pas une restriction d'accès. Referme la question ouverte débattue en `bmad-party-mode` — c'est bien la piste "libre" qui était juste, affinée par la Transcendance plutôt que par un simple bonus de passif.

**Répercussions sur le code du prototype, signalées mais non appliquées** (accord de travail : jamais de modification de code sans confirmation) :
- `MAX_ENERGY = 3` codé en dur dans les 3 prototypes — à retirer (pas de plafond).
- Verrouillage strict des cartes spéciales par classe, codé dans `proto-deck-main-defausse` (champ `owner` bloquant) — à transformer en association cosmétique + logique de Transcendance.
- Classe "Voleur" nommée ainsi dans le code — à renommer "Assassin".
- Le Clerc et sa carte "Soin" existent dans les 3 prototypes — à remplacer par le Paladin (cartes de classe maintenant définies : Rempart, Provocation, Clairvoyance, Lumière divine).
- Les 3 prototypes n'ont ni ressource Défense, ni statuts (Saignements, Esquive en stacks, Incapacité, Vulnérabilité, Camouflé) — tout le système de combat carte par carte doit être réécrit pour correspondre à la vraie liste de 18 cartes, pas seulement les 4 classes/coûts renommés.
- Coût de "Coup direct" : 1 dans le code actuel, 0 dans le canon. "Esquive" (annulation totale, coût 1) n'existe plus — remplacée par "Encaisser" (gain de 4 défense, coût 0) et le statut Esquive à stacks (accordé par certaines cartes, ex. Image miroir).

**Questions ouvertes signalées mais explicitement non tranchées ici (à la demande du porteur de projet) :**
- Justification narrative du retour au village après défaite (façon *Dead Cells*).
- Nom du mécanisme de rétention/défausse de fin de tour.
- Direction sonore, entièrement à définir.
- Rythme exact du loot (pourcentages de drop).
- Carte de classe du Paladin (voir Primary Mechanics).
- Commandes UI pour le changement de ligne du Paladin et la conservation de carte du Mage (voir Character Selection → Pouvoir de Classe).
- Condition exacte du bonus de dégâts du Camouflé de l'Assassin (formulation source ambiguë).

**Dépendances de contenu :**
- Le tableur des classes ne documente pour l'instant qu'1 classe sur les 40 héros prévus (Paladin) — mais son Pouvoir de Classe et sa Transcendance sont maintenant définis directement par le porteur de projet, indépendamment du tableur. La dépendance bloquante porte sur les 36 héros restants, pas sur le Paladin du MVP.
- Le mécanisme de génération de la carte de quêtes (aléatoire/semi-aléatoire/manuel) n'est pas spécifié.
- Le système de deckbuilding déblocable au village (mentionné dans le document source parmi les dépenses de ressources possibles) n'est pas détaillé.
