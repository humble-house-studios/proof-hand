extends Node
## Holds loaded content and the current run. Core logic lives in scripts/core/.

const DATA_FILES: Array[String] = [
	"hand_types", "axioms", "lemmas", "blinds", "prover_lines",
]

var data: Dictionary = {}


func _ready() -> void:
	for key in DATA_FILES:
		data[key] = load_json("res://data/%s.json" % key)


static func load_json(path: String) -> Variant:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("Missing data file: %s" % path)
		return null
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	if parsed == null:
		push_error("Invalid JSON: %s" % path)
	return parsed
