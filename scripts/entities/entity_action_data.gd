class_name EntityActionData
extends Resource
## 满足条件后先取最高 priority，再按 weight 选择；选择只在锁定时抽 RNG。
@export var id: StringName
@export var display_name: String
@export var conditions: Array[ConditionData] = []
@export var priority: int = 0
@export var weight: int = 1
@export var cooldown: int = 0
@export var effects: Array[EffectData] = []
@export var state_after: StringName
# 当前锁定意图对撤离 HP 区间的小幅修正。
@export var escape_damage_modifier: int = 0
