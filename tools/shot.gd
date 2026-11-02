extends SceneTree
## Screenshots of a run through the real UI, saved to $OUT (needs a display):
##   OUT=/some/dir xvfb-run -a -s "-screen 0 540x960x24" godot --path . \
##     --rendering-driver opengl3 --resolution 540x960 -s tools/shot.gd
## title, conjecture, intro, play (hint), selected, scoring, scored, cash,
## library, hands, lost. Wipes user://notebook.json.

var main: Control


func _init() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://notebook.json"))
	for i in 3: await process_frame
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await _f(20)
	_shot("title")
	_press("START A RUN")
	await _f(10)
	_shot("conjecture")
	_press("BEGIN")
	await _f(10)
	_shot("intro")
	_press("PROVE IT")
	await _f(10)
	_shot("play")
	main._use_hint()
	await _f(5)
	_shot("selected")
	main.run.axioms.append(main.Game.data.axioms[0] if false else Game_axiom(0))
	main.run.axioms.append(Game_axiom(4))
	main._refresh()
	main._on_play()
	await _f(40)
	_shot("scoring")
	await _f(120)
	_shot("scored")
	main._blind.score = main._blind.target
	main._blind_over()
	await _f(10)
	_shot("cash")
	_press("TO THE LIBRARY")
	await _f(10)
	_shot("library")
	_press("NEXT:")
	_press("PROVE IT")
	await _f(5)
	main._show_hands()
	await _f(5)
	_shot("hands")
	main._close_screen()
	main._blind.plays_left = 0
	main._blind_over()
	await _f(5)
	_shot("lost")
	quit()


func Game_axiom(i: int) -> Dictionary:
	return root.get_node("Game").data.axioms[i]


func _press(prefix: String) -> void:
	var stack: Array = [main]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is Button and n.is_visible_in_tree() and n.text.begins_with(prefix):
			n.pressed.emit()
			return
		stack.append_array(n.get_children())
	print("no button ", prefix)


func _f(n: int) -> void:
	for i in n: await process_frame


func _shot(name: String) -> void:
	root.get_texture().get_image().save_png(OS.get_environment("OUT") + "/" + name + ".png")
