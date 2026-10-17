extends Control

@onready var _turn_manager: TurnManager = $TurnManager
@onready var _stats_label: Label = %RunStats
@onready var _end_turn_button: Button = %EndTurn


func _ready() -> void:
	_turn_manager.turn_started.connect(_on_turn_started)
	_end_turn_button.pressed.connect(_turn_manager.end_turn)
	_refresh_state()
	print("[APP] Project initialized")


func _on_turn_started(_turn_number: int) -> void:
	_refresh_state()


func _refresh_state() -> void:
	var state: RunState = _turn_manager.run_state
	_stats_label.text = "HP: %d\nStress: %d\nThreat: %d\nCognition: %d\nTurn: %d\nAP: %d" % [
		state.player_hp,
		state.stress,
		state.threat,
		state.cognition,
		state.turn_number,
		state.ap,
	]
