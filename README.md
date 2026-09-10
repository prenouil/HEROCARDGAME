# Hero Card Game (Run Infini)

Deck-builder roguelike solo en [LÖVE](https://love2d.org/)/Lua, 6 classes
jouables, système de Boss par biome, Temple de bénédictions/malédictions,
"Run Solo" pour une partie courte. Le jeu lui-même vit dans [`game/`](game/) —
voir [`game/README.md`](game/README.md) pour la structure du code et comment
lancer/lire le moteur.

## Lancer le jeu

```
love game
```
(ou glisser le dossier `game/` sur `love.exe`).

## Lancer les tests

Le moteur de règles (`game/src/rules/*`, `game/src/data/*`) ne dépend
d'aucune API LÖVE — il se teste en Lua pur avec
[Busted](https://lunarmodules.github.io/busted/). Les specs vivent dans
[`spec/`](spec/) à la racine (pas dans `game/`), et `.busted` à la racine
pointe déjà `lpath` vers `game/` pour que `require("src.rules.combat")`
fonctionne tel quel depuis les specs. Une fois l'environnement en place (voir
plus bas) :

```
busted
```

### Mettre en place Busted (Windows, sans Lua/LuaRocks/compilateur C au départ)

LuaRocks ne bundle jamais de compilateur C sur Windows (voir sa
[doc d'installation](https://github.com/luarocks/luarocks/blob/main/docs/installation_instructions_for_windows.md))
— il en faut un pour compiler les dépendances natives de Busted
(`luasystem`, `luafilesystem`). Chemin le plus court trouvé (2026-09-10),
avec [winget](https://learn.microsoft.com/windows/package-manager/winget/)
déjà présent sur Windows 10/11 :

1. **Lua 5.4 + LuaRocks** (un seul paquet) :
   ```
   winget install DEVCOM.Lua
   ```
2. **Un compilateur C** (MinGW-w64, ~200 Mo, pas besoin de Visual Studio) :
   ```
   winget install BrechtSanders.WinLibs.POSIX.UCRT
   ```
3. Fermer/rouvrir le terminal pour que le PATH voie les 2 installations.
4. **Busted et ses dépendances** :
   ```
   luarocks install busted
   ```
5. LuaRocks installe les commandes (`busted`) dans
   `%APPDATA%\luarocks\bin`, qui n'est PAS automatiquement sur le PATH côté
   Windows, et le script `busted` déployé est un script Lua brut (pas un
   `.exe`) : il faut un petit wrapper pour l'invoquer directement.
   - Ajouter `%APPDATA%\luarocks\bin` au PATH utilisateur.
   - Créer `%APPDATA%\luarocks\bin\busted.bat` :
     ```bat
     @echo off
     lua "%~dp0busted" %*
     ```
   - Persister `LUA_PATH`/`LUA_CPATH` (variables d'environnement
     utilisateur) avec la sortie de `luarocks path` (sinon `lua`/`busted` ne
     retrouvent pas les rocks installés) :
     ```
     luarocks path
     ```
     copier les valeurs `LUA_PATH`/`LUA_CPATH` affichées dans les variables
     d'environnement utilisateur du même nom (Panneau de configuration, ou
     `[System.Environment]::SetEnvironmentVariable("LUA_PATH", "<valeur>", "User")`
     en PowerShell).
6. Rouvrir un terminal, vérifier : `busted --version`.

Une fois ces variables/PATH en place, tout terminal ouvert par la suite les
voit automatiquement — cette installation ne se refait qu'une fois par
machine.

## Structure du repo

```
game/               -- le jeu LÖVE (voir game/README.md)
spec/               -- suite de tests Busted (moteur de règles, voir ci-dessus)
docs/design/        -- documentation de Game Design reconstruite depuis le
                        code réel (cartes, classes, bestiaire, Temple, modes,
                        glossaire) -- tenue à jour par un agent dédié
content/            -- mémoire de contenu (propositions de cartes/mécaniques)
tools/              -- scripts Node.js de génération d'images IA (assets)
prototype/          -- prototypes JS/HTML antérieurs au port LÖVE
_bmad/, _bmad-output/ -- outillage/artefacts BMAD (agents, workflows)
```

## Assets IA

`tools/generate-image.js` (Cloudflare Workers AI, gratuit/limité) et
`tools/generate-image-stability.js` (Stability AI, payant, en test parallèle)
génèrent les illustrations pixel art du jeu — voir les commentaires en tête
de ces fichiers pour l'usage et les clés requises dans `.env` (jamais commité).
