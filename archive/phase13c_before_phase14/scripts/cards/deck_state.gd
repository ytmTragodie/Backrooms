class_name DeckState
extends RefCounted

# 玩家牌区的唯一权威所有者，跨楼层保留。
# hand 是三类行动牌的唯一可见手牌集合；抽弃牌堆仅允许 NORMAL。
# 装备牌也进入 hand，但装备生成调度属于 EquipmentState，不在这里保存。
var draw_pile: Array[CardInstance] = []
var hand: Array[CardInstance] = []
var discard_pile: Array[CardInstance] = []


func get_card_count() -> int:
	var count: int = draw_pile.size() + discard_pile.size()
	for card: CardInstance in hand:
		if card.source == CardData.Source.NORMAL:
			count += 1
	return count
