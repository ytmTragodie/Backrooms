class_name CardRewardCommand
extends RefCounted

var reward: CardReward
var choice: CardData
var card: CardInstance
var captured_definition: CardData


func _init(opportunity: CardReward, selected: CardData = null, instance: CardInstance = null) -> void:
	reward = opportunity
	choice = selected
	card = instance
	captured_definition = instance.definition if instance != null else null
