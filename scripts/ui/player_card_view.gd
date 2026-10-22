class_name PlayerCardView
extends Button
## 纯呈现：真实 CardInstance 与只读合法性。不保存游戏数值。
var card: CardInstance
var _face: Panel
var _raised: Tween

func present(instance: CardInstance, error: StringName) -> void:
	card = instance
	custom_minimum_size = Vector2(144, 222)
	disabled = not error.is_empty()
	tooltip_text = CardText.description(card.definition) + ("\n暂不可用：" + MainGameView.error_text(error) if disabled else "")
	flat = true
	_face = Panel.new()
	_face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_face.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_face.add_theme_stylebox_override("panel", GameUITheme.panel(Color("171c1e"), GameUITheme.BLUE))
	add_child(_face)
	var frame: TextureRect = GameUITheme.texture(_face, &"frame_equipment" if card.definition.source == CardData.Source.EQUIPMENT else &"frame_player")
	frame.stretch_mode = TextureRect.STRETCH_SCALE
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var art: TextureRect = GameUITheme.texture(_face, card.definition.id)
	art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	art.anchor_left = 0.07
	art.anchor_right = 0.93
	art.anchor_top = 0.08
	art.anchor_bottom = 0.44
	var name_paper: TextureRect = GameUITheme.texture(_face, &"ui_name_panel")
	name_paper.position = Vector2(10,104)
	name_paper.size = Vector2(124,28)
	var title: Label = GameUITheme.label(_face, card.definition.display_name, 16, GameUITheme.INK)
	title.position = Vector2(10, 105)
	title.size = Vector2(124, 25)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var body_paper: TextureRect = GameUITheme.texture(_face, &"ui_description_panel")
	body_paper.position = Vector2(10, 137)
	body_paper.size = Vector2(124, 61)
	var primary: String = CardText.effects_text(card.definition.effects)
	if card.definition.source == CardData.Source.EQUIPMENT and card.definition.equipment_cost > 0: primary += "\n装备次数 -%d" % card.definition.equipment_cost
	var body: Label = GameUITheme.label(_face, primary, 12, GameUITheme.INK)
	body.position = Vector2(17, 138)
	body.size = Vector2(116, 59)
	body.clip_text = true
	body.max_lines_visible = 3
	var cost: Label = GameUITheme.label(_face, str(card.definition.ap_cost), 20)
	cost.position = Vector2(12, 4)
	var keyword: Label = GameUITheme.label(_face, "情报 %d" % card.definition.intel_cost if card.definition.intel_cost > 0 else "消耗" if card.definition.exhaust else "保留" if card.definition.retain else "", 11)
	keyword.position = Vector2(55, 9)
	var source: Label = GameUITheme.label(_face, "装备 · 剩余%d" % card.source_equipment.remaining_uses if card.source_equipment != null else "M.E.G. 战术", 11)
	source.position = Vector2(14, 202)
	source.add_theme_color_override("font_outline_color",Color.BLACK)
	source.add_theme_constant_override("outline_size",2)
	_face.modulate = Color(0.52, 0.52, 0.52) if disabled else Color.WHITE
	mouse_entered.connect(func() -> void: _hover(true))
	mouse_exited.connect(func() -> void: _hover(false))

func _hover(raised: bool) -> void:
	if _raised != null: _raised.kill()
	_raised = create_tween()
	_raised.tween_property(_face, "position:y", -8.0 if raised else 0.0, 0.10)
	z_index = 4 if raised else 0
