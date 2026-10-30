class_name HandType
extends RefCounted
## One row of data/hand_types.json. Levels start at 1; each level above 1
## adds level_chips / level_mult.

var id: String
var name: String
var priority: int
var base_chips: int
var base_mult: int
var level_chips: int
var level_mult: int


static func from_dict(d: Dictionary) -> HandType:
	var h := HandType.new()
	h.id = d["id"]
	h.name = d["name"]
	h.priority = int(d["priority"])
	h.base_chips = int(d["chips"])
	h.base_mult = int(d["mult"])
	h.level_chips = int(d["level_chips"])
	h.level_mult = int(d["level_mult"])
	return h


## Loads all hand types from a JSON file, sorted by priority (1 = checked first).
static func load_all(path: String) -> Array[HandType]:
	var out: Array[HandType] = []
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("Missing hand types file: %s" % path)
		return out
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	if not parsed is Array:
		push_error("Invalid hand types JSON: %s" % path)
		return out
	for d: Dictionary in parsed:
		out.append(from_dict(d))
	out.sort_custom(func(a: HandType, b: HandType) -> bool: return a.priority < b.priority)
	return out


func chips_at(level: int) -> int:
	return base_chips + level_chips * maxi(level - 1, 0)


func mult_at(level: int) -> int:
	return base_mult + level_mult * maxi(level - 1, 0)
