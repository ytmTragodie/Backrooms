class_name EventChange
extends RefCounted

# 只属于一次解析的私有计划；失败时不会写入事件实例。
var target: EventInstance
var remaining_turns: int
var matching_actions: int
var checked_turn: int
var retired: bool = false
var reason: StringName


func _init(event: EventInstance) -> void:
	target = event
	remaining_turns = event.remaining_turns
	matching_actions = event.matching_actions
	checked_turn = event.checked_turn

