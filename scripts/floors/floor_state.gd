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
var board_state: BoardState = BoardState.new()
# 旧领域读取暂保留只读转发；调度器只写 BoardState，不维护第二份事件引用。
var current_event: EventInstance:
	get:
		return board_state.active_event
# ID 从实例派生，避免两份可写的“当前事件”状态。
var current_event_id: StringName:
	get:
		return current_event.event_id if current_event != null else &""
var floor_flags: Array[StringName] = []
var resource_nodes: Array[ResourceNode] = []
var cutout_state: CutOutState = CutOutState.new()
var entity: EntityInstance:
	get:
		return board_state.entity
	set(value):
		board_state.entity = value
var player_block: int = 0
var dark_observation_used: bool = false
var light_active: bool = false


func _init(definition: FloorData) -> void:
	assert(definition != null and not definition.id.is_empty(), "Floor needs a stable ID")
	floor_id = definition.id
	floor_flags = definition.initial_flags.duplicate()
	if definition.entry_entity != null:
		entity = EntitySystem.spawn(definition.entry_entity)
	for node: ResourceNodeData in definition.resource_nodes:
		assert(node != null and not node.id.is_empty() and find_resource(node.id) == null, "Resource node needs a unique stable ID")
		resource_nodes.append(ResourceNode.new(node.id))
	for resource: Resource in definition.cutout_destinations:
		var destination: FloorData = resource as FloorData
		assert(destination != null and not destination.id.is_empty(), "Cut-out destination needs a stable ID")
		cutout_state.destination_candidates.append(destination.id)
	for event: EventData in definition.fresh_events:
		assert(event != null and not event.id.is_empty(), "Fresh event needs a stable ID")
		assert(not remaining_fresh_events.has(event.id), "Duplicate Fresh Event ID")
		remaining_fresh_events.append(event.id)


func find_resource(node_id: StringName) -> ResourceNode:
	for node: ResourceNode in resource_nodes:
		if node != null and node.node_id == node_id:
			return node
	return null
