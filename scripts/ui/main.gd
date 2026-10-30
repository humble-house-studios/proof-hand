extends Control
## Title screen placeholder with an M1 engine demo (deal 5, evaluate, score).
## Replaced in M2/M3.

const DEMO_SEED := 1

@onready var _status: Label = $Center/Status
@onready var _deal: Button = $Center/Deal

var _evaluator: HandEvaluator
var _deck: Deck


func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = DEMO_SEED
	_evaluator = HandEvaluator.new(Game.hand_types)
	_deck = Deck.new(rng)
	_deck.shuffle()
	_status.text = "M1 core engine · %d hand types loaded" % Game.hand_types.size()
	_deal.pressed.connect(_on_deal)


func _on_deal() -> void:
	if _deck.draw_pile.size() < 5:
		_deck.reset()
	var cards := _deck.draw(5)
	_deck.discard(cards)
	var result := _evaluator.evaluate(cards)
	var score := Scorer.score(result)
	var labels := " ".join(cards.map(func(c: Card) -> String: return c.label()))
	_status.text = "%s\n%s\n%d × %d = %d" % [
		labels, result.hand_type.name, score.chips, int(score.mult), score.total]
