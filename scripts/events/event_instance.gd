class_name EventInstance
extends RefCounted

# 临时事件没有 Explore；计时与机会条件计数不与 Objective 进度混用。
var definition: EventData
var remaining_turns: int
var matching_actions: int = 0
var checked_turn: int = 0
var retired: bool = false


func _init(data: EventData) -> void:
	definition = data
	remaining_turns = data.duration
