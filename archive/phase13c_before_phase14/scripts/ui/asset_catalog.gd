class_name AssetCatalog
extends RefCounted

const MANIFEST: String = "res://assets/asset_manifest.json"
const CARD_PLACEHOLDER: Texture2D = preload("res://assets/placeholders/card.svg")
const BACKGROUND_PLACEHOLDER: Texture2D = preload("res://assets/placeholders/background.svg")
const FRAME_PLACEHOLDER: Texture2D = preload("res://assets/placeholders/frame.svg")
const ICON_PLACEHOLDER: Texture2D = preload("res://assets/placeholders/icon.svg")
static var _entries: Dictionary = {}


static func entries() -> Dictionary:
	if _entries.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST))
		if parsed is Dictionary: _entries = parsed
	return _entries.duplicate(true)


static func path_for(id: StringName) -> String:
	if _entries.is_empty(): entries()
	var entry: Dictionary = _entries.get(String(id), {})
	var path: String = entry.get("path", "")
	# 清单也不能成为加载本机任意文件的后门；缺失文件不交给 load 报错。
	return path if path.begins_with("res://assets/") and not path.contains("..") else ""


static func is_provided(id: StringName) -> bool:
	var path: String = path_for(id)
	return not path.is_empty() and ResourceLoader.exists(path)


static func texture(id: StringName, category: StringName = &"card") -> Texture2D:
	if is_provided(id):
		var loaded: Texture2D = load(path_for(id)) as Texture2D
		if loaded != null: return loaded
	if _entries.is_empty(): entries()
	var fallback: String = _entries.get(String(id), {}).get("fallback_path", "")
	if fallback.begins_with("res://assets/") and not fallback.contains("..") and ResourceLoader.exists(fallback):
		var loaded_default: Texture2D = load(fallback) as Texture2D
		if loaded_default != null: return loaded_default
	match category:
		&"background": return BACKGROUND_PLACEHOLDER
		&"frame": return FRAME_PLACEHOLDER
		&"icon": return ICON_PLACEHOLDER
	return CARD_PLACEHOLDER


static func audio(id: StringName) -> AudioStream:
	return load(path_for(id)) as AudioStream if is_provided(id) else null


static func font(id: StringName) -> Font:
	return load(path_for(id)) as Font if is_provided(id) else null


static func frame(id: StringName) -> StyleBoxTexture:
	var style: StyleBoxTexture = StyleBoxTexture.new()
	style.texture = texture(id, &"frame")
	for side: Side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		style.set_texture_margin(side, 12)
		style.set_content_margin(side, 8)
	return style


static func world_art(button: Button, id: StringName, frame_id: StringName) -> void:
	for state_name: String in ["normal", "hover", "pressed", "disabled"]:
		button.add_theme_stylebox_override(state_name, frame(frame_id))
	var art: TextureRect = button.get_node_or_null("Illustration") as TextureRect
	if art == null:
		art = TextureRect.new()
		art.name = "Illustration"
		art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		art.modulate.a = 0.14
		button.add_child(art)
		button.move_child(art, 0)
		art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	art.texture = texture(id)

