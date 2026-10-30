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
