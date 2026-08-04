---
gdd: gdd.md
created: 2026-08-04
---

- (source) Inputs available at start: Game Brief (`_bmad-output/planning-artifacts/briefs/brief-HERO-CARD-GAME-2026-08-04/brief.md` + `addendum.md`), the user's own source GDD on Google Docs (linked in `docs/liens`, already extracted into the brief/addendum), and 3 evolving code prototypes (`prototype/mini-proto-2-cartes/`, `prototype/proto-4-heros-2-ennemis/`, `prototype/proto-deck-main-defausse/`) that already encode concrete, tested mechanics (individual energy, enemy telegraph+targeting, deck/hand/discard, class-locked special cards).
- (decision) Intent = Create (no prior gdd.md workspace existed).
- (note) resolve_customization.py could not run (no working python interpreter on this machine) — read `customize.toml` directly instead, no overrides present, proceeding with defaults.
- (gap→pending) Game type match: both "roguelike" and "card-game" genre guides match strongly (run structure/permadeath/meta-progression AND deck/hand/mana/turn-structure). Proposing to blend both into one GameType Specific Design section rather than picking one — to confirm with user.
- (decision by user) Working mode = Facilitative (not Express) — walking design-heavy sections conversationally before drafting.
- (decision by user) Game Pillars finalized, 4 total, each pressure-tested with the "cut it, what's left" test:
  1. Énergie individuelle par aventurier, pas un pool global.
  2. Les ennemis annoncent leurs actions à l'avance.
  3. Chaque run débloque quelque chose de significatif et permanent.
  4. Une troupe de 4 héros à identité individuelle et non interchangeable (PV/énergie/carte de classe propres, ennemis ciblent un héros précis) — REPLACES the brief's original pillar 4 ("un monde familier plutôt qu'original"), which pressure-tested as content/audience direction, not a gameplay pillar (demoted to Vision/Art Direction framing, not lost).
- (decision by user) Core Gameplay Loop confirmed as the RUN-level cycle (choisir 4 héros → quête → combats/événements → boss → déblocage → village → dépense → relance). The combat flow (pioche 5 → jouer cartes → résolution ennemie → tour suivant) is a sub-loop inside Core Gameplay, not a separate top-level loop or pillar.
