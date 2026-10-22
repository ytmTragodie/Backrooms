class_name ResourceNode
extends RefCounted

enum Status { UNDISCOVERED, DISCOVERED, LOOTED, DEPLETED }

var node_id: StringName
var status: Status = Status.UNDISCOVERED


func _init(id: StringName) -> void:
	node_id = id
