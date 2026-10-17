class_name EntityInstance
extends RefCounted

# 状态、HP 和意图都属于本次遭遇；Data 不保存任何可变生命值。
var entity_id: StringName
var hp: int
var max_hp: int
var state: StringName
var intent: StringName
# 区分“主动攻击惹怒”与“实际观察到光照反应”，前者不能凭空验证避光 Insight。
var light_exposed: bool = false
var alive: bool:
	get:
		return hp > 0
var active: bool:
	get:
		return alive and state not in [&"DISENGAGED", &"WITHDRAWN"]
