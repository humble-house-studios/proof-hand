class_name Card
extends RefCounted
## A single card. Rank 1–9, or INFINITY (ranks above 9, worth 11 chips).

enum Field { NUMBER_THEORY, GEOMETRY, ANALYSIS, LOGIC }

const INFINITY := 10
const PRIMES: Array[int] = [2, 3, 5, 7]
const FIELD_GLYPHS: Array[String] = ["ℕ", "△", "∂", "⊢"]

var rank: int
var field: Field


func _init(p_rank: int, p_field: Field) -> void:
	rank = p_rank
	field = p_field


func chips() -> int:
	return 11 if rank == INFINITY else rank


func is_prime() -> bool:
	return rank in PRIMES


func label() -> String:
	var r := "∞" if rank == INFINITY else str(rank)
	return "%s%s" % [r, FIELD_GLYPHS[field]]
