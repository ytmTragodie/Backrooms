class_name CardInstance
extends RefCounted

# 同一定义的多张牌依靠不同实例区分；所在牌区由 DeckState 的集合表达。
var definition: CardData
var source_equipment: EquipmentInstance
# 绑定访问内身份而非 floor_id；重访同一楼层也不能复用旧临时牌。
var source_board: BoardState
var source: CardData.Source:
	get:
		return definition.source


func _init(card_definition: CardData) -> void:
	definition = card_definition
