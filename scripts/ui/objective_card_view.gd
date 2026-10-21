class_name ObjectiveCardView
extends BoardCardView

var _description: Label
var _progress: Label
var _pressure: Label
var _rule: Label
var _clues: Label
var _state: Label
var _goal: Label
var _bar: ProgressBar


func _ready() -> void:
	super._ready()
	heading.name = "SituationName"
	heading.owner = owner if owner != null else self
	heading.unique_name_in_owner = true
	_progress = legacy_label("Objective", information, true)
	_bar = ProgressBar.new()
	_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bar.show_percentage = false
	_bar.custom_minimum_size.y = 8
	information.add_child(_bar)
	_goal = GameUITheme.label(information, "", 14)
	_goal.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_goal.max_lines_visible = 2
	_clues = legacy_label("Clues", information, true)
	_clues.add_theme_color_override("font_color", GameUITheme.GREEN)
	_clues.custom_minimum_size.y = 34
	_state = legacy_label("SituationState", information, true)
	_description = legacy_label("Description")
	_pressure = legacy_label("Pressure")
	_rule = legacy_label("SituationRule")


func present(floor: FloorState, data: FloorData, environment_reward: bool, selected_value: bool) -> void:
	var objective: ObjectiveInstance = floor.current_objective
	var definition: ObjectiveData = data.find_objective(objective.objective_id) if objective != null else null
	disabled = objective == null and not environment_reward
	_bar.visible = objective != null
	if objective == null:
		heading.text = "目标已调查完毕" if floor.remaining_fresh_objectives.is_empty() else "暂无活动目标"
		_goal.text = "周围仍有有限补给，可选择环境后搜索。" if environment_reward else "等待新目标，或用手牌应对实体／离层。"
		_progress.text = "当前没有活动调查目标"
		_clues.text = "已确认认知：%d" % floor.cognition
		_state.text = "未出现目标也不会永久阻止切出。"
		artwork.texture = AssetCatalog.texture(data.id, &"background")
		_description.text = _goal.text
		_pressure.text = "回合末后果：无目标压力"
		_rule.text = ""
		if data.is_placeholder:
			heading.text = "已离层：本次探索完成"
			_goal.text = data.placeholder_description
	else:
		heading.text = "目标牌 · %s%s" % [definition.display_name, "（已选）" if selected_value else ""]
		artwork.texture = AssetCatalog.texture(definition.asset_id)
		match definition.objective_type:
			ObjectiveData.ObjectiveType.PROGRESS:
				_progress.text = "调查进度：%d／%d" % [objective.explore_progress, definition.progress_threshold]
				_bar.max_value = definition.progress_threshold
				_bar.value = objective.explore_progress
				_rule.text = "匹配标签额外调查 +%d" % definition.explore_bonus if definition.explore_bonus > 0 else "按卡牌基础调查值推进"
			ObjectiveData.ObjectiveType.CONDITION:
				_progress.text = "条件进度：%d／%d" % [objective.completed_interactions.size(), definition.required_actions.size()]
				_bar.max_value = definition.required_actions.size()
				_bar.value = objective.completed_interactions.size()
				_rule.text = "任意顺序完成：%s" % "、".join(definition.required_actions)
			ObjectiveData.ObjectiveType.SEQUENCE:
				_progress.text = "顺序进度：%d／%d" % [objective.sequence_index, definition.sequence_actions.size()]
				_bar.max_value = definition.sequence_actions.size()
				_bar.value = objective.sequence_index
				var next_step: StringName = definition.sequence_actions[objective.sequence_index] if objective.sequence_index < definition.sequence_actions.size() else &""
				if next_step.is_empty():
					_rule.text = "顺序已完成"
				else:
					_rule.text = "下一步：%s" % next_step
		_goal.text = definition.objective_text
		_description.text = definition.display_text
		if not objective.known_information.is_empty():
			_clues.text = "线索：%s" % "；".join(objective.known_information)
		elif definition.clue_threshold > 0:
			_clues.text = "线索：达到 %d 后揭示" % definition.clue_threshold
		else:
			_clues.text = "线索：无额外线索"
		_state.text = "已解决" if objective.resolved else _rule.text
		_pressure.text = "回合末后果：压力 +%d，伤害 %d；%s" % [definition.neglect_stress, definition.neglect_damage, "本回合已推进" if objective.last_progress_turn == floor.turn_count else "尚未推进"]
		if objective.resolved: _pressure.text = "回合末后果：已解决"
	tooltip_text = "%s\n%s\n%s\n%s\n%s" % [heading.text, _description.text, _goal.text, _pressure.text, _clues.text]
	set_target_presentation(selected_value)

