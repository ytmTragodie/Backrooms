class_name ObjectiveSystem
extends RefCounted


static func validate_definition(data: ObjectiveData) -> StringName:
	if data == null or data.id.is_empty() or data.weight <= 0 or data.explore_threshold <= 0 or data.clue_threshold <= 0 or data.clue_threshold > data.explore_threshold:
		return &"invalid_objective_definition"
	if data.clue_text.is_empty() or data.objective_text.is_empty() or data.explore_bonus < 0 or data.neglect_stress < 0 or data.neglect_damage < 0:
		return &"invalid_objective_definition"
	if data.explore_bonus > 0 and data.bonus_tag.is_empty():
		return &"invalid_objective_definition"
	if data.clue_stability < 0 or data.clue_knowledge < 0 or data.completion_supply < 0:
		return &"invalid_objective_definition"
	var reward_error: StringName = CardRewardSystem.validate_definition(data.completion_reward)
	if not reward_error.is_empty():
		return reward_error
	if data.clue_insight != null:
		var error: StringName = InsightSystem.validate_definition(data.clue_insight)
		if not error.is_empty():
			return error
	return InsightSystem.validate_definition(data.completion_insight)


static func validate_board(floor: FloorState, data: FloorData) -> StringName:
	if floor.board_state == null:
		return &"invalid_objective_context"
	var ids: Array[StringName] = []
	for definition: ObjectiveData in data.fresh_objectives:
		var error: StringName = validate_definition(definition)
		if not error.is_empty():
			return error
		if ids.has(definition.id):
			return &"invalid_objective_definition"
		ids.append(definition.id)
	var objective: ObjectiveInstance = floor.board_state.active_objective
	if objective == null:
		return &""
	var definition: ObjectiveData = data.find_objective(objective.objective_id)
	if definition == null:
		return &"invalid_objective_context"
	if objective.explore_progress < 0 or objective.explore_progress > definition.explore_threshold or objective.resolved != (objective.explore_progress == definition.explore_threshold):
		return &"invalid_objective_state"
	if objective.clue_revealed != (objective.explore_progress >= definition.clue_threshold) or objective.last_progress_turn < 0 or objective.last_progress_turn > floor.turn_count or objective.pressure_checked_turn < 0 or objective.pressure_checked_turn > floor.turn_count:
		return &"invalid_objective_state"
	return &""


static func validate_target(command: PlayCardCommand, floor: FloorState) -> StringName:
	# 对象身份加访问内 Board 身份共同校验；同 ID 的旧事件也不能重新命中。
	if command.target_board != floor.board_state or command.target_objective == null or command.target_objective != floor.board_state.active_objective:
		return &"invalid_objective_target"
	if command.target_objective.resolved:
		return &"objective_resolved"
	return &""


static func explore_bonus(card: CardData, objective: ObjectiveData) -> int:
	return objective.explore_bonus if not objective.bonus_tag.is_empty() and card.tags.has(objective.bonus_tag) else 0


static func plan_explore(result: ActionResult, card: CardData, floor: FloorState, data: FloorData) -> void:
	var objective: ObjectiveInstance = floor.board_state.active_objective
	var definition: ObjectiveData = data.find_objective(objective.objective_id)
	result.action_id = &"explore"
	result.objective_target = objective
	result.objective_id = objective.objective_id
	result.explore_base = card.explore_amount
	result.explore_bonus = explore_bonus(card, definition) + card.contextual_bonus(floor.player_block, floor.threat)
	result.explore_after = mini(definition.explore_threshold, objective.explore_progress + result.explore_base + result.explore_bonus)
	result.explore_applied = result.explore_after - objective.explore_progress
	result.clue_revealed = not objective.clue_revealed and result.explore_after >= definition.clue_threshold
	if result.clue_revealed:
		result.light_activated = definition.clue_light_exposure
		result.objective_information.append(definition.clue_text)
		if definition.clue_stability > 0 or definition.clue_knowledge > 0:
			CutOutSystem.plan_gain(result, floor.cutout_state, definition.clue_stability, definition.clue_knowledge, &"objective_clue")
		if definition.clue_insight != null:
			InsightSystem.plan_confirmation(result, definition.clue_insight, floor)
	result.objective_resolved = result.explore_after == definition.explore_threshold
	if result.objective_resolved:
		result.supply_delta += definition.completion_supply
		InsightSystem.plan_confirmation(result, definition.completion_insight, floor)
	if card.threat_cost > 0:
		result.threat_delta = mini(card.threat_cost, FloorState.MAX_THREAT - floor.threat)
		result.threat_reason = &"card_risk"


static func plan_pressure(result: ActionResult, floor: FloorState, data: FloorData) -> void:
	var objective: ObjectiveInstance = floor.board_state.active_objective
	if objective == null or objective.resolved or objective.pressure_checked_turn == floor.turn_count:
		return
	result.objective_target = objective
	result.pressure_checked = true
	if objective.last_progress_turn != floor.turn_count:
		var definition: ObjectiveData = data.find_objective(objective.objective_id)
		result.pressure_stress += definition.neglect_stress
		var blocked: int = mini(floor.player_block - result.pressure_blocked, definition.neglect_damage)
		result.pressure_blocked += blocked
		result.pressure_damage += definition.neglect_damage - blocked


static func commit(result: ActionResult, state: RunState) -> void:
	var objective: ObjectiveInstance = result.objective_target
	if objective == null:
		return
	if result.explore_after >= 0:
		# 阈值、线索与进度在同一次提交生效；没有 UI 事件链驱动奖励。
		objective.explore_progress = result.explore_after
		state.floor_state.total_explore += result.explore_applied
		objective.last_progress_turn = state.floor_state.turn_count
		objective.clue_revealed = objective.clue_revealed or result.clue_revealed
		objective.known_information.append_array(result.objective_information)
		objective.resolved = result.objective_resolved
		result.debug_lines.append("[EXPLORE] %s base=%d bonus=%d applied=%d progress=%d" % [objective.objective_id, result.explore_base, result.explore_bonus, result.explore_applied, objective.explore_progress])
		if result.clue_revealed:
			result.debug_lines.append("[OBJECTIVE] clue %s" % objective.objective_id)
		if objective.resolved:
			state.floor_state.completed_objectives += 1
			result.debug_lines.append("[OBJECTIVE] resolved %s" % objective.objective_id)
	if result.pressure_checked:
		objective.pressure_checked_turn = state.floor_state.turn_count
		result.debug_lines.append("[PRESSURE] %s stress +%d reason=%s" % [objective.objective_id, result.pressure_stress, "progressed" if objective.last_progress_turn == state.floor_state.turn_count else "neglected"])
		result.debug_lines.append("[PRESSURE] damage=%d blocked=%d" % [result.pressure_damage, result.pressure_blocked])


static func conditions_met(required: Array[StringName], blocked: Array[StringName], flags: Array[StringName]) -> bool:
	for flag: StringName in required:
		if not flags.has(flag):
			return false
	for flag: StringName in blocked:
		if flags.has(flag):
			return false
	return true


static func draw_fresh(data: FloorData, state: FloorState, rng: RandomNumberGenerator, emit_log: bool = true) -> StringName:
	assert(data.id == state.floor_id, "Objective selection requires matching floor data/state")
	# 未完成事件跨回合保留，不能靠结束回合跳过进度或刷新基础交互。
	if state.current_objective != null and not state.current_objective.resolved:
		return state.current_objective_id
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
	state.board_state.active_objective = null
	if candidates.is_empty():
		if emit_log and OS.is_debug_build():
			print("[OBJECTIVE] no_eligible_fresh remaining=%d" % state.remaining_fresh_objectives.size())
		return &""
	# 先过滤条件，再用本局 RNG 加权选择；无候选时不消耗随机数。
	var intro: ObjectiveData = data.intro_objective if state.seen_objective_ids.is_empty() and candidates.has(data.intro_objective) else null
	var roll: int = 1 if intro != null else rng.randi_range(1, total_weight)
	for objective: ObjectiveData in candidates:
		if intro != null and objective != intro:
			continue
		roll -= objective.weight
		if roll > 0:
			continue
		state.board_state.active_objective = ObjectiveInstance.new(objective.id)
		state.board_state.active_objective.activated_turn = state.turn_count
		state.remaining_fresh_objectives.erase(objective.id)
		state.seen_objective_ids.append(objective.id)
		if emit_log and OS.is_debug_build():
			print("[OBJECTIVE] draw %s" % objective.id)
		return objective.id
	return &""
