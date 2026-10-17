extends Control

@onready var _turn_manager: TurnManager = $TurnManager
@onready var _stats_label: Label = %RunStats
@onready var _end_turn_button: Button = %EndTurn
@onready var _pile_counts: Label = %PileCounts
@onready var _hand: VBoxContainer = %Hand
@onready var _status_label: Label = %Status


func _ready() -> void:
	_turn_manager.state_changed.connect(_refresh_state)
	_turn_manager.action_resolved.connect(_on_action_resolved)
	_end_turn_button.pressed.connect(_turn_manager.end_turn)
	_refresh_state()
	print("[APP] Project initialized")


func _on_action_resolved(result: ActionResult) -> void:
	if result.success:
		_status_label.text = "Played %s | AP spent: %d | Damage requested: %d" % [result.card_played.definition.display_name, result.ap_spent, result.damage_requested]
	else:
		_status_label.text = "Play failed: %s" % result.failure_reason


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
	var deck: DeckState = state.deck_state
	_pile_counts.text = "Draw pile: %d | Discard pile: %d" % [deck.draw_pile.size(), deck.discard_pile.size()]
	for child: Node in _hand.get_children():
		_hand.remove_child(child)
		child.queue_free()
	for card: CardInstance in deck.hand:
		var play_button: Button = Button.new()
		play_button.text = "%s | AP: %d | Play" % [card.definition.display_name, card.definition.ap_cost]
		# UI 只转发请求；规则验证、AP 扣除和牌区移动全部留在领域层。
		play_button.pressed.connect(_turn_manager.request_play_card.bind(card))
		_hand.add_child(play_button)
