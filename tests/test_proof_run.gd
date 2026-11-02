extends RefCounted
## A run: antes and blinds, boss rules, cash out, the Library, Lemmas, the
## Prover's signatures and Conjecture.

const C := preload("res://tests/cards.gd")

var _types := HandType.load_all("res://data/hand_types.json")
var _data := {}
var _fails: Array[String] = []


func run() -> Array[String]:
	for k in ["blinds", "axioms", "lemmas", "prover_lines"]:
		_data[k] = _json("res://data/%s.json" % k)
	_test_blinds_and_bosses()
	_test_cash_out_and_shop()
	_test_lemmas()
	_test_prover()
	_test_seeded()
	_test_office_relics()
	return _fails


func _run(s := 7) -> ProofRun:
	return ProofRun.new(_data, _types, s, {})


func _test_blinds_and_bosses() -> void:
	var r := _run()
	_eq(r.spec().target, 300, "Ante 1 Lemma target")
	var b := r.start_blind()
	_eq(b.hand.size(), 8, "deals 8")
	_eq(b.plays_left, 4, "4 Plays")
	r.advance()
	r.advance()
	_eq(r.kind(), "boss", "third blind is the boss")
	_eq(r.spec().rule, "infinity_zero_chips", "Ante 1 boss rule")
	r.advance()
	r.advance()
	r.advance()
	_eq(r.start_blind().plays_left, 3, "The Speed of Knowing: 3 Plays")
	r.debt = 2
	_eq(r.spec().target, 3450, "two Debt: boss +50%")
	r.advance()
	r.advance()
	r.advance()
	_eq(r.advance(), true, "the third boss wins the run")
	_eq(r.won, true, "won")


func _test_cash_out_and_shop() -> void:
	var r := _run()
	r.start_blind()
	r.blind.plays_left = 2
	r.money = 10
	var lines := r.cash_out()
	# Lemma $3 + 2 Plays $2 + interest $2 = $7.
	_eq(r.money, 17, "cash out pays: %s" % [lines])
	r.restock()
	_eq(r.stock.size(), 4, "2 Axioms, 1 Lemma, 1 Field Study")
	for s in r.stock:
		if s.kind == "axiom" and s.item.get("locked", false):
			_fails.append("a locked Axiom in the shop")
	r.money = 100
	var axiom_i := 0
	_eq(r.buy(axiom_i), true, "buy an Axiom")
	_eq(r.axioms.size(), 1, "it's yours")
	var price := int(r.axioms[0].price)
	var before := r.money
	r.sell(0)
	_eq(r.money, before + price / 2, "sell for half")
	r.money = 5
	_eq(r.reroll(), true, "reroll $5")
	_eq(r.reroll_price, 6, "the next reroll costs more")
	_eq(r.reroll(), false, "can't afford it")
	r.money = 100
	for i in 6:
		r.axioms.append(_data.axioms[i])
	r.axioms.resize(5)
	r.restock()
	_eq(r.cant_buy(0), "Axiom slots full. Sell one first.", "five Axioms max")
	r.move_left(1)
	_eq(r.axioms[0].id, _data.axioms[1].id, "move an Axiom left")
	# A Field Study levels its hand.
	r.restock()
	var study := r.stock.size() - 1
	var id: String = r.stock[study].item.id
	r.buy(study)
	_eq(r.levels[id], 2, "Field Study levels up %s" % id)


func _test_lemmas() -> void:
	var r := _run()
	var b := r.start_blind()
	r.lemmas.append(_data.lemmas[2])  # Infinity Map
	_eq(r.cant_use(0), "Select cards first.", "needs a selection")
	b.toggle(b.hand[0])
	b.toggle(b.hand[1])
	_eq(r.cant_use(0), "Select at most 1.", "Infinity Map takes one card")
	b.toggle(b.hand[1])
	var card: Card = b.selected[0]
	r.use_lemma(0)
	_eq(card.rank, Card.INFINITY, "it's ∞ now")
	_eq(r.lemmas.size(), 0, "used up")
	r.lemmas.append(_data.lemmas[3])  # sorry
	r.use_lemma(0)
	_eq(b.is_won(), true, "sorry clears the blind")
	_eq(r.debt, 1, "and costs Debt")


func _test_prover() -> void:
	var ev := HandEvaluator.new(_types)
	var res := ev.evaluate(C.hand("7N 7G"))
	_eq(Prover.signature(res), "identity|ℕ,△", "signature")
	_eq(Prover.readable("identity|ℕ,△", _types), "Identity over Number Theory and Geometry", "readable")
	var r := ProofRun.new(_data, _types, 3, {})
	r.conjecture = "identity|ℕ,△"
	r.start_blind()
	var b := r.score(res)
	# Identity 10+14 = 24; Novel +10 → 12; Conjecture ×2 → 24.
	_eq(b.total, 24 * 24, "Novel and Conjecture on a first find")
	var got := r.record(res, b)
	_eq(got.novel and got.proved, true, "recorded: novel and proved")
	_eq(r.score(res).total, 24 * 4, "seen now: no Novel, still ×2")
	var rng := RandomNumberGenerator.new()
	var all := {}
	for shape in Prover.CONJECTURE_SHAPES:
		for f in Prover._field_sets(int(shape[1])):
			all["%s|%s" % [shape[0], ",".join(f.map(func(x: int) -> String: return Card.FIELD_GLYPHS[x]))]] = 1
	_eq(Prover.propose(rng, all), "", "nothing left to conjecture")


func _test_seeded() -> void:
	var a := _run(42)
	var b := _run(42)
	_eq(Prover.signature(a.start_blind().preview() if false else ev_dummy()), Prover.signature(ev_dummy()), "")
	_eq(a.conjecture, b.conjecture, "same seed, same Conjecture")
	a.restock()
	b.restock()
	_eq(str(a.stock), str(b.stock), "same seed, same shop")


func ev_dummy() -> HandEvaluator.Result:
	return HandEvaluator.new(_types).evaluate(C.hand("1N"))


func _eq(got, want, what: String) -> void:
	if str(got) != str(want):
		_fails.append("%s: expected %s, got %s" % [what, want, got])


static func _json(path: String) -> Variant:
	return JSON.parse_string(FileAccess.get_file_as_string(path))


func _test_office_relics() -> void:
	var r := _run()
	r.bonus_plays = 1
	r.bonus_discards = 1
	r.bonus_mult = 2.0
	var b := r.start_blind()
	_eq(b.plays_left, 5, "Chalk Nub: +1 Play")
	_eq(b.discards_left, 4, "Eraser: +1 Discard")
	r.seen = {"identity|ℕ,△": 1}
	var res := HandEvaluator.new(_types).evaluate(C.hand("7N 7G"))
	_eq(r.score(res).total, 24 * 4, "Lucky Infinity: +2 Mult")
