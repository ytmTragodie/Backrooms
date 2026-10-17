class_name TurnManager
extends Node

signal turn_started(turn_number: int)
signal state_changed
signal action_resolved(result: ActionResult)

@export var starter_deck: DeckData = preload("res://data/cards/starter_deck.tres")

# 本节点与 CardSystem 始终绑定同一局状态；新一局应创建新的 TurnManager。
var _run_state: RunState = RunState.new()
var run_state: RunState:
	get:
		return _run_state
	set(_value):
		push_error("RunState cannot be replaced; create a new TurnManager for a new run")
var card_system: CardSystem


func _ready() -> void:
	card_system = CardSystem.new(run_state, starter_deck.cards)
	card_system.draw_to_hand_size()
	if OS.is_debug_build():
		print("[RUN] seed=%d" % run_state.rng_seed)
	_announce_turn_start()


func end_turn() -> void:
	var ended_turn: int = run_state.turn_number
	if OS.is_debug_build():
		print("[TURN] end turn=%d" % ended_turn)
	card_system.discard_hand()
	run_state.turn_number += 1
	run_state.ap = RunState.AP_PER_TURN
	card_system.draw_to_hand_size()
	_announce_turn_start()


func request_play_card(card: CardInstance) -> ActionResult:
	# 所有对外出牌请求统一经过这里，避免提交成功却漏发界面通知。
	var result: ActionResult = RuleResolver.resolve(PlayCardCommand.new(card), run_state, card_system)
	# 完整提交后才通知；失败仅发布结果，不伪装成一次状态变化。
	if result.success:
		state_changed.emit()
	action_resolved.emit(result)
	return result


func _announce_turn_start() -> void:
	if OS.is_debug_build():
		print("[TURN] start turn=%d ap=%d" % [run_state.turn_number, run_state.ap])
	turn_started.emit(run_state.turn_number)
	state_changed.emit()
