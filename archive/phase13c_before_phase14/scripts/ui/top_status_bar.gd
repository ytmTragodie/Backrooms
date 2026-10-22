class_name TopStatusBar
extends HBoxContainer

var _values: Array[Label] = []


func _ready() -> void:
	var ids: Array[StringName] = [&"icon_hp", &"icon_stress", &"icon_threat", &"icon_cognition", &"icon_ap", &"", &"icon_guard"]
	var names: Array[String] = ["生命", "压力", "威胁", "认知", "行动点", "回合", "防护"]
	for index: int in range(names.size()):
		var group: HBoxContainer = HBoxContainer.new()
		group.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		group.alignment = BoxContainer.ALIGNMENT_CENTER
		add_child(group)
		if not ids[index].is_empty():
			var icon: TextureRect = GameUITheme.texture(group, ids[index])
			icon.custom_minimum_size = Vector2(20, 20)
			icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		_values.append(GameUITheme.label(group, names[index], 15))


func present(state: RunState) -> void:
	var names: Array[String] = ["生命", "压力", "威胁", "认知", "行动点", "回合", "防护"]
	var values: Array[int] = [state.player.hp, state.player.stress, state.floor_state.threat, state.floor_state.cognition, state.player.ap, state.flow.turn_number, state.player.block]
	for index: int in range(values.size()):
		_values[index].text = "%s %d" % [names[index], values[index]]
