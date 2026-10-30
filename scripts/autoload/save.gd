extends Node
## Persists the Prover's Notebook to user://. Fleshed out in M5.

const PATH := "user://notebook.json"

var notebook: Dictionary = {
	"version": 1,
	"signatures": {},        # signature -> first run number
	"proven_conjectures": [],
	"unlocked_axioms": [],
	"total_runs": 0,
	"best_score": 0,
}


func _ready() -> void:
	load_notebook()


func load_notebook() -> void:
	if not FileAccess.file_exists(PATH):
		return
	var f := FileAccess.open(PATH, FileAccess.READ)
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	if parsed is Dictionary:
		notebook.merge(parsed, true)


func save_notebook() -> void:
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	f.store_string(JSON.stringify(notebook, "\t"))
