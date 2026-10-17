class_name ActionResult
extends RefCounted

# 记录本次动作的事实；ap_spent 是消耗量，权威 AP 仍只存于 RunState。
var success: bool = false
var failure_reason: StringName
var ap_spent: int = 0
var card_played: CardInstance
var effect: StringName
var damage_requested: int = 0
var debug_lines: Array[String] = []
