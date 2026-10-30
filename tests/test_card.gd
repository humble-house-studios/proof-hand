extends RefCounted


func run() -> Array[String]:
	var fails: Array[String] = []

	var inf := Card.new(Card.INFINITY, Card.Field.ANALYSIS)
	if inf.chips() != 11:
		fails.append("∞ should be worth 11 chips, got %d" % inf.chips())
	if inf.label() != "∞∂":
		fails.append("∞ label wrong: %s" % inf.label())

	var seven := Card.new(7, Card.Field.LOGIC)
	if not seven.is_prime():
		fails.append("7 should be prime")
	if Card.new(9, Card.Field.LOGIC).is_prime():
		fails.append("9 should not be prime")

	var data: Variant = _load("res://data/hand_types.json")
	if not (data is Array and data.size() == 9):
		fails.append("hand_types.json should define 9 hand types")

	return fails


func _load(path: String) -> Variant:
	var f := FileAccess.open(path, FileAccess.READ)
	return JSON.parse_string(f.get_as_text()) if f else null
