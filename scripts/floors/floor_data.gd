class_name FloorData
extends Resource

@export var id: StringName
@export var display_name: String
@export var fresh_events: Array[EventData] = []
# 正式可玩楼层必须声明卡牌规则；旧配置由解析器拒绝，不再提供旁路。
@export var card_first_exploration: bool = false
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
# 原型只容纳一个当前实体；后续遭遇必须在前一个失去活跃性后由命令进入。
@export var followup_entity: EntityData
@export var landmark_insight: InsightData
@export var rushed_cutout_card: CardData = preload("res://data/cards/generated/card_cutout_rushed.tres")
@export var safe_cutout_card: CardData = preload("res://data/cards/generated/card_cutout_safe.tres")
@export var followup_on_light: bool = false
@export var intro_event: EventData
@export var safe_point: SafePointData
@export var minimum_exit_turn: int = 1
@export var minimum_exit_explore: int = 0
@export var fallback_exit_turn: int = 2
@export var threat_damage_step: int = 0
@export var max_threat_damage_bonus: int = 2
# 旧测试夹具保留回合末退场；正式内容解决后立即清空，下一回合再补 Fresh。
@export var retire_resolved_situations: bool = false


func find_entity(entity_id: StringName) -> EntityData:
	for definition: EntityData in [entry_entity, followup_entity]:
		if definition != null and definition.id == entity_id:
			return definition
	return null


func find_event(event_id: StringName) -> EventData:
	for event: EventData in fresh_events:
		if event.id == event_id:
			return event
	return null


func find_insight(insight_id: StringName) -> InsightData:
	if landmark_insight != null and landmark_insight.id == insight_id:
		return landmark_insight
	for definition: EntityData in [entry_entity, followup_entity]:
		if definition != null and definition.rule_insight != null and definition.rule_insight.id == insight_id:
			return definition.rule_insight
	for event: EventData in fresh_events:
		if event.clue_insight != null and event.clue_insight.id == insight_id:
			return event.clue_insight
		if event.completion_insight != null and event.completion_insight.id == insight_id:
			return event.completion_insight
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
