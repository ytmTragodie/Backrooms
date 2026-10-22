class_name DeckState
extends RefCounted
## 整局永久持有牌，仅 NORMAL；没有手牌/抽弃堆。
var cards: Array[CardInstance] = []
func get_card_count() -> int:
	return cards.size()
