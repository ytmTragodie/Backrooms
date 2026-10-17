class_name ActionResult
extends RefCounted

# 记录本次动作的事实；ap_spent 是消耗量，权威 AP 仍只存于 RunState。
var success: bool = false
var failure_reason: StringName
var ap_spent: int = 0
var card_played: CardInstance
var effect: StringName
var damage_requested: int = 0
var action_id: StringName
var event_id: StringName
var floor_flags_added: Array[StringName] = []
var insight_ids: Array[StringName] = []
var cognition_delta: int = 0
var threat_delta: int = 0
var threat_reason: StringName
# 事件变更计划与 AP、牌区变更一并提交，失败不留下半次交互。
var event_interaction: StringName
var event_information: Array[String] = []
var event_resolved: bool = false
var debug_lines: Array[String] = []
