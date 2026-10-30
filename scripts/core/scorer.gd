class_name Scorer
extends RefCounted
## Chips × Mult for an evaluated hand. Axioms and Prover bonuses plug in
## after the card step in later milestones (PRD §4.2).


class Breakdown:
	extends RefCounted
	var chips: int = 0
	var mult: float = 0.0
	var total: int = 0
	## Ordered tick-up steps for the UI: {"source": String, "chips": int, "mult": float}.
	var steps: Array[Dictionary] = []


## level: the hand type's current level (1 = base).
static func score(result: HandEvaluator.Result, level: int = 1) -> Breakdown:
	var b := Breakdown.new()
	var t := result.hand_type
	b.chips = t.chips_at(level)
	b.mult = t.mult_at(level)
	b.steps.append({"source": t.name, "chips": b.chips, "mult": b.mult})
	for c in result.scoring:
		b.chips += c.chips()
		b.steps.append({"source": c.label(), "chips": c.chips(), "mult": 0.0})
	b.total = floori(b.chips * b.mult)
	return b
