class_name BoardCardView
extends Button

# 只共享两类目标牌真正共有的呈现；领域仍是不同的 Objective/Entity 实例。
var artwork: TextureRect
var information: VBoxContainer
var heading: Label
var is_target_valid: bool = false
var _selected: bool = false
var _previewing: bool = false
var _accent: Color = GameUITheme.GOLD
var _highlight: TextureRect


func _ready() -> void:
	clip_text = true
	custom_minimum_size = Vector2(360, 160)
	var margin: MarginContainer = MarginContainer.new()
	margin.name = "Content"
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(margin)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 12)
	var row: HBoxContainer = HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 14)
	margin.add_child(row)
	artwork = GameUITheme.texture(row, &"card_observe")
	artwork.custom_minimum_size.x = 142
	artwork.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	artwork.size_flags_stretch_ratio = 0.7
	information = VBoxContainer.new()
	information.mouse_filter = Control.MOUSE_FILTER_IGNORE
	information.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	information.size_flags_stretch_ratio = 1.3
	information.add_theme_constant_override("separation", 5)
	row.add_child(information)
	heading = GameUITheme.label(information, "", 19)
	heading.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if AssetCatalog.is_provided(&"fx_target_highlight"):
		_highlight = GameUITheme.texture(self, &"fx_target_highlight")
		_highlight.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_highlight.hide()
	_update_border()


func legacy_label(name_text: String, parent: Node = null, visible_value: bool = false) -> Label:
	var item: Label = GameUITheme.label(parent if parent != null else self, "", 13)
	item.name = name_text
	item.owner = owner if owner != null else self
	item.unique_name_in_owner = true
	item.visible = visible_value
	item.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	item.clip_text = true
	item.max_lines_visible = 2 if visible_value else 1
	# clip_text 会使 Label 的自动最小高度接近零；可见行必须明确保留阅读高度。
	if visible_value: item.custom_minimum_size.y = 19
	return item


func set_target_presentation(selected_value: bool, valid: bool = false, previewing: bool = false) -> void:
	_selected = selected_value
	is_target_valid = valid
	_previewing = previewing
	modulate = Color(0.48, 0.48, 0.48) if previewing and not valid else Color.WHITE
	if _highlight != null: _highlight.visible = selected_value or (previewing and valid)
	_update_border()


func _update_border() -> void:
	var border: Color = GameUITheme.BLUE if _previewing and is_target_valid else (Color("f1d48c") if _selected else _accent)
	var style: StyleBoxFlat = GameUITheme.panel(Color(0.07, 0.09, 0.10, 0.95), border, 2 if _selected or (_previewing and is_target_valid) else 1)
	for state: String in ["normal", "hover", "pressed", "disabled", "focus"]:
		add_theme_stylebox_override(state, style)

