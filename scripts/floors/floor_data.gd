class_name FloorData
extends Resource

@export var id: StringName
@export var display_name: String
@export var fresh_events: Array[EventData] = []
@export var overstay_start_turn: int = 3
@export var overstay_interval: int = 2
@export var resource_nodes: Array[ResourceNodeData] = []
# 不使用自引用 Array[FloorData] 导出，避免 Godot 脚本默认值形成引用环。
# 读取时明确转换并校验，内容仍由楼层 Resource 配置。
@export var cutout_destinations: Array[Resource] = []
@export var is_placeholder: bool = false
@export_multiline var placeholder_description: String
@export var initial_flags: Array[StringName] = []
@export var dark_observe_surcharge: int = 0
@export var entry_entity: EntityData


func find_event(event_id: StringName) -> EventData:
	for event: EventData in fresh_events:
		if event.id == event_id:
			return event
	return null


func find_insight(insight_id: StringName) -> InsightData:
	for event: EventData in fresh_events:
		for rule: EventActionData in event.action_results:
			if rule.insight != null and rule.insight.id == insight_id:
				return rule.insight
	return null


func find_resource(node_id: StringName) -> ResourceNodeData:
	for definition: ResourceNodeData in resource_nodes:
		if definition != null and definition.id == node_id:
			return definition
	return null


func find_destination(destination_id: StringName) -> FloorData:
	for resource: Resource in cutout_destinations:
		var definition: FloorData = resource as FloorData
		if definition != null and definition.id == destination_id:
			return definition
	return null
