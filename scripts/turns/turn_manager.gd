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
		ObjectiveSystem.draw_fresh(floor_data, run_state.floor_state, run_state.rng)
		EventSystem.fill_slots(run_state.floor_state, floor_data)
	card_system.begin_hand(floor_data)
	if OS.is_debug_build():
		print("[RUN] seed=%d" % run_state.rng_seed)
	_announce_turn_start()


func end_turn() -> ActionResult:
	# 解析器固定结算局势 -> 实体 -> 滞留 -> 清理；本节点仅推进计数与抽弃牌。
	var result: ActionResult = RuleResolver.resolve_end_turn(run_state, floor_data)
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
		ObjectiveSystem.draw_fresh(floor_data, run_state.floor_state, run_state.rng)
		EventSystem.fill_slots(run_state.floor_state, floor_data)
	card_system.begin_hand(floor_data)
	_announce_turn_start()
	action_resolved.emit(result)
	return result


func request_play_card(card: CardInstance, objective: ObjectiveInstance = null, board: BoardState = null, entity: EntityInstance = null) -> ActionResult:
	return submit_card_command(PlayCardCommand.new(card, objective, board, entity))


func submit_card_command(command: PlayCardCommand) -> ActionResult:
	# 所有对外出牌请求统一经过这里，避免提交成功却漏发界面通知。
	var result: ActionResult = RuleResolver.resolve(command, run_state, card_system, floor_data)
	if result.success and result.destination != null:
		# 换层只同步定义；不重建 Run、牌组、装备或恢复 AP。
		floor_data = result.destination
	# 完整提交后才通知；失败仅发布结果，不伪装成一次状态变化。
	if result.success:
		state_changed.emit()
	action_resolved.emit(result)
	return result


func _announce_turn_start() -> void:
	if floor_data != null and not floor_data.is_placeholder:
		var options: int = RuleResolver.legal_hand_options(run_state, floor_data)
		run_state.metrics.hands_checked += 1
		if options == 0:
			run_state.metrics.dead_hands += 1
		if options >= 2:
			run_state.metrics.multiple_option_hands += 1
		if OS.is_debug_build():
			print("[BALANCE] hand options=%d cards=%d turn=%d" % [options, run_state.deck_state.hand.size(), run_state.turn_number])
	if OS.is_debug_build():
		print("[TURN] start turn=%d ap=%d" % [run_state.turn_number, run_state.ap])
	turn_started.emit(run_state.turn_number)
	state_changed.emit()


func submit_reward_command(command: CardRewardCommand) -> ActionResult:
	var result: ActionResult = RuleResolver.resolve_reward(command, run_state)
	if result.success:
		state_changed.emit()
	action_resolved.emit(result)
	return result


func submit_safe_point_command(command: SafePointCommand) -> ActionResult:
	var result: ActionResult = RuleResolver.resolve_safe_point(command, run_state)
	if result.success:
		state_changed.emit()
	action_resolved.emit(result)
	return result
