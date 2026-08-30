# Bestiaire

Reconstruit depuis le code le 2026-08-30 (`game/src/data/enemies.lua` pour les stats/coups, `game/src/rules/encounter.lua` pour la génération de rencontre et la courbe de difficulté). Ce système ("Run Infini" : bestiaire à budget, scaling de niveau) n'est documenté nulle part dans le GDD BMAD/Google Doc — pas une contradiction, une absence totale côté anciens documents.

Toutes les valeurs ci-dessous sont celles de **niveau 1**. Chaque ennemi scale avec son niveau (voir Scaling, en bas de page) : les PV et les montants de coups affichés en jeu sont donc plus élevés dans un combat avancé du mode Infini.

## Ennemis courants (mode Infini)

| Ennemi | Icône | PV (Nv.1) | Coût (budget) | Ciblage | Coups |
|---|---|---|---|---|---|
| Gobelin Maraudeur | 👺 | 15 | 8 | Aléatoire (pondéré) | Griffure (épée, 4 dégâts, fréquent ~2/3) · Charge Brutale (💥, 7 dégâts, rare ~1/3) |
| Squelette Archer | 💀 | 12 | 6 | Aléatoire | Tir à l'Arc (arc, 4 dégâts, toujours) |
| Troll des Marais | 🧌 | 28 | 14 | Aléatoire | Coup de Massue (épée, 8 dégâts, fréquent ~2/3) · Régénération (+15 PV, rare ~1/3 — indisponible à PV pleins, annulée si le Troll a subi des dégâts "feu" pendant la phase joueur de ce tour) |
| Gobelourd | 🗿 | 20 | 10 | Aléatoire | Coup de Gourdin, alterne un tour sur deux : mode attaque (8 dégâts, sans bonus) / mode défense (3 dégâts, +3 bouclier ce tour) — attaque toujours, quel que soit le mode. 1 bouclier passif permanent (`shield_base`). |
| Loup Enragé | 🐺 | 10 | 9 | Aléatoire | Morsure (épée, 9 dégâts, toujours) — peu de PV, glass cannon |
| Araignée Venimeuse | 🕷️ | 12 | 7 | Aléatoire | Piqûre (☠️, 2 dégâts brut + "Saignements" 3, toujours) |
| Nécromancien Novice | 🧙 | 10 | 8 | Aléatoire | Malédiction ("Vulnérabilité" 3, aucun dégât direct, fréquent ~2/3) · Toucher Nécrotique (magique, 3 dégâts, rare ~1/3) — règle cachée ci-dessous |
| Golem de Pierre | 🪨 | 35 | 16 | Aléatoire | Poing de Pierre (épée, 7 dégâts, seulement s'il a subi des dégâts pendant la phase joueur de ce tour, sinon ne fait rien). 3 bouclier passif permanent, très gros PV. |
| Bandit Fourbe | 🔪 | 14 | 9 | **PV le plus bas** (déterministe) | Coup Sournois (épée, 6 dégâts, toujours — cible systématiquement le héros au moins de PV) |
| Chaman Gobelin | 🪄 | 12 | 8 | Aléatoire | Chant Rituel (soigne un allié blessé de 5 PV s'il y en a un) · sinon Chant Rituel (repli) (magique, 3 dégâts) |

**Règle cachée du Nécromancien Novice** (volontairement absente de tout texte affiché au joueur) : si aucun ennemi vivant n'inflige de dégâts directs ce tour une fois tous les télégraphes tirés, chaque Nécromancien Novice présent échange sa Malédiction contre Toucher Nécrotique — jamais un tour entièrement inoffensif côté monstres.

## Boss

Rencontre fixe, jamais mêlée à la génération aléatoire du mode Infini (`boss_only = true`, exclus du pool aléatoire). Tirée 50/50 entre les 2 boss disponibles à chaque appel (`Encounter.boss_encounter`), déclenchée depuis "Tester le boss" au menu ou en fin d'un run "bounded" (après le Refuge forcé du 9ᵉ combat, voir `docs/design/evenements.md`). Toujours niveau 1.

### Homme Arbre 🌳 — avec 4 Pousses d'Arbre 🌱

Composition fixe : 2 Pousses d'Arbre, Homme Arbre (centre), 2 Pousses d'Arbre (ordre d'affichage voulu, l'Homme Arbre au centre).

**Pousse d'Arbre** — 3 PV, coût 3, ciblage aléatoire.
- Griffure de Ronce (🌿, 2 dégâts, toujours)

**Homme Arbre** — 80 PV, coût 60, ciblage aléatoire. Sensible au feu : tout coup portant le tag "feu" (Main de feu/Boule de feu/Tornade de feu du Mage) lui inflige +50% de dégâts (`Combat.damage_multiplier`).
- Coup de Branche (🦴, épée, 8 dégâts à un aventurier — ~1/2 chance hors invocation)
- Onde Sylvestre (🍃, magique, 3 dégâts à tous les aventuriers — l'autre ~1/2 chance)
- Renaissance Sylvestre (🌱, ramène les Pousses d'Arbre vaincues à pleine vie — seulement possible si au moins une Pousse est morte, ~1/3 chance dans ce cas ; ne crée jamais de nouvelle Pousse, ressuscite seulement les 4 existantes)

Ses PV ont été remontés à 80 le 2026-08-24 (après un premier ajustement à 50), compensés par une vraie faiblesse exploitable (sensibilité au feu) plutôt que par un simple plafond de PV bas — ses propres dégâts (8/3) restent réduits.

### Aigle Géant 🦅

Seul, aucun sbire (contrairement à l'Homme Arbre) — tout son budget de PV/tours est porté par lui seul, PV base plus élevé pour compenser l'absence de sbires à abattre séparément.

**Aigle Géant** — 95 PV, coût 65, ciblage aléatoire.

Cycle à 2 temps :
- **Au sol** (`vol` = 0) : ~35% de chance de choisir Envol plutôt qu'attaquer ; sinon 50/50 entre Coup de Bec et Serres Tranchantes.
  - Coup de Bec (🦅, épée, 6 dégâts à un aventurier)
  - Serres Tranchantes (🦅, épée, 9 dégâts à un aventurier)
  - Envol (🩶, prend son envol : gagne le statut "Vol" + inflige 2 dégâts faibles à TOUS les aventuriers — un "vent tranchant" au décollage, volontairement plus bas que l'Onde Sylvestre de l'Homme Arbre car Vol est déjà un vrai avantage défensif en soi)
- **En vol** (`vol` > 0) : forcé sur Charge en Piqué, sa seule attaque disponible tant qu'il vole.
  - Charge en Piqué (🦅, épée, 14 dégâts à un aventurier — le ramène au sol, retire "Vol")

"Vol" réduit à 0 tout dégât de TYPE physique ("épée") pendant qu'il est actif — contraint le joueur à garder une source de dégâts magique/nécrotique sous la main pour ne pas perdre un tour complet de DPS à chaque envol. Contrairement à Incapacité/Vulnérabilité, "Vol" ne décroît jamais tout seul — seule sa propre Charge en Piqué le retire.

Deuxième boss ajouté le 2026-08-30 ("il faudrait un deuxième boss : un aigle géant") ; possède 2 illustrations distinctes (au sol / en vol), suit directement l'état `vol`.

## Composition de rencontre et courbe de difficulté (mode Infini)

- **Taille** : 1 à 4 ennemis par combat (`MAX_ENEMIES_PER_COMBAT = 4`).
- **Budget du combat n** : `round(20 × 1.12^(n-1))` (`BUDGET_BASE = 20`, `BUDGET_GROWTH = 0.12`). Ralentie le 2026-08-28 depuis 0.22 ("la montée moins forte, moins exponentielle") — reste exponentielle mais nettement aplatie sur la durée d'un run (ex. budget du combat 10 : ~120 avant, ~55 aujourd'hui, pour un même départ à 20). Toujours un placeholder à ajuster en playtest, pas un chiffre canon.
- **Génération** : 40 tentatives tirées au hasard (nombre d'ennemis 1-4, puis un ennemi au hasard dans le pool non-boss pour chaque emplacement, niveau = `round((budget/nb d'emplacements) / coût de l'ennemi)`, minimum 1) — la composition dont le coût total colle le mieux au budget est retenue.
- **Scaling par niveau** : `LEVEL_GROWTH = 0.20` (+20% par niveau, placeholder à tester) appliqué à toute valeur de base (PV, dégâts, soin, bouclier passif) ; `VALUE_VARIANCE = 0.20` (±20%) ajoute une variance aléatoire autour de cette valeur scalée à chaque tirage — d'où les fourchettes affichées en jeu plutôt qu'un chiffre unique.
- **Ciblage** (`Encounter.pick_hero_target`) :
  - Un héros Camouflé est exclu du pool de cibles tant qu'un autre héros vivant non-Camouflé existe.
  - Mode "lowest-hp" (Bandit Fourbe) : déterministe, cible toujours le héros au moins de PV parmi les visibles.
  - Mode "random" (tous les autres) : pondéré — chaque point de Discrétion du candidat retire 10% de poids relatif (jamais négatif) ; "Provocation" (Paladin) et la malédiction du Temple "Le Martyr" appliquent chacun ×1.5 au poids, cumulables entre eux si un même héros porte les deux.

## Écart avec les anciens documents

Le bestiaire du mode Infini (10 ennemis + budget de rencontre + scaling de niveau) et les 2 boss ne figurent dans AUCUN des deux anciens documents (Google Doc, GDD BMAD) — absence totale plutôt que contradiction, ce système a été construit après leur rédaction.
