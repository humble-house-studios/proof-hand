extends RefCounted

const C := preload("res://tests/cards.gd")

var _eval := HandEvaluator.new(HandType.load_all("res://data/hand_types.json"))
var _fails: Array[String] = []


func run() -> Array[String]:
	# Only scoring cards add chips.
	_expect("4N 9G 4A 1L", 1, 10 + 4 + 4, 2.0)             # Identity: 18 × 2
	_expect("2N 8G 5A 3L 1N", 1, 5 + 8, 1.0)               # Lone Term: 13 × 1
	_expect("4N 4G 4A 9L 1N", 1, 30 + 12, 3.0)             # Trinity: 42 × 3
	_expect("6A 7A 8A 9A ∞A", 1, 100 + 6 + 7 + 8 + 9 + 11, 8.0)  # ∞ = 11 chips
	# Levels add per-level chips/mult.
	_expect("5N 3G 4A 1L 2N", 1, 30 + 15, 4.0)
	_expect("5N 3G 4A 1L 2N", 2, 60 + 15, 7.0)

	var b := Scorer.score(_eval.evaluate(C.hand("4N 4G 4A 9L 1N")))
	if b.total != 126:
		_fails.append("Trinity of 4s total should be 126, got %d" % b.total)
	if b.steps.size() != 4 or b.steps[0]["source"] != "Trinity" or b.steps[1]["chips"] != 4:
		_fails.append("steps should be hand + one per scoring card: %s" % [b.steps])
	return _fails


func _expect(codes: String, level: int, chips: int, mult: float) -> void:
	var b := Scorer.score(_eval.evaluate(C.hand(codes)), level)
	if b.chips != chips or not is_equal_approx(b.mult, mult):
		_fails.append("%s L%d → %d×%s, expected %d×%s" % [codes, level, b.chips, b.mult, chips, mult])
	if b.total != floori(chips * mult):
		_fails.append("%s L%d total %d, expected %d" % [codes, level, b.total, floori(chips * mult)])
