class_name Blind
extends RefCounted
## One blind on the play screen: a hand of cards, a tap-ordered selection,
## Plays/Discards left, and the score against a target (PRD §4).

enum SortMode { RANK, FIELD }

var name: String
var target: int
var hand_size: int
var plays_left: int
var discards_left: int
var score: int = 0
var hand: Array[Card] = []
## Selected cards in tap order (= play order).
var selected: Array[Card] = []
var sort_mode: SortMode = SortMode.RANK
## The last Play's result, for the score readout (null before the first Play).
var last_result: HandEvaluator.Result
var last_breakdown: Scorer.Breakdown

var _deck: Deck
var _evaluator: HandEvaluator


func _init(p_name: String, p_target: int, deck: Deck, evaluator: HandEvaluator,
		p_hand_size: int = 8, plays: int = 4, discards: int = 3) -> void:
	name = p_name
	target = p_target
	_deck = deck
	_evaluator = evaluator
	hand_size = p_hand_size
	plays_left = plays
	discards_left = discards


## Shuffles everything back into the deck and deals a fresh hand.
func start() -> void:
	_deck.discard(hand)
	hand.clear()
	selected.clear()
	_deck.reset()
	_refill()


func is_won() -> bool:
	return score >= target


func is_lost() -> bool:
	return not is_won() and plays_left <= 0


func is_over() -> bool:
	return is_won() or is_lost()


func is_selected(card: Card) -> bool:
	return card in selected


## 1-based position in the play order, or 0 if not selected.
func order_of(card: Card) -> int:
	return selected.find(card) + 1


## Tap a card: select it (if fewer than 5 are selected) or deselect it.
## Returns true if the selection changed.
func toggle(card: Card) -> bool:
	if is_over() or not card in hand:
		return false
	if card in selected:
		selected.erase(card)
		return true
	if selected.size() >= HandEvaluator.MAX_CARDS:
		return false
	selected.append(card)
	return true


## The hand the current selection would make, or null if nothing is selected.
func preview() -> HandEvaluator.Result:
	return _evaluator.evaluate(selected)


func can_play() -> bool:
	return not is_over() and plays_left > 0 and not selected.is_empty()


func can_discard() -> bool:
	return not is_over() and discards_left > 0 and not selected.is_empty()


## Scores the selection, then draws back up. Returns the breakdown, or null
## if there was nothing to play.
func play() -> Scorer.Breakdown:
	if not can_play():
		return null
	last_result = preview()
	last_breakdown = Scorer.score(last_result)
	score += last_breakdown.total
	plays_left -= 1
	_remove_selected()
	if not is_over():
		_refill()
	return last_breakdown


func discard() -> bool:
	if not can_discard():
		return false
	discards_left -= 1
	_remove_selected()
	_refill()
	return true


## Sets the sort mode and reorders the hand (selection order is unchanged).
func sort_by(mode: SortMode) -> void:
	sort_mode = mode
	_sort()


func toggle_sort() -> void:
	sort_by(SortMode.FIELD if sort_mode == SortMode.RANK else SortMode.RANK)


func _remove_selected() -> void:
	for c in selected:
		hand.erase(c)
	_deck.discard(selected)
	selected = []


## Draws back up to hand_size. If the deck runs dry the hand stays short.
func _refill() -> void:
	hand.append_array(_deck.draw(hand_size - hand.size()))
	_sort()


## Rank mode: high to low, then Field. Field mode: by Field, then high to low.
func _sort() -> void:
	var by_field := sort_mode == SortMode.FIELD
	hand.sort_custom(func(a: Card, b: Card) -> bool:
		if by_field and a.field != b.field:
			return a.field < b.field
		if a.rank != b.rank:
			return a.rank > b.rank
		return a.field < b.field)
