class_name EventData
extends Resource

@export var id: StringName
@export var display_name: String
@export_multiline var display_text: String
@export var required_flags: Array[StringName] = []
@export var blocked_flags: Array[StringName] = []
@export var once_per_instance: bool = true
@export_range(1, 100, 1, "or_greater") var weight: int = 1
@export var action_results: Array[EventActionData] = []
@export var tags: Array[StringName] = []
@export_multiline var objective_text: String
@export var explore_threshold: int = 0
@export var clue_threshold: int = 0
@export_multiline var clue_text: String
@export var completion_insight: InsightData
@export var clue_insight: InsightData
@export var clue_stability: int = 0
@export var clue_knowledge: int = 0
@export var bonus_tag: StringName
@export var explore_bonus: int = 0
# 首轮只实现一种可读压力：未推进的未解局势在回合末增加压力。
@export var neglect_stress: int = 0
# 可格挡的环境伤害与旧 Stress 后果分开声明，不引入通用压力解释器。
@export var neglect_damage: int = 0


func has_action(action: StringName) -> bool:
	for rule: EventActionData in action_results:
		if rule != null and rule.action_id == action:
			return true
	return false
