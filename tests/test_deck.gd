extends RefCounted


func run() -> Array[String]:
	var fails: Array[String] = []

	var deck := Deck.new(_rng(1))
	if deck.size() != 40:
		fails.append("standard deck should have 40 cards, got %d" % deck.size())
	var counts := {}
	for c in deck.draw_pile:
		counts[c.label()] = counts.get(c.label(), 0) + 1
	if counts.size() != 40:
		fails.append("standard deck should have 40 distinct cards, got %d" % counts.size())

	# Same seed → same order; different seed → different order.
	var a := Deck.new(_rng(42))
	var b := Deck.new(_rng(42))
	var c := Deck.new(_rng(43))
	a.shuffle(); b.shuffle(); c.shuffle()
	if _order(a) != _order(b):
		fails.append("same seed should shuffle identically")
	if _order(a) == _order(c):
		fails.append("different seeds should shuffle differently")

	var drawn := a.draw(8)
	if drawn.size() != 8 or a.draw_pile.size() != 32:
		fails.append("draw(8) should leave 32 in pile")
	a.discard(drawn)
	if a.size() != 40 or a.discard_pile.size() != 8:
		fails.append("discard should keep deck at 40")
	a.reset()
	if a.draw_pile.size() != 40 or not a.discard_pile.is_empty():
		fails.append("reset should return all cards to draw pile")

	var tail := a.draw(100)
	if tail.size() != 40:
		fails.append("draw past end should return remaining cards, got %d" % tail.size())
	return fails


func _rng(seed_value: int) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = seed_value
	return r


func _order(d: Deck) -> String:
	return ",".join(d.draw_pile.map(func(c: Card) -> String: return c.label()))
