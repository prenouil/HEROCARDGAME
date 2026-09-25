---
name: pilier-sacrifice-proposition
description: Nouvel onglet "Sacrifice" du Codex — proposition de design non implémentée (mort volontaire, cartes Legs/Héritage), ajoutée le 2026-09-25, à ne jamais traiter comme état réel du jeu.
metadata:
  type: project
---

Le 2026-09-25, ajout explicitement demandé par l'utilisateur d'un nouvel onglet "Sacrifice 🚧" au Codex Hero Card Game (Artifact combiné, même URL que les 7 autres onglets — voir `project_avancement-reconstruction.md`), à partir du compte-rendu d'une session de brainstorming (party-mode) portée par Zgrubulu, PAS d'une relecture de code — aucun fichier `game/src/...` concerné.

**Contenu de l'onglet** : pitch ("Sacrificial Dungeon", titre de travail non confirmé), 9 décisions actées par Zgrubulu (sacrifice par carte existante, auto-sacrifice/fratricide décrits dans le texte de carte, fratricide sans seuil de PV, cartes de mort réservées au palier Avancé/Forge, 1 carte min. par classe, carte "Legs"/"Héritage" insérée en défausse à usage unique, cible toujours 1 seul allié jamais toute l'équipe, 2 tiers Legs=mort subie/Héritage=mort volontaire aux effets parfois différents, accumulation sur un "Élu" comme axe de deck-building), un tableau des 6 classes (répartition auto-sacrifice/fratricide — le PRINCIPE est validé, noms de cartes/effets NON validés, étiqueté comme tel), et une liste de questions ouvertes (cartes existantes vs nouvelles, détail de la "Victoire de l'Élu", renommage du jeu, rien n'est en Lua).

**Convention de rédaction établie pour ce type de contenu** (proposition non implémentée dans un Codex qui documente par ailleurs l'état réel du code) :
- Bandeau `.draft-banner` (nouvelle classe CSS, réutilise les tokens `--warn-bg`/`--warn-line` déjà existants pour rester theme-aware clair/sombre) en tête de section : "🚧 Proposition de design — non implémentée, non entièrement validée."
- Tag inline `.draft-tag` (pastille) sur chaque `<h2>` pour distinguer "validé par Zgrubulu" vs "principe validé, détails non validés" vs "non tranché" — le degré de validation varie PAR SECTION, jamais un seul bandeau générique pour tout.
- Un encart `.xref` en fin de section rappelle explicitement que cette proposition ne doit jamais être citée comme source de vérité par les autres onglets, et précise le chemin de migration si un jour implémentée (relecture fraîche du code, jamais recopie telle quelle).
- La note `src` en tête de section cite la session de brainstorming comme source (pas de fichier `game/src/...`), à l'inverse de tous les autres onglets.
- Footer-note de la page mise à jour avec une phrase d'exception expliquant que cet onglet n'a pas de fichier Markdown git-suivi correspondant dans `docs/design/` tant qu'il n'est pas validé/implémenté (volontaire — pas un oubli).

**Pourquoi :** l'utilisateur a explicitement encadré cette tâche comme une exception au mandat habituel d'agent_doc (documenter uniquement l'existant) — le livrable doit rester lisible comme brouillon distinct, jamais confondu avec les sections reconstruites depuis le code.

**Comment l'appliquer :** si une future demande porte sur CE pilier (affiner les décisions, ajouter des cartes, faire évoluer le tableau des 6 classes), repartir de cette section déjà écrite dans l'Artifact + relire ce fichier de mémoire, pas d'un nouvel audit du code (il n'y a rien à auditer, c'est un brouillon). Si le pilier est un jour implémenté en Lua, retraiter alors comme n'importe quelle reconstruction normale (relecture fraîche du code, migration vers `cartes.md`/nouveau document `docs/design/`, suppression ou requalification de cet onglet "Sacrifice").

**URL de l'Artifact republié** : https://claude.ai/code/artifact/7554fe23-0c31-4dfb-b10d-cc589dfc1345 (même URL que d'habitude, version 13 après cet ajout, label "sacrifice-proposition-2026-09-25"). Note : le résultat de publication a renvoyé un lien de la forme `https://claude.ai/artifact/<id-court>` — même artifact, format d'URL alternatif observé une fois, à surveiller si ça se reproduit.
