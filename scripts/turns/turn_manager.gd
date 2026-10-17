class_name TurnManager
extends Node

signal turn_started(turn_number: int)
signal state_changed
signal action_resolved(result: ActionResult)

@export var starter_deck: DeckData = preload("res://data/cards/starter_deck.tres")
@export var floor_data: FloorData
@export var starting_equipment: Array[EquipmentData] = []

# 本节点与 CardSystem 始终绑定同一局状态；新一局应创建新的 TurnManager。
var _run_state: RunState = RunState.new()
var run_state: RunState:
	get:
		return _run_state
	set(_value):
		push_error("RunState cannot be replaced; create a new TurnManager for a new run")
var card_system: CardSystem


func _ready() -> void:
	var equipment_error: StringName = EquipmentSystem.initialize(run_state, starting_equipment)
	if not equipment_error.is_empty():
		push_error("Cannot initialize carry slots: %s" % equipment_error)
		return
	card_system = CardSystem.new(run_state, starter_deck.cards)
	if floor_data != null:
		run_state.floor_state = FloorState.new(floor_data)
		if OS.is_debug_build():
			print("[FLOOR] enter %s" % floor_data.id)
			if run_state.floor_state.entity != null:
				print("[ENTITY] spawn %s hp=%d state=%s" % [run_state.floor_state.entity.entity_id, run_state.floor_state.entity.hp, run_state.floor_state.entity.state])
		EventSystem.draw_fresh(floor_data, run_state.floor_state, run_state.rng)
	card_system.draw_to_hand_size()
	if OS.is_debug_build():
		print("[RUN] seed=%d" % run_state.rng_seed)
	_announce_turn_start()


func end_turn() -> ActionResult:
	# 滞留压力先经过规则结算；回合计数、弃牌、抽牌仍由本节点协调。
	var result: ActionResult = RuleResolver.resolve_exploration(ExplorationCommand.new(&"end_turn"), run_state, floor_data)
	if not result.success:
		action_resolved.emit(result)
		return result
	# 致命意图已完整提交；不再给死亡角色恢复 AP 或开启下一回合。
	if run_state.player_hp <= 0:
		state_changed.emit()
		action_resolved.emit(result)
		return result
	var ended_turn: int = run_state.turn_number
	if OS.is_debug_build():
		print("[TURN] end turn=%d" % ended_turn)
	card_system.discard_hand()
	run_state.turn_number += 1
	run_state.ap = RunState.AP_PER_TURN
	if run_state.floor_state != null:
		ResourceNodeSystem.finish_turn(run_state.floor_state)
		run_state.floor_state.turn_count += 1
		# 仅已解决事件在新回合推进；未完成事件及其交互记录继续保留。
		EventSystem.draw_fresh(floor_data, run_state.floor_state, run_state.rng)
	card_system.draw_to_hand_size()
	_announce_turn_start()
	action_resolved.emit(result)
	return result


func request_play_card(card: CardInstance) -> ActionResult:
	# 所有对外出牌请求统一经过这里，避免提交成功却漏发界面通知。
	var result: ActionResult = RuleResolver.resolve(PlayCardCommand.new(card), run_state, card_system, floor_data)
	# 完整提交后才通知；失败仅发布结果，不伪装成一次状态变化。
	if result.success:
		state_changed.emit()
	action_resolved.emit(result)
	return result


func request_use_equipment(slot_index: int) -> ActionResult:
	var result: ActionResult = RuleResolver.resolve_equipment(UseEquipmentCommand.new(slot_index), run_state, floor_data)
	if result.success:
		state_changed.emit()
	action_resolved.emit(result)
	return result


func request_exploration(action_id: StringName, target_id: StringName = &"") -> ActionResult:
	if action_id == &"end_turn":
		return end_turn()
	var result: ActionResult = RuleResolver.resolve_exploration(ExplorationCommand.new(action_id, target_id), run_state, floor_data)
	if result.success:
		# 解析器已提交楼层状态；在通知前同步相应的只读定义，不在信号里执行规则。
		if result.destination != null:
			floor_data = result.destination
		state_changed.emit()
	action_resolved.emit(result)
	return result


func _announce_turn_start() -> void:
	if OS.is_debug_build():
		print("[TURN] start turn=%d ap=%d" % [run_state.turn_number, run_state.ap])
	turn_started.emit(run_state.turn_number)
	state_changed.emit()
