# Hero Card Game — port LÖVE

Port du prototype `prototype/proto-cartes-completes/index.html` (JS/HTML, variante
"Run Infini" du 2026-08-06) vers [LÖVE](https://love2d.org/) (Lua), décidé en party
mode le 2026-08-06 : moteur de combat déjà validé au playtest, VFX/animations
détaillés volontairement remis à plus tard, Steam PC visé en premier (mobile et
manette de côté pour l'instant).

## Lancer le jeu

```
love game
```
(ou glisser le dossier `game/` sur `love.exe`).

## Lancer les tests

Le moteur de règles (`src/rules/*`, `src/data/*`) ne dépend d'aucune API LÖVE —
il se teste avec [busted](https://lunarmodules.github.io/busted/) en Lua pur,
depuis ce dossier :

```
cd game
busted
```

## Structure

```
main.lua          -- callbacks love.load/update/draw/mousepressed, juste le branchement
conf.lua           -- fenêtre LÖVE
src/
  data/             -- contenu : glossaire, héros, ennemis, cartes (tables pures)
  rules/            -- moteur de jeu pur, testable sans LÖVE :
                          combat.lua    dégâts/défense/soin/ciblage
                          deck.lua      deck/main/défausse
                          encounter.lua génération de rencontre (budget, niveaux)
                          draft.lua     draft de carte en fin de combat
                          game.lua      orchestrateur (tours, victoire/défaite, run)
  ui/               -- tout ce qui dépend de LÖVE :
                          controller.lua  colle les règles au rythme réel (Sequencer)
                          view.lua        rendu + calcul des rectangles cliquables
                          input.lua       souris -> appels Controller
                          theme.lua, fonts.lua
  util/
    sequencer.lua   -- remplace les chaînes async/await + setTimeout du JS
tests/              -- specs busted (moteur de règles uniquement)
libs/               -- vide pour l'instant — voir "Dépendances" ci-dessous
assets/             -- vide — pas d'art pour le moment, rendu en rectangles/texte
```

`src/rules` et `src/data` ne font jamais `require("love")` ni n'appellent
`love.*` — c'est la règle qui garde le moteur testable. Tout ce qui touche à
l'écran, la souris ou le temps réel vit dans `src/ui`.

## Ce qui a changé par rapport au prototype JS

- **Contrôles :** le prototype JS utilisait déjà la séquence à 3 taps (carte →
  héros → cible) comme raccourci volontaire de prototype — le Drag & Drop reste
  la cible de design du jeu final (voir `gdd.md` → Controls and Input). Ce port
  reprend la séquence à 3 taps, à l'identique du JS.
- **VFX/animations :** pulses et secousses sont approximés (le port ne
  reproduit pas les courbes d'easing CSS ni le vol des cartes pioche/défausse
  image par image) — décision explicite de la party du 2026-08-06 : le moteur
  d'abord, le feedback visuel après.
- **Tout le reste (règles) est un port fidèle**, y compris ses divergences
  actuelles avec `gdd.md` — signalées en commentaire dans `src/data/cards.lua`
  plutôt que corrigées silencieusement :
  - Coup mortel inflige 4 dégâts dans le code (gdd.md dit encore 3).
  - Provocation est palier "Avancé" dans le code (gdd.md dit "Départ").
  - Assassinat (10 dégâts si Camouflé) n'est pas marqué "brut" dans le code
    (gdd.md dit qu'il l'est — la Défense l'absorbe donc actuellement).
  - Le système "Run Infini" complet (bestiaire à 10 ennemis, scaling par
    niveau, budget de rencontre croissant, draft de carte après victoire,
    deck de départ à 10 cartes) n'est pour l'instant documenté nulle part
    dans `gdd.md`/`epics.md`.

  Aucune de ces divergences n'a été tranchée ici — le port suit le code, pas le
  GDD, par cohérence avec la demande ("réécrire le code du prototype"). À
  reconcilier avec `gdd.md` séparément si besoin (passage `gds-gdd`).

## Dépendances

Aucune bibliothèque tierce vendue pour l'instant (`libs/` est vide) : le
séquenceur d'animation est écrit pour ce port plutôt que d'inclure `hump`/
`tween.lua`/`anim8` sans pouvoir en vérifier le code exact depuis cet
environnement. Ce sont de bons candidats à ajouter dans `libs/` quand le
chantier VFX/animation démarrera pour de vrai (voir `anim8` en particulier
pour les sprite sheets idle/action/hit/KO du GDD).
