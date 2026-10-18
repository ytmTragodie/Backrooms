extends Control
## 5 张不同卡牌共享同一套 CardView，按钮演示运行时动态文字。

const CardViewScript = preload("res://scripts/card_view.gd")
const CARD_SCALE := 0.36
var views: Array[Control] = []
var source_cards: Array = []
var renamed := false

func _ready() -> void:
    var bg := ColorRect.new()
    bg.color = Color("#111316")
    bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    add_child(bg)

    _label("THE BACKROOMS  /  通用卡牌模板 v1", Vector2(55, 20), Vector2(1050, 54), 30)
    _label("所有卡牌复用同一 CardView；图片不包含卡名、费用和效果文字。", Vector2(58, 77), Vector2(1060, 32), 17)

    var raw := FileAccess.get_file_as_string("res://data/cards.json")
    var parsed: Variant = JSON.parse_string(raw)
    if not (parsed is Array):
        push_error("cards.json must contain an array")
        return
    source_cards = parsed
    var positions := [Vector2(70, 122), Vector2(415, 122), Vector2(760, 122), Vector2(255, 530), Vector2(600, 530)]
    for i in range(mini(source_cards.size(), positions.size())):
        var view: Control = CardViewScript.new()
        view.position = positions[i]
        view.scale = Vector2.ONE * CARD_SCALE
        add_child(view)
        view.call("set_card", source_cards[i])
        views.append(view)

    _button("手电费用 -1", Vector2(940, 615), func(): _modify_cost(-1))
    _button("手电费用 +1", Vector2(940, 675), func(): _modify_cost(1))
    _button("切换手电名称", Vector2(940, 735), func(): _toggle_name())
    _button("恢复原始数据", Vector2(940, 795), func(): _reset_first())
    _label("数据来自 data/cards.json", Vector2(925, 860), Vector2(260, 42), 15)

func _label(value: String, xy: Vector2, wh: Vector2, sz: int) -> void:
    var label := Label.new()
    label.text = value
    label.position = xy
    label.size = wh
    label.add_theme_font_size_override("font_size", sz)
    label.add_theme_color_override("font_color", Color("#e8d9b8"))
    add_child(label)

func _button(value: String, xy: Vector2, callback: Callable) -> void:
    var button := Button.new()
    button.text = value
    button.position = xy
    button.size = Vector2(220, 47)
    button.pressed.connect(callback)
    add_child(button)

func _modify_cost(delta: int) -> void:
    if views.is_empty():
        return
    var view: Control = views[0]
    var data: Dictionary = view.get("card_data")
    view.call("set_cost", int(data.get("cost", 0)) + delta)

func _toggle_name() -> void:
    if views.is_empty():
        return
    renamed = not renamed
    views[0].call("set_card_name", "应急手电·改" if renamed else "应急手电")

func _reset_first() -> void:
    if views.is_empty():
        return
    renamed = false
    views[0].call("set_card", source_cards[0])
