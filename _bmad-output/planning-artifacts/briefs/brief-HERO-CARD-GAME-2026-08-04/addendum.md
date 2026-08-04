---
brief: brief.md
created: 2026-08-04
---

# Addendum — Hero Card Game

Contenu qui a sa valeur mais qui alourdirait le brief. Utile pour la GDD (`gds-gdd`) et les passes suivantes.

## Sources

- GDD principal (Google Doc, titre interne "Heroic Card Game") : https://docs.google.com/document/d/1qm-23aGEkOOQX_xcryKOBR6b8PNKCi0aMPO-hfIAH2s/edit
- Comparatif concurrentiel : https://docs.google.com/document/d/19Bezv7yryATJLroPq55HNCxMqWhH3RQBNeAbdyV7kA4/edit
- Ambition et étapes (définition du MVP) : https://docs.google.com/document/d/1bZ8YnrffqFoKFvsc8r7LCjwOg-9hwKgJlL7XfquPHQk/edit
- Tableur des classes : https://docs.google.com/spreadsheets/d/1Tk4eqeyT33Jis05hLdiMEMw6vL6RAiYjJUHJ3ksaHdY/edit (seul l'onglet "Classes" a été lu — ex. Paladin : passif "50% de chances d'attirer les attaques ennemies, dégâts subis -1" ; actif : cible perd 1 attaque et a 100% de chances d'être attaquée par le Paladin)

## Comparatif concurrentiel — détail complet

Le porteur du projet a rédigé une analyse forces/faiblesses de 9 titres. La version condensée est dans `brief.md` (References & Differentiation) ; le détail complet ci-dessous garde les nuances utiles pour la GDD.

**Slay the Spire / Slay the Spire 2** — Force : a démocratisé la formule (3 actes, labyrinthe linéaire, feux de camp, choix parmi 3 cartes, reliques aléatoires, potions, banque d'événements fournie, magasins avec suppression de cartes, déblocages entre runs, un seul héros par run). Accessibilité et fluidité sont son point fort absolu — "pas beau, mais clair". Le 2 est mieux équilibré, runs moins punitifs. Faiblesse : chaos fort, sentiment de punition injustifiée ; on perd tout en fin de run et on recommence immédiatement ; déblocages de plus en plus rares, la difficulté seule progresse, ce qui nourrit la frustration ; les achievements poussent au farm mais restent méta, sans impliquer le joueur dans son aventure ; au final, seule l'envie de jouer motive à relancer — sentiment de vacuité une fois l'objectif atteint.

**Monster Train** — Force : adapte des règles façon *Darkest Dungeon* (petite armée plutôt qu'un seul général), personnages et monstres en ligne selon la formation. Peu de combats (9) mais intenses, place à la stratégie. Entre 2 combats, long moment calme de préparation de deck. Clans, généraux et leurs 3 builds chacun sont très originaux, forte rejouabilité (2 clans choisis en début de run, un principal et un secondaire). Faiblesse : débuts difficiles et frustrants, courbe d'apprentissage réelle ; le système de pari en début de combat (plus de risque = meilleures récompenses) pénalise à l'inverse ceux qui jouent prudemment ; plusieurs vagues de monstres par combat peuvent allonger les runs ; les 2 dernières vagues, nombreuses et avec beaucoup de PV, annulent certaines stratégies.

**Blood Card** — Proche de *Slay the Spire*, sauf que les PV du joueur SONT les cartes du deck : ne plus pouvoir piocher = mort ; perdre des PV = défausser. Choix de loot entre cartes faibles (toujours par 3, donc +3 PV) et cartes rares (par 1) — un deck puissant devient dangereux. Pixel art gothique agréable. Faiblesse : maniement des cartes (pioche ↔ défausse direct) peu intuitif, demande de l'habitude ; beaucoup de texte sur les cartes pour des mécaniques pas toujours heureuses, nomenclature à améliorer.

**Tainted Grail** — Univers 3D façon MMO façon *Diablo*, ambiance lourde et pessimiste, le joueur incarne vraiment un héros porteur de lumière. Narration riche et impliquante (héros, villageois, PNJ rencontrés en run). 9 classes très différenciées (cartes, passifs, ultimes propres). Ressources collectées en run dépensées au village en améliorations permanentes — le passage au village, avec déplacement physique de PNJ en PNJ, est satisfaisant en rythme et en gestion du stress. Faiblesse : runs longs, obligation de vider la carte pour affronter le boss final ; une fois le deck équilibré, sensation de "réciter en boucle" tout en craignant de perdre ; difficulté élevée, l'aléatoire des tirages peut ruiner un run sans espoir de rebond.

**Inscryption** (première phase, la cabane, seule pertinente ici — les phases suivantes sortent du cadre car la mort permanente y disparaît) — Ambiance horrifique avec histoire ; entre 2 runs, le joueur cherche à s'échapper de la cabane via des énigmes. Personnages et cartes s'adressent au joueur pour rappeler l'enjeu de survie. Débloque des séquences façon *Le Projet Blair Witch* qui renforcent l'immersion. Mécaniques simples mais redoutablement efficaces. Faiblesse : mécaniques si simples et combats si courts que certaines situations basculent en défaite en un instant, frustration importante ; peu de contenu réel dans la cabane, on tourne vite en rond ; une fois tout débloqué, il ne reste qu'à enchaîner les runs.

**Wildfrost** — Combat = 2 armées de quelques personnages face à face sur 2 lignes, la position compte. Chaque personnage agit quand son compteur tombe à zéro ; tous les compteurs baissent d'1 à chaque carte/action jouée, ce qui implique le joueur dans l'ordre de ses choix. 3 races et de nombreux généraux renouvellent bien l'expérience. Faiblesse : les défis de déblocage (accumuler X fois un pouvoir, battre X fois un monstre) n'influent ni sur les runs ni sur leur contenu ni sur la difficulté — on relance pour l'exploit, puis le run continue sans but réel ; monde intéressant mais sans narration associée.

**Zet Zillion** — Graphismes simples mais efficaces, jeu délirant, VFX partout, monstres (planètes à visages) qui contribuent au fun. Réel effort de méta-narration, mais absente des runs eux-mêmes. Faiblesse : le système trouve vite ses limites ; l'univers ne plaira pas à tout le monde.

**Griftlands** — Jeu de cartes complexe pour qui veut s'investir, combats aussi bien physiques que sociaux. Narration forte, incite à relancer pour connaître la suite. Faiblesse : trop de règles au départ, trop de complexité, "facture" d'entrée trop lourde.

**Hand of Fate** — Pas un jeu de cartes à proprement parler, mais les cartes-événements qui se débloquent progressivement, révélant une histoire run après run, apportent une vraie valeur ajoutée.

## Prototype Minimaliste V1 — note

Le document "Ambition et étapes" distingue deux paliers :
1. **Prototype Minimaliste V1 (interne)** — détaillé intégralement dans `brief.md` (Scope & MVP).
2. **"Fonctionnalités minimales pour une première partie EN EXTERNE"** — mentionné dans le même document mais sans détail donné à ce stade ("destinées aux vrais joueurs, sans détails supplémentaires"). À clarifier avec le porteur du projet avant la GDD si ce palier doit être planifié précisément.

## Mécaniques détaillées non reprises dans le brief

Les systèmes de combat (tour par tour, ciblage, coûts), de village (ressources métaux/plantes/gemmes, boutiques, PNJ), de loot (3 cartes au choix, rareté croissante), de règles globales (l'Astronome et ses modificateurs type "Lune d'Or"/"Lune Vermeille"), et de quêtes (classes, narratives, spéciales, multiples) sont documentés en détail dans le GDD source. Ils relèvent du niveau GDD plutôt que du brief — à reprendre intégralement lors du passage à `gds-gdd`.
