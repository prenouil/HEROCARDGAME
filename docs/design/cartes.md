# Cartes de classes

Reconstruit depuis le code le 2026-08-30 (`game/src/data/cards.lua`, 36 cartes — 6 classes × 6), **mis à jour le 2026-09-02** suite à une session de rééquilibrage (Guerrier/Assassin/Nécromancien/Barde) — voir les paragraphes de chaque classe pour le détail des écarts. Format repris de celui déjà utilisé par agent_content pour proposer des cartes : Nom | Classe | Palier | Coût | Mots-clés | Texte (base) | Texte amélioré.

Notes de lecture :
- **Palier** : "Départ" (fait partie du deck de départ de la classe si elle est sélectionnée en équipe) ou "Avancé" (obtenue en jeu via le Draft de fin de combat).
- **Coût** : énergie (ressource d'équipe partagée, 3/tour) ; si la carte consomme en plus une ressource propre à sa classe, elle est notée à la suite (ex. "1 + 1 mana", "1 (+0-3 Corruption)" pour un coût variable plafonné). Si le coût change à l'amélioration (rare — seul cas actuel : "Coup de taille"), noté "base (amélioré)".
- **Mots-clés** : catégories internes de la carte (`cats`), qui pilotent aussi son filtrage (ex. Draft/Forge). Distinct des mots-clés du Glossaire cités entre guillemets dans le texte (voir `docs/design/glossaire.md`).
- **Texte** : recopié tel quel depuis `desc`/`upgrade.desc` (guillemets = mot-clé du Glossaire).
- **Ciblage** : la plupart des cartes ciblent un ennemi, un allié, soi-même (`target = "self"`), tous les ennemis (`"all-enemies"`), ou sont conditionnelles à la situation (`"conditional"`, ex. Riposte — cible le déclencheur de son effet, pas un choix du joueur). Depuis le 2026-09-02, un nouveau mode existe : `"enemy-or-ally"` (« Combattant expérimenté » du Guerrier, seule carte concernée à ce jour) — le joueur clique librement un ennemi OU un allié (les deux sont mis en surbrillance comme cibles valides), et selon le type cliqué, un seul des deux effets du texte se déclenche, jamais les deux (voir `Game.resolve_pending`, `game/src/ui/input.lua`/`view.lua`, qui traitent ce mode comme l'union de "enemy" et "ally").

## Guerrier ⚔️

| Nom | Palier | Coût | Mots-clés | Texte (base) | Texte amélioré |
|---|---|---|---|---|---|
| Combattant expérimenté | Départ | 0 | melee, degats, defense | Inflige 4 "epee" à un ennemi OU 4 "bouclier" à un allié. | Inflige 6 "epee" à un ennemi OU 6 "bouclier" à un allié. |
| Coup appuyé | Départ | 1 | melee, degats | Inflige 6 "epee" et "Vulnerabilite" 2 à un ennemi. | Inflige 9 "epee" et "Vulnerabilite" 3 à un ennemi. |
| Coup de taille | Départ | 1 (0 amélioré) | melee, degats | Inflige 3 "epee" à tous les ennemis. | Coût 0. Inflige 3 "epee" à tous les ennemis. |
| Coup Contandant | Avancé | 1 | melee, degats | Inflige 4 "epee". Inflige 4 "epee" de plus si l'ennemi a du "bouclier" ou "Vulnerabilite". | Inflige 6 "epee". Inflige 6 "epee" de plus si l'ennemi a du "bouclier" ou "Vulnerabilite". |
| Avalanche de coups | Avancé | 1 | melee, degats | Inflige 4 "epee", son coût devient 0 jusqu'à la fin du combat. S'il tue la cible, revient en main. | Inflige 6 "epee", son coût devient 0 jusqu'à la fin du combat. S'il tue la cible, revient en main. |
| Riposte | Avancé | 2 | melee, degats, defense | Si "cibleennemi", annule l'attaque et inflige la moitié des dégâts en retour. | Si "cibleennemi", annule l'attaque et inflige la totalité des dégâts en retour. |

**Passe du 2026-09-02 (demande explicite) :**
- « Coup direct » renommée « Combattant expérimenté » (code interne inchangé, `coup-direct-guerrier`) et devient la première carte à utiliser le nouveau mode de ciblage `"enemy-or-ally"` (voir Notes de lecture ci-dessus) : le joueur choisit librement un ennemi (dégâts "epee") ou un allié (bouclier), jamais les deux à la fois sur le même lancer.
- « Coup de taille » : dégâts de base relevés de 2 à 3 "epee" ; son amélioration ne change plus les dégâts (reste 3) mais fait passer son coût de 1 à 0.
- « Coup d'estoc » renommée « Coup Contandant » (code interne inchangé, `coup-estoc`), aucun changement de mécanique.
- « Avalanche de coups » : texte clarifié pour préciser explicitement que le coût à 0 dure « jusqu'à la fin du combat » — la mécanique de reset entre combats existait déjà (dégâts 4 base/6 amélioré confirmés corrects, inchangés).
- « Riposte » : coût réduit de 3 à 2 ; le montant renvoyé reste proportionnel aux dégâts de l'attaque annulée (moitié/totalité), et ne se déclenche que contre une attaque de type dégâts (une Malédiction annulée ne renvoie rien) — mécanique inchangée depuis le 2026-08-28.

Historique : "Coup appuyé"/"Avalanche de coups" ont remplacé "Encaisser"/"Coup mortel" le 2026-08-28 — le Guerrier n'a donc plus de carte de bouclier propre en Départ, ce case du kit est devenu un 2ᵉ coup offensif.

## Paladin 🛡️

| Nom | Palier | Coût | Mots-clés | Texte (base) | Texte amélioré |
|---|---|---|---|---|---|
| Rempart | Départ | 1 | defense | L'allié ciblé gagne 4 "bouclier". Gagne 4 "bouclier". | L'allié ciblé gagne 6 "bouclier". Gagne 6 "bouclier". |
| Provocateur | Départ | 1 | defense | L'allié ciblé gagne 4 "bouclier". Gagne "Provocation" 2. | L'allié ciblé gagne 6 "bouclier". Gagne "Provocation" 3. |
| Infranchissable | Départ | 1 | defense | Gagne 10 "bouclier". Gagne 10 "bouclier" au début du prochain tour. Gagne "Provocation" 2. | Gagne 15 "bouclier". Gagne 15 "bouclier" au début des 2 prochains tours. Gagne "Provocation" 3. |
| Raillerie | Avancé | 2 | defense | L'ennemi ciblé cible le Paladin. Gagne 8 "bouclier". | L'ennemi ciblé cible le Paladin. Gagne 12 "bouclier". |
| Clairvoyance | Avancé | 0 | sort, amnesie | "Pioche" 1. Gagne 1 "energie". "soin" 4. "Amnesie" | "Pioche" 2. Gagne 1 "energie". "soin" 6. "Amnesie" |
| Lumière divine | Avancé | 2 | defense, soin, sort, amnesie | Tous les alliés gagnent 6 "bouclier". "soin" 4 à tous les alliés. "Amnesie" | Tous les alliés gagnent 9 "bouclier". "soin" 6 à tous les alliés. "Amnesie" |

Refonte complète du 2026-08-28 : "Coup direct"/"Encaisser" disparaissent totalement (remplacées par Provocateur/Infranchissable) — le Paladin n'a donc plus aucune carte de dégâts, devient un pur tank/support. "Provocation" (statut, +50% de chances d'être ciblé par les ennemis, -1/tour) est distinct de la carte "Raillerie" (ex-"Provocation", renommée pour éviter la confusion — effet inchangé : redirection immédiate d'un ennemi vers le Paladin, sans passer par le statut). Rempart : amélioration symétrique (avant le 2026-08-24, +5 pour soi / +6 pour l'allié). Clairvoyance/Lumière divine portent "Amnésie" : la carte disparaît de la rotation du combat en cours après avoir été jouée, revient au combat suivant.

## Mage 🔮

| Nom | Palier | Coût | Mots-clés | Texte (base) | Texte amélioré |
|---|---|---|---|---|---|
| Main de feu | Départ | 1 + 0 mana | melee, degats, feu | Inflige 2 "etincelle" à un ennemi. Gagne 1 mana. | Inflige 3 "etincelle" à un ennemi. Gagne 2 mana. |
| Barrière | Départ | 1 + 0 mana | defense | L'allié gagne 2 "bouclier". Gagne 1 mana. | L'allié gagne 3 "bouclier". Gagne 2 mana. |
| Missile magique | Départ | 1 + 1 mana | sort, distance, degats | Inflige 8 "etincelle". | Inflige 12 "etincelle". |
| Image miroir | Avancé | 1 + 1 mana | sort, defense | Gagne "Esquive" 2. | Gagne "Esquive" 3. |
| Tornade de feu | Avancé | 1 + 2 mana | sort, distance, degats, feu | Inflige 8 "fireball" à tous les ennemis. | Inflige 12 "fireball" à tous les ennemis. |
| Boule de feu | Avancé | 2 + 3 mana | sort, distance, degats, feu | Inflige 20 "fireball". | Inflige 30 "fireball". |

Seule classe dont les 2 cartes de base portent un nom propre ("Main de feu"/"Barrière") plutôt que "Coup direct"/"Encaisser" génériques. Main de feu/Barrière portent un `mana_cost` de 0 par souci de cohérence visuelle (la pastille de mana s'affiche ainsi sur les 6 cartes du Mage, pas seulement les 4 qui en dépensent réellement) — elles rapportent du mana au lieu d'en coûter. Main de feu est un vrai coup de feu magique (tag "feu" : déclenche la sensibilité au feu de l'Homme Arbre et bloque la Régénération du Troll, voir `docs/design/ennemis.md`), après un revirement (d'abord gardée physique/mêlée malgré son nom). Amélioration de Main de feu/Barrière relevée à 2 mana (avant : 1 mana comme la version de base, seuls les dégâts montaient).

## Assassin 🗡️

| Nom | Palier | Coût | Mots-clés | Texte (base) | Texte amélioré |
|---|---|---|---|---|---|
| Plan d'attaque | Départ | 1 | melee, degats, furtif | Si Camouflé, inflige 8 "epee", sinon inflige 4 "epee". "Furtif" | Si Camouflé, inflige 12 "epee", sinon inflige 6 "epee". "Furtif" |
| Se cacher | Départ | 1 | defense, furtif | L'Assassin gagne 8 "bouclier". "Furtif" | L'Assassin gagne 12 "bouclier". "Furtif" |
| Repli stratégique | Départ | 1 | defense, furtif | Si "cibleennemi", ces ennemis changent de cible pour l'allié ciblé, qui gagne 6 "bouclier" par ennemi. "Furtif" | Si "cibleennemi", ces ennemis changent de cible pour l'allié ciblé, qui gagne 9 "bouclier" par ennemi. "Furtif" |
| En traître | Avancé | 1 | melee, degats, furtif | Si Camouflé, inflige 6 "epee" et "Saignements" 3, reste Camouflé. "Furtif" | Si Camouflé, inflige 8 "epee" et "Saignements" 4, reste Camouflé. "Furtif" |
| Assassinat | Avancé | 1 | melee, degats, furtif | Si Camouflé, inflige 12 "epee", sinon gagne "Discrétion" 5, "Puissance" 2 et Assassinat va sur le dessus du deck. "Furtif" | Si Camouflé, inflige 18 "epee", sinon gagne "Discrétion" 10, "Puissance" 2 et Assassinat va sur le dessus du deck. "Furtif" |
| Préparation | Avancé | 1 | defense, furtif | Gagne 4 "bouclier", 1 "energie" et "Discrétion" 3. "Furtif" | Gagne 6 "bouclier", 2 "energie" et "Discrétion" 5. "Furtif" |

**Passe du 2026-09-02 (demande explicite) :**
- « Se cacher » ne cible plus un allié : cible désormais l'Assassin lui-même (`target = "self"`), et son bouclier passe de 4/6 à 8/12. La valeur améliorée (12) n'a pas été donnée explicitement par le porteur de projet — inférée par le même ratio ×1.5 que le reste du kit, pourrait encore changer.
- « Repli stratégique » réécrite : redirige désormais TOUS les ennemis dont l'action télégraphiée vise l'Assassin (pas un seul comme avant) vers l'allié ciblé, qui gagne 6 "bouclier" PAR ennemi redirigé (9 amélioré, également une valeur inférée par le même ratio, non confirmée explicitement) — plus aucun bouclier plancher inconditionnel : 0 bouclier si aucun ennemi n'est redirigé.
- « En traître » : coût réduit de 2 à 1, dégâts nerfés (8→6 base, 12→8 amélioré), ne donne plus de Discrétion (retiré du texte et de l'effet). « reste Camouflé » ajouté au texte par clarté seulement — déjà garanti par le tag "Furtif" (`Game.on_card_played` ne retire Discrétion/Camouflé que pour une carte non-Furtif), aucun changement de comportement réel sur ce point.
- « Assassinat » : la branche « pas Camouflé » (lot de consolation) monte de 2 à 5 Discrétion en base et de 3 à 10 en amélioré ; la Puissance accordée est désormais unifiée à 2 aux DEUX paliers (avant : 2 base / 3 amélioré).

Historique : refonte complète du 2026-08-28 (les 6 cartes remplacées d'un bloc, les 3 de Départ ont aussi changé de nom — ex-"Coup direct"/"Encaisser" génériques). Toutes tagguées "Furtif" : les jouer ne fait pas perdre Discrétion/Camouflé, et une carte Furtif défaussée sans avoir été jouée rapporte +2 Discrétion (voir `docs/design/glossaire.md`, texte de "Furtif" simplifié le 2026-09-02). "En traître" est entièrement conditionnelle à Camouflé — sans Camouflé, elle ne fait strictement rien (le coût est payé pour rien). Assassinat a perdu "et perd Camouflé" dès le 2026-08-28 (disparu du texte fourni) : la jouer ne fait plus perdre Discrétion/Camouflé du tout, qu'elle ait frappé en Camouflé ou non.

## Nécromancien 💀

Conçu avec agent_content (2026-08-29). `corruption_cost_cap` = coût variable en Corruption : X = tout ce que le Nécromancien peut fournir jusqu'à ce plafond, déduit automatiquement (jamais un choix du joueur), noté ci-dessous "0-N Corruption".

| Nom | Palier | Coût | Mots-clés | Texte (base) | Texte amélioré |
|---|---|---|---|---|---|
| Rite mineur | Départ | 1 (+0-3 Corruption) | sort, degats, soin | Inflige 6 "necrose" à un ennemi. Se soigne de 2×X. | Inflige 9 "necrose" à un ennemi. Se soigne de 3×X. |
| Sceau de faiblesse | Départ | 0 | sort, debuff | Perd 2 "PV". Applique "Vulnerabilite" 3 à un ennemi. | Perd 2 "PV". Applique "Vulnerabilite" 4 à un ennemi. |
| Voile d'ossements | Départ | 1 | defense | Perd 2 "PV" : l'allié ciblé gagne 1 "bouclier" par Corruption. | Perd 3 "PV" : l'allié ciblé gagne 2 "bouclier" par Corruption. |
| Pacte funeste | Avancé | 1 | sort, degats | Perd la moitié de ses "PV" actuels. Inflige 2 "necrose" par PV perdu à un ennemi. | Perd le tiers de ses "PV" actuels. Inflige 3 "necrose" par PV perdu à un ennemi. |
| Servant d'os | Avancé | 2 (+0-4 Corruption) | sort, degats | Inflige X "brut" à un ennemi aléatoire, au début des 3 prochains tours. | Inflige X "brut" à un ennemi aléatoire, au début des 4 prochains tours. |
| Communion des morts | Avancé | 1 (+0-6 Corruption) | sort, soin | Se soigne de 2×X. | Se soigne de 3×X. |

**Passe du 2026-09-02 (demande explicite, correction de comportement pur sans changement de texte affiché pour Rite mineur/Communion des morts) :**
- « Rite mineur »/« Communion des morts » plafonnent désormais leur dépense de Corruption au soin RÉELLEMENT nécessaire pour revenir à PV max (`def.heal_per_corruption`, voir `Game.resolve_pending`) — elles ne vident plus systématiquement toute la Corruption disponible si le héros a moins besoin. « Servant d'os » partage le même mécanisme de plafond en Corruption (`corruption_cost_cap`) mais sans `heal_per_corruption` (dégâts, pas soin) : non concerné par ce changement, continue de dépenser tout le plafond disponible.
- « Pacte funeste » : texte simplifié (ne mentionne plus « arrondi au supérieur » ni « Gagne autant de Corruption » — toujours vrai mécaniquement, juste retiré de l'affichage). Le multiplicateur de dégâts par PV perdu de la version améliorée passe de 2 à 3.
- « Voile d'ossements » entièrement réécrite. Avant : donnait un bouclier fixe à un allié + un bouclier scalé sur la Corruption au Nécromancien lui-même. Maintenant : le Nécromancien perd 2 PV (3 amélioré) — ce qui lui donne automatiquement de la Corruption via la mécanique générique « +1 Corruption par PV perdu » — puis l'ALLIÉ ciblé gagne 1 bouclier par Corruption du Nécromancien (2 par Corruption amélioré). Plus aucun bouclier flat, plus aucun bouclier pour le Nécromancien lui-même ; elle lit toujours la Corruption cumulée passivement (comme "Air belliqueux" côté Barde) sans jamais la dépenser, seulement la source du bouclier a changé.

Servant d'os n'a aucun effet garanti à X=0 (confirmé volontaire, pas un oubli) : rien n'est programmé si le Nécromancien n'a pas de Corruption à ce moment.

## Barde 🎵

Conçu avec agent_content (2026-08-29). "Inspiration" est un statut générique : n'importe quel héros peut le porter, pas seulement le Barde (voir `docs/design/classes.md`).

| Nom | Palier | Coût | Mots-clés | Texte (base) | Texte amélioré |
|---|---|---|---|---|---|
| Air belliqueux | Départ | 1 | melee, degats | Inflige 3 "epee" à un ennemi. +2 par charge d'Inspiration sur les alliés. | Inflige 5 "epee" à un ennemi. +3 par charge d'Inspiration sur les alliés. |
| Chœur de bataille | Départ | 1 | sort | Tous les alliés gagnent "Inspiration" 2. | Tous les alliés gagnent "Inspiration" 3. |
| Improvisation | Départ | 0 | sort | Gagne "Inspiration" 2. "Pioche" 1. | Gagne "Inspiration" 3. "Pioche" 1. |
| Dernier rappel | Avancé | 1 | sort | L'allié ciblé ne perd pas d'Inspiration à la fin de ce tour et gagne "Inspiration" 3. | L'allié ciblé ne perd pas d'Inspiration à la fin des 2 prochains tours et gagne "Inspiration" 5. |
| Bis | Avancé | 1 | sort | Si l'allié a de l'"Inspiration", elle est retirée et sa prochaine carte est "Gratuite" et jouée 2 fois. "Encore" | Si l'allié a de l'"Inspiration", elle est retirée et sa prochaine carte est "Gratuite" et jouée 3 fois. "Encore" |
| Rappel triomphal | Avancé | 2 | sort, defense | Tous les alliés gagnent "Inspiration" 2 et 6 "bouclier". | Tous les alliés gagnent "Inspiration" 3 et 9 "bouclier". |

**Passe du 2026-09-02 (demande explicite) :**
- « Air belliqueux » : dégâts de base nerfés de 5 à 3 (7→5 amélioré). Le bonus par charge d'Inspiration (+2/+3) ne change pas.
- « Dernier rappel » : le gain d'Inspiration passe de 2 à 3 en base, et de 3 à 5 en amélioré. La protection contre la décroissance ne change pas.
- « Bis » : coût réduit de 2 à 1. En plus de son effet existant (« Encore » — la prochaine carte de la cible se déclenche des fois supplémentaires), donne désormais aussi 1 charge de « Gratuite » à la cible (sa prochaine carte devient gratuite en plus de se déclencher plusieurs fois) — nouveau mot-clé générique du glossaire (voir `docs/design/glossaire.md`), pas propre au Barde.
- « Rappel triomphal » : coût réduit de 3 à 2.
- Écart de comportement signalé côté glossaire (pas un changement de texte de carte) : "Encore" ne se perd plus en fin de tour si inutilisé — persiste indéfiniment jusqu'à être consommé par la prochaine carte jouée par son porteur.

Historique : Air belliqueux lit passivement l'Inspiration cumulée de TOUS les alliés (comme Voile d'ossements côté Nécromancien) — mécanisme distinct de la consommation générique "+6 flat" d'Inspiration ; les deux peuvent s'appliquer sur le même coup si le Barde porte lui-même de l'Inspiration. Rappel triomphal remplace intégralement une carte antérieure ("Grand final", jugée trop compliquée à mettre en place) : effet plat inconditionnel, sans calcul par charge.

## Écarts et remarques transverses

- **Format de tableur totalement différent dans le GDD BMAD** (`gdd.md`, section cartes : colonnes Carte/Classe/Palier/Coût/Catégorie/Effet, sur les 4 classes MVP d'alors avec Transcendance) — obsolète, remplacé par le contenu ci-dessus. Ne pas s'y fier pour un seul nom de carte ou chiffre : quasiment toutes les cartes ont été rééquilibrées ou remplacées depuis (rééquilibrage complet du 2026-08-24, refontes Paladin/Assassin du 2026-08-28, ajout Nécromancien/Barde le 2026-08-29, rééquilibrage Guerrier/Assassin/Nécromancien/Barde le 2026-09-02).
- **Nécromancien et Barde pleinement jouables** : les deux classes, conçues avec agent_content (2026-08-29), sont sélectionnables à l'écran de choix d'équipe exactement au même titre que les 4 autres (`heroes.lua`/`Controller:enter_team_select`, aucun filtrage). Un commentaire de `cards.lua` affirmait un temps le contraire pour le Barde — corrigé depuis, plus de contradiction dans le code.
- **2 valeurs inférées, pas confirmées explicitement par le porteur de projet** (2026-09-02) : « Se cacher » amélioré (12 bouclier) et « Repli stratégique » amélioré (9 bouclier/ennemi) — voir la section Assassin ci-dessus. Déjà dans le code tel quel, documentées normalement sans marqueur "provisoire" dans le tableau, mais pourraient encore changer sur retour du porteur de projet.
