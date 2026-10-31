class_name GameUITheme
extends RefCounted

const INK: Color = Color("241d15")
const PAPER: Color = Color("e8d6ad")
const GOLD: Color = Color("bba36b")
const BLUE: Color = Color("7ba5ba")
const GREEN: Color = Color("a4b78c")
const RED: Color = Color("d78372")
static var _fonts: Dictionary = {}

static func release_fonts() -> void:
	_fonts.clear()

static func font(role: StringName = &"body") -> Font:
	var key: String = String(role) + str(AssetCatalog.development_preview)
	if _fonts.has(key): return _fonts[key]
	var fallback: SystemFont = SystemFont.new()
	fallback.font_names = PackedStringArray(["Microsoft YaHei UI", "Microsoft YaHei", "Noto Sans CJK SC", "WenQuanYi Micro Hei"])
	var source: Font = AssetCatalog.font(StringName("font_" + String(role)))
	if source == null:
		_fonts[key] = fallback
	else:
		# 不改共享 FontFile；缺少的简体字和符号由系统中文字体补全。
		var variation: FontVariation = FontVariation.new()
		variation.base_font = source
		variation.fallbacks = [fallback]
		_fonts[key] = variation
	return _fonts[key] as Font

static func apply_role(control: Control, role: StringName) -> void:
	control.add_theme_font_override("font",font(role))

static func archive_button(state: String) -> StyleBox:
	var id: StringName = StringName("ui_archive_" + ("hover" if state in ["hover","focus"] else "pressed" if state == "pressed" else "normal"))
	var box: StyleBoxTexture = StyleBoxTexture.new()
	box.texture = AssetCatalog.texture(id)
	box.modulate_color = Color("555343") if state in ["hover","focus"] else Color("242824") if state == "disabled" else Color("33362e")
	box.set_texture_margin_all(5)
	box.content_margin_left = 16
	box.content_margin_right = 16
	box.content_margin_top = 9
	box.content_margin_bottom = 9
	return box


static func panel(color: Color = Color("171b1d"), border: Color = GOLD, width: int = 1) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = border
	style.set_border_width_all(width)
	style.set_corner_radius_all(5)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	return style


static func build() -> Theme:
	var result: Theme = Theme.new()
	result.default_font_size = 15
	result.default_font = font(&"body")
	result.set_color("font_color", "Label", PAPER)
	for state: String in ["normal", "hover", "pressed", "focus", "disabled"]:
		result.set_stylebox(state, "Button", archive_button(state))
	result.set_color("font_color", "Button", PAPER)
	result.set_color("font_hover_color", "Button", Color("fff1cc"))
	result.set_color("font_disabled_color", "Button", Color("777b76"))
	result.set_stylebox("panel", "PanelContainer", panel())
	result.set_stylebox("background", "ProgressBar", panel(Color("111618"), Color("4c514b")))
	result.set_stylebox("fill", "ProgressBar", panel(GOLD, GOLD, 0))
	return result


static func label(parent: Node, value: String = "", font_size: int = 14, color: Color = PAPER) -> Label:
	var item: Label = Label.new()
	item.text = value
	apply_role(item,&"body")
	item.mouse_filter = Control.MOUSE_FILTER_IGNORE
	item.add_theme_font_size_override("font_size", font_size)
	item.add_theme_color_override("font_color", color)
	parent.add_child(item)
	return item

static func icon_label(parent: Node, id: StringName, text_value: String, color: Color = PAPER) -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation",5)
	parent.add_child(row)
	var icon: TextureRect = texture(row,id)
	icon.custom_minimum_size = Vector2(20,20)
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var text: Label = label(row,text_value,14,color)
	apply_role(text,&"numbers")
	return row


static func texture(parent: Node, asset_id: StringName) -> TextureRect:
	var item: TextureRect = TextureRect.new()
	item.texture = AssetCatalog.texture(asset_id)
	item.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	item.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	item.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(item)
	return item


static func style_modal(panel_node: PanelContainer) -> void:
	panel_node.add_theme_stylebox_override("panel", panel(Color("151a1c"), GOLD, 2))
	panel_node.z_index = 50
	var title: Label = panel_node.get_node("Margin/Layout/Title") as Label
	title.add_theme_color_override("font_color", PAPER)
	title.add_theme_font_size_override("font_size", 26)

