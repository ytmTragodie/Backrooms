class_name UseEquipmentCommand
extends RefCounted

var slot_index: int


func _init(index: int = -1) -> void:
	slot_index = index
