class_name WeaknessData
extends Resource
## 条件反应，同一弱点有独立冷却，不递归触发自身。
@export var id: StringName
@export var trigger: TriggerData
@export var conditions: Array[ConditionData] = []
@export var effects: Array[EffectData] = []
# 回合间隔；即使填 0，同一回合仍至多一次，避免开关光源刷反应。
@export var cooldown: int = 1
@export var state_after: StringName
