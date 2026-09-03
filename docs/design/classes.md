# Classes

Reconstruit depuis le code le 2026-08-30 (`game/src/data/heroes.lua`). Remplace toute mention de classes/rôles dans le Google Doc et le GDD BMAD, obsolètes sur ce point (voir écarts en bas de page).

## Roster

Catalogue de 6 aventuriers débloqués (`Heroes.defs`). À l'écran "Choisis ton équipe", le joueur en sélectionne 4 parmi les 6 pour composer une run — aucune classe n'est filtrée ou verrouillée à cet écran. Équipe par défaut (utilisée uniquement quand aucune sélection explicite n'est fournie, ex. "Tester un boss" au menu) : Guerrier, Paladin, Mage, Assassin. Exception : le mode "Run Solo" (2026-09-02) réduit cette sélection à **1 seul** aventurier — voir `docs/design/modes.md`.

| Classe | Icône | PV de base | Ressource propre |
|---|---|---|---|
| Guerrier | ⚔️ | 36 | — (aucune) |
| Paladin | 🛡️ | 28 | — (aucune) |
| Mage | 🔮 | 20 | Mana |
| Assassin | 🗡️ | 24 | Discrétion |
| Nécromancien | 💀 | 24 | Corruption |
| Barde | 🎵 | 24 | — (aucune ressource propre, mais distribue "Inspiration") |

Ces PV ne sont pas un chiffre canon figé : le commentaire de tête de `heroes.lua` les qualifie explicitement de repères de test du prototype ("aucun montant n'est fixé au canon"), doublés le 2026-08-28 (18/14/10/12 → 36/28/20/24).

Une 7ᵉ ressource, l'Énergie, est partagée par toute l'équipe (pas propre à une classe) : la réserve globale est remise à 3 pile à chaque début de tour (`Game.TURN_START_ENERGY`), sans plafond en cours de tour si une carte en ajoute plus.

Entre deux combats d'une même run, seuls les PV persistent (blessures non soignées) ; toute ressource propre à une classe repart à un niveau fixe à CHAQUE nouveau combat (`carried_hero` dans `game/src/rules/game.lua`, même règle pour le tout premier combat via `fresh_hero`) — mais ce niveau fixe n'est pas toujours 0 :
- **Discrétion** (Assassin) et **Corruption** (Nécromancien) repartent à 0 à chaque combat, sans exception.
- **Mana** (Mage) repart à `MAGE_MANA_START` = 2 à CHAQUE combat (le tout premier compris) — une remise à niveau fixe non nulle, pas une ressource qui démarre vide. Le même principe que l'Énergie d'équipe en début de tour (voir ci-dessus), mais côté Mage et par combat plutôt que par tour.

## Rôle et mécanique propre, par classe

### Guerrier ⚔️ (36 PV)
Un combattant qui sait faire des dégâts. Aucune ressource propre, aucune mécanique identitaire au-delà de ses cartes — c'est la classe dégâts pure du roster.

### Paladin 🛡️ (28 PV)
Un défenseur qui aime protéger ses alliés. Depuis la refonte du 2026-08-28, le Paladin n'a plus aucune carte de dégâts : pur tank/support (bouclier, "Provocation", soin). Aucune ressource propre non plus — la Provocation qu'il génère est un statut de combat classique (décroît -1/tour), pas une ressource accumulée comme le Mana ou la Corruption.

### Mage 🔮 (20 PV)
A besoin de "Mana" pour lancer de puissants sorts. Mana : démarre TOUJOURS chaque combat à 2 (`MAGE_MANA_START`, une remise à niveau fixe — pas une ressource qui repart de zéro comme Discrétion/Corruption), ne régénère jamais tout seul en cours de combat — seules certaines cartes du Mage lui-même en accordent (Main de feu, Barrière : +1 base / +2 amélioré). Les autres cartes du Mage (Missile magique, Image miroir, Tornade de feu, Boule de feu) en consomment un montant fixe par lancer.

### Assassin 🗡️ (24 PV)
Gagne de la "Discrétion" en laissant ses alliés agir :
- +1 Discrétion quand un autre allié agit
- +5 s'il termine le tour sans avoir lui-même joué de carte
- Devient "Camouflé" à 10 Discrétion (plafond)
- Discrétion revient à 0 s'il joue une carte non-Furtif, ou dès qu'il subit une vraie perte de PV
- Toutes les cartes de l'Assassin portent le mot-clé "Furtif" : les jouer ne fait pas perdre Discrétion/Camouflé ; une carte Furtif défaussée sans avoir été jouée rapporte +2 Discrétion.

### Nécromancien 💀 (24 PV)
Dépense ses propres PV pour amasser de la "Corruption", puis la libère dans des rituels :
- +1 Corruption par PV perdu (dégâts subis ou PV sacrifiés par ses propres cartes)
- Repart à 0 Corruption à chaque nouveau combat
- Certaines cartes en dépensent jusqu'à un plafond variable propre à la carte pour amplifier leur effet (voir `docs/design/cartes.md`, colonne Coût — format "X (+0-N Corruption)")

### Barde 🎵 (24 PV)
Insuffle de l'"Inspiration" à ses alliés pour amplifier leur prochaine carte, quelle que soit leur classe :
- Inspiration : +6 flat au premier effet de dégâts/soin/bouclier du porteur, calculé AVANT les multiplicateurs (Vulnérabilité, Puissance, Incapacité)
- -1 charge à l'utilisation, ET -1 automatique en fin de tour (les deux peuvent se cumuler le même tour)
- Repart à 0 à chaque nouveau combat
- "Inspiration" est un statut générique : n'importe quel héros peut le porter (pas seulement le Barde), c'est le cœur de la synergie inter-classes du Barde — jouer une carte Barde PUIS une carte d'une autre classe dans le même tour.

## Écart code vs. anciens documents

Le GDD BMAD/Google Doc décrivent un système sensiblement différent de ce qui existe aujourd'hui — à nuancer classe par classe plutôt qu'un simple "tout est obsolète" :

- **Roster cible de 40 héros** : reste un objectif futur explicitement hors périmètre actuel (le code n'implémente que les 6 classes ci-dessus). Ce n'est pas une contradiction à corriger, c'est une roadmap non commencée — rien à signaler comme un écart, juste une portée différente.
- **"Transcendance"** : système décrit dans le GDD BMAD (bonus individuel par héros), entièrement absent du code actuel. À traiter comme intégralement retiré.
- **"Pouvoir de Classe"** (l'ancien système AUTOMATIQUE décrit dans le GDD BMAD — coups gratuits du Guerrier, réanimation du Paladin, "garder 1 carte" pour le Mage, Camouflage/Puissance automatiques en Concentration pour l'Assassin, retiré du code le 2026-08-09) : ce système précis-là est bien retiré en bloc et n'a jamais été réintroduit tel quel. Mais dire que "plus aucune classe n'a de mécanique identitaire" serait faux aujourd'hui — au cas par cas, une nouvelle mécanique/ressource propre à la classe joue désormais un rôle comparable pour certaines classes seulement :
  - **Nécromancien** : la Corruption (ressource + rituels) joue clairement ce rôle.
  - **Mage** : le Mana joue ce rôle.
  - **Assassin** : la Discrétion/Camouflé joue ce rôle.
  - **Barde** : l'Inspiration (bien que ce soit un statut générique qu'il distribue, pas une ressource qu'il porte lui-même) joue ce rôle.
  - **Guerrier** et **Paladin** : aucune ressource propre, aucune mécanique identitaire de ce type — leur identité tient uniquement à leurs cartes (dégâts purs pour l'un, tank/support pour l'autre).
- **Ligne Front/Back** : mécanique abandonnée avant même le code actuel (absente du tableur des classes refait le 2026-08-06, remplacée puis retirée avec le Pouvoir de Classe). Absente du code actuel, à traiter comme obsolète.
- **Nécromancien et Barde** : conçus avec agent_content (2026-08-29), tous deux pleinement jouables et sélectionnables à l'écran de choix d'équipe, exactement au même titre que les 4 autres classes (voir `docs/design/cartes.md`, section Barde).
