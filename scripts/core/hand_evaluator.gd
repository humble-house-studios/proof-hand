class_name HandEvaluator
extends RefCounted
## Detects the hand type of 1–5 cards given in play (tap) order.
## Rules are keyed by hand type id; priorities and numbers come from data.

const MAX_CARDS := 5


class Result:
	extends RefCounted
	var hand_type: HandType
	## Cards that form the hand, in play order.
	var scoring: Array[Card] = []


var _types: Array[HandType]


## types must be sorted by priority (HandType.load_all does this).
func _init(types: Array[HandType]) -> void:
	_types = types


## Returns null for an empty or oversized selection.
func evaluate(cards: Array[Card]) -> Result:
	if cards.is_empty() or cards.size() > MAX_CARDS:
		return null
	for t in _types:
		var scoring: Variant = _match(t.id, cards)
		if scoring != null:
			var r := Result.new()
			r.hand_type = t
			r.scoring = scoring
			return r
	return null


## Returns the scoring cards if `id` matches, else null.
func _match(id: String, cards: Array[Card]) -> Variant:
	var groups := _rank_groups(cards)
	match id:
		"infinite_series":
			return cards if _is_sequence(cards) and _is_one_field(cards) else null
		"tautology":
			return _cards_in_groups(cards, groups, 4, 1)
		"symmetry":
			return cards if _is_palindrome(cards) else null
		"same_field":
			return cards if cards.size() == MAX_CARDS and _is_one_field(cards) else null
		"sequence":
			return cards if _is_sequence(cards) else null
		"trinity":
			return _cards_in_groups(cards, groups, 3, 1)
		"double_identity":
			return _cards_in_groups(cards, groups, 2, 2)
		"identity":
			return _cards_in_groups(cards, groups, 2, 1)
		"lone_term":
			var lone: Array[Card] = [_highest(cards)]
			return lone
	push_error("Unknown hand type id: %s" % id)
	return null


## rank -> number of cards with that rank.
static func _rank_groups(cards: Array[Card]) -> Dictionary:
	var groups := {}
	for c in cards:
		groups[c.rank] = groups.get(c.rank, 0) + 1
	return groups


## If at least `needed` ranks appear `min_count`+ times, returns every card of
## those ranks in play order; else null.
static func _cards_in_groups(cards: Array[Card], groups: Dictionary, min_count: int, needed: int) -> Variant:
	var ranks: Array[int] = []
	for rank: int in groups:
		if groups[rank] >= min_count:
			ranks.append(rank)
	if ranks.size() < needed:
		return null
	var out: Array[Card] = []
	for c in cards:
		if c.rank in ranks:
			out.append(c)
	return out


## 5 distinct consecutive ranks, any order. ∞ is rank 10 (above 9, never low).
static func _is_sequence(cards: Array[Card]) -> bool:
	if cards.size() != MAX_CARDS:
		return false
	var ranks := cards.map(func(c: Card) -> int: return c.rank)
	ranks.sort()
	for i in range(1, ranks.size()):
		if ranks[i] != ranks[i - 1] + 1:
			return false
	return true


static func _is_one_field(cards: Array[Card]) -> bool:
	return cards.all(func(c: Card) -> bool: return c.field == cards[0].field)


## Ranks read the same forwards and backwards in play order.
static func _is_palindrome(cards: Array[Card]) -> bool:
	if cards.size() != MAX_CARDS:
		return false
	for i in range(2):
		if cards[i].rank != cards[MAX_CARDS - 1 - i].rank:
			return false
	return true


## Highest rank; earliest in play order on ties.
static func _highest(cards: Array[Card]) -> Card:
	var best := cards[0]
	for c in cards:
		if c.rank > best.rank:
			best = c
	return best
