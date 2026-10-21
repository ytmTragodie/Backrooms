class_name ObjectiveData
extends Resource

enum ObjectiveType {
	PROGRESS, # 累计探索进度
	CONDITION, # 任意顺序完成指定标签，重复标签不重复计数
	SEQUENCE # 按顺序完成指定标签，允许同一标签重复出现
}

@export var id: StringName
@export var asset_id: StringName
@export var display_name: String
@export_multiline var display_text: String

@export var required_flags: Array[StringName] = []
@export var blocked_flags: Array[StringName] = []

@export var once_per_instance: bool = true
@export_range(1, 100, 1, "or_greater") var weight: int = 1
# 旧 EventActionData 仅用于历史内容查找 Insight；新目标逻辑不读取。
@export var action_results: Array[EventActionData] = []
@export var tags: Array[StringName] = []
@export_multiline var objective_text: String

@export var objective_type: ObjectiveType = ObjectiveType.PROGRESS

# PROGRESS：完成所需的探索值。
@export var progress_threshold: int = 0
# CONDITION：需要完成的标签。重复标签在数据校验时拒绝。
@export var required_actions: Array[StringName] = []
# SEQUENCE：按顺序完成的标签。允许重复，例如 OBSERVE -> SEARCH -> OBSERVE。
@export var sequence_actions: Array[StringName] = []

# 线索阈值：PROGRESS 表示进度，CONDITION/SEQUENCE 表示已完成步骤数。
@export var clue_threshold: int = 0
@export_multiline var clue_text: String
@export var clue_insight: InsightData
@export var clue_stability: int = 0
@export var clue_knowledge: int = 0

# PROGRESS 的标签加成：牌面含有 bonus_tag 时额外增加 explore_bonus。
@export var bonus_tag: StringName
@export var explore_bonus: int = 0

# 回合末未推进时的环境后果；只由 ObjectiveSystem 规划、PlayerSystem 提交。
@export var neglect_stress: int = 0
@export var neglect_damage: int = 0

# 线索揭示时是否立刻点亮光源。
@export var clue_light_exposure: bool = false

@export var completion_supply: int = 0
@export var completion_insight: InsightData
@export var completion_reward: CardRewardData


func has_action(action: StringName) -> bool:
	for rule: EventActionData in action_results:
		if rule != null and rule.action_id == action:
			return true
	return false