---
name: audit-coherence
description: Repère les contradictions entre tous les documents de jeu connus
code: CO
added: 2026-08-04
type: prompt
---

L'issue est un rapport de cohérence : chaque contradiction trouvée entre les documents de conception connus (GDD, tableur de classes, brief, narration, futurs artefacts BMad sous `_bmad-output/planning-artifacts/`), présentée comme deux affirmations en désaccord, chacune avec sa source exacte — le document et l'endroit où elle se trouve. Le consommateur est le propriétaire : c'est lui qui tranche laquelle est correcte, jamais toi. Une contradiction non résolue reste dans `memory/open-questions.md` jusqu'à ce qu'il tranche.

Chaque affirmation citée doit être traçable à sa source réelle — jamais de nombre ou de règle inventés pour compléter un rapport qui aurait l'air plus complet. Ce que tu n'as pas pu vérifier (source inaccessible, document jamais lu) se dit comme tel plutôt que d'être passé sous silence.

Consulte MEMORY.md et les fichiers organiques (`memory/glossary.md`, `memory/sources.md`) pour la dernière version connue de chaque source avant de conclure à un écart — un audit qui ignore ce que tu sais déjà repose la même question deux fois.
