# Glossaire

Reconstruit depuis le code le 2026-08-30, **corrigé le même jour sur le rendu des icônes**, puis **mis à jour le 2026-08-30 (mana)**, puis **mis à jour le 2026-09-01 (Brûlure, nouveau statut du Volcan — voir `docs/design/bestiaire.md`)**, puis **mis à jour le 2026-09-02 ("or", "Puissance" corrigée, "Incandescence", puis "Furtif"/"Encore"/"Gratuite" suite à une session de rééquilibrage des cartes — voir `docs/design/cartes.md`)** — voir encadrés ci-dessous. Source : `game/src/data/glossary.lua`, 37 entrées (le chiffre "25" cité par une version antérieure de ce document était déjà inexact avant l'ajout de Brûlure — corrigé au passage). Tout mot-clé cité entre guillemets dans le texte d'une carte (`docs/design/cartes.md`), d'un effet des Statues de Temple (`docs/design/temple.md`) ou d'une description de classe (`docs/design/classes.md`) est reconnu depuis cette liste — c'est elle qui alimente l'infobulle explicative affichée au survol en jeu.

Deux familles : les termes "à icône" (`has_icon = true`, remplacés par un pictogramme + un mot court dans l'interface — épée, arc, feu...) et les statuts/mécaniques "texte" (`has_icon = false`, affichés en toutes lettres — la majorité des vrais effets de gameplay).

> **Mise à jour du 2026-09-02 — "or" (PO), "Puissance" corrigée, "Incandescence".** Trois changements de règles/contenu côté code, aucun des trois documenté avant cette passe :
> 1. **"or" (PO)** : nouvelle ressource persistante de l'équipe (`state.gold`, `game/src/rules/game.lua`) — un run démarre à 100 PO (`Game.reset_run`), jamais remise à 0 en cours de run (contrairement à l'énergie, remise à 0 à chaque combat), gagnée à la victoire via `Game.compute_gold_reward` (somme du coût de budget de chaque ennemi vaincu × 0.5, ratio explicitement en placeholder à ajuster en playtest). A désormais son propre PNG (`or.png`), pas de statut d'exception comme "mana" en a eu un temps.
> 2. **"Puissance" — bug de décroissance corrigé** : avant, seuls les héros perdaient 1 Puissance, et en DÉBUT de tour (`Game.start_turn`) — les ennemis ne la perdaient jamais automatiquement. Désormais, Puissance décroît de 1 en **FIN** de tour (`Game.decay_end_of_turn_statuses`), **symétriquement** pour les héros ET les ennemis — c'est la seule règle de décroissance restante, `Game.start_turn` ne touche plus du tout à Puissance. Le texte "Puissance" ci-dessous a été corrigé en conséquence.
> 3. **"Incandescence" (nouveau statut)** : remplace l'ancien détournement de Puissance sur 4 coups du biome Volcan (voir `docs/design/bestiaire.md`) — bonus **flat** (+X dégâts physiques, X = valeur actuelle), pas +25%/stack multiplicatif comme Puissance, appliqué **avant** tout multiplicateur (même étage de calcul qu'Inspiration). Ne décroît **jamais** automatiquement, quel que soit le côté qui la porte (même famille que Vol/Brûlure).
>
> **Écart interne au code, signalé pour mémoire :** le champ `explain` de l'entrée `puissance` dans `glossary.lua` (celui qui alimente l'infobulle en jeu) est resté sur une formulation intermédiaire ("Un aventurier en perd 1 au début de chaque tour ; certains ennemis n'en perdent jamais seuls.") — une étape de correction antérieure au fix final ci-dessus, jamais mise à jour après. Ce document décrit le comportement **réellement implémenté aujourd'hui** dans `game.lua` (fin de tour, symétrique), pas ce texte d'infobulle actuellement affiché en jeu, qui est donc lui-même obsolète.

> **Mise à jour du 2026-09-02 (2) — session de rééquilibrage des cartes, "Furtif"/"Encore"/"Gratuite".** Trois changements, tous vérifiés directement dans `game/src/data/glossary.lua` :
> 1. **"Furtif"** : texte réduit — ne mentionne plus « Ne fait pas perdre de Discrétion en la jouant » (ce comportement reste vrai en pratique, `Game.on_card_played` ne le retire toujours que pour une carte non-Furtif — juste retiré du texte affiché). Ne garde que « Donne 2 Discrétion si défaussée sans avoir été jouée. »
> 2. **"Encore"** : vrai changement de comportement, pas seulement de texte — "Encore" ne se perd plus automatiquement en fin de tour si son porteur ne joue aucune carte. Il persiste désormais indéfiniment jusqu'à être consommé par la prochaine carte jouée par ce porteur, quel que soit le nombre de tours écoulés entre-temps.
> 3. **"Gratuite" (nouveau statut, 37ᵉ entrée)** : générique — n'importe quel héros peut le porter, pas propre au Barde (même statut qu'Inspiration/Encore sur ce point). Tant que > 0, toutes les cartes du porteur coûtent et affichent 0 en énergie (`Combat.effective_cost`), -1 à chaque carte jouée par ce héros (`Game.on_card_played`), quelle qu'elle soit — ne touche que le coût en énergie, jamais un coût en ressource propre (mana/Corruption). Actuellement seule la carte "Bis" du Barde le distribue (voir `docs/design/cartes.md`), en plus de son effet "Encore" existant.

> **Correction du 2026-08-30 — le champ `icon` de `glossary.lua` n'est PAS ce qui s'affiche en jeu.** Ma première passe recopiait tel quel le champ `icon` (des emoji Unicode, ex. "⚔️" pour épée, "🔵" pour mana) comme si c'était l'icône réellement visible en jeu. Ce n'est pas le cas : le rendu réel du texte des cartes (`RichText.draw` dans `game/src/ui/richtext.lua`, via `Sprites.keyword` dans `game/src/ui/sprites.lua`) charge un **PNG pixel-art dédié** dans `game/assets/icons/keywords/<clé>.png` — un fichier par mot-clé, jamais l'emoji. Le champ `icon` de `glossary.lua` est une métadonnée de design ancienne, jamais consommée par ce chemin de rendu (le commentaire en tête du fichier le confirme : `label` est le vrai repli texte utilisé par la UI LÖVE, `icon` n'est qu'une "vraie donnée de design ... pour une police/un rendu capable de les afficher plus tard"). Le tableau ci-dessous a été corrigé pour citer le fichier PNG réel plutôt que l'emoji.

> **Mise à jour du 2026-08-30 — "mana" a désormais son PNG.** `game/assets/icons/keywords/mana.png` (goutte de mana pixel-art, même gabarit 512×512 que les 15 autres) a été ajouté, et les 4 mentions `"mana"` de `cards.lua` (Main de feu/Barrière, base et amélioré) ont reçu leurs guillemets pour être reconnues par `RichText`. Les **17 termes "à icône" ont désormais tous un PNG dédié** dans `game/assets/icons/keywords/` — "mana" n'est plus un cas particulier sans icône.

## Termes à icône (cosmétiques ou nature de dégâts)

Les 18 termes "à icône" ont chacun un PNG dédié dans `game/assets/icons/keywords/` (chargement paresseux, `Sprites.load`).

| Terme | Icône en jeu (`assets/icons/keywords/…`) | Explication |
|---|---|---|
| énergie | `energie.png` | Ressource d'équipe partagée, dépensée pour jouer une carte (voir `docs/design/classes.md`). |
| or | `or.png` | Ressource **persistante** de l'équipe (PO) : 100 au départ d'un run, ne se réinitialise jamais en cours de run (contrairement à l'énergie). Gagnée à chaque victoire (`Game.compute_gold_reward`, voir encadré ci-dessus). |
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
| Puissance | Les attaques physiques gagnent +25% par stack (multiplicatif). -1 Puissance en **fin** de tour, **symétriquement** pour les aventuriers ET les ennemis (seule règle de décroissance, `Game.decay_end_of_turn_statuses`). |
| Incandescence | Les attaques physiques gagnent +X dégâts (**flat**, X = valeur actuelle), additionné avant tout multiplicateur — pas +25%/stack comme Puissance. Ne décroît **jamais** automatiquement, quel que soit le porteur. Posée par plusieurs ennemis du Volcan (Salamandre de Lave, Golem de Magma, Vouivre des Cendres, Élémentaire de Feu) — voir `docs/design/bestiaire.md`. |
| Vol | Les dégâts de type "épée" (physique) sont réduits à 0. Ne décroît PAS tout seul — seule "Charge en Piqué" (Aigle Géant) le retire. |
| Brûlure | Inflige X dégâts brut à la fin du tour. Comme Vol, ne décroît JAMAIS tout seule (contrairement à Saignement, -1/tour) — reste à sa valeur tant que rien ne la retire explicitement. Posée par plusieurs ennemis du Volcan (Cracheur de Braise, Élémentaire de Cendre, Élémentaire de Feu) — voir `docs/design/bestiaire.md`. |
| Discrétion | Ressource propre à l'Assassin (0 à 10) : +1 quand un autre héros joue une carte, +5 s'il termine le tour sans en avoir joué. À 10, devient Camouflé. Repart à 0 dès que l'Assassin joue une carte non-Furtif, ou dès qu'il reçoit des dégâts. |
| Furtif | Donne 2 Discrétion si défaussée sans avoir été jouée. |
| Provocation | Le personnage a +50% de chances d'être ciblé par les ennemis. -1 Provocation au début de chaque tour. |
| Amnésie | Après utilisation, la carte disparaît pour le reste du combat (elle revient au combat suivant). |
| Nécrose | Dégâts magique nécrotique — se comporte exactement comme "étincelle" (Vulnérabilité s'applique, Puissance non, réservée aux dégâts "physique"). |
| Corruption | Ressource propre au Nécromancien : +1 par PV perdu (dégâts subis ou PV sacrifiés par ses propres cartes), repart à 0 à chaque nouveau combat. Certaines cartes en dépensent jusqu'à un plafond pour amplifier leur effet. |
| Inspiration | +6 flat au premier effet de dégâts/soin/bouclier que le porteur déclenche en jouant une carte (quelle que soit sa classe). -1 charge à cette utilisation, ET -1 automatique à la fin de chaque tour (les deux peuvent se cumuler le même tour). |
| Encore | La prochaine carte jouée par le porteur ce tour se déclenche des fois supplémentaires. Ne se perd plus en fin de tour si inutilisé (2026-09-02) : persiste indéfiniment jusqu'à être consommé par la prochaine carte jouée par son porteur. |
| Gratuite | Tant que Gratuite > 0, toutes les cartes de l'aventurier coûtent et affichent 0 en énergie. -1 à chaque utilisation. Statut générique (n'importe quel héros peut le porter, pas propre au Barde) — actuellement seule "Bis" (Barde) le distribue. |

## Notes

- "Vulnérabilité"/"Incapacité"/"Puissance" sont tous les trois des bonus **multiplicatifs** (+25%/-25%/+25% par stack pour Puissance uniquement), jamais composés en pourcentage entre eux — voir l'ordre de calcul documenté dans `Combat.deal_damage` : les bonus **additifs** (Inspiration +6, Incandescence +X) s'appliquent d'abord sur le montant de base, puis les multiplicateurs (Vulnérabilité/Puissance/Incapacité/sensibilité au feu) s'appliquent en une seule fois sur ce total.
- "Vol" est le seul statut de la liste qui court-circuite entièrement ce calcul : contre un porteur de Vol, tout dégât de type physique est ramené à 0, avant même d'appliquer les autres multiplicateurs.
- Convention d'accord : toujours au pluriel dans le texte des cartes ("Saignements"), jamais de parenthèse "(s)" — accord fautif accepté à X=1 plutôt que la parenthèse.

## Écart avec les anciens documents

Ni le Google Doc ni le GDD BMAD ne documentent ce glossaire sous cette forme (23 termes à l'origine côté prototype, 37 aujourd'hui avec Vol/Nécrose/Brûlure/or/Incandescence/Gratuite ajoutés pour l'Aigle Géant, le Nécromancien, le biome Volcan, la ressource PO et la carte "Bis" du Barde) — le GDD BMAD ne connaît ni Discrétion/Camouflé, ni Corruption, ni Inspiration/Encore/Gratuite, ni Vol/Brûlure/Incandescence, ni "or" : ces mécaniques sont postérieures à sa rédaction (2026-08-04). À traiter comme une lacune de couverture, pas une contradiction ligne à ligne.
