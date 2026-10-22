class_name EntityInstance
extends RefCounted
## 战斗实例，HP/防护/状态/冷却唯一所有者。
var instance_id: int
var definition: EntityData
var hp: int
var block: int = 0
var state: StringName
var current_intent: EnemyIntent
var statuses: Array[StatusInstance] = []
var last_actions: Dictionary = {}
var weakness_turns: Dictionary = {}
var previous_action: StringName
var alive: bool:
	get: return hp > 0
var active: bool:
	get: return alive and state != &"WITHDRAWN"

func copy() -> EntityInstance:
	var next: EntityInstance = EntityInstance.new()
	next.instance_id = instance_id
	next.definition = definition
	next.hp = hp
	next.block = block
	next.state = state
	next.current_intent = current_intent
	for status: StatusInstance in statuses: next.statuses.append(status.copy())
	next.last_actions = last_actions.duplicate()
	next.weakness_turns = weakness_turns.duplicate()
	next.previous_action = previous_action
	return next
