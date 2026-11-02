class_name Scorer
extends RefCounted
## Chips × Mult for an evaluated hand (PRD §4.2): the hand type, each scoring
## card (boss rules can zero them), then Axioms left to right
## (scripts/core/axiom_effects.gd), then the Prover's bonuses (Novel: +10
## Mult, the proven Conjecture: ×2 Mult) last.

const NOVEL_MULT := 10.0
const CONJECTURE_X := 2.0


class Breakdown:
	extends RefCounted
	var chips: int = 0
	var mult: float = 0.0
	var total: int = 0
	## Ordered tick-up steps for the UI: {"source": String, "chips": int,
	## "mult": float, "xmult": float (×, 0 = none), "kind": "hand" / "card" /
	## "axiom" / "prover"}.
	var steps: Array[Dictionary] = []


## level: the hand type's current level (1 = base). axioms: the run's Axiom
## data in slot order. ctx: {"rule": boss rule, "last_play": bool,
## "discards_used": int, "novel": bool, "conjecture": bool}.
static func score(result: HandEvaluator.Result, level: int = 1, axioms: Array = [], ctx: Dictionary = {}) -> Breakdown:
	var b := Breakdown.new()
	var t := result.hand_type
	b.chips = t.chips_at(level)
	b.mult = t.mult_at(level)
	b.steps.append({"source": t.name, "chips": b.chips, "mult": b.mult, "xmult": 0.0, "kind": "hand"})
	var rule: String = ctx.get("rule", "")
	for c in result.scoring:
		var chips := card_chips(c, rule)
		b.chips += chips
		b.steps.append({"source": c.label(), "chips": chips, "mult": 0.0, "xmult": 0.0, "kind": "card"})
	var actx := ctx.duplicate()
	actx["axioms_owned"] = axioms.size()
	for a: Dictionary in axioms:
		var step := AxiomEffects.apply(a, result, actx)
		if step.is_empty():
			continue
		_add(b, step)
	if float(ctx.get("relic_mult", 0.0)) > 0.0:
		_add(b, {"source": "OFFICE RELIC", "chips": 0, "mult": float(ctx.relic_mult), "xmult": 0.0, "kind": "axiom"})
	if ctx.get("novel", false):
		_add(b, {"source": "NOVEL", "chips": 0, "mult": NOVEL_MULT, "xmult": 0.0, "kind": "prover"})
	if ctx.get("conjecture", false):
		_add(b, {"source": "CONJECTURE", "chips": 0, "mult": 0.0, "xmult": CONJECTURE_X, "kind": "prover"})
	b.total = floori(b.chips * b.mult)
	return b


## A card's chips under a boss rule.
static func card_chips(c: Card, rule: String) -> int:
	if rule == "infinity_zero_chips" and c.rank == Card.INFINITY:
		return 0
	if rule == "primes_only_chips" and not c.is_prime():
		return 0
	return c.chips()


static func _add(b: Breakdown, step: Dictionary) -> void:
	b.chips += int(step.get("chips", 0))
	b.mult += float(step.get("mult", 0.0))
	var x := float(step.get("xmult", 0.0))
	if x > 0.0:
		b.mult *= x
	b.steps.append(step)
