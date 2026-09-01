# Glossaire

Reconstruit depuis le code le 2026-08-30, **corrigé le même jour sur le rendu des icônes**, puis **mis à jour le 2026-08-30 (mana)**, puis **mis à jour le 2026-09-01 (Brûlure, nouveau statut du Volcan — voir `docs/design/bestiaire.md`)** — voir encadrés ci-dessous. Source : `game/src/data/glossary.lua`, 34 entrées (le chiffre "25" cité par une version antérieure de ce document était déjà inexact avant l'ajout de Brûlure — corrigé au passage). Tout mot-clé cité entre guillemets dans le texte d'une carte (`docs/design/cartes.md`), d'un effet des Statues de Temple (`docs/design/temple.md`) ou d'une description de classe (`docs/design/classes.md`) est reconnu depuis cette liste — c'est elle qui alimente l'infobulle explicative affichée au survol en jeu.

Deux familles : les termes "à icône" (`has_icon = true`, remplacés par un pictogramme + un mot court dans l'interface — épée, arc, feu...) et les statuts/mécaniques "texte" (`has_icon = false`, affichés en toutes lettres — la majorité des vrais effets de gameplay).

> **Correction du 2026-08-30 — le champ `icon` de `glossary.lua` n'est PAS ce qui s'affiche en jeu.** Ma première passe recopiait tel quel le champ `icon` (des emoji Unicode, ex. "⚔️" pour épée, "🔵" pour mana) comme si c'était l'icône réellement visible en jeu. Ce n'est pas le cas : le rendu réel du texte des cartes (`RichText.draw` dans `game/src/ui/richtext.lua`, via `Sprites.keyword` dans `game/src/ui/sprites.lua`) charge un **PNG pixel-art dédié** dans `game/assets/icons/keywords/<clé>.png` — un fichier par mot-clé, jamais l'emoji. Le champ `icon` de `glossary.lua` est une métadonnée de design ancienne, jamais consommée par ce chemin de rendu (le commentaire en tête du fichier le confirme : `label` est le vrai repli texte utilisé par la UI LÖVE, `icon` n'est qu'une "vraie donnée de design ... pour une police/un rendu capable de les afficher plus tard"). Le tableau ci-dessous a été corrigé pour citer le fichier PNG réel plutôt que l'emoji.

> **Mise à jour du 2026-08-30 — "mana" a désormais son PNG.** `game/assets/icons/keywords/mana.png` (goutte de mana pixel-art, même gabarit 512×512 que les 15 autres) a été ajouté, et les 4 mentions `"mana"` de `cards.lua` (Main de feu/Barrière, base et amélioré) ont reçu leurs guillemets pour être reconnues par `RichText`. Les **17 termes "à icône" ont désormais tous un PNG dédié** dans `game/assets/icons/keywords/` — "mana" n'est plus un cas particulier sans icône.

## Termes à icône (cosmétiques ou nature de dégâts)

Les 17 termes "à icône" ont chacun un PNG dédié dans `game/assets/icons/keywords/` (chargement paresseux, `Sprites.load`).

| Terme | Icône en jeu (`assets/icons/keywords/…`) | Explication |
|---|---|---|
| énergie | `energie.png` | Ressource d'équipe partagée, dépensée pour jouer une carte (voir `docs/design/classes.md`). |
| mana | `mana.png` | Ressource propre au Mage : ne se régénère jamais seule, seules des cartes peuvent l'augmenter. |
| épée | `epee.png` | Dégâts physique de mêlée (cosmétique — même mécanique que "arc", `dmg_type = "physique"`). |
| arc | `arc.png` | Dégâts physique à distance (cosmétique, `dmg_type = "physique"`). |
| brut | `brut.png` | Dégâts brut : ne tient pas compte des boucliers ou barrières. |
| bouclier | `bouclier.png` | Défense physique. |
| barrière | `barriere.png` | Défense magique. |
| concentration (alias : concentre) | `concentration.png` | Terme du glossaire, sans mécanique de jeu active actuellement (aucune carte ne l'utilise dans le kit actuel). |
| épée de feu | `epeefeu.png` | Dégâts physique feu (cosmétique). |
| feu (fireball) | `fireball.png` | Dégâts magique feu. |
| magie (etincelle) | `etincelle.png` | Dégâts magique. |
| poison | `poison.png` | Dégât brut (cosmétique). |
| sort | `sort.png` | Terme cosmétique de catégorie de carte. |
| PV | `pv.png` | Point de vie. |
| soin | `soin.png` | Soin. |
| [ciblé] (cibleennemi, alias cibleenemi/ennemicible) | `cibleennemi.png` | Ciblé par un ennemi. |
| [allié] (alliecible) | `alliecible.png` | Cible un allié. |

## Statuts et mécaniques (texte)

| Terme | Explication |
|---|---|
| Pioche | Pioche X cartes. |
| Esquive | Ne subit aucun dégât des X prochaines attaques (-1 Esquive à chaque attaque esquivée). |
| Saignement(s) | Inflige X dégâts brut à la fin du tour, -1 Saignement au début de chaque tour. |
| Incapacité | Inflige -25% de dégâts (flat, peu importe le nombre de stacks), -1 Incapacité au début de chaque tour. |
| Vulnérabilité | Reçoit +25% de dégâts (flat, peu importe le nombre de stacks), -1 Vulnérabilité au début de chaque tour. |
| Camouflé | Ne peut pas être ciblé par un ennemi. Reste tant qu'un allié est en vie et jusqu'à jouer une carte. |
| Puissance | Les attaques physiques gagnent +25% par stack, -1 Puissance au début de chaque tour. |
| Vol | Les dégâts de type "épée" (physique) sont réduits à 0. Ne décroît PAS tout seul — seule "Charge en Piqué" (Aigle Géant) le retire. |
| Brûlure | Inflige X dégâts brut à la fin du tour. Comme Vol, ne décroît JAMAIS tout seule (contrairement à Saignement, -1/tour) — reste à sa valeur tant que rien ne la retire explicitement. Posée par plusieurs ennemis du Volcan (Cracheur de Braise, Élémentaire de Cendre, Élémentaire de Feu) — voir `docs/design/bestiaire.md`. |
| Discrétion | Ressource propre à l'Assassin (0 à 10) : +1 quand un autre héros joue une carte, +5 s'il termine le tour sans en avoir joué. À 10, devient Camouflé. Repart à 0 dès que l'Assassin joue une carte non-Furtif, ou dès qu'il reçoit des dégâts. |
| Furtif | Ne fait pas perdre de Discrétion en la jouant. Donne 2 Discrétion si défaussée sans avoir été jouée. |
| Provocation | Le personnage a +50% de chances d'être ciblé par les ennemis. -1 Provocation au début de chaque tour. |
| Amnésie | Après utilisation, la carte disparaît pour le reste du combat (elle revient au combat suivant). |
| Nécrose | Dégâts magique nécrotique — se comporte exactement comme "étincelle" (Vulnérabilité s'applique, Puissance non, réservée aux dégâts "physique"). |
| Corruption | Ressource propre au Nécromancien : +1 par PV perdu (dégâts subis ou PV sacrifiés par ses propres cartes), repart à 0 à chaque nouveau combat. Certaines cartes en dépensent jusqu'à un plafond pour amplifier leur effet. |
| Inspiration | +6 flat au premier effet de dégâts/soin/bouclier que le porteur déclenche en jouant une carte (quelle que soit sa classe). -1 charge à cette utilisation, ET -1 automatique à la fin de chaque tour (les deux peuvent se cumuler le même tour). |
| Encore | La prochaine carte jouée par le porteur ce tour se déclenche des fois supplémentaires. Perdu en fin de tour si aucune carte n'est jouée avant. |

## Notes

- "Vulnérabilité"/"Incapacité"/"Puissance" sont tous les trois des bonus **flat** (+25%/-25%/+25% par stack pour Puissance uniquement), jamais composés en pourcentage multiplicatif entre eux — voir l'ordre de calcul documenté dans `Combat.deal_damage` : les bonus additifs (Inspiration) s'appliquent d'abord sur le montant de base, puis les multiplicateurs (Vulnérabilité/Puissance/Incapacité/sensibilité au feu) s'appliquent en une seule fois sur ce total.
- "Vol" est le seul statut de la liste qui court-circuite entièrement ce calcul : contre un porteur de Vol, tout dégât de type physique est ramené à 0, avant même d'appliquer les autres multiplicateurs.
- Convention d'accord : toujours au pluriel dans le texte des cartes ("Saignements"), jamais de parenthèse "(s)" — accord fautif accepté à X=1 plutôt que la parenthèse.

## Écart avec les anciens documents

Ni le Google Doc ni le GDD BMAD ne documentent ce glossaire sous cette forme (23 termes à l'origine côté prototype, 34 aujourd'hui avec Vol/Nécrose/Brûlure ajoutés pour l'Aigle Géant, le Nécromancien et le biome Volcan) — le GDD BMAD ne connaît ni Discrétion/Camouflé, ni Corruption, ni Inspiration/Encore, ni Vol/Brûlure : ces mécaniques sont postérieures à sa rédaction (2026-08-04). À traiter comme une lacune de couverture, pas une contradiction ligne à ligne.
