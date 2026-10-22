class_name CardInstance
extends RefCounted
## 一张真实牌；战斗牌与持有牌实例分离，定义可以共享。
var definition: CardData
var source_equipment: EquipmentInstance
func _init(data: CardData = null) -> void:
	definition = data
