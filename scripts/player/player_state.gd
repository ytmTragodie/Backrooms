class_name PlayerState
extends RefCounted
## 跨战斗玩家状态；没有 AP/Block/Intel/Noise 的平行副本。
var hp: int = 30
var max_hp: int = 30
var stress: int = 0
var supply: int = 5
var deck: DeckState = DeckState.new()
var equipment: EquipmentState = EquipmentState.new()
var knowledge: KnowledgeState = KnowledgeState.new()
