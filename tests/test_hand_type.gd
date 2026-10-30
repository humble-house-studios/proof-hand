extends RefCounted


func run() -> Array[String]:
	var fails: Array[String] = []
	var types := HandType.load_all("res://data/hand_types.json")
	if types.size() != 9:
		fails.append("expected 9 hand types, got %d" % types.size())
		return fails

	var order := types.map(func(t: HandType) -> String: return t.id)
	var expected := ["infinite_series", "tautology", "symmetry", "same_field", "sequence",
		"trinity", "double_identity", "identity", "lone_term"]
	if order != expected:
		fails.append("priority order wrong: %s" % [order])

	var seq: HandType = types[4]
	if seq.chips_at(1) != 30 or seq.mult_at(1) != 4:
		fails.append("Sequence L1 should be 30×4, got %d×%d" % [seq.chips_at(1), seq.mult_at(1)])
	if seq.chips_at(3) != 90 or seq.mult_at(3) != 10:
		fails.append("Sequence L3 should be 90×10, got %d×%d" % [seq.chips_at(3), seq.mult_at(3)])
	return fails
