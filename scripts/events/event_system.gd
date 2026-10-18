class_name EventSystem
extends RefCounted


static func validate_situation(data: EventData) -> StringName:
	if data == null or data.id.is_empty() or data.weight <= 0 or data.explore_threshold <= 0 or data.clue_threshold <= 0 or data.clue_threshold > data.explore_threshold:
		return &"invalid_event_definition"
	if data.clue_text.is_empty() or data.objective_text.is_empty() or data.explore_bonus < 0 or data.neglect_stress < 0:
		return &"invalid_event_definition"
	if data.explore_bonus > 0 and data.bonus_tag.is_empty():
		return &"invalid_event_definition"
	return InsightSystem.validate_definition(data.completion_insight)


static func validate_board(floor: FloorState, data: FloorData) -> StringName:
	if floor.board_state == null:
		return &"invalid_event_context"
	var ids: Array[StringName] = []
	for definition: EventData in data.fresh_events:
		var error: StringName = validate_situation(definition)
		if not error.is_empty():
			return error
		if ids.has(definition.id):
			return &"invalid_event_definition"
		ids.append(definition.id)
	var event: EventInstance = floor.board_state.active_event
	if event == null:
		return &""
	var definition: EventData = data.find_event(event.event_id)
	if definition == null:
		return &"invalid_event_context"
	if event.explore_progress < 0 or event.explore_progress > definition.explore_threshold or event.resolved != (event.explore_progress == definition.explore_threshold):
		return &"invalid_event_state"
	if event.clue_revealed != (event.explore_progress >= definition.clue_threshold) or event.last_progress_turn < 0 or event.last_progress_turn > floor.turn_count or event.pressure_checked_turn < 0 or event.pressure_checked_turn > floor.turn_count:
		return &"invalid_event_state"
	return &""


static func validate_target(command: PlayCardCommand, floor: FloorState) -> StringName:
	# 对象身份加访问内 Board 身份共同校验；同 ID 的旧事件也不能重新命中。
	if command.target_board != floor.board_state or command.target_event == null or command.target_event != floor.board_state.active_event:
		return &"invalid_event_target"
	if command.target_event.resolved:
		return &"event_resolved"
	return &""


static func explore_bonus(card: CardData, situation: EventData) -> int:
	return situation.explore_bonus if not situation.bonus_tag.is_empty() and card.tags.has(situation.bonus_tag) else 0


static func plan_explore(result: ActionResult, card: CardData, floor: FloorState, data: FloorData) -> void:
	var event: EventInstance = floor.board_state.active_event
	var definition: EventData = data.find_event(event.event_id)
	result.action_id = &"explore"
	result.event_target = event
	result.event_id = event.event_id
	result.explore_base = card.explore_amount
	result.explore_bonus = explore_bonus(card, definition)
	result.explore_after = mini(definition.explore_threshold, event.explore_progress + result.explore_base + result.explore_bonus)
	result.explore_applied = result.explore_after - event.explore_progress
	result.clue_revealed = not event.clue_revealed and result.explore_after >= definition.clue_threshold
	if result.clue_revealed:
		result.event_information.append(definition.clue_text)
	result.event_resolved = result.explore_after == definition.explore_threshold
	if result.event_resolved:
		InsightSystem.plan_confirmation(result, definition.completion_insight, floor)
	if card.threat_cost > 0:
		result.threat_delta = mini(card.threat_cost, FloorState.MAX_THREAT - floor.threat)
		result.threat_reason = &"card_risk"


static func plan_pressure(result: ActionResult, floor: FloorState, data: FloorData) -> void:
	var event: EventInstance = floor.board_state.active_event
	if event == null or event.resolved or event.pressure_checked_turn == floor.turn_count:
		return
	result.event_target = event
	result.pressure_checked = true
	if event.last_progress_turn != floor.turn_count:
		result.pressure_stress = data.find_event(event.event_id).neglect_stress


static func commit_situation(result: ActionResult, state: RunState) -> void:
	var event: EventInstance = result.event_target
	if event == null:
		return
	if result.explore_after >= 0:
		# 阈值、线索与进度在同一次提交生效；没有 UI 事件链驱动奖励。
		event.explore_progress = result.explore_after
		event.last_progress_turn = state.floor_state.turn_count
		event.clue_revealed = event.clue_revealed or result.clue_revealed
		event.known_information.append_array(result.event_information)
		event.resolved = result.event_resolved
		result.debug_lines.append("[EXPLORE] %s base=%d bonus=%d applied=%d progress=%d" % [event.event_id, result.explore_base, result.explore_bonus, result.explore_applied, event.explore_progress])
		if result.clue_revealed:
			result.debug_lines.append("[SITUATION] clue %s" % event.event_id)
		if event.resolved:
			result.debug_lines.append("[SITUATION] resolved %s" % event.event_id)
	if result.pressure_checked:
		event.pressure_checked_turn = state.floor_state.turn_count
		state.stress += result.pressure_stress
		result.debug_lines.append("[PRESSURE] %s stress +%d reason=%s" % [event.event_id, result.pressure_stress, "progressed" if event.last_progress_turn == state.floor_state.turn_count else "neglected"])


static func conditions_met(required: Array[StringName], blocked: Array[StringName], flags: Array[StringName]) -> bool:
	for flag: StringName in required:
		if not flags.has(flag):
			return false
	for flag: StringName in blocked:
		if flags.has(flag):
			return false
	return true


static func draw_fresh(data: FloorData, state: FloorState, rng: RandomNumberGenerator, emit_log: bool = true) -> StringName:
	assert(data.id == state.floor_id, "Event selection requires matching floor data/state")
	# 未完成事件跨回合保留，不能靠结束回合跳过进度或刷新基础交互。
	if state.current_event != null and not state.current_event.resolved:
		return state.current_event_id
	var candidates: Array[EventData] = []
	var total_weight: int = 0
	for event_id: StringName in state.remaining_fresh_events:
		var event: EventData = data.find_event(event_id)
		assert(event != null and event.weight > 0, "Invalid Fresh Event definition")
		if event.once_per_instance and state.seen_event_ids.has(event.id):
			continue
		if not conditions_met(event.required_flags, event.blocked_flags, state.floor_flags):
			continue
		candidates.append(event)
		total_weight += event.weight
	state.board_state.active_event = null
	if candidates.is_empty():
		if emit_log and OS.is_debug_build():
			print("[EVENT] no_eligible_fresh remaining=%d" % state.remaining_fresh_events.size())
		return &""
	# 先过滤条件，再用本局 RNG 加权选择；无候选时不消耗随机数。
	var roll: int = rng.randi_range(1, total_weight)
	for event: EventData in candidates:
		roll -= event.weight
		if roll > 0:
			continue
		state.board_state.active_event = EventInstance.new(event.id)
		state.remaining_fresh_events.erase(event.id)
		state.seen_event_ids.append(event.id)
		if emit_log and OS.is_debug_build():
			print("[EVENT] draw %s" % event.id)
		return event.id
	return &""
