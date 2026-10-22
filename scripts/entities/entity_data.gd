class_name EntityData
extends Resource
## 敌对能力定义；友善/中立身份可在 EventData 选项中表达。
@export var id: StringName
@export var display_name: String
@export_multiline var description: String
@export var asset_id: StringName
@export var max_hp: int = 18
@export var initial_state: StringName = &"WATCHING"
@export var damage_reduction: int = 0
@export var behavior_data: EntityBehaviorData
@export var weaknesses: Array[WeaknessData] = []
@export var reward_data: RewardTableData
@export var escape_damage_min: int = 2
@export var escape_damage_max: int = 4
@export var escape_stress: int = 2
# 通过活着退去确认的唯一知识；事件可以提供相同知识的替代路线。
@export var behavior_knowledge: StringName
