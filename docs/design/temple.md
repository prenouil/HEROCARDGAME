# Statues de Temple

Catalogue des 8 bénédictions et 8 malédictions attribuables à l'écran du Temple. Reconstruit depuis le code le 2026-08-30 (`game/src/rules/temple.lua`, refonte complète du 2026-08-29). Absent des deux anciens documents (Google Doc, GDD BMAD) — écrit après leur rédaction, rien à comparer.

Pour le comportement de l'écran lui-même en tant qu'évènement post-combat (conditions de déclenchement, sélection des candidats, ce que le joueur voit et fait), voir `docs/design/evenements.md` — ce document-ci ne couvre QUE le contenu des statues (nom, couleur, effet).

## Fonctionnement

- À chaque visite, un **type** est tiré au hasard entre Bénédiction et Malédiction — jamais les deux à la fois, jamais un mélange dans le même choix.
- Le tirage ne porte que sur les types **viables** (au moins 1 effet de ce type ET au moins 1 aventurier éligible pour l'un d'eux) : si un seul type est viable, ce sera toujours lui ; si aucun ne l'est, l'écran du Temple n'apparaît pas du tout ce combat-ci (voir `docs/design/evenements.md`).
- Jusqu'à **3 effets distincts** de ce type sont proposés (`Temple.CHOICE_COUNT`), sans remise — moins si le pool n'en contient pas assez (jamais le cas ici : 8 bénédictions et 8 malédictions disponibles).
- Le joueur choisit **1 aventurier ET 1 effet**, puis confirme. Aucun "Passer" possible sur cet écran — s'il n'y avait rien à proposer, l'écran n'apparaît simplement pas (voir ci-dessus).
- Chaque aventurier ne peut porter qu'**une seule bénédiction et une seule malédiction à la fois** (2 champs indépendants) — il peut cumuler les deux types en même temps, mais jamais 2 bénédictions ou 2 malédictions.
- Un effet attribué **n'est pas retiré du pool** : rien n'empêche qu'il réapparaisse et soit donné à un autre aventurier plus tard dans le même run.
- Une fois attribués, bénédiction et malédiction **durent tout le run** (contrairement aux statuts de combat classiques, remis à zéro entre 2 combats).

## Bénédictions

| Nom | Couleur (statue) | Effet |
|---|---|---|
| La Guérisseuse | Vert | "Soin" 5 à chaque début de combat. |
| L'Illusionniste | Bleu | "Esquive" 1 au début de chaque combat. |
| Le Puissant | Rouge | "Puissance" 3 au début de chaque combat. |
| La Renaissante | Blanc | À la place de mourir, reste vivant à 1 "PV", 1 seule fois (pour tout le run). |
| L'Archiviste | Violet | "Pioche" une carte en plus à chaque tour. |
| Le Réserviste | Noir | L'"énergie" non dépensée reste pour le tour suivant, 1 fois par combat. |
| Le Protecteur | Orange | Gagne 4 "bouclier" au début de chaque tour. |
| Le Rancunier | Gris | Renvoie 2 dégâts (brut, ignore le bouclier) à l'attaquant à chaque coup reçu. |

## Malédictions

| Nom | Couleur (statue) | Effet |
|---|---|---|
| Le Maudit | Vert | Perd 2 "PV" à chaque début de combat. |
| Le Corrompu | Bleu | Les cartes de cet aventurier coûtent 1 "énergie" de plus. |
| Le Maladroit | Rouge | Les cartes de cet aventurier ont 50% de chances d'être défaussées de suite (à la pioche). |
| Le Martyr | Blanc | Chances d'être pris pour cible par les ennemis : +50% (permanent, cumulable avec le statut "Provocation" du Paladin si le même héros porte les deux). |
| Le Vulnérable | Violet | "Vulnérabilité" 3 au début de chaque combat. |
| Le Faible | Noir | "Incapacité" 3 au début de chaque combat. |
| Le Blessé | Orange | Perd 1 "PV" à chaque attaque faisant des dégâts. |
| L'Amnésique | Gris | Les cartes de cet aventurier gagnent "Amnésie". |

## Écart avec les anciens documents

Aucun — le Temple n'existe dans aucun des deux anciens documents (Google Doc, GDD BMAD, tous deux antérieurs à sa conception). Absence totale, pas une contradiction.
