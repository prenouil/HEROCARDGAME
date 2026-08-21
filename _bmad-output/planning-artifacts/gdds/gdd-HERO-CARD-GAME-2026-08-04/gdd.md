---
title: Hero Card Game - Game Design Document
game_type: Roguelike / Card Game (hybride)
platforms: PC (souris, manette), smartphone (tactile)
created: 2026-08-04
updated: 2026-08-25
status: draft
---

# Hero Card Game - Game Design Document

**Author:** Zgrubulu
**Game Type:** Roguelike / Card Game (hybride)
**Target Platform(s):** PC (souris, manette), smartphone (tactile), à parité

---

## Executive Summary

### Core Concept

Deck-building roguelike. Le joueur mène une troupe de 4 aventuriers (choisis parmi une collection qui grandit au fil des runs) à travers une carte de quêtes à embranchements jusqu'à un combat de boss, puis retourne au village pour dépenser les ressources accumulées avant de relancer un run. *(Révisé 2026-08-24 — voir `decision-log.md` : l'énergie est devenue une réserve commune au groupe, remise à un niveau fixe chaque tour, et la Transcendance a été retirée. Ce qui reste individuel : chaque carte n'appartient qu'à UN seul aventurier — jamais interchangeable entre héros —, et le Mage/l'Assassin possèdent chacun une ressource propre en plus de l'énergie commune (Mana, Discrétion). Un aventurier peut désormais agir plusieurs fois par tour, sans limite de nombre d'actions.)*

### Target Audience

Joueurs de jeux de cartes roguelike qui recherchent un système lisible plutôt qu'une originalité mécanique : règles intuitives sans courbe d'apprentissage cachée, monde heroic fantasy classique (AD&D — guerrier, mage, voleur, paladin ; gobelins, squelettes, trolls) comme repère de compréhension immédiate, cartes et VFX explicites. Points d'ancrage : fans de *Pokémon* (ampleur de la collection), joueurs de *Sims*/*Animal Crossing* (le village), JRPGistes (collecte de personnages façon *Suikoden*, déblocages façon *FF7*).

### Unique Selling Points (USPs)

1. **Chaque carte appartient à un seul aventurier, jamais interchangeable** — la sélectionner assigne automatiquement son propriétaire ; la décision tactique porte sur *quelle carte résout la situation*, pas sur *qui a encore de l'énergie disponible* (renversé le 2026-08-24, remplace l'ancien pilier "énergie individuelle" — voir Assumptions and Dependencies).
2. **Les ennemis télégraphient leurs actions et leur cible** avant que le joueur ne joue — élimine la punition perçue comme injuste (réponse directe à *Slay the Spire*).
3. **Déblocage significatif et permanent garanti à chaque run** — élimine le vide ressenti une fois l'objectif principal atteint.
4. **Troupe de 4 héros à identité individuelle non interchangeable** (PV et cartes propres — voir pilier 1 — plus une ressource de classe dédiée pour le Mage et l'Assassin ; les ennemis ciblent un héros précis, pas "le groupe").

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

1. **Chaque carte appartient à un seul aventurier, jamais interchangeable.** *(Renversé le 2026-08-24 — remplace "énergie individuelle par aventurier, pas un pool global", voir Assumptions and Dependencies pour l'historique complet du renversement.)* L'énergie est désormais une réserve commune au groupe (remise à un niveau fixe chaque tour), mais chaque carte de la main n'a qu'un seul propriétaire possible — sélectionner une carte assigne automatiquement l'aventurier qui va la jouer, sans jamais laisser le joueur choisir un autre héros pour la jouer à sa place. Retirer ce pilier ramène le deck à un pool de cartes interchangeables jouées par n'importe quel héros disponible — perd la lecture tactique "quelle carte, donc quel aventurier" qui différencie le jeu. `[NOTE FOR DESIGNER]` Cette formulation est une inférence directe du renversement de code confirmé par le porteur de projet, pas le résultat d'un nouveau passage de pressure-test ("si on coupe ce pilier, que reste-t-il ?") mené avec lui en direct — à repasser ensemble si la reformulation ne correspond pas exactement à son intention.
2. **Les ennemis annoncent leurs actions et leur cible à l'avance.** Retirer ce pilier réintroduit le chaos perçu comme injuste de *Slay the Spire*, la frustration n°1 identifiée dans le comparatif concurrentiel.
3. **Chaque run débloque quelque chose de significatif et permanent.** Retirer ce pilier réintroduit le vide de fin de run ("pourquoi relancer ?"), frustration n°2 identifiée.
4. **Une troupe de 4 héros à identité individuelle et non interchangeable.** PV propres à chacun, cartes propres (voir pilier 1), et une ressource de classe dédiée pour 2 des 4 classes (Mana du Mage, Discrétion de l'Assassin — voir Primary Mechanics) ; les ennemis ciblent un héros précis, jamais "le groupe" en abstrait. Retirer ce pilier réduit la troupe à un skin cosmétique sur un deck générique — perd l'investissement individuel qui motive la collection de 40 héros.

*(Le pilier initial du brief "un monde familier plutôt qu'original" a été pressure-testé et rétrogradé : c'est une direction de contenu/vision, pas un pilier de gameplay — il ne pilote aucune décision mécanique. Il reste documenté dans Target Audience et Art Style.)*

### Core Gameplay Loop

**Boucle de run (niveau macro) :**
Choisir 4 aventuriers parmi les débloqués (1-2 parfois imposés selon le type de quête) → sélectionner une quête sur la carte → traverser combats et événements → vaincre un boss → débloquer une récompense significative et permanente → retour au village pour dépenser les ressources accumulées → relancer un run.

**Retour au village (confirmé) :** automatique et instantané (« Pierre de Foyer »), sans retraverser le chemin. Les éléments temporaires du run (deck, potions, objets spécifiques) sont perdus au retour — seules les ressources de village sont ramenées (« Transport par Tunnel des Taupes »). Impossible d'enchaîner directement sur une autre quête sans repasser par le village et réinitialiser son deck — référence explicite du porteur de projet à la mort inéluctable de *Slay the Spire* face à l'Architecte en fin de run : le même type d'artifice est recherché ici.

**Boucle de combat (sous-boucle, imbriquée dans "traverser combats") — réécrite le 2026-08-24, voir Assumptions and Dependencies :**
Début de tour (la réserve d'énergie commune est remise à un niveau fixe ; la main est complétée jusqu'à 5 cartes ; chaque ennemi vivant télégraphie son action et sa cible) → phase joueur (le joueur sélectionne une carte de sa main — son propriétaire est assigné automatiquement, jamais un choix manuel — puis désigne une cible si la carte en a besoin ; répétable autant de fois que l'énergie commune le permet, sans limite de nombre d'actions par aventurier) → fin de tour (les cartes non jouées de la main sont défaussées) → phase ennemie (chaque ennemi résout son action telegraphée contre sa cible déclarée) → tour suivant, jusqu'à victoire ou défaite du combat.

**Règle "un héros, une carte par tour" — abandonnée (2026-08-24).** Un aventurier peut désormais recevoir et jouer plusieurs cartes dans le même tour, sans autre limite que la réserve d'énergie (et, pour le Mage, sa Mana). L'ancienne exception "Clairvoyance" n'a plus d'objet : cette carte garde son effet (pioche + gain d'énergie) mais ne "contourne" plus rien, puisque la règle qu'elle contournait n'existe plus.

### Win/Loss Conditions

- **Victoire de combat :** tous les ennemis à 0 PV → passage au combat/événement suivant.
- **Défaite de combat :** tous les héros de la troupe à 0 PV → le run s'arrête, le joueur est renvoyé au village.
- **Égalités** (victoire et défaite au même tour) : à trancher au cas par cas — non spécifié plus précisément dans les sources. `[NOTE FOR DESIGNER]`
- **Victoire de run :** boss de fin de run vaincu → épilogue narratif + déblocage majeur + ressources de village importantes. *(Implémentation prototype actuelle du combat de boss lui-même, distincte de cette vision long terme : voir "Boss de run borné — Homme Arbre" sous Roguelike / Card Game Specific Design.)*
- **Mission Secours (optionnelle, confirmée par le document source) :** en cas de défaite, une quête spéciale apparaît temporairement, permettant à une autre équipe de tenter de rejoindre l'équipe vaincue. Si elle y parvient, le run vaincu reprend dans l'état où il a été perdu ; sinon, il est perdu définitivement.
- `[NOTE FOR DESIGNER]` **Justification narrative du retour au village après défaite** (résurrection façon *Dead Cells* — malédiction, réincarnation) : demandée explicitement par le porteur de projet mais **non tranchée à sa propre demande** (voir Risks du brief). Ne pas inventer de réponse ici — décision à prendre séparément, probablement au passage `gds-create-narrative`.

---

## Game Mechanics

### Primary Mechanics

**Énergie (réécrit le 2026-08-24, renversement complet — voir Assumptions and Dependencies) :** réserve GLOBALE unique, commune aux 4 aventuriers (il n'existe plus de réserve individuelle par héros). Remise à un niveau FIXE de 3 au tout début de chaque tour — pas un plancher : que la réserve soit plus haute ou plus basse que 3 à la fin du tour précédent, elle retombe toujours exactement sur 3. Certaines cartes (Clairvoyance, Dans les ombres) peuvent faire gagner de l'énergie EN COURS DE TOUR, sans plafond à ce moment précis — mais ce gain ne survit jamais au changement de tour. Ceci remplace et referme la décision antérieure "pas de plafond, énergie individuelle banquée indéfiniment" (actée 2026-08-06/09) : c'est un nouveau design, pas une correction de bug.

**Concentration — mécanique retirée (2026-08-20/24).** L'action générique "place une carte sans résoudre son effet, gagne 1 énergie à la place" n'existe plus, sous aucune forme.

**Ressources de classe (nouveau, 2026-08-24) :** en plus de l'énergie commune, 2 des 4 classes possèdent une ressource propre, jamais partagée avec le reste du groupe :
- **Mana (Mage)** : démarre à 2. Ne se régénère JAMAIS automatiquement (ni par tour, ni entre deux combats) — seules des cartes peuvent l'augmenter. Certaines cartes du Mage exigent un coût en Mana EN PLUS de leur coût en énergie (les deux doivent être couverts pour être jouées) — voir Card Types and Effects.
- **Discrétion (Assassin)** : de 0 à 10 (plafonnée). +1 quand un AUTRE aventurier de la troupe (jamais un ennemi) joue une carte ; +5 si l'Assassin lui-même termine un tour sans avoir joué aucune carte. Revient à 0 dès que l'Assassin joue une carte lui-même. À 10, l'Assassin devient Camouflé (voir ci-dessous). Chaque point de Discrétion réduit aussi de 10% la probabilité relative que l'Assassin soit choisi comme cible par un ennemi tirant au hasard (hors Camouflé complet, qui est une exclusion totale).

**Défense (nouvelle ressource, confirmée par la liste de cartes du porteur de projet) :** en plus des PV, un héros peut accumuler de la Défense — un pool qui absorbe les dégâts entrants. Remplace le modèle binaire "Esquive annule tout" documenté précédemment à partir des prototypes de code. `[NOTE FOR DESIGNER] La formule exacte d'absorption (soustraction un-pour-un aux dégâts reçus, ou autre) n'est pas précisée dans la source — à confirmer avant implémentation.`

**Deck, main et défausse (réécrit le 2026-08-24 — plus de cartes génériques, voir Run Infini pour le détail complet) :** chaque classe possède désormais 6 cartes propres (3 "Départ" + 3 "Avancé", aucune carte partagée entre classes — voir Card Types and Effects). Le deck de départ d'un run est construit à partir des 3 cartes "Départ" de chacune des 4 classes sélectionnées = **12 cartes**, 1 exemplaire de chacune. Les cartes "Avancé" s'ajoutent au deck par le draft de fin de combat (voir Run Infini), à raison d'1 carte choisie parmi 3 après chaque victoire. Main commune de 5 cartes, piochée en début de tour jusqu'à ce seuil. Les cartes non jouées en fin de tour sont défaussées. Quand le deck est vide, la défausse est remélangée en nouveau deck.

**Propriété des cartes — renversement majeur (2026-08-24), voir Assumptions and Dependencies :** chaque carte appartient désormais à UN SEUL aventurier, déterminé par sa classe — **jamais jouable par un autre héros**, même s'il a l'énergie requise. Sélectionner une carte dans sa main assigne AUTOMATIQUEMENT son propriétaire (plus aucun choix manuel de "quel héros la joue") ; si le propriétaire ne peut pas la jouer (mort, énergie/mana insuffisants), la sélection est simplement refusée. Ceci renverse la décision "verrouillage de carte par classe abandonné" actée le 2026-08-04 (voir Assumptions and Dependencies pour l'historique) et rend caduque toute la mécanique de Transcendance, retirée dans le même mouvement — voir Character Selection. Liste complète (palier, coût, catégorie, effet exact) des 24 cartes (6 par classe × 4 classes) dans Card Types and Effects, ci-dessous.

**Mots-clés / statuts (mis à jour 2026-08-24) :** Saignements (dégâts continus, en stacks — ex. "Saignements 3"), Esquive (stacks d'esquive accordés par certaines cartes), Incapacité (-25% dégâts infligés par la cible affectée, décroît de 1 par tour), Vulnérabilité (+25% dégâts reçus par la cible affectée, décroît de 1 par tour — désormais côté héros ET ennemis, un bug faisait que ça ne décroissait jamais côté héros), Puissance (+25% dégâts physiques infligés par stack, décroît de 1 par tour). **Camouflé — devenu un état mécanique réel (2026-08-24) :** un ÉTAT BINAIRE (présent/absent, jamais un compteur, jamais accordé directement par une carte) — le SEUL chemin vers Camouflé est d'atteindre 10 Discrétion (voir Ressources de classe ci-dessus, Assassin uniquement). Un héros Camouflé est réellement exclu du ciblage aléatoire de la télégraphie ennemie tant qu'il reste au moins un autre allié vivant non-Camouflé pour le "couvrir" (avant le 2026-08-24, ce statut était purement décoratif, jamais câblé dans le ciblage réel — corrigé au passage). Se termine dès que son porteur joue une carte, ou dès qu'il ne reste plus d'allié non-Camouflé vivant.

**Ciblage :** ennemi unique, tous les ennemis (AoE), soi-même, allié — selon le type de carte. Certaines actions ennemies sont ciblées sur un héros précis et affichées comme telles ("vise [Nom]"), d'autres sont aléatoires.

**Télégraphie ennemie :** chaque ennemi vivant tire indépendamment, en début de tour, une action pondérée (ex. Gobelin Maraudeur : Griffure 4 dégâts poids 2, Charge Brutale 7 dégâts poids 1) et une cible parmi les héros vivants ; affichée avec icône, nom, valeur et cible avant que le joueur ne joue.

**Retenir/défausser manuellement :** une carte de la main peut être glissée à gauche de l'écran pour être retenue, ou à droite pour être défaussée volontairement.

**Durée de combat :** 2 à 5 tours pour un combat normal ; plus long pour les boss d'étape et de fin de run (durée exacte non spécifiée). `[NOTE FOR DESIGNER]`

### Controls and Input

*(Réécrit le 2026-08-09 : un spike de ciblage dynamique, testé en jeu et validé par le porteur de projet, remplace le Drag & Drop comme cible de design finale. Voir `decision-log.md` pour la décision et son origine — spike inspiré de *Slay the Spire*, proposé en réponse au retour du porteur de projet : "notre jeu est une série de clics peu engageant".)*

**Design cible (jeu final) — ciblage dynamique à la flèche (flux simplifié le 2026-08-20/24, voir Assumptions and Dependencies) :** la carte ne suit pas la souris (contrairement au Drag & Drop précédemment documenté ci-dessous, abandonné) — c'est une ligne dessinée entre elle et le curseur qui porte l'intention du joueur. Il n'y a plus que 2 temps, pas 3 : le choix de l'aventurier a disparu (chaque carte n'a qu'un seul propriétaire possible, voir Primary Mechanics → Propriété des cartes).
1. **Survol d'une carte en main :** elle grossit immédiatement (pas de délai, contrairement à l'infobulle standard).
2. **Clic sur la carte :** elle se sélectionne ET assigne automatiquement son propriétaire dans le même geste — refusé sans effet si le propriétaire ne peut pas la jouer (mort, énergie/mana insuffisants). L'aventurier propriétaire grossit et pulse en boucle tant que sa carte attend une résolution.
3. **Flèche, de l'aventurier propriétaire vers la cible survolée (SI la carte a besoin d'une cible) :** courbe légère avec un balancement continu (façon chaîne qui pend), composée de petits maillons plutôt qu'un trait droit. Couleur : verte si la cible survolée est valide (ennemi ou allié selon le type de carte), rouge sinon. Un clic sur une cible invalide **annule tout** — retour à la main, pas de retour en arrière d'un cran. Les cibles `self`/`all-enemies` n'ont pas de flèche : la carte se résout dès l'étape 2.

**Mode alterné (prototype) — séquence à taps :** conservée dans le code comme second mode, basculable à tout moment. Réduite à 2 temps pour la même raison que ci-dessus (plus de choix d'aventurier) :
1. Toucher/cliquer une carte de la main → sélection et assignation automatique du propriétaire, même règle qu'en mode flèche.
2. Toucher/cliquer la cible valide → surbrillance des cibles éligibles selon le type de ciblage de la carte ; les cibles `self` et `all-enemies` se résolvent automatiquement sans ce second temps.

Annulation dans ce mode : recliquer la carte déjà sélectionnée (pas de retour en arrière automatique sur cible invalide, contrairement au mode flèche). `[NOTE FOR DESIGNER] Équivalent tactile des deux modes (survol n'existe pas nativement au toucher) encore à définir — le prototype actuel n'a été testé qu'à la souris.`

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

- ~~**Transcendance**~~ **— retirée le 2026-08-24** (voir Character Selection). Le Pouvoir de Classe, qui l'accompagnait jusqu'au 2026-08-06, avait déjà été retiré le 2026-08-09. Il n'existe plus aucun bonus/malus lié à la classe du héros qui joue une carte — le mécanisme de synergie individuelle est désormais la propriété fixe de chaque carte (voir Primary Mechanics → Propriété des cartes, et Character Selection).
- **Rareté des cartes :** commune, rare, légendaire — la probabilité augmente avec la progression du run. Un taux exact n'est pas spécifié. `[NOTE FOR DESIGNER]`
- **Cartes épiques :** spécifiques à une ou plusieurs classes, s'intègrent temporairement au deck pour la durée du run (distinctes des 3 paliers de rareté ci-dessus — c'est un type de carte, pas un palier de rareté).
- **Loot complémentaire :** potions, objets magiques (effets puissants et/ou insolites), ressources de village.
- **Risque/récompense (Astronome) :** voir Difficulty Modifiers.

### Character Selection

**MVP (Mois 1) :** 4 héros — Guerrier, Paladin, Mage, Assassin *(le Paladin remplace le Clerc initialement prévu — décision du porteur de projet)*. Chacun : 1 skin avec animations idle (2 frames), action, coup reçu, KO ; 6 cartes propres, jamais partagées avec les autres classes (voir Card Types and Effects). Chaque aventurier porte aussi un passé, un but dans la vie, et des interactions particulières avec les éléments du jeu — contenu narratif, à développer avec `gds-create-narrative` (`needs_narrative` déjà signalé, voir Finalize).

**Cible long terme :** 40 héros débloquables au total (4 au départ, 36 à débloquer). Chaque héros possède au maximum **15 cartes propres** : 5 "cartes de départ" (1 initiale + 4 à débloquer — 1 seule utilisée dans le deck au lancement d'un run) et 10 "cartes spéciales" (2 initiales + 8 à débloquer, toutes rencontrables au loot une fois débloquées), soit 12 cartes à débloquer par héros. Sur 40 héros : **~480 cartes à débloquer** (12×40) pour **~600 cartes distinctes au total** sur l'ensemble du roster (15×40). *(Le compteur "améliorations de passifs" — 80 avec Pouvoir de Classe + Transcendance, retombé à 40 avec la Transcendance seule le 2026-08-09 — tombe maintenant à **0** : plus aucun système de passif par héros, voir la note Transcendance ci-dessous. Séparément, corrige le chiffre "~640 améliorations" utilisé jusqu'au 2026-08-06 pour les cartes — erreur de transcription du document source, 15×40 fait 600, pas 640.)* Ce périmètre complet est délibérément hors du MVP — voir Out of Scope.

**Contrôle en village :** n'importe quel aventurier de la troupe active peut être déplacé physiquement pour interagir avec les PNJ — pas limité à un "chef de groupe" fixe (voir Level Design Framework pour le rôle du chef de groupe dans le choix des quêtes).

*(Section Pouvoir de Classe retirée le 2026-08-09 — décision radicale du porteur de projet : « ça ne marche pas pour l'instant, je les remettrai peut-être plus tard, repensés. » Couvrait jusque-là un pouvoir par classe (coups gratuits du Guerrier, réanimation du Paladin, garder une carte pour le Mage, Camouflage + Puissance en Concentration pour l'Assassin).)*

#### Transcendance — retirée (2026-08-24)

**La Transcendance a été entièrement retirée, dans le même mouvement que le renversement de la propriété des cartes** (voir Primary Mechanics → Propriété des cartes, et Assumptions and Dependencies pour l'historique complet). Il n'existe plus aucun bonus/malus lié à la classe du héros qui joue une carte — la table par classe (Guerrier +50% "épée", Paladin +50% "bouclier"/"soin", Mage -2 coût "sort", Assassin Incapacité+Vulnérabilité sur "épée") n'a plus d'objet et est retirée de ce document.

**Ce qui remplace son rôle de synergie :** la Transcendance récompensait le fait de jouer une carte sur son propre aventurier plutôt que de restreindre l'accès — l'association carte↔aventurier restait alors "purement cosmétique/lore" (voir la question résolue le 2026-08-04 dans Assumptions and Dependencies). C'est maintenant l'inverse : chaque carte a un propriétaire FIXE et UNIQUE (déterminé par sa classe), et cette association redevient une contrainte de gameplay à part entière, pas juste un repère de lore. `[NOTE FOR DESIGNER]` Aucun bonus de synergie individuel (façon Transcendance) n'existe plus pour distinguer un héros d'un autre de la même classe une fois le roster élargi à 40 — à retravailler si ce différenciateur reste souhaité pour la cible long terme, question non tranchée par le porteur de projet à ce stade.

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

*(Rééquilibrage complet 2026-08-24 : refonte totale du tableur de cartes par le porteur de projet, sur la branche Proto_manaGeneral — passage de 18 à **24 cartes**. Les cartes génériques "Coup direct"/"Encaisser" disparaissent : chaque classe reçoit désormais sa propre copie (même nom affiché, sauf le Mage — voir plus bas), plus une 3ᵉ carte de départ propre à la classe. Chaque classe compte donc **6 cartes propres, jamais partagées** : 3 "Départ" + 3 "Avancé" — voir aussi Character Selection, où le rôle de synergie individuelle auparavant tenu par la Transcendance (retirée) est repris par cette propriété fixe de carte. Décision journalisée dans `decision-log.md`.)*

La table ci-dessous est la liste **MVP** telle qu'implémentée dans le prototype (24 cartes fixes, 6 par héros). Elle est une instanciation simplifiée de la structure long terme décrite en Character Selection (5 "cartes de départ" + 10 "cartes spéciales" par héros, débloquées progressivement sur les 40 héros) — les deux ne se contredisent pas : celle-ci est le sous-ensemble jouable dès aujourd'hui, l'autre la cible complète du jeu fini.

| Carte | Classe | Palier | Coût | Cible | Catégorie | Effet | Effet amélioré ("+", feu de camp) |
|---|---|---|---|---|---|---|---|
| Coup direct | Guerrier | Départ | 1 én. | Ennemi | épée | Inflige 4 dégâts. | Inflige 6 dégâts. |
| Encaisser | Guerrier | Départ | 1 én. | Allié | bouclier | L'allié gagne 4 défense. | L'allié gagne 6 défense. |
| Coup de taille | Guerrier | Départ | 1 én. | Tous les ennemis | épée | Inflige 2 dégâts à tous les ennemis. | Inflige 3 dégâts à tous les ennemis. |
| Coup d'estoc | Guerrier | Avancé | 1 én. | Ennemi | épée | Inflige 4 dégâts. Inflige 4 dégâts de plus si la cible a de la défense. | Inflige 6 dégâts. Inflige 6 dégâts de plus si la cible a de la défense. |
| Coup mortel | Guerrier | Avancé | 1 én. | Ennemi | épée | Inflige 4 dégâts. Si tue sa cible, la carte retourne en main (au lieu de la défausse). | Inflige 6 dégâts (reste de l'effet inchangé). |
| Riposte | Guerrier | Avancé | 3 én. | Soi-même | bouclier + épée | Si l'aventurier est la cible de l'attaque ennemie, annule cette attaque et inflige 4 dégâts. | Inflige 6 dégâts. |
| Coup direct | Paladin | Départ | 1 én. | Ennemi | épée | Inflige 4 dégâts. | Inflige 6 dégâts. |
| Encaisser | Paladin | Départ | 1 én. | Allié | bouclier | L'allié gagne 4 défense. | L'allié gagne 6 défense. |
| Rempart | Paladin | Départ | 1 én. | Allié | bouclier | L'allié ciblé et le Paladin gagnent chacun 4 défense. | L'allié ciblé et le Paladin gagnent chacun 6 défense — **montée désormais symétrique** (corrigé le 2026-08-24 ; l'ancienne version 5/6 asymétrique était une erreur de tableur). |
| Provocation | Paladin | Avancé | 2 én. | Ennemi | bouclier | L'ennemi ciblé change sa cible pour le Paladin. Gagne 6 défense. | Gagne 9 défense. |
| Clairvoyance | Paladin | Avancé | 0 én. | Soi-même | sort | Pioche 1 carte. Gagne 1 énergie. | Pioche 2 cartes. Gagne 1 énergie. |
| Lumière divine | Paladin | Avancé | 2 én. | Soi-même (tous alliés) | bouclier + soin + sort | Tous les alliés gagnent 4 défense et 4 PV. | Tous les alliés gagnent 6 défense et 6 PV. |
| Main de feu | Mage | Départ | 1 én. + 0 mana | Ennemi | épée, feu | Inflige 2 dégâts magiques de feu. Gagne 1 mana. | Inflige 3 dégâts magiques de feu. Gagne 1 mana. |
| Barrière | Mage | Départ | 1 én. + 0 mana | Allié | bouclier | L'allié gagne 2 défense. Gagne 1 mana. | L'allié gagne 3 défense. Gagne 1 mana. |
| Missile magique | Mage | Départ | 1 én. + 1 mana | Ennemi | sort, distance | Inflige 8 dégâts magiques. | Inflige 12 dégâts magiques. |
| Image miroir | Mage | Avancé | 1 én. + 1 mana | Soi-même | sort, défense | Gagne Esquive 2. | Gagne Esquive 3. |
| Tornade de feu | Mage | Avancé | 1 én. + 2 mana | Tous les ennemis | sort, distance, feu | Inflige 8 dégâts magiques de feu à tous les ennemis. | Inflige 12 dégâts magiques de feu à tous les ennemis. |
| Boule de feu | Mage | Avancé | 2 én. + 3 mana | Ennemi | sort, distance, feu | Inflige 20 dégâts magiques de feu. | Inflige 30 dégâts magiques de feu. |
| Coup direct | Assassin | Départ | 1 én. | Ennemi | épée | Inflige 4 dégâts. | Inflige 6 dégâts. |
| Encaisser | Assassin | Départ | 1 én. | Allié | bouclier | L'allié gagne 4 défense. | L'allié gagne 6 défense. |
| Stratégie | Assassin | Départ | 0 én. | Ennemi (conditionnel) | épée + bouclier | S'il est ciblé par un ennemi, gagne 4 défense ; sinon, inflige 4 dégâts. | Gagne 6 défense ; sinon inflige 6 dégâts. |
| Blessure ouverte | Assassin | Avancé | 2 én. | Ennemi | épée | Inflige 6 dégâts. Inflige Saignements 3 **si l'Assassin est Camouflé** (avant 2026-08-24 : inconditionnel). | Inflige 9 dégâts. Saignements 4 si Camouflé. |
| Assassinat | Assassin | Avancé | 1 én. | Ennemi | épée | Si Camouflé : inflige 12 dégâts et perd le Camouflage. Sinon : gagne Discrétion 2 et Puissance 2, la carte retourne au sommet du deck. | Si Camouflé : inflige 18 dégâts. Sinon : Discrétion 3, Puissance 3. |
| Dans les ombres | Assassin | Avancé | 1 én. | Soi-même | bouclier | Gagne 4 défense, 1 énergie et Discrétion 3. | Gagne 6 défense, 2 énergie et Discrétion 5. |

**Mage — "Main de feu"/"Barrière" remplacent "Coup direct"/"Encaisser" (2026-08-24) :** seule classe dont les deux cartes de base portent un nom différent des trois autres. **"Main de feu" (ex-"Flamèche", renommée une 2ᵉ fois le 2026-08-24) — renversement de design :** depuis sa création, cette carte infligeait des dégâts physiques/mêlée malgré son nom à thème "feu", un choix volontaire documenté ici même jusqu'à ce renversement (voir `decision-log.md` pour l'entrée qui l'acte explicitement comme une correction, pas un simple ajustement). Elle inflige désormais un vrai dégât de feu — type magique, taguée "feu" — ce qui déclenche à la fois la nouvelle sensibilité au feu de l'Homme Arbre (+50% de dégâts, voir "Boss de run borné — Homme Arbre" ci-dessous) et le blocage de Régénération du Troll des Marais déjà documenté (voir Run Infini → Bestiaire). Dégâts inchangés (2 de base, 3 amélioré). "Barrière" n'est pas concernée par ce changement. Leur seule autre différence vis-à-vis des cartes génériques des autres classes reste le gain de 1 mana à chaque utilisation. `mana_cost = 0` est affiché quand même sur ces deux cartes (pastille de mana visible sur les 6 cartes du Mage, pas seulement les 4 qui en dépensent réellement) — cohérence visuelle, pas une exigence mécanique.

**Coût de Stratégie confirmé à 0** par le porteur de projet (2026-08-06, reconfirmé 2026-08-24) — le tableur refait fait foi.

**Glossaire de mots-clés :** un glossaire de **25 termes** (icône, mot-clé lié, explication ; 23 jusqu'au 2026-08-11, +2 le 2026-08-24 avec Mana et Discrétion) a été fourni par le porteur de projet et implémenté dans le prototype — les mots-clés entre guillemets dans le texte des cartes sont automatiquement remplacés par leur icône (ex. "épée" → ⚔️, "bouclier" → 🛡️, "brut" → 💥, "soin" → 💚) quand le glossaire indique une icône, ou laissés en texte sinon (ex. Esquive, Saignements, Incapacité, Vulnérabilité, Discrétion, Camouflé, Puissance, Pioche, Mana). Une infobulle au survol (1s de délai), déjà en place pour les aventuriers et ennemis, liste désormais aussi les mots-clés présents sur chaque carte avec leurs mots-clés liés et explications. Le mot-clé "soin" (employé par Lumière divine) a été ajouté au glossaire le 2026-08-06 avec une icône (💚, choisie par distinction avec ❤️ de "pv") — la lacune précédemment signalée est comblée. "Mana" a été ajouté au glossaire le 2026-08-24 (voir Primary Mechanics → Ressources de classe).

Catégories confirmées : cartes de classe (palier Départ = deck de run initial, palier Avancé = débloqué), cartes épiques (spécifiques à une ou plusieurs classes, intégration temporaire au deck pendant un run — non détaillées carte par carte à ce stade). Paliers de rareté (au-delà de Départ/Avancé, pour la collection long terme) : commune, rare, légendaire. **Coût du Mage revu à la baisse le 2026-08-24** (1-2 énergie + 0-3 mana, contre 2-8 énergie seule auparavant) — l'ancienne justification "compensé par la Transcendance du Mage (-2 coût de sort)" ne tient plus, la Transcendance étant retirée (voir Character Selection) ; le nouveau coût combiné énergie+mana est la seule contrepartie du surcroît de puissance du Mage.

**"Coup de taille" cible tous les ennemis, sans notion d'adjacence :** confirmé par le porteur de projet (2026-08-06) — la notion de ligne/adjacence entre ennemis est abandonnée à ce stade du prototype, pas seulement simplifiée temporairement.

**Chaque classe a désormais 3 cartes Départ et 3 cartes Avancé (2026-08-24)** — avant cette refonte, chaque classe n'avait qu'une seule carte Départ propre (Coup d'estoc, Rempart, Missile magique, Stratégie) complétée par les 2 génériques ; les génériques ont disparu, remplacées par une copie de classe. **Le Guerrier a en plus échangé les paliers de Coup de taille et Coup d'estoc** (2026-08-24) : Coup de taille (dégâts réduits à 2 par ennemi) est désormais Départ, Coup d'estoc redevient Avancé — l'inverse de la répartition 2026-08-06.

### Run Infini (mode de prototype, implémenté 2026-08-06)

Amélioration du prototype de combat existant (le continue, ne le remplace pas) — implémentée dans `proto-cartes-completes` suite à une session de party mode dédiée aux "nouveaux objectifs". Fonctionnement :

- **Deck de départ (12 cartes, 2026-08-24) :** les 3 cartes "Départ" de chaque classe présente dans le groupe, 1 exemplaire chacune (ex. Guerrier : Coup direct, Encaisser, Coup de taille) — voir Card Types and Effects. *(Avant le 2026-08-24 : 10 cartes, 3 Coup direct + 3 Encaisser génériques + 1 carte Départ par classe ; les génériques ont disparu avec le rééquilibrage complet des cartes.)*
- **Progression :** à la fin de chaque combat gagné, le joueur choisit 1 carte parmi 3 (draft) qui s'ajoute à son deck. Entre deux combats d'un même run, **le deck et les PV des aventuriers persistent** (blessures non soignées d'un combat à l'autre — un héros tombé à 0 PV le reste tant qu'il n'est pas soigné) ; tout le reste repart à zéro à chaque nouveau combat : énergie, Défense, Esquive, Incapacité, Vulnérabilité, Camouflage, Puissance, Saignements. Le run est **infini** — pas encore de condition de victoire ni de récompense de fin de run ; il s'arrête à la défaite (tous les héros à 0 PV), l'écran de fin indiquant le nombre de combats remportés.
- **Difficulté :** chaque combat reçoit un budget fixe, totalement indépendant de l'état du groupe joueur (`20 × 1.22^(N-1)`, croissance exponentielle à +22%/combat — remplace la version linéaire initiale du 2026-08-06, jugée trop lente en playtest ; base relevée et courbe ralentie le 2026-08-09, demande explicite du porteur de projet ; valeurs placeholder, à tester). Le moteur traduit ce budget en un nombre d'ennemis (jusqu'à 4, pour la lisibilité) et leur niveau, tirés dans un bestiaire de 10 types.
- **Bestiaire (10 ennemis, niveau 1, comportement fixe — seules les valeurs scalent avec le niveau, +20 %/niveau) :** Gobelin Maraudeur, Squelette Archer, Troll des Marais (régénération annulée par des dégâts de feu subis pendant la phase joueur), Gobelourd (attaque toujours, dégâts réduits en défense), Loup Enragé, Araignée Venimeuse (dégâts brut + Saignement), Nécromancien Novice (Vulnérabilité 3, pas de dégât direct), Golem de Pierre (ne fait rien sauf s'il est touché pendant la phase joueur, auquel cas il riposte), Bandit Fourbe (cible toujours le héros au moins de PV), Chaman Gobelin (soigne un allié blessé s'il y en a un, sinon attaque). *(+2 ennemis supplémentaires depuis le 2026-08-21, jamais tirés par cette génération aléatoire — voir "Boss de run borné — Homme Arbre" ci-dessous.)*
- **Variance aléatoire :** chaque montant ennemi (dégâts, soin, bouclier, PV max) est tiré dans une fourchette ±20 % autour d'une valeur centrale — le télégraphe affiche toujours le montant réel déjà tiré (jamais la fourchette), qui n'apparaît qu'à titre informatif dans l'infobulle de l'ennemi.
- **Écran de fin de combat :** les 3 cartes du draft apparaissent face cachée, se retournent une par une après 2 s, sont survolables (même infobulle que la main) ; le choix ajoute la carte au deck, les 2 autres sont détruites visuellement. Règles de tirage : pool = génériques + classes présentes dans le groupe ; une carte Départ ne peut être que celle déjà dans le deck ; probabilité de doublon par slot 100 % / 25 % / 50 % ; jamais deux fois la même carte parmi les 3 ; pool de cartes inédites épuisé → retombe simplement sur un doublon.
- **Feu de camp (2026-08-10, voir Système d'amélioration de cartes ci-dessous) :** après le draft, avant le combat suivant — soin partiel de l'aventurier le plus blessé ou amélioration de 2 cartes.
- **"Recommencer" relance le combat en cours**, pas toute la run (mêmes ennemis, mêmes niveaux/PV déjà tirés, même deck) — une sauvegarde de l'état est prise au tout début de chaque combat. Le "Rejouer" affiché sur l'écran de défaite, lui, relance bien une run entière depuis le combat 1.

Hors scope de cette implémentation : le scaling comportemental des ennemis (nouveaux patterns à des paliers de puissance, prévu plus tard) et la récompense de fin de run garantie (pilier 3) — testé via Playwright (chargement sans erreur, boucle combat→draft→combat suivant→défaite jouée sur un run réel).

Mots-clés/statuts : voir Primary Mechanics.

### Système d'amélioration de cartes (feu de camp, implémenté 2026-08-10, revu 2026-08-11)

Deuxième écran de fin de combat, immédiatement après le draft et avant le combat suivant, à chaque combat sans exception — jamais aléatoire dans son apparition, contrairement au draft. Nommé "feuDeCamp" (nom canon choisi par le porteur de projet, repris tel quel dans le code : nom d'écran, nom du flux aléatoire dédié). S'intercale de façon totalement transparente dans la boucle : **ne fait jamais avancer le budget de difficulté** du combat suivant (`20 × 1.22^(N-1)`, voir Run Infini ci-dessus).

Le joueur choisit entre deux options, tirées une seule fois à l'entrée de l'écran (donc déjà déterminées avant même le premier clic — même logique que les 3 cartes du draft) :

1. **Repos (soin/résurrection) :** cible automatiquement l'aventurier le plus blessé en pourcentage de PV manquants. Un aventurier mort compte comme 100 % blessé, donc toujours prioritaire sur un vivant même à 1 PV. Égalité entre plusieurs aventuriers départagée aléatoirement. **Ne rend que 20 % des PV maximum de la cible — jamais un soin complet, y compris pour ressusciter un mort** (décision du porteur de projet, revue à la baisse le 2026-08-11 : posé à 100 % lors de l'implémentation initiale du 2026-08-10, jugé trop généreux). Grisée si personne n'est blessé.
2. **Forge (amélioration de carte) :** tire 2 cartes distinctes au hasard dans tout le deck du joueur (doublons d'une même carte inclus) et les fait passer à leur version "+" (voir la colonne "Effet amélioré" de Card Types and Effects ci-dessus, 24 valeurs alignées sur le tableur du porteur de projet, resynchronisé le 2026-08-24). Le nom affiché est suffixé " +" (ex. "Coup direct" → "Coup direct +"). Une carte déjà améliorée n'est plus jamais retirable — pas de second palier au-delà du "+". Grisée si le joueur possède moins de 2 cartes encore améliorables.

Si les deux options sont grisées simultanément (personne blessé et moins de 2 cartes améliorables), un bouton "Passer" apparaît comme seule issue. Aléatoire résolu par un flux dédié et reproductible (5ᵉ flux de la run, après ceux de la rencontre/du deck/des tours ennemis/du draft), pour rester cohérent avec le reste du système décrit en Assumptions and Dependencies.

Présentation : le portrait réel de l'aventurier (pas une icône) s'affiche en grand sur l'option Repos, avec les PV chiffrés avant/après en plus des barres. Les 2 cartes proposées à l'amélioration s'affichent en pleine face (coût, nom, texte complet), pas en simple titre. Au choix de l'amélioration, les 2 cartes de base et les flèches qui les reliaient à leur version "+" s'effacent en fondu pendant que les cartes améliorées se recentrent dans leur emplacement ; 1 seconde après, le combat suivant démarre.

### Boss de run borné — Homme Arbre (implémenté 2026-08-21, ajusté 2026-08-24)

Premier vrai combat de boss du prototype, harnais pour la cible long terme "boss de fin de run" du pilier 3 (voir Win/Loss Conditions et Development Epics → Epic 4) — accessible de deux façons : le bouton "Tester le boss" au menu principal (combat isolé, héros et deck neufs), et comme 6ᵉ et dernier combat d'un **run borné à 5 combats + 1 boss** (mode distinct du Run Infini par défaut, sélectionné au lancement de la run).

**Composition fixe :** 1 Homme Arbre + 4 Pousses d'Arbre, toujours niveau 1, jamais générée par le budget de difficulté aléatoire du Run Infini — les deux templates portent un indicateur dédié qui les exclut explicitement du tirage aléatoire normal (voir Run Infini → Bestiaire). Rangée d'ennemis toujours dans l'ordre Pousse, Pousse, Homme Arbre, Pousse, Pousse — l'Homme Arbre tombe donc toujours au centre, encadré de 2 Pousses de chaque côté.

**Pousse d'Arbre :** PV bas, un seul coup faible ("Griffure de Ronce").

**Homme Arbre — 3 coups :**
- **"Coup de Branche" :** dégâts élevés sur un héros ciblé au hasard.
- **"Onde Sylvestre" :** dégâts plus faibles à TOUS les héros vivants — nouveau type d'attaque ennemie en zone (jusqu'ici, seules des cartes héros infligeaient des dégâts de zone).
- **"Renaissance Sylvestre" :** ramène les Pousses d'Arbre vaincues à pleine vie — jamais une invocation de nouvelles Pousses, seulement une résurrection de celles présentes depuis le début du combat. Disponible uniquement si au moins une Pousse est morte.

**Équilibrage :** PV et dégâts d'abord divisés par deux (jugé trop fort en playtest), puis les PV de l'Homme Arbre remontés à 80 une fois qu'il a gagné une vraie faiblesse exploitable plutôt que de dépendre d'un plafond de PV bas (voir ci-dessous) ; les Pousses restent à PV réduits, et les dégâts de l'Homme Arbre restent réduits.

**Sensibilité au feu (nouvelle mécanique) :** l'Homme Arbre est FAIBLE AU FEU — tout dégât porté par une carte taguée "feu" (voir Card Types and Effects — Main de feu, Tornade de feu, Boule de feu) lui inflige +50%. Affiché au joueur par une ligne dédiée dans son infobulle ET par une icône badge permanente dans son cadre à l'écran — ce n'est pas un statut temporaire, c'est un trait fixe propre à ce boss précis, toujours visible tant qu'il est vivant.

Sprites IA dédiés générés pour les deux nouveaux ennemis, même pipeline pixel art que le reste du bestiaire (voir Art Style).

**Flux de fin de combat — écart volontaire avec le chemin normal :** gagner CE combat précis (que ce soit via "Tester le boss" ou comme fin d'un run borné) saute entièrement le draft de carte ET l'écran feuDeCamp — un bref écran "Victoire ! / Le Boss est vaincu !" s'affiche puis renvoie directement au menu principal. Gagner un combat normal (non-boss) continue de suivre le chemin habituel draft → feu de camp → combat suivant, inchangé. `[NOTE FOR DESIGNER]` Cet écran de victoire simplifié est un harnais de test, pas encore l'épilogue narratif + déblocage majeur + ressources de village décrits comme cible long terme en Win/Loss Conditions — la récompense de fin de run reste à construire (voir Development Epics → Epic 4).

### Deck Building

Le deck n'est pas construit librement par le joueur avant un run : il est assemblé automatiquement à partir des 4 héros sélectionnés — les 3 cartes de classe "Départ" de chaque héros, 1 exemplaire chacune (voir Card Types and Effects pour la liste complète et Run Infini pour le detail du deck de départ), les cartes "Avancé" s'ajoutant par le draft de fin de combat plutôt que par un déblocage classique dans ce mode de prototype. *(Avant le 2026-08-24 : 2 cartes génériques à 3 exemplaires + 1 carte de classe Départ par héros — les génériques ont disparu du jeu, voir Card Types and Effects.)* `[NOTE FOR DESIGNER] Nombre de copies par carte au-delà du deck de départ non précisé par la source — voir Primary Mechanics.` Le document source mentionne que les upgrades de village peuvent porter sur "les possibilités de deckbuilding" — un système de personnalisation du deck plus poussé est donc envisagé mais non détaillé. `[NOTE FOR DESIGNER]`

### Mana/Resource System

Voir Primary Mechanics — énergie globale au groupe (remise à 3 chaque tour, pas de ramp-up ni de couleur de mana façon jeu de cartes à collectionner), plus 2 ressources de classe dédiées depuis le 2026-08-24 : Mana du Mage et Discrétion de l'Assassin (voir Primary Mechanics → Ressources de classe). *(Le titre de cette sous-section vient du gabarit générique du genre et désignait déjà l'énergie avant l'ajout de la vraie ressource "Mana" du Mage le 2026-08-24 — coïncidence de nom, pas un doublon.)*

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

*(Mis à jour le 2026-08-09 — premier jalon concret sur une question jusque-là "entièrement à définir", voir `decision-log.md`. +2 sons le 2026-08-10 (écran feu de camp, voir Run Infini) ; total corrigé à cette occasion, la bibliothèque comptait déjà 8 sons distincts avant cet ajout et non 9 comme précédemment écrit ici — décompte refait directement sur `sfx.lua`. Reste listé aussi en Assumptions and Dependencies tant que le porteur de projet n'a pas validé le rendu à l'oreille — pas encore promu au canon complet.)*

**Direction retenue : synthèse audio procédurale façon puce sonore NES.** Ondes carrée/triangle/bruit générées directement en mémoire au lancement (aucun fichier audio, aucune dépendance externe, aucun service à payer) — le même principe que la console elle-même, qui ne jouait pas de samples enregistrés. 10 sons nommés : pioche d'une carte et retournement d'une carte au loot (même son), dégâts physiques, dégâts magiques (deux sons distincts), gain de bouclier ou dégâts intégralement bloqués par un bouclier (même son), un ennemi qui s'apprête à résoudre son action télégraphiée, résolution d'une Concentration, **soin/résurrection au feu de camp, amélioration d'une carte au feu de camp**, fanfare de victoire, fanfare de défaite. `[NOTE FOR DESIGNER] Un seul son joué par résolution même si une carte touche plusieurs cibles (pas de salve superposée) ; bibliothèque volontairement scopée à ces 10 événements pour l'instant, à étendre seulement après validation du style.`

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
| 1 | Boucle de combat centrale (énergie globale, deck/main/défausse, ciblage, télégraphie ennemie) | 1, 2 | Prototypé sur 5 itérations de code ; branche `Proto_manaGeneral` (mode **Run Infini**, voir Run Infini) est le modèle canonique, les 4 précédentes restent des jalons historiques non mis à jour. **Renversement du 2026-08-24 : énergie individuelle → globale** (voir Assumptions and Dependencies) |
| 2 | Identité de classe (4 héros MVP, cartes de classe verrouillées par propriétaire) | 4 | Prototypé — branche `Proto_manaGeneral` alignée sur le canon (Paladin, Assassin, 6 cartes propres par classe, propriétaire fixe par carte) ; les prototypes plus anciens restent en divergence (historique, non mis à jour). Le Pouvoir de Classe (retiré le 2026-08-09) puis la Transcendance (retirée le 2026-08-24) ont tour à tour disparu de cette epic — voir Character Selection |
| 3 | Lisibilité du premier combat / onboarding | 1, 2 | Non démarré — flaggé prioritaire par la séance `bmad-party-mode` |
| 4 | Structure de run et déblocage garanti (carte de quêtes, boss, récompense de fin de run) | 3 | En cours — premier combat de boss (Homme Arbre) implémenté et jouable (2026-08-21/24, voir "Boss de run borné — Homme Arbre") ; carte de quêtes, biomes, récompense de fin de run et reste de la structure toujours non démarrés, cible Mois 2 |
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
- Les 36 héros restants au-delà des 4 du MVP (cible 40), les ~480 cartes restantes à débloquer vers la cible ~600 cartes distinctes au total sur les 40 héros. *(Le volet "améliorations de passifs" — 80 avec Pouvoir de Classe + Transcendance, 40 avec la Transcendance seule à partir du 2026-08-09 — n'existe plus depuis le retrait complet de la Transcendance le 2026-08-24, voir Character Selection.)*
- Le système de l'Astronome (modificateurs globaux).
- La boucle complète de dépense de ressources au village (le MVP valide la boucle de combat, pas l'économie de village).
- La carte de quêtes à embranchements complète et les 4 types de quêtes (classe/narrative/spéciale/multiple) — ciblés Mois 2.
- Tout mode compétitif, coopératif ou multijoueur — non mentionné dans aucune source, traité comme non prévu plutôt que différé.

Hors périmètre du jeu en général (aucune source ne l'évoque) :
- Achat de cartes ou de contenu (packs, gacha) — contraire au modèle "achat unique" déclaré.

---

## Assumptions and Dependencies

**Renversement majeur du 2026-08-24 (branche Proto_manaGeneral, commit 70d1e28) — à lire avant les décisions plus anciennes ci-dessous, qu'il contredit sur plusieurs points :**
- **Énergie : individuelle → globale.** L'énergie n'est plus un compteur par héros sans plafond (décision 2026-08-06/09, ci-dessous) : c'est désormais une réserve unique partagée par le groupe (`state.energy`), remise à une valeur FIXE de 3 (`Game.TURN_START_ENERGY`) au tout début de chaque tour — pas un plancher, une remise à niveau : un surplus non dépensé ne survit jamais au changement de tour. Des cartes (Clairvoyance, Dans les ombres) peuvent faire gagner de l'énergie en cours de tour sans plafond à ce moment précis, mais ce gain disparaît lui aussi au tour suivant. Voir Primary Mechanics → Énergie.
- **Transcendance : entièrement retirée.** Plus aucun bonus/malus lié à la classe du héros qui joue une carte (Guerrier +50% "épée", Paladin +50% "bouclier"/"soin", Mage -2 coût "sort", Assassin Incapacité+Vulnérabilité). Voir Character Selection.
- **Propriété des cartes : libre → verrouillée (re-renversement de la décision 2026-08-04).** Chaque carte a maintenant un propriétaire FIXE et unique, déterminé par sa classe (`def.class_id`) — un Guerrier ne peut jamais jouer une carte du Mage. Sélectionner une carte dans sa main assigne AUTOMATIQUEMENT son propriétaire ; si celui-ci ne peut pas la jouer (mort, énergie/mana insuffisants), la sélection est simplement refusée — plus de choix manuel de "quel héros la joue". Raison probable de ce second renversement : depuis que chaque classe a sa propre copie de "Coup direct"/"Encaisser" (même nom affiché, code différent — voir Card Types and Effects), l'association carte↔héros a un sens mécanique réel, plus seulement cosmétique. C'est ce verrouillage qui reprend le rôle de synergie individuelle auparavant tenu par la Transcendance (retirée ci-dessus).
- **"Un héros, une carte par tour" : supprimée.** Un aventurier peut désormais jouer plusieurs cartes dans le même tour ; seule l'énergie/mana globale limite le nombre d'actions. L'exception que Clairvoyance faisait à cette règle n'a plus d'objet — la carte garde son effet (pioche + énergie) sans plus rien "contourner". Voir Core Gameplay Loop.
- **Rééquilibrage complet des cartes (18 → 24) :** les cartes génériques disparaissent, chaque classe reçoit 6 cartes propres (3 Départ + 3 Avancé). Voir Card Types and Effects pour le détail complet des coûts/effets.
- **Nouvelles ressources de classe : Mana (Mage) et Discrétion (Assassin).** Voir Primary Mechanics → Ressources de classe.
- **Camouflé devient un état binaire** (pas un compteur numérique), atteint uniquement via 10 points de Discrétion, avec effet réel sur le ciblage ennemi (avant : badge décoratif sans effet mécanique). Voir Primary Mechanics → Mots-clés / statuts.
- **Bugs corrigés :** la Vulnérabilité ne décroissait jamais côté aventuriers en fin de tour (seulement côté ennemis) ; le badge/l'infobulle Vulnérabilité/Incapacité n'apparaissait jamais sur les aventuriers malgré une mécanique déjà fonctionnelle ; le Troll des Marais pouvait choisir Régénération à PV pleins (soin plafonné à 0, tour gâché).

**Décisions actées cette session (à ne pas re-demander) :**
- Type de jeu hybride Roguelike + Card Game confirmé par le porteur de projet.
- Modèle de main/défausse confirmé : main commune de 5 cartes, piochée en début de tour, défausse en fin de tour, remélange à vide (mécanique du prototype `proto-deck-main-defausse`, cohérente avec le "main de 5 cartes" déjà écrit dans le brief). **Le chiffre "deck de 12 cartes" a d'abord été rendu caduc (2026-08-11, remplacé par 2 génériques + 2 "Départ" par héros), puis redevient exact par coïncidence le 2026-08-24** avec le passage à 12 cartes de départ (3 "Départ" par héros × 4 héros, plus de génériques — voir Primary Mechanics et Card Types and Effects), nombre de copies au-delà du deck de départ encore à confirmer pour le jeu final.
- **Taille de deck du prototype (temporaire, pas le canon final) :** 24 cartes (rééquilibrage complet du 2026-08-24, remplace les 18 cartes fixées le 2026-08-06 — voir le renversement majeur en tête de section), 1 exemplaire de chacune dans la table de référence. Scope explicitement limité au prototype pour permettre de tester le système complet tout de suite ; le nombre de copies pour les versions ultérieures reste ouvert.
- Coût de la carte Assassin "Stratégie" **confirmé à 0** par le porteur de projet (2026-08-06), tranchant le conflit avec la valeur 1 fixée lors d'une session précédente (abandonnée).
- Coûts de cartes du Mage (2 à 8) confirmés intentionnels, aucune correction nécessaire.
- **PV des héros — aucun montant fixé pour le moment, tout est temporaire** (précision du porteur de projet, 2026-08-06). PV de départ du Guerrier un temps noté "fixé à 18" ; cette formulation est retirée, la valeur redevient provisoire comme celle des 3 autres classes. Le prototype `proto-cartes-completes` utilise actuellement Guerrier 18, Paladin 14, Mage 10, Assassin 12 — à traiter comme des repères de test, pas comme le canon final.
- **Nom canonique du jeu : "Hero Card Game"** — tranché par le porteur de projet. Les variantes "Heroic Card Game" (ancien titre du GDD source) et "HERO CARD GAME" (nom de dossier/projet BMad, casse infrastructure uniquement) sont abandonnées comme noms du jeu ; le nom de dossier/dépôt technique reste inchangé, c'est une question d'infrastructure distincte du titre créatif.
- ~~**Pas de plafond d'énergie**~~ **— renversé le 2026-08-24** (voir le renversement majeur en tête de section) : l'énergie n'est plus individuelle par héros et ne se banque plus indéfiniment ; c'est désormais une réserve globale remise à 3 pile à chaque début de tour. Les 3 prototypes de code plus anciens (plafond à 3, non individuels) se retrouvent par coïncidence plus proches du nouveau canon sur ce point précis qu'ils ne l'étaient de l'ancien.
- **Contrôles : ciblage dynamique à la flèche confirmé comme cible de design du jeu final (2026-08-09), remplace le Drag & Drop** — voir Controls and Input. Spike testé en jeu et validé par le porteur de projet avant d'être promu au canon. La séquence à 3 taps reste un mode alterné du prototype `proto-cartes-completes`, jamais le canon.
- **Économie de cartes long terme corrigée (2026-08-06) :** 15 cartes propres par héros (5 "cartes de départ" + 10 "cartes spéciales", 12 à débloquer), soit ~480 cartes à débloquer et ~600 cartes distinctes au total sur 40 héros — remplace le chiffre "~640 améliorations" utilisé jusqu'ici, qui provenait d'une erreur de transcription du document source (15×40 = 600, pas 640). *(Le volet "améliorations de passifs" de cette même décision, alors 80 = Pouvoir de Classe + Transcendance × 2 par héros, est retombé à 40 = Transcendance seule le 2026-08-09 avec le retrait du Pouvoir de Classe — voir ci-dessous.)*
- **Pouvoir de Classe retiré (2026-08-09), décision radicale du porteur de projet** : « ça ne marche pas pour l'instant, je les remettrai peut-être plus tard, repensés. » Les 4 pouvoirs (coups gratuits du Guerrier, réanimation du Paladin, garder 1 carte du Mage, Camouflage + Puissance 2 en Concentration de l'Assassin) disparaissent du canon — voir Character Selection. La Transcendance individuelle n'est pas concernée. **Correction 2026-08-11 :** la conséquence alors signalée ici (plus aucune source n'accordant Camouflage à Assassinat) ne tient plus — le même jour (2026-08-09), l'Assassin a été retravaillé pour s'accorder Camouflage lui-même : Assassinat non-Camouflé donne désormais Camouflage 1 + Puissance 1 (la carte retourne au sommet du deck plutôt que de se concentrer), et la nouvelle carte "Dans les ombres" (voir Card Types and Effects) donne Camouflage 1 en plus de défense et d'énergie. Assassinat peut donc de nouveau résoudre sa branche Camouflé.
- **Le Paladin remplace le Clerc dans le roster MVP** (Guerrier, Paladin, Mage, Assassin).
- **Nom de classe canonique : Assassin**, pas "Voleur" — le prototype `proto-deck-main-defausse` a dérivé sur ce nom, à corriger.
- ~~**Verrouillage de carte par classe abandonné**~~ **— re-renversé le 2026-08-24** (voir le renversement majeur en tête de section) : chaque carte a maintenant un propriétaire fixe et unique, et le mécanisme de synergie réel n'est plus la Transcendance (retirée) mais cette propriété elle-même. La question ouverte débattue en `bmad-party-mode` ("libre + synergie" vs "verrouillage strict") est donc rouverte, avec un résultat final inverse de celui acté le 2026-08-04 : c'est la piste "verrouillage strict" qui l'a finalement emporté.
- **Système de ligne Front/Back abandonné** : absent du tableur des classes refait le 2026-08-06, remplacé à l'époque par le pouvoir de réanimation du Paladin (lui-même retiré depuis le 2026-08-09 avec tout le Pouvoir de Classe — voir Character Selection). Retiré du prototype `proto-cartes-completes` (CSS + logique + bonus de dégâts par ligne).
- **Relecture complète du GDD source (Google Doc), 2026-08-06 :** le porteur de projet a fourni un export PDF intégral (la lecture web précédente ne renvoyait qu'un résumé automatique tronqué, jugé peu fiable et écarté). Contenu significativement plus riche que l'extraction du 2026-08-04 sur Win/Loss (Mission Secours), Core Gameplay Loop (retour au village), Controls and Input (Drag & Drop vs prototype), Difficulty Modifiers (Malédictions, règles spécifiques de quête, difficulté ajustable, Challenge hard), Run Structure (Biomes), Level Design Framework (événements, durée par quête, Village, arbre de quêtes, Narrative Delivery) et Character Selection/Card Collection (économie de cartes par héros). Toutes ces sections ont été mises à jour en conséquence — voir chacune pour le détail.
- **Écran "feuDeCamp" ajouté au mode Run Infini (2026-08-10)** — voir Système d'amélioration de cartes (feu de camp) sous Run Infini et la colonne "Effet amélioré" de Card Types and Effects pour le détail complet. Décisions prises en cours de route :
  - **2026-08-11, revu à la baisse par le porteur de projet :** le soin de l'écran ne rend que 20 % des PV max de la cible, jamais un soin complet — vrai aussi pour une résurrection. Posé à 100 % lors de l'implémentation initiale du 2026-08-10, jugé trop généreux.
  - **Nom canon "feuDeCamp"** tranché par le porteur de projet, repris tel quel comme nom d'écran et de flux aléatoire dans le code — pas de traduction anglaise à chercher.
  - **Suffixe " +" pour une carte améliorée** (ex. "Coup direct +"), convention calée sur le genre (Slay the Spire) plutôt qu'un badge ou une icône dédiée.
  - **2026-08-11 :** présentation revue — portrait réel de l'aventurier (pas une icône) affiché en grand sur l'option de soin, PV chiffrés en plus des barres (réduites de taille), et les 2 cartes proposées à l'amélioration affichées en pleine face plutôt qu'en simple titre.
- **Table Card Types and Effects resynchronisée avec le code (2026-08-11)** — coûts et dégâts de Missile magique/Tornade de feu/Boule de feu faux, effet de Lumière divine sous-évalué, Assassinat obsolète (ancienne version qui perdait le Camouflage au lieu d'en gagner), et la 18ᵉ carte Assassin toujours listée comme "Lâcheté" alors que `decision-log.md` trace déjà sa réécriture en "Dans les ombres" le 2026-08-09 (même passe que la refonte de la Transcendance Assassin) — décisions actées mais jamais reportées dans cette table jusqu'ici. `game/src/data/cards.lua` fait foi désormais ; voir aussi la correction ci-dessus sur Assassinat/Camouflage.

**État du prototype (branche `Proto_manaGeneral`, le plus à jour) — canon désormais appliqué en code, plus seulement documenté :**
- **Énergie globale, remise à 3 chaque tour (2026-08-24)** — remplace l'ancien `MAX_ENERGY` individuel sans plafond. Voir le renversement majeur en tête de section et Primary Mechanics → Énergie.
- **Verrouillage de carte par classe (2026-08-24)** : chaque carte a un propriétaire fixe déterminé par sa classe, sélectionner une carte assigne automatiquement ce propriétaire. La Transcendance qui accompagnait l'ancien mode "libre" est retirée du code — plus aucun bonus lié au mot-clé de la carte ni à la classe qui la joue.
- Classe renommée "Assassin" (plus de "Voleur").
- Clerc retiré, remplacé par le Paladin (Rempart, Provocation, Clairvoyance, Lumière divine).
- **Pouvoir de Classe retiré du code le 2026-08-09**, puis **Transcendance individuelle retirée à son tour le 2026-08-24** (voir Character Selection) — plus aucun système de bonus par héros ou par classe.
- **Ciblage dynamique à la flèche implémenté le 2026-08-09** (voir Controls and Input), en mode alterné avec la séquence à 3 taps — bascule possible à tout moment en jeu.
- **VFX de combat et son chiptune procédural implémentés le 2026-08-09** — voir Combat Feedback (VFX) et Audio and Music.
- Ressource Défense et statuts (Saignements — désormais aussi côté héros —, Esquive en stacks, Incapacité, Vulnérabilité — désormais décroissante des deux côtés —, Discrétion, Camouflé, Puissance) implémentés. Voir Primary Mechanics → Ressources de classe pour Discrétion et Mana.
- **Liste de cartes rééquilibrée le 2026-08-24 (24 cartes, voir Card Types and Effects)** — remplace la liste à 18 cartes du 2026-08-06 : cartes génériques retirées, chaque classe reçoit 6 cartes propres (3 Départ + 3 Avancé), Mage renommé Flamèche/Barrière puis, le même jour, Flamèche renommée une 2ᵉ fois "Main de feu" avec un vrai dégât de feu magique (voir plus bas), Guerrier ayant échangé les paliers Coup de taille/Coup d'estoc.
- Glossaire de mots-clés (icônes + infobulles au survol) implémenté.
- **Mode Run Infini implémenté (2026-08-06)** — boucle de combats enchaînés avec draft de carte après chaque victoire, bestiaire à 10 ennemis, budget de difficulté croissant, PV/deck persistants entre combats d'un même run. Détail complet : voir Run Infini, sous Roguelike / Card Game Specific Design. C'est un harnais de test pour l'Epic 1 (boucle de combat), pas une redéfinition de la structure de run finale (carte de quêtes/village/biomes, toujours visée à terme — voir Run Structure et Development Epics → Epic 4).
- **Écran "feuDeCamp" implémenté (2026-08-10, présentation revue le 2026-08-11)** — soin partiel (20 % des PV max) ou amélioration de 2 cartes vers leur version "+", entre le draft et le combat suivant, sans jamais avancer le budget de difficulté. Détail complet : voir Système d'amélioration de cartes (feu de camp), sous Run Infini.
- **Boss "Homme Arbre" implémenté (2026-08-21, faiblesse au feu ajoutée/PV réajustés le 2026-08-24)** — combat fixe (1 Homme Arbre + 4 Pousses d'Arbre), accessible via "Tester le boss" au menu ou en fin de run borné à 5 combats + 1 boss ; sensibilité au feu (+50% de dégâts sur toute carte taguée "feu"), Renaissance Sylvestre (résurrection des Pousses déjà présentes, jamais d'invocation), sortie de combat qui saute le draft et le feu de camp. Détail complet : voir "Boss de run borné — Homme Arbre", sous Roguelike / Card Game Specific Design.
- **"Main de feu" (ex-"Flamèche", Mage) devient un vrai dégât de feu magique le 2026-08-24** — renversement de design, pas une correction de bug : la carte infligeait des dégâts physiques/mêlée depuis sa création malgré son nom, un choix jusqu'alors documenté comme volontaire dans ce même document. Voir Card Types and Effects pour le détail et la justification du renversement.

**Prototypes plus anciens (`mini-proto-2-cartes`, `proto-4-heros-2-ennemis`, `proto-deck-main-defausse`), conservés comme jalons historiques, non mis à jour — toujours en divergence avec le canon actuel** (énergie individuelle par héros au lieu de globale, nom "Voleur", Clerc/Soin, pas de ressource Défense ni de statuts, coût de "Coup direct" à 1 au lieu de 0, pas de Mana/Discrétion). *(Sur deux points précis — plafond d'énergie et verrouillage de carte par classe — le renversement du 2026-08-24 rapproche par coïncidence le canon actuel de ces vieux prototypes, sans que ce soit voulu ni une restauration délibérée.)*

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
- Le tableur des classes ne documente pour l'instant que les 4 héros du MVP (Guerrier, Paladin, Mage, Assassin) sur les 40 prévus. Sans Transcendance ni Pouvoir de Classe (tous deux retirés, voir Character Selection), le seul différenciateur individuel restant est l'ensemble fixe des 6 cartes propres à chaque héros (voir Card Types and Effects) — la dépendance bloquante porte sur la définition de ces 6 cartes pour les 36 héros restants, `[NOTE FOR DESIGNER]` sans qu'aucun autre système de synergie individuelle ne soit prévu pour l'instant (signalé aussi en Character Selection).
- Le mécanisme de génération de la carte de quêtes (aléatoire/semi-aléatoire/manuel) n'est pas spécifié.
- Le système de deckbuilding déblocable au village (mentionné dans le document source parmi les dépenses de ressources possibles) n'est pas détaillé.
