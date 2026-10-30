# Decisions log

One line per judgment call on an ambiguous PRD rule. Newest at bottom.

- 2026-10-29 — ∞ is stored as rank 10 internally, worth 11 chips; ranks above 9 for Sequences, never low.
- 2026-10-30 — Enabled `rendering/textures/vram_compression/import_etc2_astc` so the Web preset (mobile VRAM compression on) exports; without it export fails with an unprinted config error.
