extends RefCounted
## Test helper: build cards from short codes. Rank 1–9 or ∞, then Field
## letter N(umber Theory) G(eometry) A(nalysis) L(ogic). "7L", "∞A".

const FIELDS := {"N": Card.Field.NUMBER_THEORY, "G": Card.Field.GEOMETRY, "A": Card.Field.ANALYSIS, "L": Card.Field.LOGIC}


static func hand(codes: String) -> Array[Card]:
	var out: Array[Card] = []
	for code in codes.split(" ", false):
		var r := code.substr(0, code.length() - 1)
		var rank := Card.INFINITY if r == "∞" else int(r)
		out.append(Card.new(rank, FIELDS[code.right(1)]))
	return out


static func labels(cards: Array[Card]) -> String:
	return " ".join(cards.map(func(c: Card) -> String: return c.label()))
