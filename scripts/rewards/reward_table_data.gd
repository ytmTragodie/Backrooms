class_name RewardTableData
extends Resource
## guaranteed 全发；random_rewards 按权重无放回抽 random_count 项。
@export var id: StringName
@export var guaranteed_rewards: Array[RewardEntryData] = []
@export var random_rewards: Array[RewardEntryData] = []
@export var random_count: int = 0
