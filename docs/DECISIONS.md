# Decisions log

One line per judgment call on an ambiguous PRD rule. Newest at bottom.

- 2026-10-29 — ∞ is stored as rank 10 internally, worth 11 chips; ranks above 9 for Sequences, never low.
- 2026-10-30 — Enabled `rendering/textures/vram_compression/import_etc2_astc` so the Web preset (mobile VRAM compression on) exports; without it export fails with an unprinted config error.
- 2026-10-30 — Hand levels start at 1; level n adds (n−1) × the per-level chips/mult.
- 2026-10-30 — Rank-group hands (Tautology, Trinity, Double Identity, Identity) score every card of the matching rank(s); a 5-of-a-kind (possible via Substitution) is a Tautology scoring all 5.
- 2026-10-30 — 3+2 ("full house") is a Trinity by priority; only the three score.
- 2026-10-30 — Lone Term ties (equal highest rank) score the earliest card in play order.
- 2026-10-30 — Symmetry requires exactly 5 cards (3-card palindromes stay an open question, PRD §13).
- 2026-10-30 — Scorer keeps Mult as float (for future ×1.5 effects); score = floor(chips × mult).
- 2026-10-31 — M2 hand is two rows of four cards instead of a fan: bigger touch targets (232×360) with one thumb; a fan can come with the M6 art pass.
- 2026-10-31 — Bundled DejaVu Sans (fonts/, free license in fonts/DejaVu-LICENSE.txt): Godot's default font has no ℕ △ ∂ ⊢ ∞, and the web build can't fall back to system fonts.
- 2026-10-31 — M2's one hard-coded blind is Ante 1's Lemma (target, Plays, Discards and hand size read from data/blinds.json); each new blind gets a fresh seed, shown at the bottom.
- 2026-10-31 — If the deck runs dry mid-blind the hand stays short (no reshuffle), as in Balatro.
- 2026-10-31 — Rank sort is high→low then Field; Field sort is ℕ△∂⊢ then high→low. Sorting never changes the tap order of selected cards.
- 2026-11-02 — Ante 2 and 3 targets raised (1000/1500/2300, 3200/4800/7500): with the PRD numbers an autopilot that always plays the best hand won 80% of runs; now ~30%, so bosses are a real wall and Axioms matter (tools/tune.gd).
- 2026-11-02 — The Prover coaches during Ante 1 only: "Best you hold: Trinity" and SHOW ME (selects it). From Ante 2 on, finding the hand is the player's job.
- 2026-11-02 — Substitution raises the rank by 1 (up to ∞) instead of ±1: one tap, no direction picker on a phone.
- 2026-11-02 — Blind Select is a single intro card per blind (ante ladder, target, boss rule, PROVE IT); skipping blinds isn't in the MVP.
- 2026-11-02 — Axiom reorder is a ◀ button in the Library (dragging is fiddly with one thumb).
