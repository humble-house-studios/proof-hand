class_name ProofRun
extends RefCounted
## One run (PRD §2, §5, §6): 3 antes × (Lemma, Theorem, Boss Conjecture),
## Grant money, the Library shop between blinds, Axioms (max 5, applied left
## to right), Lemmas (hold 2), Field Studies (hand levels), Debt from
## `sorry`, and the Prover's Conjecture. Pure rules: the play screen reads it
## and calls it. Seeded: the same seed plays the same run.

const MAX_AXIOMS := 5
const MAX_LEMMAS := 2
const FIELD_STUDY_PRICE := 4
const REROLL_PRICE := 5
const DEBT_STEP := 0.25
const KINDS := ["lemma", "theorem", "boss"]

var seed_value: int
var rng := RandomNumberGenerator.new()
var data: Dictionary
var types: Array[HandType]
var money := 0
var ante := 0
## 0 = Lemma, 1 = Theorem, 2 = Boss.
var stage := 0
var axioms: Array = []
var lemmas: Array = []
var levels := {}
var debt := 0
var deck_cards: Array[Card] = []
var conjecture := ""
var proven := false
var won := false
var lost := false
## This run: signatures first found, best single hand, hands played.
var discoveries: Array[String] = []
var best_hand := 0
var best_hand_name := ""
var hands_played := 0
## The Library's stock this visit: [{kind: axiom/lemma/study, ...}], and the
## reroll price.
var stock: Array = []
var reroll_price := REROLL_PRICE
var blind: Blind
## The Notebook's signatures (shared with the save): a signature not in here
## is Novel.
var seen: Dictionary = {}
var _evaluator: HandEvaluator


## data: Game.data (blinds, axioms, lemmas, prover_lines). seen: the
## Notebook's signatures (the Conjecture is one you haven't found).
func _init(p_data: Dictionary, p_types: Array[HandType], p_seed: int, seen := {}) -> void:
	data = p_data
	types = p_types
	seed_value = p_seed
	rng.seed = p_seed
	money = int(data.blinds.get("start_money", 4))
	deck_cards = Deck.standard_cards()
	for t in types:
		levels[t.id] = 1
	self.seen = seen
	conjecture = Prover.propose(rng, seen)
	_evaluator = HandEvaluator.new(types)


# ---------------------------------------------------------------- blinds

func kind() -> String:
	return KINDS[stage]


## {kind, name, target, rule, text, taunt} for the blind you're on.
func spec(a := -1, s := -1) -> Dictionary:
	a = ante if a < 0 else a
	s = stage if s < 0 else s
	var cfg: Dictionary = data.blinds.antes[a]
	if s < 2:
		var k: String = KINDS[s]
		return {"kind": k, "name": k.capitalize(), "target": int(cfg[k]), "rule": "", "text": "", "taunt": ""}
	var boss: Dictionary = cfg.boss
	var target := int(round(float(boss.target) * (1.0 + DEBT_STEP * debt)))
	return {"kind": "boss", "name": boss.name, "target": target, "rule": str(boss.get("rule", "")),
		"text": str(boss.get("text", "")), "taunt": str(boss.get("taunt", ""))}


func antes() -> int:
	return data.blinds.antes.size()


## Deal the blind you're on.
func start_blind() -> Blind:
	var sp := spec()
	var plays := int(data.blinds.plays_per_blind)
	if sp.rule == "plays_3":
		plays = 3
	_evaluator.infinity_wild = AxiomEffects.has_rule(axioms, "infinity_wild_sequence")
	var deck_rng := RandomNumberGenerator.new()
	deck_rng.seed = rng.randi()
	blind = Blind.new(sp.name, sp.target, Deck.new(deck_rng, deck_cards), _evaluator,
			int(data.blinds.hand_size), plays, int(data.blinds.discards_per_blind))
	blind.score_fn = score
	blind.start()
	return blind


## Score a result the way this run would right now (Axioms, boss rule,
## Novel, the Conjecture).
func score(result: HandEvaluator.Result) -> Scorer.Breakdown:
	var sig := Prover.signature(result)
	var ctx := {
		"rule": spec().rule,
		"last_play": blind != null and blind.plays_left == 1,
		"discards_used": blind.discards_used if blind else 0,
		"played": blind.selected.size() if blind and not blind.selected.is_empty() else result.scoring.size(),
		"novel": not seen.has(sig),
		"conjecture": sig == conjecture,
	}
	return Scorer.score(result, int(levels.get(result.hand_type.id, 1)), axioms, ctx)


## After a Play (the blind calls it): remember it. Returns {novel, proved,
## signature} for the stamps.
func record(result: HandEvaluator.Result, b: Scorer.Breakdown) -> Dictionary:
	hands_played += 1
	var sig := Prover.signature(result)
	var novel := not seen.has(sig)
	if novel:
		discoveries.append(sig)
		seen[sig] = 1
	var proved := sig == conjecture and not proven
	if proved:
		proven = true
	if b.total > best_hand:
		best_hand = b.total
		best_hand_name = result.hand_type.name
	return {"novel": novel, "proved": proved, "signature": sig}


## A blind is over: won → cash out next (and advance); lost → run over.
func finish_blind() -> void:
	if blind == null:
		return
	if not blind.is_won():
		lost = true


## The cash-out lines: [[label, $], ...]. Pays them.
func cash_out() -> Array:
	var r: Dictionary = data.blinds.reward
	var lines: Array = []
	lines.append(["%s cleared" % spec().name, int(r[kind()])])
	if blind and blind.plays_left > 0:
		lines.append(["%d unused Play%s" % [blind.plays_left, "" if blind.plays_left == 1 else "s"], blind.plays_left * int(r.per_unused_play)])
	var interest := mini(money / int(r.interest_per), int(r.interest_cap))
	if interest > 0:
		lines.append(["Interest ($1 per $%d held)" % int(r.interest_per), interest])
	var grant := AxiomEffects.cash_bonus(axioms)
	if grant > 0:
		lines.append(["Grant Writer", grant])
	for l in lines:
		money += int(l[1])
	return lines


## Move on after cash out. True if that was the last boss (the run is won).
func advance() -> bool:
	stage += 1
	if stage > 2:
		stage = 0
		ante += 1
	if ante >= antes():
		won = true
		ante = antes() - 1
		stage = 2
		return true
	return false


# ---------------------------------------------------------------- the Library

## Fill the shop: 2 Axioms, 1 Lemma, 1 Field Study.
func restock(unlocked: Array = []) -> void:
	reroll_price = REROLL_PRICE
	_fill(unlocked)


func reroll(unlocked: Array = []) -> bool:
	if money < reroll_price:
		return false
	money -= reroll_price
	reroll_price += 1
	_fill(unlocked)
	return true


func _fill(unlocked: Array) -> void:
	stock.clear()
	var pool: Array = []
	for a: Dictionary in data.axioms:
		if a.get("locked", false) and not a.id in unlocked:
			continue
		if _owns(a.id):
			continue
		pool.append(a)
	for i in 2:
		if pool.is_empty():
			break
		var a: Dictionary = pool.pop_at(rng.randi_range(0, pool.size() - 1))
		stock.append({"kind": "axiom", "item": a, "price": int(a.price)})
	var lemmas_pool: Array = []
	var sorry: Dictionary = {}
	for l: Dictionary in data.lemmas:
		if l.has("shop_chance"):
			sorry = l
		else:
			lemmas_pool.append(l)
	var lemma: Dictionary = lemmas_pool[rng.randi_range(0, lemmas_pool.size() - 1)]
	if not sorry.is_empty() and rng.randf() < float(sorry.shop_chance):
		lemma = sorry
	stock.append({"kind": "lemma", "item": lemma, "price": int(lemma.price)})
	var t: HandType = types[rng.randi_range(0, types.size() - 1)]
	stock.append({"kind": "study", "item": {"id": t.id, "name": "Field Study: " + t.name,
		"text": "Level up %s (+%d Chips, +%d Mult)" % [t.name, t.level_chips, t.level_mult]}, "price": FIELD_STUDY_PRICE})


func _owns(id: String) -> bool:
	for a: Dictionary in axioms:
		if a.id == id:
			return true
	return false


## Why you can't buy stock item i ("" = you can).
func cant_buy(i: int) -> String:
	if i < 0 or i >= stock.size():
		return "Sold."
	var s: Dictionary = stock[i]
	if money < int(s.price):
		return "Not enough money."
	if s.kind == "axiom" and axioms.size() >= MAX_AXIOMS:
		return "Axiom slots full. Sell one first."
	if s.kind == "lemma" and lemmas.size() >= MAX_LEMMAS:
		return "Lemma slots full. Use one first."
	return ""


func buy(i: int) -> bool:
	if cant_buy(i) != "":
		return false
	var s: Dictionary = stock.pop_at(i)
	money -= int(s.price)
	match s.kind:
		"axiom":
			axioms.append(s.item)
		"lemma":
			lemmas.append(s.item)
		"study":
			levels[s.item.id] = int(levels.get(s.item.id, 1)) + 1
	return true


## Half price back, rounded down.
func sell(i: int) -> int:
	if i < 0 or i >= axioms.size():
		return 0
	var a: Dictionary = axioms.pop_at(i)
	var back := int(a.price) / 2
	money += back
	return back


## Swap an Axiom with its left neighbour (order matters: left to right).
func move_left(i: int) -> void:
	if i <= 0 or i >= axioms.size():
		return
	var a = axioms[i]
	axioms[i] = axioms[i - 1]
	axioms[i - 1] = a


# ---------------------------------------------------------------- Lemmas

## Why Lemma i can't be used on the current selection ("" = it can).
func cant_use(i: int) -> String:
	if blind == null or i < 0 or i >= lemmas.size():
		return "No Lemma."
	var e: Dictionary = lemmas[i].effect
	if e.type == "skip_blind":
		return "Not on a boss." if kind() == "boss" else ""
	var n := blind.selected.size()
	if n == 0:
		return "Select cards first."
	if n > int(e.get("max_cards", 5)):
		return "Select at most %d." % int(e.max_cards)
	return ""


## Use Lemma i on the selected cards. Card changes are permanent (they're
## the run's own cards). Returns what happened, for the Prover panel.
func use_lemma(i: int) -> String:
	if cant_use(i) != "":
		return ""
	var l: Dictionary = lemmas.pop_at(i)
	var e: Dictionary = l.effect
	var sel: Array[Card] = blind.selected.duplicate()
	match str(e.type):
		"shift_rank":
			for c in sel:
				c.rank = mini(c.rank + 1, Card.INFINITY)
		"set_field":
			for c in sel:
				c.field = sel[0].field
		"set_infinity":
			for c in sel:
				c.rank = Card.INFINITY
		"skip_blind":
			debt += int(e.get("debt", 1))
			blind.score = maxi(blind.score, blind.target)
			return "sorry"
	blind.refresh_order()
	return l.name


# ---------------------------------------------------------------- hints

## The best hand you could play from what you hold now: {result, total,
## cards} or {} (ignores order, so it never suggests a Symmetry).
func best_in_hand() -> Dictionary:
	if blind == null:
		return {}
	var hand: Array[Card] = blind.hand
	var best := {}
	var n := hand.size()
	for mask in range(1, 1 << n):
		var bits := 0
		for i in n:
			if mask & (1 << i):
				bits += 1
		if bits > HandEvaluator.MAX_CARDS:
			continue
		var cards: Array[Card] = []
		for i in n:
			if mask & (1 << i):
				cards.append(hand[i])
		var r := _evaluator.evaluate(cards)
		if r == null:
			continue
		# Only the scoring cards are worth suggesting.
		if r.scoring.size() < cards.size():
			continue
		var b := Scorer.score(r, int(levels.get(r.hand_type.id, 1)), axioms, {"rule": spec().rule})
		if best.is_empty() or b.total > int(best.total):
			best = {"result": r, "total": b.total, "cards": r.scoring}
	return best
