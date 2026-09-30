# Glossaire

Reconstruit depuis le code le 2026-08-30, **corrigé le même jour sur le rendu des icônes**, puis **mis à jour le 2026-08-30 (mana)**, puis **mis à jour le 2026-09-01 (Brûlure, nouveau statut du Volcan — voir `docs/design/bestiaire.md`)**, puis **mis à jour le 2026-09-02 ("or", "Puissance" corrigée, "Incandescence", puis "Furtif"/"Encore"/"Gratuite" suite à une session de rééquilibrage des cartes — voir `docs/design/cartes.md`)**, puis **mis à jour le 2026-09-30 (7 mots-clés du pilier du sacrifice + alias "camouflage" sur "Camouflé")** — voir encadrés ci-dessous. Source : `game/src/data/glossary.lua`, **44 entrées** (37 avant cette dernière passe). Tout mot-clé cité entre guillemets dans le texte d'une carte (`docs/design/cartes.md`), d'un effet des Statues de Temple (`docs/design/temple.md`) ou d'une description de classe (`docs/design/classes.md`) est reconnu depuis cette liste — c'est elle qui alimente l'infobulle explicative affichée au survol en jeu.

Deux familles : les termes "à icône" (`has_icon = true`, remplacés par un pictogramme + un mot court dans l'interface — épée, arc, feu...) et les statuts/mécaniques "texte" (`has_icon = false`, affichés en toutes lettres — la majorité des vrais effets de gameplay).

> **Mise à jour du 2026-09-30 — 7 mots-clés du pilier du sacrifice, alias "camouflage".** Relecture fraîche complète de `glossary.lua` (pas seulement les 7 entrées signalées) à la demande explicite du porteur de projet, en même temps que la reconstruction de l'onglet "Sacrifice" (`docs/design/sacrifice.md`) — voir `project_pilier-sacrifice-implemente.md`. 37 → **44 entrées**, aucun autre écart trouvé ailleurs dans le fichier (familles "à icône" et statuts pré-existants inchangés, "concentration" toujours sans carte qui l'utilise).
> 1. **7 nouvelles entrées texte** (Icone/Statut "no" pour les 7 — juste le texte entre guillemets sur la carte, comme Amnésie/Furtif) : **Mise à mort** (`miseamort`), **Héritage** (`heritage`), **meurt** (`meurt`), **Permanent** (`permanent`), **Survie** (`survie`), **Exaltation** (`exaltation`), **Vol de Vie** (`voldevie`) — voir le tableau des statuts ci-dessous et `docs/design/sacrifice.md` pour le détail complet du pilier (Legs/Héritage/Écho, les 24 cartes).
> 2. **`label` explicite sur "Mise à mort" et "Vol de Vie"** : ces deux clés fusionnent plusieurs mots sans espace (`normalize_kw`) — la clé brute ("miseamort", "voldevie") serait illisible une fois affichée sans icône, contrairement à un mot-clé à un seul mot (ex. "Vulnerabilite" → "Vulnérabilité" reste lisible en perdant juste l'accent). `label` corrige ce cas précis ; les 5 autres nouvelles entrées n'en ont pas besoin (mots uniques ou déjà présents à l'identique).
> 3. **"Camouflé" (`camoufle`) gagne l'alias "camouflage"** : plusieurs cartes du pilier écrivent `"Camouflage"` entre guillemets plutôt que `"Camouflé"` — même statut (`hero.camoufle`), désormais reconnu sous les deux formes. Même convention déjà utilisée pour concentration/concentre, cibleennemi/cibleenemi/ennemicible, saignement/saignements, brulure/brulures.
> 4. **"Survie" remplace l'ancien `death_ward` de "La Renaissante"** (Statue du Temple) : harmonisés sur ce même mécanisme unique (10 % des PV max au lieu de l'ancien 1 PV fixe). Correction de `docs/design/temple.md` faite depuis (2026-10-02, passe dédiée) : voir ce document pour la nuance "rechargée à chaque combat jusqu'à la 1ʳᵉ sauvegarde réelle, jamais ensuite" (donc "1 fois par run", pas "1 fois par combat").
>
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
| Camouflé (alias : camouflage) | Ne peut pas être ciblé par un ennemi. Retiré à tous les Camouflés dès qu'il ne reste plus aucun allié vivant et visible pour "couvrir" le groupe — sauf s'il ne reste plus qu'un seul aventurier vivant, auquel cas il reste Camouflé seul (2026-10-03). Retiré aussi dès que son porteur joue une carte (sauf "Furtif"). |
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
| Mise à mort | La carte qui la porte est détruite après utilisation (jamais reprise, contrairement à Amnésie qui revient au combat suivant). Déclenche l'Héritage (pas le Legs) de l'aventurier qui meurt en la jouant, que ce soit un auto-sacrifice ou un allié ciblé. Voir `docs/design/sacrifice.md`. |
| Héritage | Mot-clé générique, distinct de la catégorie de carte "Héritage du \<Classe\>" : à la mort de son porteur, dépose une carte Héritage en défausse au lieu d'un Legs. Aucune carte ne l'accorde encore à ce jour (2026-09-30) — posé en prévision d'un futur effet qui l'octroierait à un allié. |
| meurt | Met les PV à 0 directement (pas une simple perte de PV). Rien ne peut éviter cette mort : ni Défense, ni Bouclier, ni immunité — contrairement aux dégâts normaux, ce chemin ne passe jamais par la résolution de combat habituelle. |
| Permanent | Cible un allié : il gagne une icône dédiée au nom de la carte, qui lui donne le bonus décrit à tout instant, pour le reste du run (contrairement à un statut de combat classique, remis à zéro entre 2 combats). Mot-clé des cartes Legs/Héritage du pilier du sacrifice. |
| Survie | La prochaine fois que le porteur doit mourir, il reste en vie avec 10 % de ses PV max à la place — sauf une carte "Mise à mort", à laquelle rien n'échappe. Même mécanisme que "La Renaissante" (Statue du Temple, voir `docs/design/temple.md`), qui le recharge à chaque début de combat, mais seulement tant qu'il n'a jamais encore sauvé le porteur pour de vrai (une fois consommé pour de bon via la bénédiction, ne revient plus jamais du reste du run). |
| Exaltation | Les attaques magiques gagnent +X dégâts (flat, X = valeur actuelle), même principe qu'Incandescence mais pour la magie plutôt que le physique. Contrairement à Incandescence, décroît de 1 en fin de tour (comme Puissance). |
| Vol de Vie | Chaque fois que le personnage inflige des dégâts, il regagne X PV (X = valeur actuelle). -1 en fin de tour. |

## Notes

- "Vulnérabilité"/"Incapacité"/"Puissance" sont tous les trois des bonus **multiplicatifs** (+25%/-25%/+25% par stack pour Puissance uniquement), jamais composés en pourcentage entre eux — voir l'ordre de calcul documenté dans `Combat.deal_damage` : les bonus **additifs** (Inspiration +6, Incandescence +X, Exaltation +X) s'appliquent d'abord sur le montant de base, puis les multiplicateurs (Vulnérabilité/Puissance/Incapacité/sensibilité au feu) s'appliquent en une seule fois sur ce total. Incandescence s'applique aux dégâts physiques, Exaltation à la magie — sinon même principe, sauf qu'Exaltation décroît -1/tour (comme Puissance) alors qu'Incandescence ne décroît jamais.
- "Vol" est le seul statut de la liste qui court-circuite entièrement ce calcul : contre un porteur de Vol, tout dégât de type physique est ramené à 0, avant même d'appliquer les autres multiplicateurs.
- Convention d'accord : toujours au pluriel dans le texte des cartes ("Saignements"), jamais de parenthèse "(s)" — accord fautif accepté à X=1 plutôt que la parenthèse.

## Écart avec les anciens documents

Ni le Google Doc ni le GDD BMAD ne documentent ce glossaire sous cette forme (23 termes à l'origine côté prototype, 37 après la session du 2026-09-02, **44 aujourd'hui** avec les 7 mots-clés du pilier du sacrifice — Mise à mort/Héritage/meurt/Permanent/Survie/Exaltation/Vol de Vie) — le GDD BMAD ne connaît ni Discrétion/Camouflé, ni Corruption, ni Inspiration/Encore/Gratuite, ni Vol/Brûlure/Incandescence, ni "or", ni le pilier du sacrifice : ces mécaniques sont toutes postérieures à sa rédaction (2026-08-04). À traiter comme une lacune de couverture, pas une contradiction ligne à ligne.

**Écart interne à `docs/design/` signalé le 2026-09-30, corrigé le 2026-10-02 :** `docs/design/temple.md` décrivait encore "La Renaissante" avec l'ancien mécanisme ("reste vivant à 1 PV, 1 seule fois pour tout le run") — corrigé depuis (voir ce document pour le détail complet du mécanisme "Survie" harmonisé, y compris la nuance sur la recharge par combat limitée à la 1ʳᵉ sauvegarde réelle).
