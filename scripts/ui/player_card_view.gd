class_name PlayerCardView
extends Button

signal preview_requested(card: CardInstance)
signal preview_ended(card: CardInstance)

var card: CardInstance
var selected: bool = false
var target_compatible: bool = true
var _face: Panel
var _art: TextureRect
var _frame: TextureRect
var _name_label: Label
var _cost_label: Label
var _effect_label: Label
var _source_label: Label
var _keywords: Label
var _hovered: bool = false
var _tween: Tween
var _highlight: TextureRect


func _ready() -> void:
	clip_text = true
	flat = true
	for state: String in ["normal", "hover", "pressed", "focus", "disabled"]:
		add_theme_stylebox_override(state, StyleBoxEmpty.new())
	for state: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_disabled_color"]:
		add_theme_color_override(state, Color.TRANSPARENT)
	_face = Panel.new()
	_face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_face)
	var paper: TextureRect = GameUITheme.texture(_face, &"ui_card_background")
	paper.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_art = GameUITheme.texture(_face, &"card_observe")
	_frame = GameUITheme.texture(_face, &"frame_player")
	_frame.stretch_mode = TextureRect.STRETCH_SCALE
	_frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var name_panel: TextureRect = GameUITheme.texture(_face, &"ui_name_panel")
	name_panel.name = "NamePaper"
	var body: TextureRect = GameUITheme.texture(_face, &"ui_description_panel")
	body.name = "BodyPaper"
	var medallion: TextureRect = GameUITheme.texture(_face, &"ui_cost")
	medallion.name = "CostMedallion"
	_cost_label = GameUITheme.label(_face, "", 18)
	_cost_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_label = GameUITheme.label(_face, "", 14, GameUITheme.INK)
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_effect_label = GameUITheme.label(_face, "", 12, GameUITheme.INK)
	_effect_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_effect_label.clip_text = true
	_source_label = GameUITheme.label(_face, "", 11)
	_source_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_keywords = GameUITheme.label(_face, "", 11, GameUITheme.GOLD)
	_keywords.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_keywords.add_theme_color_override("font_outline_color", Color.BLACK)
	_keywords.add_theme_constant_override("outline_size", 2)
	if AssetCatalog.is_provided(&"fx_card_highlight"):
		_highlight = GameUITheme.texture(_face, &"fx_card_highlight")
		_highlight.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_highlight.hide()
	resized.connect(_layout)
	mouse_entered.connect(_enter)
	mouse_exited.connect(_leave)
	focus_entered.connect(_focus_preview)
	_layout()


func present(instance: CardInstance, cost: int, primary: String, detail: String, compatible: bool, unavailable: bool) -> void:
	card = instance
	disabled = unavailable
	target_compatible = compatible
	# Button.text 留给无障碍/既有输入验证；可见文字由受控短标签排版。
	text = "%s\n行动点：%d\n%s\n%s" % [card.definition.display_name, cost, detail, source_text()]
	tooltip_text = text
	_name_label.text = card.definition.display_name
	_cost_label.text = str(cost)
	_effect_label.text = primary
	_source_label.text = source_text()
	_keywords.text = "保留" if card.definition.retain else ("噪音" if card.definition.tags.has(&"NOISE") else "")
	if card.definition.threat_cost > 0:
		_keywords.text = "威胁+%d%s" % [card.definition.threat_cost, " · 噪音" if card.definition.tags.has(&"NOISE") else ""]
	_art.texture = AssetCatalog.texture(card.definition.id)
	_frame.texture = AssetCatalog.texture(&"frame_equipment" if card.source == CardData.Source.EQUIPMENT else &"frame_objective" if card.source == CardData.Source.FLOOR_TEMPORARY else &"frame_player")
	_update_visual()


func source_text() -> String:
	if card.source == CardData.Source.EQUIPMENT:
		return "装备牌 · 剩余%d" % card.source_equipment.remaining_uses
	if card.source == CardData.Source.FLOOR_TEMPORARY:
		return "楼层临时牌 · 保留"
	return "普通牌"


func set_selected(value: bool) -> void:
	selected = value
	_update_visual()


func _layout() -> void:
	if _face == null: return
	_face.size = size
	_face.position = Vector2(0, -10 if _hovered else 0)
	var w: float = size.x
	var h: float = size.y
	_art.position = Vector2(w * 0.065, h * 0.075)
	_art.size = Vector2(w * 0.87, h * 0.37)
	(_face.get_node("NamePaper") as Control).position = Vector2(w * 0.075, h * 0.46)
	(_face.get_node("NamePaper") as Control).size = Vector2(w * 0.85, h * 0.13)
	_name_label.position = Vector2(w * 0.08, h * 0.475)
	_name_label.size = Vector2(w * 0.84, h * 0.1)
	(_face.get_node("BodyPaper") as Control).position = Vector2(w * 0.075, h * 0.60)
	(_face.get_node("BodyPaper") as Control).size = Vector2(w * 0.85, h * 0.28)
	_effect_label.position = Vector2(w * 0.12, h * 0.615)
	_effect_label.size = Vector2(w * 0.76, h * 0.25)
	_effect_label.add_theme_font_size_override("font_size", clampi(int(h / 16), 12, 16))
	_name_label.add_theme_font_size_override("font_size", clampi(int(h / 14), 14, 20))
	(_face.get_node("CostMedallion") as Control).position = Vector2(w * 0.04, 3)
	(_face.get_node("CostMedallion") as Control).size = Vector2(30, 30)
	_cost_label.position = Vector2(w * 0.04, 3)
	_cost_label.size = Vector2(30, 29)
	_source_label.position = Vector2(w * 0.05, h * 0.89)
	_source_label.size = Vector2(w * 0.9, h * 0.095)
	_keywords.position = Vector2(w * 0.28, h * 0.035)
	_keywords.size = Vector2(w * 0.63, 20)


func _enter() -> void:
	_hovered = true
	_animate_hover()
	preview_requested.emit(card)


func _leave() -> void:
	_hovered = false
	_animate_hover()
	preview_ended.emit(card)


func _focus_preview() -> void:
	preview_requested.emit(card)


func _animate_hover() -> void:
	if _tween != null: _tween.kill()
	_tween = create_tween()
	_tween.tween_property(_face, "position:y", -10.0 if _hovered else 0.0, 0.1)
	z_index = 3 if _hovered else 0
	_update_visual()


func _update_visual() -> void:
	if _face == null: return
	var safe: bool = card != null and card.definition.effect_type == CardData.EffectType.CUTOUT_SAFE
	var border: Color = GameUITheme.GREEN if safe else (GameUITheme.BLUE if target_compatible else GameUITheme.GOLD)
	if selected or _hovered: border = Color("fff0b7")
	_face.add_theme_stylebox_override("panel", GameUITheme.panel(Color("15191a"), border, 2 if selected or _hovered else 1))
	_face.modulate = Color(0.65, 0.65, 0.65) if disabled else Color.WHITE
	_frame.modulate = Color("b4dca1") if safe else Color.WHITE
	if _highlight != null: _highlight.visible = selected or _hovered

