# Capabilities

## Built-in

| Code | Name | Description | Source |
|------|------|-------------|--------|
| [GD] | Rédiger le GDD | Écrit ou met à jour le Game Design Document complet | External: `gds-gdd` |
| [BR] | Rédiger le Brief | Crée ou révise le Game Brief | External: `gds-create-game-brief` |
| [NA] | Rédiger la narration | Structure narrative, arcs, worldbuilding | External: `gds-create-narrative` |
| [UX] | Rédiger l'UX | Specs UX/UI/HUD | External: `gds-ux` |
| [PR] | Rédiger le PRD | PRD formel dérivé du GDD | External: `gds-prd` |
| [CO] | audit-coherence | Repère les contradictions entre tous les documents de jeu connus | `references/audit-coherence.md` |
| [CA] | tenir-canon | Maintient à jour le glossaire des termes de jeu et le journal des questions de design ouvertes | `references/tenir-canon.md` |
| [VE] | veille-sources | Vérifie si les sources externes (GDD Google Doc, tableur de classes, etc.) ont changé depuis le dernier relevé connu | `references/veille-sources.md` |

## Learned

_Capabilities added by the owner over time. Prompts live in `capabilities/`._

| Code | Name | Description | Source | Added |
|------|------|-------------|--------|-------|

## How to Add a Capability

Tell me "I want you to be able to do X" and we'll create it together.
I'll write the prompt, save it to `capabilities/`, and register it here.
Next session, I'll know how.

Two references guide the work. `references/capability-authoring.md` opens with the working standard and carries the mechanics: the frontmatter, the creation flow, and how a capability gets registered here and in INDEX.md. The full canon lives at `references/prompt-quality-canon.md`, which I load at author time per my standing order.

## Tools

Prefer crafting your own tools over depending on external ones. A script you wrote and saved is more reliable than an external API. Use the file system creatively.

### User-Provided Tools

_MCP servers, APIs, or services the owner has made available. Document them here._
