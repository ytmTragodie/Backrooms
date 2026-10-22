class_name EntityActionResult
extends RefCounted

# 实体实例与本次对它的影响；玩家受到的伤害在 PlayerActionResult。
var target: EntityInstance
var spawned: EntityInstance

var hp_after: int = -1
var damage: int = 0

var state_after: StringName
var state_reason: StringName
var intent_after: StringName
var defeated: bool = false

# 观察/分析进度。
var analysis_after: int = -1
var analysis_applied: int = 0
var rule_revealed: String

# 本次实际执行的已公示意图。
var intent_resolved: StringName
# 本次光照是否让实体进入曝光状态。
var light_exposed: bool = false