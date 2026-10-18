class_name SafePointPanel
extends PanelContainer

signal command_submitted(command: SafePointCommand)

@onready var _options: VBoxContainer = $Margin/Layout/Scroll/Options
@onready var _title: Label = $Margin/Layout/Title
@onready var _back: Button = $Margin/Layout/Footer/Back
var _view_state: RunState


func _ready() -> void:
	GameUITheme.style_modal(self)
	_back.pressed.connect(func() -> void: open(_view_state))
	$Margin/Layout/Footer/Close.pressed.connect(hide)


func refresh(state: RunState) -> void:
	if not SafePointSystem.available(state):
		hide()


func open(state: RunState) -> void:
	if not SafePointSystem.available(state):
		return
	show()
	_view_state = state
	_back.hide()
	_clear()
	_title.text = "临时安全点\n你可以进行一次整备"
	var point: SafePointState = state.floor_state.safe_point
	var rest: Button = _button("休整\n恢复生命 %d，缓解压力 %d" % [point.definition.heal, point.definition.stress_relief])
	rest.disabled = state.player_hp == RunState.MAX_PLAYER_HP and state.stress == 0
	rest.tooltip_text = "当前无需休整" if rest.disabled else "本次安全点只能选择一项"
	rest.pressed.connect(func() -> void: command_submitted.emit(SafePointCommand.new(state.floor_state.board_state, point, SafePointCommand.Choice.REST)))
	for choice: SafePointCommand.Choice in [SafePointCommand.Choice.REMOVE, SafePointCommand.Choice.UPGRADE]:
		var kind: CardRewardData.Kind = CardRewardData.Kind.REMOVE_CARD if choice == SafePointCommand.Choice.REMOVE else CardRewardData.Kind.UPGRADE_CARD
		var button: Button = _button("整理牌组\n移除一张普通牌，至少保留五张" if choice == SafePointCommand.Choice.REMOVE else "强化\n升级一张普通牌")
		button.disabled = CardRewardSystem.eligible_cards(state, kind).is_empty()
		button.tooltip_text = "当前没有符合条件的普通牌" if button.disabled else "先查看候选，确认后才消耗整备机会"
		button.pressed.connect(_show_candidates.bind(state, choice, kind))


func _show_candidates(state: RunState, choice: SafePointCommand.Choice, kind: CardRewardData.Kind) -> void:
	_clear()
	_back.show()
	_title.text = "整理牌组：选择一张移除" if choice == SafePointCommand.Choice.REMOVE else "强化：选择一张升级"
	for card: CardInstance in CardRewardSystem.eligible_cards(state, kind):
		var zone: String = "当前手牌" if state.deck_state.hand.has(card) else ("抽牌堆" if state.deck_state.draw_pile.has(card) else "弃牌堆")
		var text: String = zone + "｜" + CardText.description(card.definition)
		if choice == SafePointCommand.Choice.UPGRADE:
			text += "\n升级为：" + CardText.description(card.definition.upgrade_to)
		var command: SafePointCommand = SafePointCommand.new(state.floor_state.board_state, state.floor_state.safe_point, choice, card)
		_button(text).pressed.connect(func() -> void: command_submitted.emit(command))


func _clear() -> void:
	for child: Node in _options.get_children():
		_options.remove_child(child)
		child.queue_free()


func _button(text: String) -> Button:
	var button: Button = Button.new()
	button.text = text
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	button.custom_minimum_size.y = 68
	button.add_theme_stylebox_override("normal", GameUITheme.panel(Color("252923"), GameUITheme.GREEN))
	_options.add_child(button)
	return button
