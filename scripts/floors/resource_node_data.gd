class_name ResourceNodeData
extends Resource

@export var id: StringName
@export var display_name: String
@export var hidden: bool = false
# 搜索结算可补充实际携带物；没有新背包／材料或独立修理按钮。
@export var supply_reward: int = 1
@export var equipment_id: StringName
@export var uses_reward: int = 0
