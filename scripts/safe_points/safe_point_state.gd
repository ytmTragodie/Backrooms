class_name SafePointState
extends RefCounted

var definition: SafePointData
var reached: bool = false
var consumed: bool = false


func _init(data: SafePointData) -> void:
	definition = data
