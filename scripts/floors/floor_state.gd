class_name FloorState
extends RefCounted

const MAX_COGNITION: int = 5
const MAX_THREAT: int = 10

# 只保存本次驻留的可变值与稳定 ID，不把共享 Resource 当作运行时状态。
var floor_id: StringName
var turn_count: int = 1
var threat: int = 0
var cognition: int = 0
var discovered_insight_ids: Array[StringName] = []
var remaining_fresh_events: Array[StringName] = []
var seen_event_ids: Array[StringName] = []
var current_event: EventInstance
# ID 从实例派生，避免两份可写的“当前事件”状态。
var current_event_id: StringName:
	get:
		return current_event.event_id if current_event != null else &""
var floor_flags: Array[StringName] = []


func _init(definition: FloorData) -> void:
	assert(definition != null and not definition.id.is_empty(), "Floor needs a stable ID")
	floor_id = definition.id
	for event: EventData in definition.fresh_events:
		assert(event != null and not event.id.is_empty(), "Fresh event needs a stable ID")
		assert(not remaining_fresh_events.has(event.id), "Duplicate Fresh Event ID")
		remaining_fresh_events.append(event.id)
