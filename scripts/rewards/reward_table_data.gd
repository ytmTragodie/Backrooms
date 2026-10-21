class_name RewardTableData
extends Resource

# 奖励表数据，包含了奖励的类型和对应的奖励数据
@export var guaranteed_rewards: Array[RewardEntryData] = []
@export var random_groups: Array[RewardEntryData] = []
# 权重用于在随机奖励中确定该奖励的出现概率，权重越高，出现的概率越大,需要在资源文件中好好定义
@export var weights: Array[float] = []