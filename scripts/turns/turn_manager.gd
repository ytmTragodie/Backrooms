class_name TurnManager
extends Node

signal turn_started(turn_number: int)
signal state_changed

@export var starter_deck: DeckData = preload("res://data/cards/starter_deck.tres")

var run_state: RunState = RunState.new()
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


func play_card(card: CardInstance) -> bool:
	if not card_system.play_card(card):
		return false
	state_changed.emit()
	return true


func _announce_turn_start() -> void:
	if OS.is_debug_build():
		print("[TURN] start turn=%d ap=%d" % [run_state.turn_number, run_state.ap])
	turn_started.emit(run_state.turn_number)
	state_changed.emit()
