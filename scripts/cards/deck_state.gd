class_name DeckState
extends RefCounted

# 每张运行时卡牌在这些集合中恰好出现一次，UI 只能读取集合。
var draw_pile: Array[CardInstance] = []
var hand: Array[CardInstance] = []
var discard_pile: Array[CardInstance] = []


func get_card_count() -> int:
	return draw_pile.size() + hand.size() + discard_pile.size()
