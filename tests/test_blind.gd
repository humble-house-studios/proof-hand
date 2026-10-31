extends RefCounted

const C := preload("res://tests/cards.gd")

var _types := HandType.load_all("res://data/hand_types.json")
var _fails: Array[String] = []


func run() -> Array[String]:
	_test_deal()
	_test_select_order()
	_test_play()
	_test_discard()
	_test_win_lose()
	_test_sort()
	_test_runs_dry()
	return _fails


## A blind over a fixed deck. Deck.draw pops from the back, so list the
## first cards dealt last.
func _blind(codes: String, target := 300, plays := 4, discards := 3) -> Blind:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	var deck := Deck.new(rng, C.hand(codes))
	var b := Blind.new("Test", target, deck, HandEvaluator.new(_types), 8, plays, discards)
	b.hand.append_array(deck.draw(8))
	b.sort_by(Blind.SortMode.RANK)
	return b


func _test_deal() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var b := Blind.new("Lemma", 300, Deck.new(rng), HandEvaluator.new(_types))
	b.start()
	_check(b.hand.size() == 8, "start deals 8, got %d" % b.hand.size())
	_check(b.plays_left == 4 and b.discards_left == 3, "4 Plays, 3 Discards")
	var rng2 := RandomNumberGenerator.new()
	rng2.seed = 7
	var b2 := Blind.new("Lemma", 300, Deck.new(rng2), HandEvaluator.new(_types))
	b2.start()
	_check(C.labels(b.hand) == C.labels(b2.hand), "same seed deals the same hand")


func _test_select_order() -> void:
	var b := _blind("1N 2N 3N 7L 3G 1A 7A 3L 9G 4N")
	var h := b.hand.duplicate()
	_check(b.toggle(h[0]) and b.toggle(h[2]), "select two")
	_check(b.order_of(h[0]) == 1 and b.order_of(h[2]) == 2 and b.order_of(h[1]) == 0, "order badges follow taps")
	b.toggle(h[0])
	_check(b.order_of(h[2]) == 1 and not b.is_selected(h[0]), "deselect renumbers")
	for i in range(8):
		b.toggle(h[i]) if not b.is_selected(h[i]) else null
	_check(b.selected.size() == 5, "max 5 selected, got %d" % b.selected.size())


func _test_play() -> void:
	# Hand (dealt from the back): 4N 9G 3L 7A 1A 3G 7L 3N; deck left: 2N 1N.
	var b := _blind("1N 2N 3N 7L 3G 1A 7A 3L 9G 4N")
	var threes := b.hand.filter(func(c: Card) -> bool: return c.rank == 3)
	for c in threes:
		b.toggle(c)
	var p := b.preview()
	_check(p != null and p.hand_type.id == "trinity", "preview shows Trinity")
	var bd := b.play()
	_check(bd != null and bd.total == (30 + 9) * 3, "Trinity of 3s scores 117, got %s" % (bd.total if bd else -1))
	_check(b.score == 117 and b.plays_left == 3, "score and Plays update")
	_check(b.hand.size() == 7, "draws back up as far as the deck allows (2 left), got %d" % b.hand.size())
	_check(b.selected.is_empty(), "selection clears after Play")
	_check(b.last_result.hand_type.id == "trinity", "last result kept for the readout")


func _test_discard() -> void:
	var b := _blind("1N 2N 3N 7L 3G 1A 7A 3L 9G 4N")
	_check(not b.discard(), "nothing selected: no discard")
	b.toggle(b.hand[0])
	_check(b.discard(), "discard one")
	_check(b.discards_left == 2 and b.plays_left == 4 and b.score == 0, "discard costs a Discard only")
	_check(b.hand.size() == 8, "discard draws back up")
	var b2 := _blind("1N 2N 3N 7L 3G 1A 7A 3L 9G 4N", 300, 4, 0)
	b2.toggle(b2.hand[0])
	_check(not b2.discard(), "no Discards left: no discard")


func _test_win_lose() -> void:
	var b := _blind("1N 2N 3N 7L 3G 1A 7A 3L 9G 4N", 100)
	for c in b.hand.filter(func(c: Card) -> bool: return c.rank == 3):
		b.toggle(c)
	b.play()
	_check(b.is_won() and b.is_over(), "117 clears a 100 target")
	_check(not b.toggle(b.hand[0]), "no selecting after the blind is over")
	var lose := _blind("1N 2N 3N 7L 3G 1A 7A 3L 9G 4N", 9999, 1)
	lose.toggle(lose.hand[0])
	lose.play()
	_check(lose.is_lost(), "out of Plays below target loses")


func _test_sort() -> void:
	var b := _blind("1N 2N 3N 7L 3G 1A 7A 3L 9G 4N")
	_check(C.labels(b.hand) == "9△ 7∂ 7⊢ 4ℕ 3ℕ 3△ 3⊢ 1∂", "rank sort high→low: %s" % C.labels(b.hand))
	b.toggle(b.hand[3])
	b.toggle(b.hand[0])
	b.toggle_sort()
	_check(C.labels(b.hand) == "4ℕ 3ℕ 9△ 3△ 7∂ 1∂ 7⊢ 3⊢", "Field sort: %s" % C.labels(b.hand))
	_check(C.labels(b.selected) == "4ℕ 9△", "sorting keeps tap order: %s" % C.labels(b.selected))


func _test_runs_dry() -> void:
	var b := _blind("1N 2N 3N 7L 3G 1A 7A 3L 9G 4N")
	b.toggle(b.hand[0])
	b.toggle(b.hand[1])
	b.toggle(b.hand[2])
	b.discard()
	_check(b.hand.size() == 7, "short hand when the deck runs dry, got %d" % b.hand.size())


func _check(ok: bool, msg: String) -> void:
	if not ok:
		_fails.append(msg)
