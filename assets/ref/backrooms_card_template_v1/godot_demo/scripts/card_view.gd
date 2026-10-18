extends Control
## 通用卡牌视图：只负责渲染，不负责战斗数值计算。
## 美术素材不含动态文字，名称、费用、描述和属性均为 Label。

const DESIGN_SIZE := Vector2(750.0, 1050.0)
const ASSET_ROOT := "res://assets/"

var card_data: Dictionary = {}
var cost_label: Label
var name_label: Label
var description_label: Label

func _ready() -> void:
    size = DESIGN_SIZE
    custom_minimum_size = DESIGN_SIZE
    if not card_data.is_empty():
        _build()

func set_card(data: Dictionary) -> void:
    card_data = data.duplicate(true)
    if is_node_ready():
        _build()

func set_cost(value: int) -> void:
    card_data["cost"] = maxi(value, 0)
    if cost_label != null:
        cost_label.text = str(card_data["cost"])

func set_card_name(value: String) -> void:
    card_data["name"] = value
    if name_label != null:
        name_label.text = value

func set_description(value: String) -> void:
    card_data["description"] = value
    if description_label != null:
        description_label.text = value

func _sprite(filename: String, xy: Vector2, wh: Vector2) -> TextureRect:
    var node := TextureRect.new()
    node.position = xy
    node.size = wh
    node.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    node.stretch_mode = TextureRect.STRETCH_SCALE
    node.mouse_filter = Control.MOUSE_FILTER_IGNORE
    var path := ASSET_ROOT + filename
    if ResourceLoader.exists(path):
        node.texture = load(path)
    else:
        push_warning("Card asset missing: " + path)
    add_child(node)
    return node

func _text(value: String, xy: Vector2, wh: Vector2, font_size: int, dark: bool, centered: bool = false) -> Label:
    var node := Label.new()
    node.text = value
    node.position = xy
    node.size = wh
    node.mouse_filter = Control.MOUSE_FILTER_IGNORE
    node.add_theme_font_size_override("font_size", font_size)
    node.add_theme_color_override("font_color", Color("#251c15") if dark else Color("#f3e3be"))
    if not dark:
        node.add_theme_color_override("font_outline_color", Color("#17110d"))
        node.add_theme_constant_override("outline_size", 2)
    node.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER if centered else HORIZONTAL_ALIGNMENT_LEFT
    node.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    node.clip_text = true
    add_child(node)
    return node

func _build() -> void:
    for child in get_children():
        remove_child(child)
        child.queue_free()

    var kind := str(card_data.get("kind", "item"))
    if not ["item", "skill", "entity", "event", "location"].has(kind):
        kind = "item"
    var art := str(card_data.get("art", "art_flashlight.png"))

    _sprite("background_grunge.png", Vector2.ZERO, DESIGN_SIZE)
    _sprite(art, Vector2(45, 86), Vector2(660, 540))
    _sprite("frame_" + kind + ".png", Vector2.ZERO, DESIGN_SIZE)
    _sprite("panel_name.png", Vector2(63, 624), Vector2(624, 106))
    _sprite("panel_description.png", Vector2(63, 746), Vector2(624, 180))
    for x in [66, 278, 490]:
        _sprite("panel_stat.png", Vector2(x, 936), Vector2(194, 95))
    _sprite("cost_medallion.png", Vector2(46, 34), Vector2(116, 116))
    _sprite("panel_type.png", Vector2(536, 645), Vector2(145, 69))

    cost_label = _text(str(card_data.get("cost", 0)), Vector2(69, 54), Vector2(71, 78), 68, false, true)
    _text("ARC-" + str(card_data.get("id", "UNKNOWN")).to_upper(), Vector2(487, 37), Vector2(190, 52), 19, true, true)
    name_label = _text(str(card_data.get("name", "未命名")), Vector2(101, 642), Vector2(427, 67), 47, true)
    _text(str(card_data.get("type", "卡牌")), Vector2(546, 655), Vector2(126, 51), 28, false, true)
    description_label = _text(str(card_data.get("description", "")), Vector2(104, 763), Vector2(534, 147), 25, true)

    var stats: Array = card_data.get("stats", [])
    for i in range(mini(stats.size(), 3)):
        var stat: Dictionary = stats[i]
        _sprite("icon_" + str(stat.get("icon", "gear")) + ".png", Vector2(84 + 212 * i, 950), Vector2(64, 64))
        _text(str(stat.get("value", "0")), Vector2(154 + 212 * i, 949), Vector2(89, 69), 41, false, true)
