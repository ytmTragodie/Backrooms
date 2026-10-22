class_name EquipmentInstance
extends RefCounted

# 电量、耐久、消耗次数共用一个运行时计数；含义和上限由只读定义说明。
var definition: EquipmentData
var remaining_uses: int


func _init(data: EquipmentData) -> void:
	definition = data
	remaining_uses = data.capacity
