class_name EntityBehaviorData
extends Resource

# 这里entity 指的是敌对实体，后续的友善实体 在别处定义，另外再重新加
# 定义敌人的行为类型和顺序规律

@export var actions : Array[EntityActionData] = []