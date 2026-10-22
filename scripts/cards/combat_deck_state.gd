class_name CombatDeckState
extends RefCounted
## 单场战斗牌区。四个数组互斥，临时装备牌不进入永久牌组。
var draw_pile: Array[CardInstance] = []
var hand: Array[CardInstance] = []
var discard_pile: Array[CardInstance] = []
var exhaust_pile: Array[CardInstance] = []
func copy() -> CombatDeckState:
	var next: CombatDeckState = CombatDeckState.new()
	next.draw_pile.assign(draw_pile)
	next.hand.assign(hand)
	next.discard_pile.assign(discard_pile)
	next.exhaust_pile.assign(exhaust_pile)
	return next
