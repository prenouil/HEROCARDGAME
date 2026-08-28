---
name: reset-ressource-par-combat
description: Intention de design confirmée — toute ressource propre à une classe (Mana, Discrétion, Corruption, future ressource) repart à sa valeur de base à chaque nouveau combat, sauf mention contraire explicite. Un décalage a été trouvé côté code actuel (Mana/Discrétion qui persistent) — c'est un bug à corriger côté implémentation, pas l'intention voulue.
metadata:
  type: reference
---

Règle générale confirmée (2026-08-28) : "en général, sauf avis contraire, les ressources spécifiques sont reset au début de chaque combat" — Discrétion → 0, Mana → sa valeur de départ (2), Corruption → 0, etc., à chaque nouvelle entrée en combat dans un run.

**Pourquoi :** intention de design explicite du porteur de projet. Une lecture précise de `game/src/rules/game.lua` (fonction `carried_hero`, appelée à chaque transition de combat) a montré que le code actuel remet à zéro les statuts de combat classiques (bouclier, esquive, camoufle, incapacité, vulnérabilité, puissance, saignements, provocation) mais PAS `hero.mana` ni `hero.discretion`, qui persistent donc tels quels d'un combat à l'autre dans le code existant. L'utilisateur a confirmé que ce n'est PAS voulu — c'est un décalage entre le code et l'intention réelle, à faire corriger côté implémentation (Mana et Discrétion devront eux aussi repartir à leur valeur de base à chaque combat).

**Comment l'appliquer :** pour toute proposition de contenu impliquant une ressource propre à une classe, partir du principe qu'elle repart à sa valeur de base à chaque nouveau combat (jamais un rattrapage rétroactif sur l'état du combat précédent), sauf si l'utilisateur précise explicitement le contraire pour cette ressource. Ne pas se fier à l'état actuel de `carried_hero` dans le code comme source de vérité sur l'intention — au moment de vérifier un comportement en jeu, distinguer "ce que fait le code aujourd'hui" (peut être un bug non encore corrigé) de "ce qui est voulu" (cette règle).