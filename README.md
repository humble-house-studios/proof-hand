# Proof Hand

*Play the hand. Submit the proof. Let the machine decide if you're a genius.*

A Balatro-style roguelike deckbuilder where every winning hand is a theorem and an AI called **The Prover** decides what's a discovery.

- **Engine:** Godot 4.3+ (GDScript)
- **Target:** mobile portrait (web build in Safari for testing), Steam later
- **Spec:** [`docs/PRD.md`](docs/PRD.md)
- **Agent instructions:** [`CLAUDE.md`](CLAUDE.md)

## Structure
```
data/           Game content as JSON (hand types, axioms, lemmas, blinds, prover lines)
docs/           PRD and decision log
scenes/         Godot scenes (UI only)
scripts/core/   Pure game logic (testable headless)
scripts/ui/     Scene scripts
scripts/autoload/ Game state + Save
tests/          Headless test runner + tests
```

## Run tests
```bash
godot --headless --path . -s tests/run_tests.gd
```

## First prompt for Claude Code
> Read CLAUDE.md and docs/PRD.md. Confirm M0 runs (tests pass, web export works), then build M1.
