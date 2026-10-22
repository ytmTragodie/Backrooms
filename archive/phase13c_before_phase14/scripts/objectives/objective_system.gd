class_name ObjectiveSystem
extends RefCounted

# Object 的静态定义验证。三种类型共享线索/完成奖励字段，但进度字段互斥。
static func validate_definition(data: ObjectiveData) -> StringName:
	if data == null or data.id.is_empty() or data.weight <= 0:
		return &"invalid_objective_definition"
	if data.objective_type not in [ObjectiveData.ObjectiveType.PROGRESS, ObjectiveData.ObjectiveType.CONDITION, ObjectiveData.ObjectiveType.SEQUENCE]:
		return &"invalid_objective_definition"
	if data.progress_threshold < 0 or data.clue_threshold < 0 or data.clue_stability < 0 or data.clue_knowledge < 0:
		return &"invalid_objective_definition"
	if data.explore_bonus < 0 or data.neglect_stress < 0 or data.neglect_damage < 0 or data.completion_supply < 0:
		return &"invalid_objective_definition"
	if data.clue_threshold > 0 and data.clue_text.strip_edges().is_empty():
		return &"invalid_objective_definition"
	if data.explore_bonus > 0 and data.bonus_tag.is_empty():
		return &"invalid_objective_definition"
	var insight_error: StringName = InsightSystem.validate_definition(data.clue_insight) if data.clue_insight != null else &""
	if not insight_error.is_empty():
		return insight_error
	insight_error = InsightSystem.validate_definition(data.completion_insight) if data.completion_insight != null else &""
	if not insight_error.is_empty():
		return insight_error
	var reward_error: StringName = CardRewardSystem.validate_definition(data.completion_reward) if data.completion_reward != null else &""
	if not reward_error.is_empty():
		return reward_error

	match data.objective_type:
		ObjectiveData.ObjectiveType.PROGRESS:
			if data.progress_threshold <= 0 or not data.required_actions.is_empty() or not data.sequence_actions.is_empty():
				return &"invalid_objective_definition"
			if data.clue_threshold > data.progress_threshold:
				return &"invalid_objective_definition"
		ObjectiveData.ObjectiveType.CONDITION:
			if data.progress_threshold != 0 or data.sequence_actions.size() > 0 or data.required_actions.is_empty():
				return &"invalid_objective_definition"
			var steps: Array[StringName] = []
			for step: StringName in data.required_actions:
				if step.is_empty() or steps.has(step):
					return &"invalid_objective_definition"
				steps.append(step)
			if data.clue_threshold > steps.size():
				return &"invalid_objective_definition"
		ObjectiveData.ObjectiveType.SEQUENCE:
			if data.progress_threshold != 0 or data.required_actions.size() > 0 or data.sequence_actions.is_empty():
				return &"invalid_objective_definition"
			for step: StringName in data.sequence_actions:
				if step.is_empty():
					return &"invalid_objective_definition"
			if data.clue_threshold > data.sequence_actions.size():
				return &"invalid_objective_definition"
	return &""


# 校验活动目标实例与静态定义的类型约束。
static func validate_board(floor: FloorState, data: FloorData) -> StringName:
	var objective: ObjectiveInstance = floor.board_state.active_objective
	if objective == null:
		return &""
	var definition: ObjectiveData = data.find_objective(objective.objective_id)
	if definition == null:
		return &"invalid_objective_definition"
	var definition_error: StringName = validate_definition(definition)
	if not definition_error.is_empty():
		return definition_error
	if objective.explore_progress < 0 or objective.sequence_index < 0 or objective.last_progress_turn < 0 or objective.last_progress_turn > floor.turn_count or objective.pressure_checked_turn < 0 or objective.pressure_checked_turn > floor.turn_count:
		return &"invalid_objective_state"

	var expected_clue: bool = false
	match definition.objective_type:
		ObjectiveData.ObjectiveType.PROGRESS:
			if objective.explore_progress > definition.progress_threshold or not objective.completed_interactions.is_empty() or objective.sequence_index != 0:
				return &"invalid_objective_state"
			if objective.resolved != (objective.explore_progress >= definition.progress_threshold):
				return &"invalid_objective_state"
			expected_clue = definition.clue_threshold > 0 and objective.explore_progress >= definition.clue_threshold
		ObjectiveData.ObjectiveType.CONDITION:
			if objective.explore_progress != 0 or objective.sequence_index != 0:
				return &"invalid_objective_state"
			var completed: Array[StringName] = []
			for step: StringName in objective.completed_interactions:
				if step.is_empty() or completed.has(step) or not definition.required_actions.has(step):
					return &"invalid_objective_state"
				completed.append(step)
			if objective.resolved != (completed.size() >= definition.required_actions.size()):
				return &"invalid_objective_state"
			expected_clue = definition.clue_threshold > 0 and completed.size() >= definition.clue_threshold
		ObjectiveData.ObjectiveType.SEQUENCE:
			if objective.explore_progress != 0 or not objective.completed_interactions.is_empty():
				return &"invalid_objective_state"
			if objective.sequence_index > definition.sequence_actions.size():
				return &"invalid_objective_state"
			if objective.resolved != (objective.sequence_index >= definition.sequence_actions.size()):
				return &"invalid_objective_state"
			expected_clue = definition.clue_threshold > 0 and objective.sequence_index >= definition.clue_threshold
	if objective.clue_revealed != expected_clue:
		return &"invalid_objective_state"
	return &""


# 目标实例必须是当前 Board 的活动目标，且尚未解决。
static func validate_target(command: PlayCardCommand, floor: FloorState) -> StringName:
	if command == null or command.target_objective == null:
		return &"invalid_objective_target"
	if command.target_board != floor.board_state or command.target_objective != floor.board_state.active_objective:
		return &"invalid_objective_target"
	if command.target_objective.resolved:
		return &"objective_resolved"
	return &""


# 在扣 AP/移牌/RNG 之前判断这张牌是否命中当前合法步骤。
static func validate_interaction(command: PlayCardCommand, floor: FloorState, data: FloorData) -> StringName:
	if data == null:
		return &"invalid_floor_context"
	var target_error: StringName = validate_target(command, floor)
	if not target_error.is_empty():
		return target_error
	var objective: ObjectiveInstance = command.target_objective
	var definition: ObjectiveData = data.find_objective(objective.objective_id)
	if definition == null:
		return &"invalid_objective_definition"
	match definition.objective_type:
		ObjectiveData.ObjectiveType.PROGRESS:
			return &"" if command.card.definition.explore_amount > 0 else &"objective_step_incompatible"
		ObjectiveData.ObjectiveType.CONDITION:
			return &"" if _matching_condition(command.card.definition, objective, definition) >= 0 else &"objective_step_incompatible"
		ObjectiveData.ObjectiveType.SEQUENCE:
			if objective.sequence_index >= definition.sequence_actions.size():
				return &"objective_resolved"
			return &"" if _matches_step(command.card.definition, definition.sequence_actions[objective.sequence_index]) else &"objective_step_incompatible"
	return &"invalid_objective_definition"


# 三种类型的统一规划入口。只写 result，不修改任何 State。
static func plan_interaction(result: ActionResult, card: CardData, floor: FloorState, data: FloorData, player: PlayerState) -> StringName:
	var objective: ObjectiveInstance = floor.board_state.active_objective
	if objective == null:
		return &"invalid_objective_target"
	if objective.resolved:
		return &"objective_resolved"
	var definition: ObjectiveData = data.find_objective(objective.objective_id)
	if definition == null:
		return &"invalid_objective_definition"
	var error: StringName = &""
	match definition.objective_type:
		ObjectiveData.ObjectiveType.PROGRESS:
			error = _plan_progress(result, card, objective, definition, floor, player)
		ObjectiveData.ObjectiveType.CONDITION:
			error = _plan_condition(result, card, objective, definition)
		ObjectiveData.ObjectiveType.SEQUENCE:
			error = _plan_sequence(result, card, objective, definition)
		_:
			return &"invalid_objective_definition"
	if not error.is_empty():
		return error
	_plan_clue(result, objective, definition, floor)
	if result.objective.newly_resolved:
		_plan_completion(result, objective, definition, floor)
	return &""


static func _plan_progress(result: ActionResult, card: CardData, objective: ObjectiveInstance, definition: ObjectiveData, floor: FloorState, player: PlayerState) -> StringName:
	if card.explore_amount <= 0:
		return &"objective_step_incompatible"
	var block: int = player.block
	var bonus: int = explore_bonus(card, definition) + card.contextual_bonus(block, floor.threat)
	result.action_id = &"explore"
	result.objective.target = objective
	result.objective.id = objective.objective_id
	result.objective.interaction = &"explore"
	result.objective.progress_base = card.explore_amount
	result.objective.progress_bonus = bonus
	result.objective.progress_after = mini(definition.progress_threshold, objective.explore_progress + card.explore_amount + bonus)
	result.objective.progress_applied = result.objective.progress_after - objective.explore_progress
	# 楼层统计归 FloorSystem；目标只规划本职业已应用的探索量。
	result.floor.total_explore_delta += result.objective.progress_applied
	result.objective.resolved = result.objective.progress_after >= definition.progress_threshold
	result.objective.newly_resolved = result.objective.resolved and not objective.resolved
	return &""


static func _plan_condition(result: ActionResult, card: CardData, objective: ObjectiveInstance, definition: ObjectiveData) -> StringName:
	var index: int = _matching_condition(card, objective, definition)
	if index < 0:
		return &"objective_step_incompatible"
	var step: StringName = definition.required_actions[index]
	var completed_count: int = objective.completed_interactions.size() + 1
	result.action_id = &"objective_condition"
	result.objective.target = objective
	result.objective.id = objective.objective_id
	result.objective.interaction = step
	result.objective.completed_conditions.append(step)
	result.objective.resolved = completed_count >= definition.required_actions.size()
	result.objective.newly_resolved = result.objective.resolved and not objective.resolved
	return &""


static func _plan_sequence(result: ActionResult, card: CardData, objective: ObjectiveInstance, definition: ObjectiveData) -> StringName:
	if objective.sequence_index >= definition.sequence_actions.size():
		return &"objective_resolved"
	var expected: StringName = definition.sequence_actions[objective.sequence_index]
	if not _matches_step(card, expected):
		return &"objective_step_incompatible"
	result.action_id = &"objective_sequence"
	result.objective.target = objective
	result.objective.id = objective.objective_id
	result.objective.interaction = expected
	result.objective.sequence_after = objective.sequence_index + 1
	result.objective.resolved = result.objective.sequence_after >= definition.sequence_actions.size()
	result.objective.newly_resolved = result.objective.resolved and not objective.resolved
	return &""


# 线索阈值按类型解释：PROGRESS 看进度，CONDITION/SEQUENCE 看已完成步骤数。
static func _plan_clue(result: ActionResult, objective: ObjectiveInstance, definition: ObjectiveData, floor: FloorState) -> void:
	if objective.clue_revealed or definition.clue_threshold <= 0:
		return
	var count: int = 0
	match definition.objective_type:
		ObjectiveData.ObjectiveType.PROGRESS:
			count = result.objective.progress_after
		ObjectiveData.ObjectiveType.CONDITION:
			count = objective.completed_interactions.size() + result.objective.completed_conditions.size()
		ObjectiveData.ObjectiveType.SEQUENCE:
			count = result.objective.sequence_after
	if count < definition.clue_threshold:
		return
	result.objective.clue_revealed = true
	if not definition.clue_text.is_empty():
		result.objective.information.append(definition.clue_text)
	if definition.clue_light_exposure:
		result.floor.light_activated = true
	if definition.clue_stability > 0 or definition.clue_knowledge > 0:
		CutOutSystem.plan_gain(result, floor.cutout_state, definition.clue_stability, definition.clue_knowledge, &"objective_clue")
	if definition.clue_insight != null:
		InsightSystem.plan_confirmation(result, definition.clue_insight, floor)


# 完成奖励只规划到其他领域；CardRewardSystem 会根据 newly_resolved 统一创建一次机会。
static func _plan_completion(result: ActionResult, objective: ObjectiveInstance, definition: ObjectiveData, floor: FloorState) -> void:
	if definition.completion_supply > 0:
		result.player.supply_delta += definition.completion_supply
	if definition.completion_insight != null:
		InsightSystem.plan_confirmation(result, definition.completion_insight, floor)
	result.debug_lines.append("[OBJECTIVE] completion %s supply=%d insight=%s" % [objective.objective_id, definition.completion_supply, definition.completion_insight.id if definition.completion_insight != null else &"none"])


# 回合末压力：只规划玩家净变化，实际提交由 PlayerSystem 完成。
static func plan_pressure(result: ActionResult, state: RunState, floor: FloorState, data: FloorData) -> void:
	var objective: ObjectiveInstance = floor.board_state.active_objective
	if objective == null or objective.resolved or objective.pressure_checked_turn == floor.turn_count:
		return
	var definition: ObjectiveData = data.find_objective(objective.objective_id)
	if definition == null:
		return
	result.objective.target = objective
	result.objective.id = objective.objective_id
	result.objective.pressure_checked = true
	if objective.last_progress_turn == floor.turn_count:
		return
	var remaining_block: int = maxi(0, state.player.block + result.player.block_delta)
	var blocked: int = mini(remaining_block, definition.neglect_damage)
	var remaining_hp: int = maxi(0, state.player.hp + result.player.hp_delta)
	var damage: int = mini(remaining_hp, definition.neglect_damage - blocked)
	result.player.pressure_stress += definition.neglect_stress
	result.player.stress_delta += definition.neglect_stress
	result.player.pressure_blocked += blocked
	result.player.block_delta -= blocked
	result.player.pressure_damage += damage
	result.player.hp_delta -= damage


static func explore_bonus(card: CardData, objective: ObjectiveData) -> int:
	return objective.explore_bonus if not objective.bonus_tag.is_empty() and card.tags.has(objective.bonus_tag) else 0


static func _matches_step(card: CardData, step: StringName) -> bool:
	return not step.is_empty() and card.tags.has(step)


static func _matching_condition(card: CardData, objective: ObjectiveInstance, definition: ObjectiveData) -> int:
	for index: int in range(definition.required_actions.size()):
		var step: StringName = definition.required_actions[index]
		if objective.completed_interactions.has(step):
			continue
		if _matches_step(card, step):
			return index
	return -1


# 只提交 ObjectiveInstance 自身；楼层统计/玩家/奖励分别由 FloorSystem/PlayerSystem/CardRewardSystem 提交。
static func commit(result: ActionResult, state: RunState) -> void:
	var objective: ObjectiveInstance = result.objective.target
	if objective == null or state == null or state.floor_state == null:
		return
	var data: ObjectiveActionResult = result.objective
	var progressed: bool = false
	if data.progress_after >= 0:
		objective.explore_progress = data.progress_after
		if data.progress_applied > 0:
			progressed = true
	for step: StringName in data.completed_conditions:
		if not objective.completed_interactions.has(step):
			objective.completed_interactions.append(step)
			progressed = true
	if data.sequence_after >= 0 and data.sequence_after != objective.sequence_index:
		objective.sequence_index = data.sequence_after
		progressed = true
	if data.clue_revealed and not objective.clue_revealed:
		objective.clue_revealed = true
		for information: String in data.information:
			if not objective.known_information.has(information):
				objective.known_information.append(information)
		progressed = true
	if progressed:
		objective.last_progress_turn = state.floor_state.turn_count
	if data.resolved and not objective.resolved:
		objective.resolved = true
		result.debug_lines.append("[OBJECTIVE] resolved %s" % objective.objective_id)
	if data.pressure_checked:
		objective.pressure_checked_turn = state.floor_state.turn_count
		result.debug_lines.append("[PRESSURE] checked %s" % objective.objective_id)


# 调度器：先决定是否生成，再从剩余候选加权选择；首个 intro 目标不消耗概率。
static func draw_fresh(data: FloorData, state: FloorState, rng: RandomNumberGenerator, emit_log: bool = true) -> StringName:
	assert(data.id == state.floor_id, "Objective selection requires matching floor data/state")
	if state.current_objective != null:
		if not state.current_objective.resolved:
			return state.current_objective_id
		state.board_state.active_objective = null
	if data.max_objectives_per_floor > 0 and state.seen_objective_ids.size() >= data.max_objectives_per_floor:
		# 本次楼层访问的生成配额已满：剩余候选不会在本层再出现。
		state.remaining_fresh_objectives.clear()
		return &""
	var candidates: Array[ObjectiveData] = []
	var total_weight: int = 0
	for objective_id: StringName in state.remaining_fresh_objectives:
		var objective: ObjectiveData = data.find_objective(objective_id)
		assert(objective != null and objective.weight > 0, "Invalid Fresh Objective definition")
		if objective.once_per_instance and state.seen_objective_ids.has(objective.id):
			continue
		if not conditions_met(objective.required_flags, objective.blocked_flags, state.floor_flags):
			continue
		candidates.append(objective)
		total_weight += objective.weight
	if candidates.is_empty():
		if emit_log and OS.is_debug_build():
			print("[OBJECTIVE] no_eligible_fresh remaining=%d" % state.remaining_fresh_objectives.size())
		return &""
	var selected: ObjectiveData
	var intro: ObjectiveData = data.intro_objective if state.seen_objective_ids.is_empty() and candidates.has(data.intro_objective) else null
	if intro != null:
		selected = intro
	else:
		if rng.randf() > data.objective_spawn_chance:
			return &""
		var roll: int = rng.randi_range(1, total_weight)
		for objective: ObjectiveData in candidates:
			roll -= objective.weight
			if roll <= 0:
				selected = objective
				break
	if selected == null:
		return &""
	state.board_state.active_objective = ObjectiveInstance.new(selected.id)
	state.board_state.active_objective.activated_turn = state.turn_count
	state.remaining_fresh_objectives.erase(selected.id)
	state.seen_objective_ids.append(selected.id)
	if emit_log and OS.is_debug_build():
		print("[OBJECTIVE] draw %s" % selected.id)
	return selected.id


static func conditions_met(required: Array[StringName], blocked: Array[StringName], flags: Array[StringName]) -> bool:
	for flag: StringName in required:
		if not flags.has(flag):
			return false
	for flag: StringName in blocked:
		if flags.has(flag):
			return false
	return true