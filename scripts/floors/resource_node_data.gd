class_name ResourceNodeData
extends Resource

@export var id: StringName
@export var display_name: String
@export var hidden: bool = false
# 电池、材料在本阶段统一折算补给，不提前引入背包或制作系统。
@export var supply_reward: int = 1
