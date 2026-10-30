class_name Deck
extends RefCounted
## Draw pile + discard pile. Shuffling uses the run's seeded RNG only.

const RANKS_PER_FIELD := 10

var draw_pile: Array[Card] = []
var discard_pile: Array[Card] = []
var _rng: RandomNumberGenerator


func _init(rng: RandomNumberGenerator, cards: Array[Card] = []) -> void:
	_rng = rng
	draw_pile = cards.duplicate() if not cards.is_empty() else standard_cards()


## The 40-card starting deck: 4 Fields × ranks 1–9 and ∞.
static func standard_cards() -> Array[Card]:
	var out: Array[Card] = []
	for field: Card.Field in Card.Field.values():
		for rank in range(1, RANKS_PER_FIELD + 1):
			out.append(Card.new(rank, field))
	return out


func size() -> int:
	return draw_pile.size() + discard_pile.size()


## Fisher–Yates over the draw pile with the seeded RNG.
func shuffle() -> void:
	for i in range(draw_pile.size() - 1, 0, -1):
		var j := _rng.randi_range(0, i)
		var tmp := draw_pile[i]
		draw_pile[i] = draw_pile[j]
		draw_pile[j] = tmp


## Draws up to n cards from the top. Returns fewer if the pile runs out.
func draw(n: int) -> Array[Card]:
	var out: Array[Card] = []
	while out.size() < n and not draw_pile.is_empty():
		out.append(draw_pile.pop_back())
	return out


func discard(cards: Array[Card]) -> void:
	discard_pile.append_array(cards)


## Returns every card to the draw pile and shuffles (start of a blind).
func reset() -> void:
	draw_pile.append_array(discard_pile)
	discard_pile.clear()
	shuffle()
