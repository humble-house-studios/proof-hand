extends RefCounted
## Axioms (PRD §6.1) apply left to right, after the cards and before the Prover.

const C := preload("res://tests/cards.gd")

var _types := HandType.load_all("res://data/hand_types.json")
var _eval := HandEvaluator.new(_types)
var _axioms := {}
var _fails: Array[String] = []


func run() -> Array[String]:
	for a: Dictionary in _json("res://data/axioms.json"):
		_axioms[a.id] = a
	# Trinity of 4s: 42 chips × 3.
	_total("4N 4G 4A 9L 1N", ["peano"], {}, 42 * 7, "Peano +4 Mult")
	_total("4N 4G 4A 9L 1N", ["pythagoras"], {}, 42 * 23, "Pythagoras +20 on Trinity")
	_total("5N 3G 4A 1L 2N", ["pythagoras"], {}, 45 * 4, "Pythagoras skips a Sequence")
	# Order matters: +4 then ×3 is not ×3 then +4.
	_total("4N 4G 4A 9L 1N", ["peano", "incompleteness"], {"last_play": true}, 42 * 21, "+4 then ×3")
	_total("4N 4G 4A 9L 1N", ["incompleteness", "peano"], {"last_play": true}, 42 * 13, "×3 then +4")
	_total("4N 4G 4A 9L 1N", ["incompleteness"], {"last_play": false}, 42 * 3, "Incompleteness waits for the last Play")
	# Per card: two primes in a pair of 7s (no: one rank) -> 7N 7G both prime.
	_total("7N 7G", ["prime_mover"], {}, (10 + 14) * (2 + 6), "Prime Mover +3 per prime")
	_total("7N 7G", ["fermats_margin"], {"played": 2}, (10 + 14 + 30) * 2, "Fermat's Margin on 2 cards")
	_total("2N 3G 5A", ["fibonacci"], {}, (5 + 5 + 8) * 1, "Fibonacci: the Lone Term 5 scores +8")
	_total("7N 7G", ["zeno"], {"discards_used": 2}, 24 * 6, "Zeno +2 per discard")
	_total("7N 7G", ["erdos_number", "peano"], {}, 24 * (2 + 4 + 4), "Erdős +2 per Axiom owned")
	_total("5N 5G", ["eulers_identity"], {}, 20 * 4, "Euler: ranks sum to 10 → ×2")
	# Cantor: ∞ fills a Sequence gap.
	_eval.infinity_wild = true
	var r := _eval.evaluate(C.hand("2N ∞G 4A 5L 6N"))
	if r == null or r.hand_type.id != "sequence":
		_fails.append("Cantor: 2 ∞ 4 5 6 should be a Sequence")
	_eval.infinity_wild = false
	r = _eval.evaluate(C.hand("2N ∞G 4A 5L 6N"))
	if r != null and r.hand_type.id == "sequence":
		_fails.append("without Cantor, ∞ isn't a 3")
	# The Prover: Novel +10 Mult, then the Conjecture ×2.
	var b := Scorer.score(_eval.evaluate(C.hand("7N 7G")), 1, [], {"novel": true, "conjecture": true})
	if b.total != 24 * 24:
		_fails.append("Novel then Conjecture: expected %d, got %d" % [24 * 24, b.total])
	# Boss rules zero card chips.
	b = Scorer.score(_eval.evaluate(C.hand("∞N ∞G")), 1, [], {"rule": "infinity_zero_chips"})
	if b.chips != 10:
		_fails.append("The Sphere Problem: ∞ scores 0 chips, got %d" % b.chips)
	b = Scorer.score(_eval.evaluate(C.hand("4N 4G")), 1, [], {"rule": "primes_only_chips"})
	if b.chips != 10:
		_fails.append("The Hum: 4s score 0 chips, got %d" % b.chips)
	return _fails


func _total(codes: String, ids: Array, ctx: Dictionary, want: int, what: String) -> void:
	var list: Array = []
	for id in ids:
		list.append(_axioms[id])
	var b := Scorer.score(_eval.evaluate(C.hand(codes)), 1, list, ctx)
	if b.total != want:
		_fails.append("%s: expected %d, got %d (%s)" % [what, want, b.total, b.steps])


static func _json(path: String) -> Variant:
	return JSON.parse_string(FileAccess.get_file_as_string(path))
