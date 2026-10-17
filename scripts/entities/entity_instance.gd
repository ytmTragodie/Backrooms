class_name EntityInstance
extends RefCounted

# 状态、HP 和意图都属于本次遭遇；Data 不保存任何可变生命值。
var entity_id: StringName
var hp: int
var max_hp: int
var state: StringName
var intent: StringName
var alive: bool:
	get:
		return hp > 0
var active: bool:
	get:
		return alive and state != &"DISENGAGED"
