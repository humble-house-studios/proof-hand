class_name Prover
extends RefCounted
## The Prover (PRD §7): every Play has a signature (hand type + the Fields of
## its scoring cards). A signature never played on this save is Novel (+10
## Mult, written to the Notebook). Each run the Prover proposes one unseen
## signature as a Conjecture; playing it proves it (×2 Mult on that hand,
## and a locked Axiom joins the shop for good). Deterministic: no network.

## Hand types a Conjecture can ask for, with how many Fields they span.
## (Each rank exists once per Field, so a pair always spans 2 Fields, three
## of a kind 3; Same Field is 1.)
const CONJECTURE_SHAPES := [
	["identity", 2], ["double_identity", 3], ["trinity", 3],
	["sequence", 2], ["sequence", 3], ["same_field", 1],
]
const FIELD_NAMES: Array[String] = ["Number Theory", "Geometry", "Analysis", "Logic"]


static func signature(result: HandEvaluator.Result) -> String:
	return "%s|%s" % [result.hand_type.id, ",".join(fields_of(result.scoring).map(func(f: int) -> String: return Card.FIELD_GLYPHS[f]))]


static func fields_of(cards: Array[Card]) -> Array[int]:
	var out: Array[int] = []
	for c in cards:
		if not int(c.field) in out:
			out.append(int(c.field))
	out.sort()
	return out


## "Sequence over Analysis and Geometry."
static func readable(sig: String, types: Array[HandType]) -> String:
	var parts := sig.split("|")
	var name := parts[0]
	for t in types:
		if t.id == parts[0]:
			name = t.name
	var fields: Array[String] = []
	for g in parts[1].split(",", false):
		fields.append(FIELD_NAMES[Card.FIELD_GLYPHS.find(g)])
	if fields.size() <= 1:
		return "%s in %s" % [name, fields[0] if fields.size() == 1 else "nothing"]
	return "%s over %s and %s" % [name, ", ".join(fields.slice(0, fields.size() - 1)), fields.back()]


## An unseen signature for this run, or "" if everything's been seen.
static func propose(rng: RandomNumberGenerator, seen: Dictionary) -> String:
	var options: Array[String] = []
	for shape in CONJECTURE_SHAPES:
		for combo in _field_sets(int(shape[1])):
			var sig := "%s|%s" % [shape[0], ",".join(combo.map(func(f: int) -> String: return Card.FIELD_GLYPHS[f]))]
			if not seen.has(sig):
				options.append(sig)
	if options.is_empty():
		return ""
	return options[rng.randi_range(0, options.size() - 1)]


static func _field_sets(n: int) -> Array:
	var out: Array = []
	for mask in range(1, 16):
		var f: Array[int] = []
		for i in 4:
			if mask & (1 << i):
				f.append(i)
		if f.size() == n:
			out.append(f)
	return out


## A line from data/prover_lines.json, with {hand} / {fields} filled in.
static func line(lines: Dictionary, key: String, rng: RandomNumberGenerator, fill := {}) -> String:
	var opts: Array = lines.get(key, [""])
	var s: String = opts[rng.randi_range(0, opts.size() - 1)]
	for k in fill:
		s = s.replace("{%s}" % k, str(fill[k]))
	return s
