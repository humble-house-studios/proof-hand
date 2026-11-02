class_name AxiomEffects
extends RefCounted
## Interprets an Axiom's typed effect (data/axioms.json, PRD §6.1) against a
## played hand. Returns one tick-up step ({source, chips, mult, xmult, kind})
## or {} when it doesn't trigger. Rule-type effects (Cantor) change the hand
## evaluator instead; cash-out effects pay at cash out (ProofRun).
##
## ctx: {"last_play": bool, "discards_used": int, "axioms_owned": int}.


static func apply(axiom: Dictionary, result: HandEvaluator.Result, ctx: Dictionary) -> Dictionary:
	var e: Dictionary = axiom.get("effect", {})
	var cond: Dictionary = e.get("condition", {})
	var v := float(e.get("value", 0))
	var step := {"source": axiom.get("name", "?"), "chips": 0, "mult": 0.0, "xmult": 0.0, "kind": "axiom"}
	match str(e.get("type", "")):
		"add_mult":
			if not hand_ok(cond, result, ctx):
				return {}
			step.mult = v
		"add_chips":
			if not hand_ok(cond, result, ctx):
				return {}
			step.chips = int(v)
		"x_mult":
			if not hand_ok(cond, result, ctx):
				return {}
			step.xmult = v
		"add_mult_per_card":
			var n := _matching_cards(cond, result)
			if n == 0:
				return {}
			step.mult = v * n
		"add_chips_per_card":
			var n := _matching_cards(cond, result)
			if n == 0:
				return {}
			step.chips = int(v) * n
		"x_mult_per_card":
			var n := _matching_cards(cond, result)
			if n == 0:
				return {}
			step.xmult = pow(v, n)
		"add_mult_per_stat":
			var n := int(ctx.get(str(e.get("stat", "")), 0))
			if n <= 0:
				return {}
			step.mult = v * n
		_:
			return {}
	return step


## Hand-level conditions: hand / hand_in / max_cards / last_play / rank_sum.
static func hand_ok(cond: Dictionary, result: HandEvaluator.Result, ctx: Dictionary) -> bool:
	if cond.has("hand") and result.hand_type.id != str(cond.hand):
		return false
	if cond.has("hand_in") and not result.hand_type.id in cond.hand_in:
		return false
	if cond.has("max_cards") and int(ctx.get("played", result.scoring.size())) > int(cond.max_cards):
		return false
	if cond.has("last_play") and bool(cond.last_play) != bool(ctx.get("last_play", false)):
		return false
	if cond.has("rank_sum"):
		var s := 0
		for c in result.scoring:
			s += c.rank
		if s != int(cond.rank_sum):
			return false
	return true


## Scoring cards a per-card condition matches (card: prime / card_ranks).
static func _matching_cards(cond: Dictionary, result: HandEvaluator.Result) -> int:
	var n := 0
	for c in result.scoring:
		if cond.get("card", "") == "prime" and not c.is_prime():
			continue
		if cond.has("card_ranks") and not float(c.rank) in cond.card_ranks.map(func(x) -> float: return float(x)):
			continue
		n += 1
	return n


## Does any owned Axiom switch on this rule ("infinity_wild_sequence")?
static func has_rule(axioms: Array, rule: String) -> bool:
	for a: Dictionary in axioms:
		var e: Dictionary = a.get("effect", {})
		if e.get("type", "") == "rule" and e.get("rule", "") == rule:
			return true
	return false


## $ an Axiom pays at cash out (Grant Writer).
static func cash_bonus(axioms: Array) -> int:
	var n := 0
	for a: Dictionary in axioms:
		var e: Dictionary = a.get("effect", {})
		if e.get("type", "") == "cash_out_bonus":
			n += int(e.get("value", 0))
	return n
