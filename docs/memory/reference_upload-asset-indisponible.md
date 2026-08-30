---
name: upload-asset-indisponible
description: L'action upload_asset de l'outil Artifact échoue systématiquement (unavailable_to_account) sur ce compte — impossible d'embarquer de vraies images (PNG) dans un Artifact via ce chemin, ni via data: URI faute d'outil d'exécution de script.
metadata:
  type: reference
---

Testé le 2026-08-30 : `Artifact` avec `action: "upload_asset"` échoue pour TOUT fichier (testé sur 17 PNG de `game/assets/icons/keywords/`) avec l'erreur `asset upload failed (unavailable_to_account): artifact assets are not available to this account`. C'est une restriction au niveau du compte, pas liée à un fichier particulier ni à la déclaration de la capability `assets` sur l'Artifact — retenter avec un autre fichier ou après avoir déclaré la capability ne change rien.

agent_doc n'a pas non plus d'outil shell/bash dans cet environnement (voir aussi `feedback_verifier-chemin-de-rendu-reel.md` / mémoire d'avancement) : donc pas de moyen d'encoder un PNG en `data:` URI à la main pour le glisser directement dans le HTML de l'Artifact.

**Conséquence concrète :** dans l'onglet Glossaire de l'Artifact "Codex Hero Card Game", la colonne "Icône en jeu" ne peut afficher que le **nom du fichier PNG réel** (`epee.png`, `mana.png`...), jamais l'image elle-même — malgré une demande explicite de l'utilisateur d'afficher l'icône. Une note visible dans l'Artifact (encadré `.note`) explique cette limite au lecteur plutôt que de la passer sous silence.

**Pourquoi :** éviter de re-tenter `upload_asset` à chaque demande future de "vraie icône dans l'Artifact" (perte de temps, échec garanti) et éviter de prétendre à tort que la limite vient d'un fichier ou d'une capability mal déclarée.

**Comment l'appliquer :** avant de proposer d'afficher une image réelle dans un Artifact publié depuis ce compte, vérifier d'abord dans cette entrée si `upload_asset` a déjà été testé indisponible. Si l'utilisateur insiste pour voir les vraies icônes, les options restantes sont : (a) attendre que la fonctionnalité soit activée sur le compte, (b) lui demander de fournir directement les images en pièce jointe/collées dans la conversation (susceptible de fonctionner différemment de `upload_asset` sur fichier local), (c) se limiter au Markdown + ouverture directe des PNG sources comme référence visuelle hors Artifact.
