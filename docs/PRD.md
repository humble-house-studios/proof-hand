# Proof Hand — MVP PRD

**Working title:** Proof Hand
**Logline:** Play the hand. Submit the proof. Let the machine decide if you're a genius.
**Genre:** Roguelike poker-style deckbuilder (Balatro-like) with a math-breakthrough skin
**Engine:** Godot 4.3+ (GDScript), Compatibility renderer
**Platforms:** Mobile portrait first (tested as a web build in Safari). Steam landscape later.
**Status:** Pre-production MVP

---

## 1. Vision

You're a lone mathematician racing to crack "impossible" problems. Each hand you play is an **expression**; good expressions are **proofs**. An AI character, **The Prover**, checks every proof, rewards genuinely new discoveries, and between runs suggests the combo you should chase next. Every run teaches the next one.

No real math is required. Math is flavor: symbols, names, and vibes. The fun is Balatro's: build a busted engine of multipliers and watch the number go up.

### Design pillars
1. **Number go up.** Chips × Mult, with big, juicy count-ups.
2. **Order matters.** Tap order of cards is part of the hand (enables *Symmetry*). Axiom order matters too.
3. **The Prover remembers.** Persistent Notebook of discoveries drives meta-progression.
4. **One-thumb play.** Every action works with a single thumb on a phone in portrait.

### Non-goals (MVP)
- No real math, no real proof checking, no Lean integration.
- No LLM calls at runtime. The Prover is deterministic code + authored lines.
- No landscape/Steam layout (but use Containers so it's possible later).
- No accounts, cloud saves, monetization, or analytics.
- No endless mode, no unlockable decks, no challenge modes.

---

## 2. Core loop

```
Run Start (Prover proposes a Conjecture)
  → Ante 1: Lemma blind → Theorem blind → Boss Conjecture
     (after each cleared blind: Cash Out → Library shop)
  → Ante 2 → Ante 3
  → Win (all 3 bosses) or Lose (fail any blind)
  → Run Summary (new Notebook entries) → Run Start
```

A full run should take **15–20 minutes**.

---

## 3. Cards

**Deck:** 40 cards = 4 Fields (suits) × 10 ranks.

| Field | Glyph | Color |
|---|---|---|
| Number Theory | ℕ | Chalk gold |
| Geometry | △ | Chalk teal |
| Analysis | ∂ | Chalk violet |
| Logic | ⊢ | Chalk coral |

**Ranks:** 1–9 and **∞**. ∞ ranks above 9 (acts as 10 for Sequences, not low).
**Card chips:** equal to rank; ∞ = 11 chips.
**Primes:** 2, 3, 5, 7 (used by Axioms and the Ante 3 boss).

---

## 4. A blind (the play screen)

- Hand size **8**. Each blind: **4 Plays**, **3 Discards**.
- Select **1–5 cards**. **Tap order = play order.** Selected cards show a small order number.
- **Play** scores the selected cards. **Discard** replaces them. Draw back up to 8 after either.
- Before playing, the Prover panel previews the detected hand type and base Chips × Mult.
- Clear the blind when total score ≥ target. Fail if Plays hit 0 below target → run over.

### 4.1 Hand types

Priority top to bottom (first match wins). Levels come from Field Studies (§6).

| Hand | Rule | Base Chips | Base Mult | Per level |
|---|---|---|---|---|
| Infinite Series | 5-card Sequence, all one Field | 100 | 8 | +40 / +4 |
| Tautology | 4 of the same rank | 60 | 7 | +30 / +3 |
| Symmetry | 5 cards whose ranks read as a palindrome **in play order** (e.g. 3-7-1-7-3 or 4-9-4-9-4) | 50 | 5 | +30 / +3 |
| Same Field | 5 cards, one Field | 35 | 4 | +15 / +2 |
| Sequence | 5 consecutive ranks (any order) | 30 | 4 | +30 / +3 |
| Trinity | 3 of the same rank | 30 | 3 | +20 / +2 |
| Double Identity | 2 pairs | 20 | 2 | +20 / +1 |
| Identity | 1 pair | 10 | 2 | +15 / +1 |
| Lone Term | anything else | 5 | 1 | +10 / +1 |

**Scoring cards:** only cards that form the hand add chips (Lone Term = highest card; Identity = the pair; Trinity = the three; 5-card hands = all five).

### 4.2 Score formula

```
chips = hand.base_chips + Σ scoring card chips
mult  = hand.base_mult
for axiom in axioms (left → right): apply its +chips / +mult / ×mult effect
apply Prover bonuses (Discovery, Conjecture)   # last
score = floor(chips × mult)
```

Show it Balatro-style: chips (blue) and mult (red) tick up per card and per Axiom, then slam together.

---

## 5. Antes and blinds

| Ante | Lemma | Theorem | Boss | Boss rule |
|---|---|---|---|---|
| 1 | 300 | 450 | 600 — *The Sphere Problem* ("Already solved. Consider it a warm-up.") | ∞ cards score 0 chips |
| 2 | 800 | 1200 | 1600 — *The Speed of Knowing* | Only 3 Plays |
| 3 | 2000 | 3000 | 4000 — *The Hum of the Primes* | Only prime-rank cards score chips |

Boss names loosely nod to Millennium Problems (Poincaré, P vs NP, Riemann). Never use real names on screen. Numbers are first-pass; expect tuning.

---

## 6. Economy and the Library (shop)

**Currency:** Grant money ($). Start each run with **$4**.

**Cash out after each cleared blind:**
- Lemma $3, Theorem $4, Boss $5
- +$1 per unused Play
- Interest: +$1 per $5 held, max +$5

**Library stock (refreshed each visit):** 2 Axioms, 1 Lemma, 1 Field Study. **Reroll** $5, +$1 each reroll that visit. Sell an Axiom for half its price (rounded down).

### 6.1 Axioms (Jokers)
Max **5** slots. Drag to reorder. Applied left → right.

| Axiom | Effect | Price |
|---|---|---|
| Peano | +4 Mult | $4 |
| Euclid's Fifth | Same Field hands: +12 Mult | $5 |
| Prime Mover | Each scoring prime card: +3 Mult | $5 |
| Fermat's Margin | Hands of 3 or fewer cards: +30 Chips | $4 |
| Incompleteness | Last Play of a blind: ×3 Mult | $7 |
| Zeno | +2 Mult per Discard used this blind | $5 |
| Pythagoras | Trinity hands: +20 Mult | $5 |
| Cantor | ∞ cards count as any rank for Sequences | $6 |
| Euler's Identity | If scoring ranks sum to exactly 10: ×2 Mult | $6 |
| Fibonacci | Each scoring 1, 2, 3, 5 or 8: +8 Chips | $4 |
| Grant Writer | +$2 at cash out | $5 |
| Erdős Number | +2 Mult per Axiom owned | $6 |

**Locked (unlocked by proving Conjectures, §7):**

| Axiom | Effect | Price |
|---|---|---|
| Riemann's Hum | Each scoring prime card: ×1.5 Mult | $8 |
| Möbius | Symmetry hands: ×3 Mult | $8 |
| Occam's Razor | Lone Term and Identity hands: ×2 Mult | $6 |

### 6.2 Lemmas (consumables)
Hold max **2**. Use any time on the play screen.

| Lemma | Effect | Price |
|---|---|---|
| Substitution | Change up to 2 selected cards' rank by ±1 (permanent) | $3 |
| Generalize | Convert up to 3 selected cards to the Field of the first selected | $3 |
| Infinity Map | Turn 1 selected card into ∞ (permanent) | $3 |
| `sorry` | Instantly clear the current non-boss blind. +1 **Debt**. Each Debt raises boss targets by 25% for the rest of the run. | $6 (rare, 15% shop chance) |

### 6.3 Field Studies
Level up one hand type by 1 (see "Per level" column). $4.

---

## 7. The Prover (signature system)

The Prover is an AI character: cold, precise, a little smug. Visually a chalk-drawn eye or terminal cursor in a panel above the hand. It speaks in short lines from `data/prover_lines.json`.

### 7.1 Verdicts (every Play)
- **Verified.** Normal score.
- **Novel.** If the hand's **signature** has never been played on this save: **+10 Mult** Discovery bonus, a special stamp animation, and the signature is written to the **Notebook**.

**Signature** = `hand_type` + sorted set of Fields among scoring cards, e.g. `SEQUENCE|∂,△`. Readable form: "Sequence over Analysis and Geometry."

### 7.2 Notebook (persistent)
Saved to `user://notebook.json`: discovered signatures (with first-run number), proven Conjectures, unlocked Axioms, total runs, best score. Viewable from the title screen as a scrolling list of chalk entries.

### 7.3 Conjectures (meta-progression)
At **Run Start**, the Prover proposes one Conjecture: an unseen signature, weighted toward hand types the player has played least. Example line: *"I suspect a Symmetry over Logic and Number Theory is significant."*

- Shown pinned at the top of the play screen all run.
- Play it during the run → **"Proven."** That hand gets **×2 Mult**, and one locked Axiom is unlocked into the shop pool permanently.
- If all locked Axioms are unlocked, proving grants +$10 instead.

All deterministic. No network. (Future: optional LLM-written flavor lines, out of MVP scope.)

---

## 8. Screens

1. **Title** — Start Run, Notebook, Settings (sound on/off).
2. **Run Start** — Prover proposes the Conjecture. Tap to continue.
3. **Blind Select** — the 3 blinds of the current ante as chalk boxes; boss rule visible.
4. **Play** — see layout below.
5. **Cash Out** — itemized $ breakdown, count-up.
6. **Library** — shop.
7. **Run Summary** — win/lose, best hand, new Notebook entries, Conjecture result.

### Play screen layout (portrait, top → bottom)
- Top bar: blind name + target, current score, Plays, Discards, $
- Conjecture banner (one line)
- Axiom row (5 slots)
- Prover panel: detected hand + Chips × Mult preview, verdict stamps
- Lemma slots (2) at side
- Hand: 8 cards in a fan; tap to select (order number badge)
- Buttons: **Play**, **Discard**, **Sort** (rank / Field toggle)

---

## 9. Art, audio, feel

- **Look:** chalkboard + graph paper. Hand-drawn chalk glyphs, dusty white UI, the four Field colors as chalk.
- **Placeholder first:** flat shapes and system font are fine through M5.
- **Juice (M6):** card lift on select, chips/mult per-card tick-up, screen shake on big hands, chalk-dust particles, "NOVEL" rubber stamp.
- **Audio:** chalk taps, a rising tone per scoring step, a typewriter blip for the Prover. Placeholder SFX OK.

---

## 10. Technical requirements

- Godot **4.3+**, GDScript, **Compatibility** renderer (required for web export).
- Base viewport **1080 × 1920**, stretch mode `canvas_items`, aspect `expand`, portrait.
- All UI built with Containers/anchors so a landscape layout can be added later.
- Touch targets ≥ 120 px. Respect safe-area margins.
- **Logic/view separation:** all rules in `scripts/core/` as plain `RefCounted` classes with no node dependencies. Scenes only render state and forward input.
- **Data-driven:** hand types, Axioms, Lemmas, blinds, Prover lines live in `data/*.json`. Adding an Axiom with an existing effect type should need no code change.
- **Seeded RNG:** each run has a seed (shown on Run Summary) for reproducible bugs.
- **Tests:** headless test runner `tests/run_tests.gd` covers hand detection, scoring, Axiom effects, economy, and signatures.
- **Web export:** preset "Web" → `build/web/index.html`, threads off (no COOP/COEP headers needed) so it runs from a simple static server and opens in mobile Safari.
- Save via `user://` only.

---

## 11. Milestones (build order for Claude Code)

Each milestone ends with: tests pass, web build exports, playable in Safari, committed.

- **M0 — Scaffold.** Project opens, main scene runs, web export works. *(Scaffold provided.)*
- **M1 — Core engine.** Card/Deck/HandEvaluator/Scorer in `scripts/core/`, loading `data/hand_types.json`. Full tests for all 9 hand types incl. Symmetry order and ∞ rules.
- **M2 — Play screen.** Deal 8, tap-select with order badges, Play/Discard/Sort, live hand preview, score readout. One hard-coded blind.
- **M3 — Run structure.** 3 antes × 3 blinds, targets, boss rules, win/lose, Blind Select, Run Summary. Seeded RNG.
- **M4 — Economy.** Cash Out, Library, Axioms (all 12), Lemmas incl. `sorry`/Debt, Field Studies, reroll, sell, reorder.
- **M5 — The Prover.** Signatures, Novel bonus, Notebook save/load, Conjecture proposal + proof + unlocks, Prover lines.
- **M6 — Feel.** Count-up animations, stamps, particles, shake, SFX, chalk art pass.

---

## 12. Success criteria (MVP)

- A full run is completable on a phone in mobile Safari with no crashes.
- Run length 15–20 min; first-time players beat Ante 1 about half the time.
- At least one "busted build" moment per winning run (a hand ≥ 10× the blind's per-play average).
- Playtesters (3+) ask for another run unprompted.
- The Prover's Conjecture is something players actively chase by run 3.

## 13. Open questions

- Should Symmetry also work for 3-card palindromes (a-b-a) as a weaker hand?
- Should `sorry` be allowed on bosses at a much higher Debt cost?
- Does the Prover ever turn rival (steal unproven Conjectures) post-MVP?
- Name: *Proof Hand* vs *QED* vs something else.
