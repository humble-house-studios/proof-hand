extends RefCounted

const C := preload("res://tests/cards.gd")

var _eval := HandEvaluator.new(HandType.load_all("res://data/hand_types.json"))
var _fails: Array[String] = []


func run() -> Array[String]:
	# Each of the 9 hand types, with expected scoring cards (play order).
	_expect("1G 2G 3G 4G 5G", "infinite_series", "1G 2G 3G 4G 5G")
	_expect("6A 7A 8A 9A ∞A", "infinite_series", "6A 7A 8A 9A ∞A")
	_expect("7N 7G 7A 7L", "tautology", "7N 7G 7A 7L")
	_expect("2L 7N 7G 7A 7L", "tautology", "7N 7G 7A 7L")
	_expect("3N 7G 1A 7L 3G", "symmetry", "3N 7G 1A 7L 3G")
	_expect("1N 3N 5N 7N 9N", "same_field", "1N 3N 5N 7N 9N")
	_expect("5N 3G 4A 1L 2N", "sequence", "5N 3G 4A 1L 2N")
	_expect("4N 4G 4A 9L 1N", "trinity", "4N 4G 4A")
	_expect("4N 9G 4A 1L 9N", "double_identity", "4N 9G 4A 9N")
	_expect("4N 9G 4A 1L", "identity", "4N 4A")
	_expect("2N 8G 5A 3L 1N", "lone_term", "8G")
	_expect("6L", "lone_term", "6L")

	# Priority: higher hand wins when several rules match.
	_expect("2G 3G 4G 5G 6G", "infinite_series", "2G 3G 4G 5G 6G") # also Sequence + Same Field
	_expect("4N 9G 4A 9L 4G", "symmetry", "4N 9G 4A 9L 4G")        # beats Trinity / Double Identity
	_expect("5N 5G 6A 5L 5A", "tautology", "5N 5G 5L 5A")           # palindrome, but Tautology first
	_expect("1L 3L 5L 3L 1L", "symmetry", "1L 3L 5L 3L 1L")         # beats Same Field
	_expect("4N 4G 4A 9L 9N", "trinity", "4N 4G 4A")                # full house → Trinity

	# Symmetry depends on tap order: same cards, non-palindrome order.
	_expect("3N 3G 7G 7L 1A", "double_identity", "3N 3G 7G 7L")
	_expect("3N 7G 1A 7L 3G", "symmetry", "3N 7G 1A 7L 3G")
	_expect("1A 3N 7G 7L 3G", "double_identity", "3N 7G 7L 3G")
	# Symmetry needs exactly 5 cards.
	_expect("3N 7G 3G", "identity", "3N 3G")

	# ∞ ranks above 9, never low.
	_expect("6N 7G 8A 9L ∞N", "sequence", "6N 7G 8A 9L ∞N")
	_expect("∞N 1G 2A 3L 4N", "lone_term", "∞N")
	_expect("∞N 9G 2A", "lone_term", "∞N")
	_expect("∞N ∞G 5A", "identity", "∞N ∞G")
	_expect("1N 2G 3A 4L 6N", "lone_term", "6N")  # gap → not a Sequence

	# Lone Term tie: earliest in play order.
	_expect("9N 2G 9A", "identity", "9N 9A")
	_expect("9A 3G 1L", "lone_term", "9A")

	# Invalid selections.
	if _eval.evaluate([] as Array[Card]) != null:
		_fails.append("empty selection should evaluate to null")
	if _eval.evaluate(C.hand("1N 2N 3N 4N 5N 6N")) != null:
		_fails.append("6-card selection should evaluate to null")
	return _fails


func _expect(codes: String, id: String, scoring: String) -> void:
	var r := _eval.evaluate(C.hand(codes))
	if r == null:
		_fails.append("%s → null, expected %s" % [codes, id])
		return
	if r.hand_type.id != id:
		_fails.append("%s → %s, expected %s" % [codes, r.hand_type.id, id])
	var got := C.labels(r.scoring)
	var want := C.labels(C.hand(scoring))
	if got != want:
		_fails.append("%s scoring cards → [%s], expected [%s]" % [codes, got, want])
