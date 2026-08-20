---
gdd: gdd.md
created: 2026-08-04
---

# Hero Card Game — Development Epics (detail)

Résumé et séquence : voir `gdd.md` → Development Epics. Détail par epic ci-dessous.

## Epic 1 — Boucle de combat centrale

**Sert les piliers :** 1 (chaque carte appartient à un seul aventurier), 2 (télégraphie ennemie).
**Statut :** prototypé sur 5 itérations de code (`prototype/mini-proto-2-cartes`, `prototype/proto-4-heros-2-ennemis`, `prototype/proto-deck-main-defausse`, `prototype/proto-cartes-completes`, branche `Proto_manaGeneral`) — `Proto_manaGeneral` est désormais le modèle canonique retenu, aligné sur le GDD ; les 4 itérations précédentes sont conservées comme jalons historiques et ne sont plus mises à jour.

Stories de haut niveau (implémentées sur `Proto_manaGeneral`) :
- **Système d'énergie globale (renversé le 2026-08-24, remplace l'énergie individuelle par héros)** : réserve unique partagée par le groupe, remise à une valeur fixe de 3 au début de chaque tour (pas un plancher). Un aventurier peut désormais jouer plusieurs cartes dans le même tour — voir `gdd.md` → Core Gameplay Loop.
- **Ressources de classe dédiées (2026-08-24) :** Mana du Mage (départ à 2, jamais de régénération automatique, augmentée uniquement par des cartes) et Discrétion de l'Assassin (0 à 10, +1 quand un allié agit, +5 en cas d'inaction, débloque Camouflé à 10) — voir `gdd.md` → Primary Mechanics → Ressources de classe.
- Deck de départ Run Infini (**12 cartes, 2026-08-24** : les 3 cartes "Départ" propres à chaque classe, plus de cartes génériques), qui grossit par draft de fin de combat (liste complète des 24 cartes dans `gdd.md` → Card Types and Effects), pioche jusqu'à 5, défausse de fin de tour, remélange à vide.
- Ressource Défense (pool qui absorbe les dégâts) et statuts (Saignements — désormais aussi sur les héros —, Esquive en stacks, Incapacité, Vulnérabilité — décroissance corrigée le 2026-08-24 pour s'appliquer aussi côté héros —, Discrétion, Camouflé — devenu un état binaire le 2026-08-24 —, Puissance) implémentés.
- **Mode Run Infini** (2026-08-06) : budget de difficulté par combat en croissance exponentielle (`20 × 1.22^(N-1)`, +22%/combat — remplace la version linéaire initiale du même jour, jugée trop lente en playtest ; base relevée et courbe ralentie le 2026-08-09, demande explicite du porteur de projet), bestiaire à 10 ennemis avec comportements fixes et valeurs scalables (+20 %/niveau) et variance aléatoire ±20 %, écran de draft de fin de combat (3 cartes face cachée → flip → choix), **le deck et les PV persistent** entre combats d'un même run (blessures non soignées), le reste des états repart à zéro à chaque combat (énergie, Défense, Esquive, statuts), écran de défaite avec nombre de combats remportés. Détail complet dans `gdd.md` → Run Infini.
- Résolution de télégraphie ennemie : tirage de l'action + de la cible (pondéré ou conditionnel selon l'ennemi), résolution séquentielle ennemi par ennemi (gauche à droite, 1s entre chaque) avec animation. Le montant affiché tient compte de l'Incapacité de l'attaquant et de la Vulnérabilité de sa cible (bug de cumul corrigé le 2026-08-09 — les bonus/malus s'additionnent avant application unique, ne se composent plus en chaîne, voir `gdd.md` → Assumptions and Dependencies).
- **Ciblage dynamique à la flèche** (2026-08-09, canon — remplace le Drag & Drop du GDD source, voir `gdd.md` → Controls and Input) : survol qui agrandit la carte en main, flèche courbée en maillons vers l'aventurier survolé puis la cible survolée, deux zones par encart héros (jouer / se concentrer), annulation totale au clic sur une zone ou une cible invalide. L'ancienne séquence à 3 taps (carte → héros → cible) reste disponible en mode alterné, basculable en jeu.
- Conditions de victoire/défaite de combat.
- Infobulles au survol (1s de délai) pour héros, ennemis, cartes de la main **et cartes de l'écran de draft** (2026-08-09, bug corrigé — elles n'en avaient jamais), avec système de glossaire de mots-clés (icônes inline + explications) et **liste des statuts actifs de l'unité survolée avec leur explication** (2026-08-09).
- **VFX de combat** (2026-08-09) : nombres de dégâts/soin flottants (zoom qui dépasse puis se stabilise sur les dégâts), petit burst de pixels à l'impact, pop d'échelle sur un statut à son application, bordure dorée sur les cartes "Avancé" en draft, grand bouclier en fondu sur un gain de Défense ou un blocage intégral — voir `gdd.md` → Combat Feedback (VFX).
- **Son chiptune procédural** (2026-08-09, +2 sons le 2026-08-10) : 10 sons synthétisés à la volée (pioche/retournement, dégâts physiques, dégâts magiques, bouclier, télégraphe ennemi, concentration, **soin, amélioration de carte**, fanfares victoire/défaite), aucun fichier audio — voir `gdd.md` → Audio and Music. Premier jalon, pas encore validé à l'oreille par le porteur de projet.
- **Écran "feuDeCamp"** (2026-08-10, présentation revue le 2026-08-11) : entre le draft de fin de combat et le combat suivant, à chaque combat — soin partiel (20% des PV max, y compris pour ressusciter) de l'aventurier le plus blessé, ou amélioration de 2 cartes aléatoires du deck vers leur version "+" (suffixe " +", **24 valeurs** listées dans `gdd.md` → Card Types and Effects, resynchronisées le 2026-08-24), sans jamais avancer le budget de difficulté. Détail complet dans `gdd.md` → Système d'amélioration de cartes (feu de camp).

## Epic 2 — Identité de classe (MVP : 4 héros)

**Sert le pilier :** 4 (troupe à identité individuelle).
**Statut :** prototypé et aligné sur le canon sur la branche `Proto_manaGeneral` (Guerrier/Paladin/Mage/Assassin, cartes de classe verrouillées par propriétaire fixe) ; les prototypes plus anciens restent en divergence (Guerrier/Mage/Voleur/Clerc) mais sont conservés comme jalons historiques, non mis à jour. Le Pouvoir de Classe a été **retiré le 2026-08-09**, puis la Transcendance qui restait ensuite a été **retirée à son tour le 2026-08-24** (voir ci-dessous) — le statut ci-dessus ne décrit que l'état actuel.

Stories de haut niveau (implémentées sur `Proto_manaGeneral`) :
- **Chaque classe a 6 cartes propres, jamais partagées (2026-08-24, remplace les 2 cartes génériques communes)** : 3 "Départ" + 3 "Avancé", chacune incluant une copie de "Coup direct"/"Encaisser" propre à la classe (renommées "Flamèche"/"Barrière" pour le Mage). Voir `gdd.md` → Card Types and Effects.
- **Propriété des cartes verrouillée (2026-08-24, re-renversement de la décision "libre" du 2026-08-04)** : chaque carte a un propriétaire fixe déterminé par sa classe ; sélectionner une carte assigne automatiquement ce propriétaire, refuse la sélection s'il ne peut pas la jouer. Voir `gdd.md` → Primary Mechanics → Propriété des cartes.
- ~~Pouvoir de Classe par classe~~ — **retiré le 2026-08-09**, décision radicale du porteur de projet : « ça ne marche pas pour l'instant, je n'en veux plus, je les remettrai peut-être plus tard, repensés. » Couvrait : Guerrier (dégâts gratuits sur "épée"), Paladin (réanimation une fois par combat), Mage (garde 1 carte en fin de tour), Assassin (Camouflage + Puissance 2 en Concentration).
- ~~Transcendance par héros~~ — **retirée à son tour le 2026-08-24** (couvrait : Guerrier +50% dégâts "épée", Paladin +50% "bouclier"/"soin", Mage -2 coût "sort", Assassin Incapacité+Vulnérabilité sur "épée"). Le rôle de synergie individuelle est repris par la propriété fixe de carte ci-dessus, pas par un nouveau système de bonus.
- 1 skin par héros avec animations idle (2 frames), action, coup reçu, KO — non prototypé (hors scope du prototype code, réservé à la production d'assets).

## Epic 3 — Lisibilité du premier combat / onboarding

**Sert les piliers :** 1, 2 (la propriété des cartes et la télégraphie ne servent à rien si le joueur ne les comprend pas dès le premier combat).
**Statut :** non démarré. Signalé comme le risque le plus urgent par la séance `bmad-party-mode` (Samus Shepard, Indie, Sally) — plus urgent que la question narrative de résurrection. **Toujours volontairement retardé le 2026-08-09** sur confirmation directe du porteur de projet : "encore trop tôt" tant que les textes de cartes/pouvoirs de classe (pas clairs, à réécrire — chantier personnel du porteur de projet, en cours) ne sont pas stabilisés. Les VFX de combat (voir Epic 1) sont désormais en place, ce qui lève une partie du manque signalé, mais pas la totalité.

Stories de haut niveau :
- Tutoriel ou premier combat scripté qui introduit l'énergie globale, l'assignation automatique de carte à son propriétaire, la télégraphie ennemie et le ciblage sans texte long.
- Playtest dédié dès que l'Epic 1 est jouable de bout en bout (voir Success Metrics dans `gdd.md`).

## Epic 4 — Structure de run et déblocage garanti

**Sert le pilier :** 3 (déblocage significatif à chaque run).
**Statut :** non démarré, cible Mois 2. Un premier squelette de run (budget de difficulté croissant, deck qui grossit par combat, persistance entre combats) est prototypé sous le nom **Run Infini** dans l'Epic 1 — volontairement sans carte de quêtes, sans boss, sans récompense de fin de run ; à absorber/étendre par cet epic plutôt que dupliqué.

Stories de haut niveau :
- Carte de quêtes à embranchements (génération à spécifier — `[NOTE FOR DESIGNER]`).
- 4 types de quêtes : classe (chef de groupe imposé, 3 autres libres), narrative (héros imposés selon la narration), spéciale (composition totalement libre), multiple (coordination de plusieurs groupes sur plusieurs runs).
- Événements de run (1 à 3 entre chaque combat) : rencontre narrative avec choix bonus/malus, gain de loot, bénédiction/malédiction.
- Malédictions (cartes négatives ajoutées au deck, ou passifs modifiant une règle de combat) et règles spécifiques par quête (façon *Final Fantasy 8* Triple Triad).
- Difficulté de quête ajustable (sauf quête principale), impact loot méta uniquement ; Challenge hard débloquant des skins cosmétiques de cartes/héros/villageois (voir `gdd.md` → Difficulty Modifiers).
- Biomes (bestiaire, règles de déplacement et de combat dédiées) et encyclopédie associée.
- Mission Secours optionnelle en cas de défaite (voir `gdd.md` → Win/Loss Conditions).
- Combat de boss de fin de run (durée non chiffrée, plus long qu'un combat normal).
- Récompense de déblocage permanent et significatif à la victoire du boss.
- Retour au village automatique (Pierre de Foyer) avec perte des éléments temporaires du run (deck, potions, objets) — seules les ressources de village sont ramenées.

## Epic 5 — Village (hub, économie, upgrades)

**Sert le pilier :** 3 (dépense des ressources accumulées).
**Statut :** non démarré, cible Mois 2.

Stories de haut niveau :
- Déplacement physique actif d'un héros dans le hub village (pas de point-and-click).
- Mécanique de chef de groupe : désigné par quête, contrôlable librement au village après le run, changeable en parlant à un autre aventurier (voir `gdd.md` → Village).
- Maisons de villageois : état délabré/vide par défaut, débloquées et upgradables.
- Aventuriers non actifs visibles au village, chacun sur un lieu dédié à sa classe avec un dialogue le plus souvent générique.
- Ressources : métaux (forgeron), plantes (herboriste), pierres précieuses (magicien), argent, autres non nommées.
- Dépenses : amélioration de deck, possibilités de deckbuilding (système à détailler — `[NOTE FOR DESIGNER]`), avantages de début de run, bonus rencontrables en run.

## Epic 6 — Système de l'Astronome

**Sert :** aucun pilier directement — système de difficulté/risque-récompense transverse.
**Statut :** post-MVP, hors Mois 1/2.

Stories de haut niveau :
- Déblocage de l'Astronome (condition non spécifiée).
- Sélection de "lune" d'abord aléatoire, puis progressivement contrôlable par le joueur.
- Modificateurs : Lune d'Or (+50% ressources de village, +1 dégât subi), Lune Vermeille (plus de cartes rares au loot, plus d'élites en combat) ; système conçu pour être extensible à d'autres lunes.

## Epic 7 — Narration par dialogues

**Sert :** différenciateur secondaire (narration progressive), pas un pilier de gameplay.
**Statut :** post-MVP ; **bloqué** tant que la justification narrative du retour au village après défaite n'est pas tranchée (question explicitement laissée ouverte par le porteur de projet).

Stories de haut niveau :
- Dialogues entre personnages uniquement (pas de narrateur, pas de narration environnementale), non bloquants et skippables — aucune pénalité de progression pour un joueur qui saute tout.
- Montée en présence avec la progression du joueur (peu présente au début, plus présente ensuite).
- Déclenchement par compteur d'événements caché, sur 5 contextes possibles : PNJ générique au village, PNJ lié à un aventurier spécifique, zone de dialogue entre 2 personnages, événement/combat spécifique en run, résolution de quête (voir `gdd.md` → Narrative Delivery).
- Suivi via un journal PNJ, déclenché par des compteurs d'événements.
- Prérequis : décision sur la justification narrative de la résurrection — recommandé de passer par `gds-create-narrative` une fois cette décision prise.
