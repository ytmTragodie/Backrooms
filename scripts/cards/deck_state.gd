class_name DeckState
extends RefCounted

var draw_pile: Array[CardInstance] = []
var hand: Array[CardInstance] = []
var discard_pile: Array[CardInstance] = []


func get_card_count() -> int:
	return draw_pile.size() + hand.size() + discard_pile.size()
