class_name EventInstance
extends RefCounted

# 每次激活事件都创建独立实例；共享 EventData 不保存已检查等局内进度。
var event_id: StringName
var completed_interactions: Array[StringName] = []
var known_information: Array[String] = []
var resolved: bool = false

var phase: StringName:
	get:
		if resolved:
			return &"resolved"
		return &"unresolved" if completed_interactions.is_empty() and known_information.is_empty() else &"partially_explored"


func _init(id: StringName) -> void:
	event_id = id


func can_interact(action: StringName) -> bool:
	return not resolved and not completed_interactions.has(action)
