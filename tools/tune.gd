extends SceneTree
## Balance check: plays N runs on autopilot (always the best hand it can see,
## discards when that's weak, buys the first Axiom it can afford) and prints
## how far they get. godot --headless --path . -s tools/tune.gd  (N=300)

const DATA := ["blinds", "axioms", "lemmas", "prover_lines"]


func _init() -> void:
	var data := {}
	for k in DATA:
		data[k] = JSON.parse_string(FileAccess.get_file_as_string("res://data/%s.json" % k))
	var types := HandType.load_all("res://data/hand_types.json")
	var n := int(OS.get_environment("N")) if OS.get_environment("N") != "" else 300
	var reached := {}
	var wins := 0
	for i in n:
		var run := ProofRun.new(data, types, 1000 + i, {})
		var cleared := 0
		while not run.won and not run.lost:
			var b := run.start_blind()
			while not b.is_over():
				var best := run.best_in_hand()
				var weak: bool = best.is_empty() or (int(best.total) * b.plays_left < b.target - b.score and b.discards_left > 0 and best.result.hand_type.id in ["lone_term", "identity"])
				if weak and b.discards_left > 0:
					# Throw away the cards outside the best pair / high card.
					var keep: Array = best.cards if not best.is_empty() else []
					var toss: Array[Card] = []
					for c in b.hand:
						if not c in keep and toss.size() < 5:
							toss.append(c)
					b.selected = toss
					b.discard()
					continue
				b.selected.assign(best.cards)
				var r := b.play()
				run.record(b.last_result, r)
			run.finish_blind()
			if run.lost:
				break
			cleared += 1
			run.cash_out()
			if run.advance():
				break
			run.restock()
			for j in 3:
				for k in run.stock.size():
					if run.stock[k].kind != "lemma" and run.cant_buy(k) == "":
						run.buy(k)
						break
		reached[cleared] = int(reached.get(cleared, 0)) + 1
		if run.won:
			wins += 1
	var names := ["", "A1 Lemma", "A1 Theorem", "A1 Boss", "A2 Lemma", "A2 Theorem", "A2 Boss", "A3 Lemma", "A3 Theorem", "A3 Boss"]
	var alive := n
	for k in range(0, 10):
		if k > 0:
			print("cleared %-10s %3d%%" % [names[k], int(100.0 * alive / n)])
		alive -= int(reached.get(k, 0))
	print("won %d / %d (%d%%)" % [wins, n, int(100.0 * wins / n)])
	quit()
