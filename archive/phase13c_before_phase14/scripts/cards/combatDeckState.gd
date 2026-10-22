class_name CombatDeckState
extends RefCounted  

# 本场战斗的抽牌堆、手牌、弃牌堆和消耗牌堆。
# 战斗开始时从长期卡组创建战斗牌区。
# 战斗内的抽牌、弃牌、消耗不直接改变长期卡组，除非卡牌效果明确规定永久变化。

var draw_pile: Array[CardInstance] = []
var hand: Array[CardInstance] = []
var discard_pile: Array[CardInstance] = [] # 弃牌堆
var exhaust_pile: Array[CardInstance] = [] # 这里保留为后面的消耗牌堆扩展做准备