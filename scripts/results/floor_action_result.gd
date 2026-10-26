class_name FloorActionResult
extends RefCounted
## 地图/历史激活计划，MapSystem 落地。activate 为 null 表示不换层。
var activate: FloorState
var new_floor: bool = false
var reenter: bool = false
# 先移动/结算当前图，再激活目标；旧节点的收益不能落到新楼层。
var move_to: StringName
var resolve_current: bool = false
var reveal: Array[StringName] = []
var event_outcome: StringName
