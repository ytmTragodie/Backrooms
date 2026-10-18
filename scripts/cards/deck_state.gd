class_name DeckState
extends RefCounted

# hand 是三类行动牌的唯一可见手牌集合；抽弃牌堆仅允许 NORMAL。
var draw_pile: Array[CardInstance] = []
var hand: Array[CardInstance] = []
var discard_pile: Array[CardInstance] = []
var equipment_generation_turn: int = -1
var next_equipment_slot: int = 0


func get_card_count() -> int:
	var count: int = draw_pile.size() + discard_pile.size()
	for card: CardInstance in hand:
		if card.source == CardData.Source.NORMAL:
			count += 1
	return count
