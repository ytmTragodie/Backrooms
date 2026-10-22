class_name SafePointCommand
extends RefCounted

enum Choice { REST, REMOVE, UPGRADE }

var board: BoardState
var point: SafePointState
var choice: Choice
var card: CardInstance
var captured_definition: CardData


func _init(visit: BoardState, opportunity: SafePointState, option: Choice, instance: CardInstance = null) -> void:
	board = visit
	point = opportunity
	choice = option
	card = instance
	captured_definition = instance.definition if instance != null else null
