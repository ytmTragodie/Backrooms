class_name GameUITheme
extends RefCounted

const INK: Color = Color("241d15")
const PAPER: Color = Color("e8d6ad")
const GOLD: Color = Color("bba36b")
const BLUE: Color = Color("7ba5ba")
const GREEN: Color = Color("a4b78c")
const RED: Color = Color("d78372")


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
	var provided_font: Font = AssetCatalog.font(&"font_chinese")
	if provided_font != null: result.default_font = provided_font
	result.set_color("font_color", "Label", PAPER)
	for state: String in ["normal", "hover", "pressed", "focus", "disabled"]:
		result.set_stylebox(state, "Button", panel(Color("202326") if state != "hover" else Color("33342e"), GOLD if state != "disabled" else Color("454742")))
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
	item.mouse_filter = Control.MOUSE_FILTER_IGNORE
	item.add_theme_font_size_override("font_size", font_size)
	item.add_theme_color_override("font_color", color)
	parent.add_child(item)
	return item


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

