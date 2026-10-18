class_name CardReward
extends RefCounted

# 机会属于本局；选项只是静态定义，领取前不创建牌实例，也不进入任何牌区。
var definition: CardRewardData
var choices: Array[CardData] = []
