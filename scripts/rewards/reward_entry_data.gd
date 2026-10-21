class_name RewardEntryData
extends Resource
# 定义奖励条目数据结构，包含奖励类型、数量、资源和权重等信息

# 奖励的类型包含卡牌选项，补给、装备、治疗和冷静（降低压力值）等类型
enum RewardType { 
    CARD_CHOICE, 
    SUPPLY, 
    EQUIPMENT, 
    HEAL,
    CALM 
}

@export var type: RewardType = RewardType.CARD_CHOICE
@export var amount: int = 1
@export var resource: Resource

