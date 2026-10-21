class_name ActionResult
extends RefCounted

# 一次命令的完整草案。各领域只读取/写入自己的子结果；
# success/failure_reason/action_id 是执行元数据，不是玩法状态。
var success: bool = false
var failure_reason: StringName
var action_id: StringName
var debug_lines: Array[String] = []

var card := CardActionResult.new()
var player := PlayerActionResult.new()
var deck := DeckActionResult.new()
var objective := ObjectiveActionResult.new()
var entity := EntityActionResult.new()
var event := EventActionResult.new()
var equipment := EquipmentActionResult.new()
var cutout := CutOutActionResult.new()
var floor := FloorActionResult.new()
var run := RunFlowResult.new()