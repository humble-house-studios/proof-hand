# CLAUDE.md — Proof Hand

Instructions for Claude Code working in this repo. Read `docs/PRD.md` before any feature work; it is the source of truth for rules and numbers.

## What this is
A Balatro-style roguelike deckbuilder with a math-breakthrough skin, built in **Godot 4.3+ (GDScript)**. Mobile portrait first, tested as a web build in mobile Safari.

## How we work
- Build one milestone at a time, in the order in `docs/PRD.md` §11. Don't start the next milestone until the current one meets its done-definition.
- Small commits with clear messages, prefixed by milestone: `M1: hand evaluator + tests`.
- When a rule in the PRD is ambiguous, pick the simplest reading, note it in `docs/DECISIONS.md` (date + one line), and keep going.
- When tuning numbers, change `data/*.json`, not code.

## Architecture rules
- `scripts/core/` = pure game logic. `RefCounted` classes only, **no** `Node`, no scene references, no signals to UI. Fully testable headless.
- `scripts/ui/` and `scenes/` = rendering and input only. They read core state and call core methods.
- `scripts/autoload/` = `Game` (run state holder) and `Save` (Notebook persistence via `user://`).
- All content (hand types, Axioms, Lemmas, blinds, Prover lines) lives in `data/*.json`. Axiom effects are expressed as typed data (e.g. `{"type": "add_mult", "value": 4, "condition": {...}}`) interpreted by `scripts/core/axiom_effects.gd`.
- Use a seeded `RandomNumberGenerator` held by the run. Never call global `randi()`/`randf()` in core.
- Static typing everywhere in GDScript (`var x: int`, typed arrays, return types).

## Display rules
- Base viewport 1080×1920, stretch `canvas_items`, aspect `expand`. Don't change these.
- Build UI with Containers and anchors; no hard-coded absolute positions for layout.
- Touch targets ≥ 120 px. Keep important UI inside safe areas.
- Renderer must stay **Compatibility** (web export requirement).

## Commands
```bash
# Run tests (headless)
godot --headless --path . -s tests/run_tests.gd

# Export web build
godot --headless --path . --export-release "Web" build/web/index.html

# Serve the web build to test on a phone
python3 -m http.server 8080 --directory build/web
```
If `godot` isn't on PATH, install Godot 4.3+ (standard, not .NET) and its export templates first.

## Build pipeline and play link
Same pipeline as phone-pong and yes-and.
- `.github/workflows/deploy.yml` runs the tests, then builds the web version on
  every push to `main` and publishes it to GitHub Pages. A failing test stops
  the build.
- After each change: push to `main`, watch the Actions run until it passes
  (fix it if it doesn't), then send Samuel the play link with one line on what
  changed and what to playtest. Safari may need a pull-to-refresh.
- End every reply with a short summary of the last build (passed or failed,
  what it contained, any Godot errors), then the play link on the very last
  line: https://humble-house-studios.github.io/proof-hand/
- If GitHub Pages isn't on yet: repo → **Settings → Pages → Source: GitHub Actions.**

## Done-definition for every milestone
1. `tests/run_tests.gd` passes with zero failures.
2. Web export succeeds with no errors.
3. The feature works by touch in a portrait browser window.
4. Committed.

## Testing
- Every core class gets tests in `tests/test_<name>.gd`. Each test file extends `RefCounted` and exposes `func run() -> Array[String]` returning failure messages (empty = pass). `run_tests.gd` auto-discovers `test_*.gd`.
- Must-cover cases: each of the 9 hand types, hand priority order, Symmetry depends on **tap order**, ∞ ranks above 9 (not low), scoring-card selection, Axiom order (left→right) changes results, Novel bonus only on first-ever signature.

## Don't
- Don't add plugins/addons or C# without asking.
- Don't add network calls. The Prover is deterministic.
- Don't use real Millennium Problem names on screen.
