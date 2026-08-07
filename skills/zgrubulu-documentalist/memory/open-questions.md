# Questions ouvertes — Hero Card Game

Points de design non tranchés, avec origine et statut. Tenu à jour au fil des sessions (capacité `tenir-canon`). Une question résolue passe en "Résolu" avec sa résolution — elle ne disparaît pas.

## Ouvertes

- **Justification narrative du retour au village après défaite** (façon *Dead Cells* — malédiction, réincarnation). Origine : porteur de projet, dès le brief (2026-08-04). Explicitement laissée ouverte à sa propre demande — ne pas trancher sans lui. Bloque l'Epic 7 (Narration) du GDD.
- **Nom du mécanisme de rétention/défausse de fin de tour.** Origine : brief (2026-08-04).
- **Direction sonore.** Entièrement à définir. Origine : brief (2026-08-04).
- **Rythme exact du loot** (pourcentages de drop). Origine : brief (2026-08-04).
- **Mécanisme de génération de la carte de quêtes** (aléatoire / semi-aléatoire / manuel). Origine : GDD source, extrait le 2026-08-04.
- **Système de deckbuilding déblocable au village.** Mentionné dans le GDD source parmi les dépenses de ressources possibles, jamais détaillé. Origine : GDD source, 2026-08-04.
- **Variété d'ennemis et échelle de puissance selon la composition d'équipe.** Le prototype ne contient que des ennemis placeholder (dont le Gobelourd). Le porteur de projet prévoit d'ajouter de nouveaux ennemis avec une échelle de puissance ajustable, non chiffrée. Origine : session du 2026-08-06.
- **Formule exacte d'absorption de la Défense** (soustraction un-pour-un aux dégâts, ou autre). Origine : liste de cartes, 2026-08-04.
- **Commande UI de sélection de la carte gardée par le Pouvoir de Classe du Mage.** Origine : tableur des classes, 2026-08-04, toujours pertinente après la refonte du 2026-08-06.
- **Nombre de copies par carte dans le deck final** (au-delà du prototype, temporairement 1 exemplaire de chaque des 18 cartes). Origine : liste de cartes, 2026-08-04.
- **PV de tous les héros, Guerrier compris.** Rouverte le 2026-08-06 : « aucun montant de point de vie n'est fixé pour le moment, tout est temporaire » (porteur de projet). Annule la résolution du 2026-08-04 ci-dessous, qui fixait le Guerrier à 18. Les 4 valeurs actuelles (Guerrier 18, Paladin 14, Mage 10, Assassin 12) restent celles du prototype `proto-cartes-completes`, à traiter comme provisoires.

## Résolues

- **Nom canonique du jeu.** Trois variantes coexistaient : « Heroic Card Game », « Hero Card Game », « HERO CARD GAME ». Résolu par le porteur de projet : **« Hero Card Game »**. Le nom de dossier/dépôt technique reste « HERO CARD GAME », question d'infrastructure distincte.
- **Modèle de main/deck.** Deux prototypes de code implémentaient deux modèles différents (main fixe de 3 cartes par héros actif sans pioche, vs deck de 12 cartes / main commune de 5 / défausse). Résolu le 2026-08-04 par le porteur de projet : modèle deck/main/défausse retenu, cohérent avec le "main de 5 cartes" déjà écrit dans le brief.
- **Type de jeu (genre GDD).** Roguelike et Card Game matchaient tous les deux fortement. Résolu le 2026-08-04 par le porteur de projet : fusion des deux, section de design spécifique hybride.
- **PV de départ du Guerrier (historique, rouverte — voir Ouvertes).** Incohérence 18 (2 prototypes récents) vs 20 (1er prototype). Un temps résolue à 18 le 2026-08-04, puis rouverte le 2026-08-06 : le porteur de projet a précisé qu'aucun PV n'est fixé pour le moment.
- **Verrouillage strict des cartes de classe.** Résolu le 2026-08-04 : abandonné, remplacé par la Transcendance comme vrai mécanisme de synergie.
- **Coût de la carte « Stratégie » (Assassin).** Deux valeurs en conflit (0 vs 1 d'une session antérieure). Résolu le 2026-08-06 par le porteur de projet : 0, la valeur 1 est abandonnée.
- **Pouvoir de Classe et Transcendance du Paladin.** Le système de lignes Front/Back (+20%/-20%) est abandonné le 2026-08-06, absent du tableur des classes refait — remplacé par une réanimation automatique une fois par combat. Transcendance élargie au bouclier ET au soin.
- **Condition exacte du bonus Camouflé de l'Assassin** (formulation source ambiguë : "+50% dégâts si la cible attaque"). Résolue par le tableur des classes refait du 2026-08-06 : statut Puissance 2 chiffré, remplace l'ancienne formulation.
- **Adjacence/ligne entre ennemis.** Résolu le 2026-08-06 : abandonnée, pas seulement simplifiée — "Coup de taille" cible tous les ennemis.
- **Coup Brutal (Guerrier) en doublon avec Blessure ouverte (Assassin).** Résolu le 2026-08-06 : Coup Brutal retiré, laissé par erreur lors de la refonte du tableur des cartes. Deck ramené de 19 à 18 cartes.
- **Contrôles cible finale (Drag & Drop vs séquence à 3 taps).** Une relecture complète du GDD source (export PDF fourni le 2026-08-06, après une lecture web jugée peu fiable) a révélé que le Drag & Drop est la cible de design finale, la séquence à 3 taps n'étant qu'un choix volontaire du prototype — corrige la lecture du 2026-08-04 qui traitait le Drag & Drop comme abandonné.
- **Économie de cartes à 40 héros (15 vs 16 cartes/héros, 600 vs 640 au total).** Le PDF donnait initialement 16 cartes/héros et ~640 au total, en conflit avec le tableur de cartes MVP déjà intégré. Le porteur de projet a corrigé le 2026-08-06 : erreur de transcription de sa part — le vrai modèle est 15 cartes/héros (5 cartes de départ + 10 spéciales), ~600 au total sur 40 héros.
