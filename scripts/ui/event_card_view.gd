class_name EventCardView
extends PanelContainer

var instance: EventInstance
var _timer: Label
var _title: Label
var _effect: Label
var _art: TextureRect
var _last_timer: int = -1


func _ready() -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	custom_minimum_size.y = 64
	mouse_filter = Control.MOUSE_FILTER_PASS
	var row: HBoxContainer = HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(row)
	_art = GameUITheme.texture(row, &"event_level0_humming")
	_art.custom_minimum_size = Vector2(48, 44)
	var info: VBoxContainer = VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info.add_theme_constant_override("separation", 1)
	row.add_child(info)
	_title = GameUITheme.label(info, "", 14)
	_effect = GameUITheme.label(info, "", 13)
	_effect.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_effect.max_lines_visible = 2
	_effect.clip_text = true
	_effect.custom_minimum_size.y = 30
	_timer = GameUITheme.label(row, "", 15)
	_timer.custom_minimum_size.x = 54
	_timer.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT


func present(event: EventInstance) -> void:
	instance = event
	var data: EventData = event.definition
	var color: Color = [GameUITheme.RED, GameUITheme.GOLD, GameUITheme.GREEN][data.category]
	add_theme_stylebox_override("panel", GameUITheme.panel(Color(0.08, 0.10, 0.11, 0.94), color))
	_title.text = "%s · %s" % [["负面", "前兆", "机会"][data.category], data.display_name]
	_title.add_theme_color_override("font_color", color)
	_effect.text = data.display_text
	_timer.text = "%d 回合" % event.remaining_turns
	if data.category == EventData.Category.OPPORTUNITY:
		_timer.text += "\n%d／%d" % [event.matching_actions, data.required_actions]
	elif event.remaining_turns == 0:
		_timer.text = "等待\n空位"
	_art.texture = AssetCatalog.texture(data.id)
	tooltip_text = "%s\n%s\n剩余 %d 回合" % [_title.text, data.display_text, event.remaining_turns]
	if _last_timer >= 0 and _last_timer != event.remaining_turns:
		_timer.modulate = Color("ffc976")
		create_tween().tween_property(_timer, "modulate", Color.WHITE, 0.18)
	_last_timer = event.remaining_turns
