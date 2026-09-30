# Pilier du sacrifice

Source : `game/src/data/cards.lua` (défs `mise-a-mort-*` / `legs-*` / `heritage-*` / `echo-*`), `game/src/rules/game.lua` (`Game.kill_hero`, `Game.process_hero_deaths`, `convert_remaining_cards_to_echo`, `Game.grant_permanent_buff`, `Game.grant_camouflage`, `Game.gain_discretion`), `game/src/rules/combat.lua` (`Combat.effective_owner`, `Combat.can_play`, `Combat.deal_damage`), `game/src/data/glossary.lua`, `game/src/rules/draft.lua`, `game/src/rules/forge.lua`. Couvert par `spec/sacrifice_spec.lua` (tests d'intégration bout-en-bout) en complément de `game_turn_spec.lua`/`combat_spec.lua`.

Reconstruit le 2026-09-30 à partir d'une relecture fraîche du code : les 6 classes ont désormais chacune leurs 4 cartes définitives (Mise à mort / Legs / Héritage / Écho), ce n'est plus un contenu générique placeholder. Ce document remplace toute version antérieure de ce pilier comme brouillon de brainstorming (party-mode, 2026-09-25/26/28) — ce brouillon reste dans l'historique de la mémoire d'agent_doc mais n'est plus une source de vérité.

## Principe

À la mort d'un aventurier (infligée par un ennemi, ou provoquée volontairement via une carte "Mise à mort") :

1. Toutes ses autres cartes encore possédées (deck, main, défausse) se transforment en une carte générique **"Écho du &lt;Classe&gt;"**.
2. Une carte **Legs** (mort subie) ou **Héritage** (mort volontaire) est déposée directement dans la défausse du joueur.

Chaque classe a exactement 4 cartes dédiées à ce pilier, toutes tier "Avancé", coût 0 pour Legs/Héritage/Écho, avec `epuisement = true` (retirées du deck pour de bon une fois jouées) et `no_forge_upgrade = true` (jamais améliorables à la Forge, aucune exception).

## Mots-clés (`game/src/data/glossary.lua`)

| Mot-clé | Explication |
|---|---|
| **Mise à mort** | La carte est détruite après utilisation (jamais reprise, comme "Épuisement"). Déclenche l'**Héritage** (jamais le Legs) de l'aventurier qui meurt en la jouant — quel que soit qui joue la carte ou qui meurt (auto-sacrifice ou allié tué). |
| **Héritage** | Mot-clé générique, distinct de la catégorie de carte "Héritage du &lt;Classe&gt;" : à la mort de son porteur, dépose une carte Héritage en défausse au lieu d'un Legs. Aucune carte ne l'accorde à un tiers pour l'instant — posé en prévision. |
| **meurt** | Met les PV à 0 directement (`Game.kill_hero`), jamais via `Combat.deal_damage` — rien ne peut l'empêcher (ni Défense, ni Bouclier, ni immunité), **y compris Survie**. |
| **Permanent** | Cible un allié : le bonus décrit dure tout le reste du run (`hero.permanent_buffs`/`Game.grant_permanent_buff`), pas seulement le combat en cours. |
| **Survie** | La prochaine fois qu'il doit mourir de dégâts normaux (pas d'une carte "Mise à mort"), l'aventurier reste en vie à 10% de ses PV max à la place, puis se consomme. Remplace l'ancien `hero.death_ward` (1 PV fixe). |
| **Exaltation X** | Les attaques magiques gagnent +X dégâts (X = valeur actuelle), -1 en fin de tour. |
| **Vol de Vie X** | Soigne le porteur de X PV à chaque coup porté sur un ennemi, -1 en fin de tour. |

**Nuance Survie/La Renaissante** : la charge de Survie donnée par une carte (ex. Célébration Finale) ne se recharge jamais toute seule. La bénédiction du Temple "La Renaissante" la recharge, elle, à chaque entrée en combat — **mais une seule fois au total pour tout le run** : une fois qu'elle a réellement sauvé le héros, elle ne se réarme plus jamais (`hero.renaissante_used`), même à un combat bien plus tard.

## Mécanique générale (moteur, `game.lua`/`combat.lua`/`draft.lua`/`forge.lua`)

- **Legs vs Héritage** : toujours déterminé par la cause de la mort de qui MEURT (`voluntary` passé à `Game.kill_hero`), jamais par qui a joué la carte. Une carte "Mise à mort" pose systématiquement `voluntary = true`, donc toujours un Héritage — même quand elle tue un allié (fratricide) plutôt que son propre lanceur.
- **Dépôt direct en défausse**, jamais en main — le joueur doit repiocher la carte avant de la jouer.
- **Conversion en Écho AVANT dépôt du Legs/Héritage** (`Game.process_hero_deaths`) : évite que la carte tout juste déposée (de la même classe que le défunt) ne se reconvertisse elle-même.
- **Jouabilité posthume** : Legs/Héritage/Écho portent tous les trois `owner_can_be_dead` (2026-10-03, correction explicite — "c'est le propriétaire qui joue Legs/Héritage sur un allié ciblé, la même dynamique que pour l'écho") et restent jouables par leur propriétaire mort lui-même ("l'esprit du défunt"), jamais par un autre héros vivant de l'équipe. Le repli de `Combat.effective_owner` sur le premier héros vivant reste un mécanisme générique du moteur, mais aucune carte du pilier du sacrifice n'en dépend plus aujourd'hui.
- **Exclusion Draft** : Legs/Héritage/Écho portent `not_draftable`, jamais proposés en récompense. La carte "Mise à mort" reste normalement draftable, **mais son code rejoint `state.run.drafted_mise_a_mort` dès qu'elle est prise une première fois** — exclusion permanente du draft pour le reste du run, même après avoir été jouée et avoir disparu de toutes les piles (contrairement à une simple vérification "actuellement possédée").
- **Exclusion Forge** : les 4 familles portent `no_forge_upgrade = true`, filtré par `Forge.upgradable_instances`.
- **`exclude_self_target`** : sur les 4 cartes à `target = "ally"` (Barde, Assassin, Mage, Nécromancien), le lanceur ne peut jamais se choisir lui-même comme cible.
- **Camouflage et télégraphes** : devenir Camouflé (via 10 Discrétion ou directement via `Game.grant_camouflage`) annule l'action de tout ennemi qui visait déjà ce héros (`on_camouflage_gained`).
- **Axe "l'Élu"** : `hero.heritage_count` est incrémenté à chaque Héritage reçu par un héros (marqueur visuel affiché sur sa fiche), mais n'a aucun effet de jeu — laissé de côté pour l'instant.

## Qui bénéficie de l'effet immédiat

Contrairement à l'intention de design d'origine ("auto-sacrifice → un allié choisi par le joueur"), le code distingue en réalité 3 patterns différents :

- **Guerrier / Paladin** (auto-sacrifice pur, `target = "self"`) : l'effet immédiat touche les ennemis ou annule leurs actions — un bénéfice d'équipe, pas un allié désigné.
- **Barde** (auto-sacrifice, mais `target = "ally"` + `exclude_self_target`) : le lanceur meurt lui-même, mais désigne un allié DIFFÉRENT de lui pour recevoir "Survie".
- **Assassin / Mage / Nécromancien** (fratricide, `target = "ally"` + `exclude_self_target`) : la cible désignée meurt, le lanceur survit et encaisse lui-même tout le bénéfice immédiat.

## Les 24 cartes

### Guerrier ⚔️

<table>
<tr><th>Carte</th><th>Détail</th></tr>
<tr><td><strong>Baroud d'Honneur</strong> (Mise à mort, coût 2)</td><td>Condition : PV &lt; 30% max. Inflige 50 "epee" aux ennemis (répartis aléatoirement), puis meurt (Héritage).</td></tr>
<tr><td><strong>Technique du Maître</strong> (Legs, coût 0)</td><td>Permanent. Les cartes ciblant un ennemi infligent 2 "epee" de plus. (Renommé le 2026-10-03 — partageait "Puissance Ancestrale" avec l'Héritage, seule exception aux 5 autres classes qui ont toujours 2 noms distincts.)</td></tr>
<tr><td><strong>Puissance Ancestrale</strong> (Héritage, coût 0)</td><td>Permanent. "Puissance" 4 à chaque début de combat. Les cartes ciblant un ennemi infligent 2 "epee" de plus.</td></tr>
<tr><td><strong>Écho du Guerrier</strong></td><td>Base : inflige 3 "epee". Amélioré : 5.</td></tr>
</table>

### Paladin 🛡️

<table>
<tr><th>Carte</th><th>Détail</th></tr>
<tr><td><strong>Ultime Rédemption</strong> (Mise à mort, coût 2)</td><td>Condition : un ennemi vise un allié (jamais le Paladin lui-même) avec une action de dégâts. Annule TOUTES les actions ennemies, puis meurt (Héritage).</td></tr>
<tr><td><strong>Bouclier Spirituel</strong> (Legs, coût 0)</td><td>Permanent. "Bouclier" 3 à chaque début de tour.</td></tr>
<tr><td><strong>Pouvoir de l'amitié</strong> (Héritage, coût 0)</td><td>Permanent. "Bouclier" 6 à chaque début de tour. "Provocation" 3 à chaque début de combat.</td></tr>
<tr><td><strong>Écho du Paladin</strong></td><td>Base : un allié gagne 2 "bouclier". Amélioré : 4.</td></tr>
</table>

### Barde 🎵

<table>
<tr><th>Carte</th><th>Détail</th></tr>
<tr><td><strong>Célébration Finale</strong> (Mise à mort, coût 2)</td><td>Condition : le Barde est inspiré. Donne "Survie" à l'allié ciblé (≠ lui-même), puis meurt (Héritage).</td></tr>
<tr><td><strong>Chant du Cygne</strong> (Legs, coût 0)</td><td>Permanent. "Inspiration" 2 à chaque début de combat.</td></tr>
<tr><td><strong>Requiem</strong> (Héritage, coût 0)</td><td>Permanent. "Inspiration" 2 à chaque début de TOUR (cadence plus forte que le Legs, même valeur).</td></tr>
<tr><td><strong>Écho du Barde</strong></td><td>Base : un allié gagne 2 "inspiration". Amélioré : 3.</td></tr>
</table>

### Assassin 🗡️ (fratricide)

<table>
<tr><th>Carte</th><th>Détail</th></tr>
<tr><td><strong>Trahison Planifiée</strong> (Mise à mort, coût 2)</td><td>Condition : seulement 2 aventuriers vivants (exactement 2, pas "au moins 2" — corrigé le 2026-10-03). L'allié ciblé (≠ Assassin) meurt (Héritage). L'Assassin devient "Camouflage" et gagne "Puissance" 6 — gain instantané (2026-10-03, REVIREMENT : n'est plus un buff permanent, ne se réapplique plus aux combats suivants).</td></tr>
<tr><td><strong>Voile de Brume</strong> (Legs, coût 0)</td><td>PAS permanent — gain instantané unique : l'allié ciblé gagne "Esquive" 2.</td></tr>
<tr><td><strong>Prédateur</strong> (Héritage, coût 0)</td><td>Permanent (nature différente du Legs, pas juste plus fort) : l'allié gagne "Camouflage" immédiatement, puis "Camouflage" + "Esquive" 2 à chaque début de combat.</td></tr>
<tr><td><strong>Écho de l'Assassin</strong></td><td>Base : un allié gagne "Esquive" 1. Amélioré : 2.</td></tr>
</table>

### Mage 🔮 (fratricide)

<table>
<tr><th>Carte</th><th>Détail</th></tr>
<tr><td><strong>Transfert Interdit</strong> (Mise à mort, coût 2)</td><td>Condition : le Mage a 0 mana. L'allié ciblé (≠ Mage) meurt (Héritage). Le Mage gagne 10 "mana", "Exaltation" 5, et regagne tous ses PV.</td></tr>
<tr><td><strong>Étincelle de magie</strong> (Legs, coût 0)</td><td>Permanent. Les cartes de dégâts de l'aventurier gagnent 2 "étincelle" de plus.</td></tr>
<tr><td><strong>Arcane Oublié</strong> (Héritage, coût 0)</td><td>Permanent. Même bonus, +5 "étincelle" au lieu de +2.</td></tr>
<tr><td><strong>Écho du Mage</strong></td><td>Base : inflige 3 "etincelle". Amélioré : 5.</td></tr>
</table>

### Nécromancien 💀 (fratricide)

<table>
<tr><th>Carte</th><th>Détail</th></tr>
<tr><td><strong>Pacte de sang</strong> (Mise à mort, coût 2)</td><td>Condition : le Nécromancien est corrompu (Corruption &gt; 0). Gagne X PV max, X PV et X "Corruption" (X = PV actuels de l'allié ciblé, capturés avant sa mort). L'allié ciblé meurt (Héritage).</td></tr>
<tr><td><strong>Siphon de vie</strong> (Legs, coût 0)</td><td>PAS permanent — gain instantané unique : l'allié gagne "Vol de Vie" 3.</td></tr>
<tr><td><strong>Mangeur d'âme</strong> (Héritage, coût 0)</td><td>Permanent (nature différente du Legs) : l'allié gagne "Vol de Vie" 3 à chaque début de combat.</td></tr>
<tr><td><strong>Écho du Nécromancien</strong></td><td>Base : l'allié ciblé perd 2 "PV" et gagne 4 "bouclier". Amélioré : 10 "bouclier".</td></tr>
</table>

## Écarts et points ouverts

- **Répartition auto-sacrifice/fratricide** : le principe 3 classes auto-sacrifice (Guerrier, Paladin, Barde) / 3 classes fratricide (Assassin, Mage, Nécromancien) du brouillon d'origine est respecté, mais le Barde est un cas hybride (auto-sacrifice + ciblage d'un allié bénéficiaire) non anticipé par la dichotomie simple du brouillon.
- **Bénéficiaire de l'effet immédiat** : ne suit pas la règle générale actée en brainstorming ("auto-sacrifice → allié choisi") — Guerrier/Paladin bénéficient toute l'équipe (dégâts de zone / annulation d'actions), pas un allié désigné.
- **Legs = simple effet instantané vs Héritage = Permanent** pour l'Assassin et le Nécromancien (différence de NATURE, pas seulement de force) ; pour Guerrier/Paladin/Barde/Mage, Legs ET Héritage sont tous deux "Permanent" avec des valeurs différentes.
- **Axe "l'Élu"** (accumulation de Héritage) : `heritage_count` existe comme compteur visuel mais sans aucun effet de jeu — laissé de côté volontairement.
- **Glossaire du Codex** (`docs/design/glossaire.md`) ne référence pas encore les 6 mots-clés de ce pilier (Mise à mort, Héritage, meurt, Permanent, Survie, Exaltation, Vol de Vie) — à synchroniser dans une prochaine passe dédiée au Glossaire.
- Ce document remplace, comme source de vérité, le contenu de brainstorming party-mode (2026-09-25/26/28) qui proposait des noms/effets différents (ex. "Dernier Assaut", "Ultime Sacrifice", "Trahison"/"Lame Fantôme") — aucun de ces noms n'a été retenu tel quel dans le code final.
