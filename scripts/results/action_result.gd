class_name ActionResult
extends RefCounted
## 一次事务计划，按最终写入所有者分组。失败时整份草案丢弃。
var success: bool = false
var failure_reason: StringName
var message: String
var expected_revision: int = -1
var expected_run: RunState
var player: PlayerActionResult = PlayerActionResult.new()
var combat: CombatActionResult = CombatActionResult.new()
var deck: DeckActionResult = DeckActionResult.new()
var equipment: EquipmentActionResult = EquipmentActionResult.new()
var floor: FloorActionResult = FloorActionResult.new()
var flow: FlowActionResult = FlowActionResult.new()
