extends Control
## Title screen placeholder. Replaced in M2/M3.

@onready var _status: Label = $Center/Status


func _ready() -> void:
	var hand_types: Array = Game.data.get("hand_types", [])
	_status.text = "M0 scaffold · %d hand types loaded" % hand_types.size()
