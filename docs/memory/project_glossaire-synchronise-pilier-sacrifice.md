---
name: glossaire-synchronise-pilier-sacrifice
description: Onglet "Glossaire" du Codex + docs/design/glossaire.md resynchronisés le 30/09/2026 avec les 7 mots-clés du pilier du sacrifice (37→44 entrées), plus l'alias "camouflage".
metadata:
  type: project
---

Le 30/09/2026, suite à la reconstruction de l'onglet "Sacrifice" (voir `project_pilier-sacrifice-implemente.md`), qui avait signalé le Glossaire comme non synchronisé, une passe dédiée a relu `game/src/data/glossary.lua` à neuf (pas seulement les entrées signalées) et mis à jour `docs/design/glossaire.md` + l'onglet "Glossaire" du Codex.

**Résultat de la relecture complète** : 37 → 44 entrées.
- **7 nouvelles entrées** (toutes `has_icon = false`, texte entre guillemets sur la carte) : Mise à mort (`miseamort`, `label` explicite car clé illisible sans lui), Héritage (`heritage`), meurt (`meurt`), Permanent (`permanent`), Survie (`survie`, remplace l'ancien `death_ward` de "La Renaissante" du Temple), Exaltation (`exaltation`), Vol de Vie (`voldevie`, `label` explicite même raison que Mise à mort).
- **1 alias ajouté à une entrée existante** : "camoufle" (Camouflé) gagne l'alias "camouflage" — plusieurs cartes du pilier écrivent `"Camouflage"` entre guillemets plutôt que `"Camouflé"`.
- **Aucun autre écart trouvé** ailleurs dans le fichier : la famille "à icône" (18 termes, tous confirmés avec leur PNG dans `game/assets/icons/keywords/`) et les 19 statuts texte pré-existants (Pioche à Gratuite) sont restés inchangés mot pour mot depuis la dernière reconstruction du 02/09/2026. "concentration" est toujours un terme du glossaire sans aucune carte qui l'utilise (vérifié par recherche dans `cards.lua`).
- **Écart repéré hors périmètre le 2026-09-30, corrigé le 2026-10-02** : `docs/design/temple.md` (et l'onglet "Statues de Temple" du Codex) décrivaient encore "La Renaissante" avec l'ancien mécanisme ("reste vivant à 1 PV, 1 seule fois pour tout le run") — voir `project_temple-survie-corrige.md` pour le détail de la correction.

**Fichiers modifiés** : `docs/design/glossaire.md` (comptes 37→44, nouvelle entrée d'historique en tête, alias Camouflé, 7 nouvelles lignes de tableau, note Exaltation/Incandescence dans "Notes", section "Écart avec les anciens documents" mise à jour + mention croisée du souci temple.md). Artifact Codex republié sur la même URL, version 20, label "glossaire-sync-pilier-sacrifice-2026-09-30" (en-tête de page, note dédiée dans l'onglet Glossaire, table des statuts, notes de calcul, section écart, ET les 2 mentions "pas encore synchronisé" dans l'onglet Sacrifice corrigées en "synchronisé").

**Pourquoi** : la reconstruction de l'onglet Sacrifice avait explicitement laissé ce point hors périmètre (demande initiale portait sur Sacrifice uniquement) — traité ensuite comme une passe dédiée, conforme à la méthode habituelle (un document déjà reconstruit se met à jour par relecture ciblée, pas par nouvel audit complet).

**Comment l'appliquer** : pour toute future demande touchant le Glossaire, repartir de `docs/design/glossaire.md` (44 entrées) + relecture ciblée de `glossary.lua`, comme pour les autres documents reconstruits.

**URL de l'Artifact** : https://claude.ai/code/artifact/7554fe23-0c31-4dfb-b10d-cc589dfc1345 (même URL que d'habitude) — version 20, label "glossaire-sync-pilier-sacrifice-2026-09-30".
