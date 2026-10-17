extends SceneTree

const MAIN_SCENE: PackedScene = preload("res://scenes/main/Main.tscn")

var _failures: int = 0
var _observed_turns: Array[int] = []
var _manager: TurnManager


func _initialize() -> void:
	call_deferred("_run_validation")


func _run_validation() -> void:
	_test_initial_state()
	_test_turn_lifecycle()
	_test_main_scene()
	if _failures == 0:
		print("[TEST] PASS Phase 1: initial state, AP reset, repeated turns, independent runs, signals, UI commands")
	else:
		push_error("[TEST] FAIL Phase 1: %d checks failed" % _failures)
	quit(0 if _failures == 0 else 1)


func _test_initial_state() -> void:
	var state: RunState = RunState.new()
	_check(state.player_hp == 30, "New run starts at 30 HP")
	_check(state.stress == 0, "New run starts at 0 Stress")
	_check(state.threat == 0, "New run starts at 0 Threat")
	_check(state.cognition == 0, "New run starts at 0 Cognition")
	_check(state.turn_number == 1, "New run starts at turn 1")
	_check(state.ap == 3, "New run starts at 3 AP")


func _test_turn_lifecycle() -> void:
	_manager = TurnManager.new()
	_manager.turn_started.connect(_on_turn_started)
	root.add_child(_manager)
	_check(_observed_turns == [1], "Entering the tree announces turn 1 once")
	var state: RunState = _manager.run_state
	# Fixtures simulate spent AP until actions exist; production UI never writes state.
	state.ap = 0
	_manager.end_turn()
	_check(state.turn_number == 2, "End Turn advances exactly one turn")
	_check(state.ap == 3, "End Turn restores exhausted AP to 3")
	_check(_observed_turns == [1, 2], "End Turn announces the committed next turn once")
	state.ap = 1
	_manager.end_turn()
	_check(state.ap == 3, "Unused AP does not carry over")
	for expected_turn: int in range(4, 11):
		_manager.end_turn()
		_check(state.turn_number == expected_turn, "Repeated End Turn advances once per command")
		_check(state.ap == 3, "Repeated End Turn always resets AP")
	_check(_observed_turns.size() == 10, "One turn-start notification per turn")
	_check(state.player_hp == 30 and state.stress == 0, "Ending turns preserves HP and Stress")
	_check(state.threat == 0 and state.cognition == 0, "Phase 1 has no automatic Threat or Cognition rules")
	# Changing a fixture must not contaminate another run's state.
	state.player_hp = 12
	var other_manager: TurnManager = TurnManager.new()
	_check(other_manager.run_state != state, "Each manager owns an independent RunState")
	_check(other_manager.run_state.player_hp == 30, "A second run has fresh HP")
	_check(other_manager.run_state.turn_number == 1 and other_manager.run_state.ap == 3, "A second run has fresh turn and AP")
	other_manager.free()
	_manager.free()


func _on_turn_started(turn_number: int) -> void:
	_observed_turns.append(turn_number)
	_check(_manager.run_state.turn_number == turn_number, "Signal observers read the committed turn")
	_check(_manager.run_state.ap == 3, "AP is restored before UI notification")


func _test_main_scene() -> void:
	var main: Control = MAIN_SCENE.instantiate() as Control
	root.add_child(main)
	var manager: TurnManager = main.get_node("TurnManager") as TurnManager
	var stats: Label = main.get_node("CenterContainer/Messages/RunStats") as Label
	var end_turn: Button = main.get_node("CenterContainer/Messages/EndTurn") as Button
	_check(stats.text == "生命：30\n压力：0\n威胁：0\n认知：0\n回合：1\n行动点：3", "UI reads the initial domain state")
	manager.run_state.ap = 0
	end_turn.pressed.emit()
	_check(manager.run_state.turn_number == 2 and manager.run_state.ap == 3, "Button forwards End Turn to the manager")
	_check(stats.text == "生命：30\n压力：0\n威胁：0\n认知：0\n回合：2\n行动点：3", "UI refreshes from state after the command")
	end_turn.pressed.emit()
	_check(manager.run_state.turn_number == 3, "A second button press advances once")
	_check(stats.text.contains("回合：3"), "UI stays synchronized on repeated commands")
	main.free()


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		push_error("[TEST] %s" % message)
