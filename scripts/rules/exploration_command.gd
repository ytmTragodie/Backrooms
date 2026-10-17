class_name ExplorationCommand
extends RefCounted

var action_id: StringName


func _init(requested_action: StringName) -> void:
	action_id = requested_action
