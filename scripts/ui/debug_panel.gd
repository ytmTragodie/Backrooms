extends PanelContainer

signal test_run_requested(floor: FloorData, deck: DeckData)

const LEVEL_0: FloorData = preload("res://data/floors/floor_level_0.tres")
const LEVEL_6: FloorData = preload("res://data/floors/floor_level_6.tres")
const RUN_DECK: DeckData = preload("res://data/cards/run_deck.tres")
const MIXED_DECK: DeckData = preload("res://data/cards/mixed_deck.tres")


func _ready() -> void:
	# 隐藏调试工具不参与主布局，也不在发布构建开放。
	hide()
	if not OS.is_debug_build():
		process_mode = Node.PROCESS_MODE_DISABLED
		return
	$Padding/Layout/StartLevel0.pressed.connect(_request_run.bind(LEVEL_0, RUN_DECK))
	$Padding/Layout/StartLevel6.pressed.connect(_request_run.bind(LEVEL_6, MIXED_DECK))
	$Padding/Layout/Close.pressed.connect(hide)


func _unhandled_key_input(event: InputEvent) -> void:
	if OS.is_debug_build() and event is InputEventKey:
		var key: InputEventKey = event as InputEventKey
		if key.pressed and not key.echo and key.keycode == KEY_F8:
			visible = not visible
			get_viewport().set_input_as_handled()


func update_context(value: String) -> void:
	$Padding/Layout/Context.text = value


func _request_run(floor: FloorData, deck: DeckData) -> void:
	if not OS.is_debug_build():
		return
	test_run_requested.emit(floor, deck)
	hide()
