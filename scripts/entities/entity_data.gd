class_name EntityData
extends Resource
# 这里entity 指的是敌对实体，后续的友善实体 在别处定义，另外再重新加
enum BehaviorType { PURSUIT, LIGHT_REACTIVE }

@export var id: StringName
@export var display_name: String
@export var description: String
@export var behavior_data : EntityBehaviorData # 添加实体的行为序列约束，规范化实体的行为。
@export var weaknesses : Array[EntityWeeknessData] = [] #定义实体的弱点数据，包含弱点类型、伤害加成和触发条件等信息。
@export var reward_data : RewardTableData # 定义实体的奖励数据，包含战斗胜利后的奖励和调查奖励等。
@export var escape_punishments : Array[EffectData] = [] # 定义逃跑惩罚数据，包含逃跑后对玩家的负面影响和惩罚效果等。
@export var max_hp: int = 18
@export var initial_state: StringName = &"WATCHING"
@export var normal_damage: int = 4
@export var aggressive_damage: int = 5
@export var behavior_type: BehaviorType = BehaviorType.PURSUIT
@export var rule_insight: InsightData
# 调查是知识路线，不折算伤害；阈值为零表示该旧内容尚未迁移。
@export var analysis_threshold: int = 0
@export_multiline var analysis_rule: String
@export var resolution_reward: CardRewardData
@export var reward_requires_light_exposure: bool = false
