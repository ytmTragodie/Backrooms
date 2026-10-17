class_name ExplorationCommand
extends RefCounted

var action_id: StringName
var target_id: StringName


func _init(requested_action: StringName, requested_target: StringName = &"") -> void:
	action_id = requested_action
	target_id = requested_target
