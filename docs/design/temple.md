# Statues de Temple

Catalogue des 8 bénédictions et 8 malédictions attribuables à l'écran du Temple. Reconstruit depuis le code le 2026-08-30 (`game/src/rules/temple.lua`, refonte complète du 2026-08-29). Absent des deux anciens documents (Google Doc, GDD BMAD) — écrit après leur rédaction, rien à comparer.

**Corrigé le 2026-10-02** : "La Renaissante" utilisait encore l'ancien mécanisme décrit lors de la reconstruction initiale (voir la section dédiée plus bas) — harmonisée entre-temps par le code avec le mot-clé "Survie" du pilier du sacrifice. Audit complet du fichier `game/src/rules/temple.lua` à cette occasion (pas seulement cette entrée) : aucune autre bénédiction/malédiction n'a divergé depuis le 2026-08-30, voir la note en fin de document.

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
| La Renaissante | Blanc | Donne "Survie" au début de chaque combat — mais seulement tant qu'elle n'a jamais encore sauvé le porteur pour de vrai. |
| L'Archiviste | Violet | "Pioche" une carte en plus à chaque tour. |
| Le Réserviste | Noir | L'"énergie" non dépensée reste pour le tour suivant, 1 fois par combat. |
| Le Protecteur | Orange | Gagne 4 "bouclier" au début de chaque tour. |
| Le Rancunier | Gris | Renvoie 2 dégâts (brut, ignore le bouclier) à l'attaquant à chaque coup reçu. |

**"La Renaissante" en détail** (voir aussi le mot-clé "Survie" dans `docs/design/glossaire.md`) : "Survie" fait que la prochaine fois que le porteur doit mourir, il reste en vie à **10% de ses PV max** à la place (jamais 1 PV fixe) — sauf face à une carte "Mise à mort", à laquelle rien n'échappe. La bénédiction **redonne** "Survie" à **chaque** entrée en combat, mais **seulement tant qu'elle n'a jamais encore sauvé le porteur pour de vrai** : dès que "Survie" a effectivement empêché une mort une fois, la bénédiction cesse de la recharger pour le reste du run, même à un combat bien plus tard. Au final, "La Renaissante" ne sauve donc qu'**une seule fois par run** — jamais "une fois par combat" comme le mécanisme d'origine (1 PV fixe, 1 fois pour tout le run — au final la même limite globale, mais pas le même PV d'arrivée). "Survie" peut aussi être accordée par une carte (Barde, "Célébration Finale") : dans ce cas c'est une charge unique indépendante de "La Renaissante", qui persiste jusqu'à consommation sans lien avec `renaissante_used`.

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

## Correction interne du 2026-10-02 — "La Renaissante"

La reconstruction initiale (2026-08-30) décrivait "La Renaissante" avec le mécanisme alors en place : `hero.death_ward`, remontée fixe à 1 PV, valable 1 seule fois pour tout le run. Le code l'a depuis harmonisée avec le mot-clé "Survie" (introduit par le pilier du sacrifice, carte "Célébration Finale" du Barde) : remontée à **10% des PV max** (jamais 1 PV fixe), rechargée à chaque entrée en combat **jusqu'à la première sauvegarde réelle**, puis plus jamais réactivée de tout le run (`hero.renaissante_used`, `game/src/rules/game.lua`/`combat.lua`) — voir le paragraphe dédié ci-dessus. L'écart avait été repéré et signalé (sans être corrigé, hors périmètre) lors de la synchronisation du Glossaire du 2026-09-30 ; corrigé ici.

**Audit du reste du fichier à cette occasion** (`game/src/rules/temple.lua` relu intégralement, pas seulement l'entrée "La Renaissante") : les 7 autres bénédictions et les 8 malédictions correspondent toujours exactement à ce document — aucun autre écart trouvé. Vérifications ciblées faites en plus de la simple lecture de `temple.lua` : "Le Rancunier" (`hero.thorns`, riposte en dégâts `brut`) confirmé ignorer bien le bouclier de la cible dans `combat.lua` ; "Le Martyr" (`hero.targeting_bonus`) confirmé cumulable multiplicativement avec la Provocation du Paladin dans `encounter.lua` (`w = w * 1.5` puis `w = w * (1 + targeting_bonus)`) ; "Le Maladroit" (`discard_on_draw_chance`) confirmé se déclencher bien à la pioche, pas à un autre moment ; "Le Blessé" (`self_damage_on_hit`) confirmé ne se déclencher que sur une attaque qui inflige réellement des dégâts à un ennemi (jamais sur un coup entièrement paré, jamais sur un allié touché par erreur).

## Écart avec les anciens documents

Aucun — le Temple n'existe dans aucun des deux anciens documents (Google Doc, GDD BMAD, tous deux antérieurs à sa conception). Absence totale, pas une contradiction.
