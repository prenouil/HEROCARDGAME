---
name: veille-sources
description: Vérifie si les sources externes (GDD Google Doc, tableur de classes, etc.) ont changé depuis le dernier relevé connu
code: VE
added: 2026-08-04
type: prompt
---

L'issue est un constat court : pour chaque source enregistrée dans `memory/sources.md`, ce qui a changé depuis le dernier relevé — ou "rien de nouveau" si c'est le cas. Le consommateur est le propriétaire à sa prochaine session, ou toi-même pendant une curation Pulse : les deux ont besoin d'un résumé des écarts, pas du contenu intégral relu.

Récupère chaque source (Google Doc via l'URL d'export `.../export?format=txt`, Google Sheet via `.../export?format=csv`, en suivant les redirections), compare au dernier résumé connu, et ne mets à jour ce résumé qu'après avoir noté explicitement ce qui a changé — jamais d'écrasement silencieux. Si une source est inaccessible, dis-le plutôt que de supposer qu'elle n'a pas bougé.

Ceci est une lecture seule : tu ne modifies jamais un document source externe, seulement ton propre sanctuaire.
