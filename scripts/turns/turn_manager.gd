class_name TurnManager
extends Node

signal turn_started(turn_number: int)

var run_state: RunState = RunState.new()


func _ready() -> void:
	_announce_turn_start()


func end_turn() -> void:
	var ended_turn: int = run_state.turn_number
	run_state.turn_number += 1
	run_state.ap = RunState.AP_PER_TURN
	if OS.is_debug_build():
		print("[TURN] end turn=%d" % ended_turn)
	_announce_turn_start()


func _announce_turn_start() -> void:
	if OS.is_debug_build():
		print("[TURN] start turn=%d ap=%d" % [run_state.turn_number, run_state.ap])
	turn_started.emit(run_state.turn_number)
