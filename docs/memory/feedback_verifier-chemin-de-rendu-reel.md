---
name: verifier-chemin-de-rendu-reel
description: Un champ de données (ex. `icon` dans glossary.lua) peut ne jamais être consommé par le vrai chemin de rendu du jeu — toujours vérifier ce qui s'affiche réellement à l'écran avant de le documenter comme un fait.
metadata:
  type: feedback
---

Erreur commise le 2026-08-30 sur `docs/design/glossaire.md` : j'ai documenté le champ `icon` de `game/src/data/glossary.lua` (emoji Unicode, ex. "⚔️" pour épée, "🔵" pour mana) comme si c'était l'icône réellement affichée en jeu. FAUX — le rendu réel du texte des cartes (`RichText.draw` dans `game/src/ui/richtext.lua`, via `Sprites.keyword` dans `game/src/ui/sprites.lua`) charge un PNG pixel-art dédié dans `game/assets/icons/keywords/<clé>.png`, jamais ce champ `icon`. Le commentaire en tête même de `glossary.lua` le disait déjà explicitement (`label` = vrai repli texte utilisé par la UI, `icon` = "vraie donnée de design ... pour un rendu capable de les afficher plus tard") — un signal que j'ai lu mais pas suivi jusqu'au bout la première fois.

**Pourquoi :** un fichier de données (`heroes.lua`, `cards.lua`, `glossary.lua`, `enemies.lua`...) peut contenir des champs cosmétiques ou legacy jamais réellement consommés par le code de rendu (UI/`view.lua`/`sprites.lua`/`richtext.lua`). Documenter un champ de données sans vérifier son chemin de consommation réel revient à documenter une intention, pas le jeu tel qu'il se joue.

**Comment l'appliquer :** avant de documenter un champ de data comme un fait visible en jeu (icône, libellé, couleur...), toujours `grep` où ce champ est effectivement LU (pas seulement où il est déclaré) — remonter jusqu'au code de rendu UI. Si le champ n'est lu nulle part dans ce chemin, le signaler explicitement comme "métadonnée non utilisée" plutôt que de le présenter comme un fait de jeu. Vaut pour toute future section touchant des assets/icônes/labels (pas seulement le Glossaire).

**Mise à jour du 2026-08-30 :** "mana" n'est plus une exception — `game/assets/icons/keywords/mana.png` a été créé et les 4 mentions `"mana"` de `cards.lua` (Main de feu/Barrière, base+amélioré) ont reçu leurs guillemets. Les 17 termes "à icône" de `glossary.lua` ont désormais tous un PNG dédié. `docs/design/glossaire.md` et l'Artifact ont été corrigés en conséquence (plus de paragraphe "cas particulier mana").
