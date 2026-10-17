class_name CardInstance
extends RefCounted

# 同一定义的多张牌依靠不同实例区分；所在牌区由 DeckState 的集合表达。
var definition: CardData


func _init(card_definition: CardData) -> void:
	definition = card_definition
