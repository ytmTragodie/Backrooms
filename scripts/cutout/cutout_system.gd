class_name CutOutSystem
extends RefCounted

const SAFE_STABILITY: int = 2
const SAFE_KNOWLEDGE: int = 1


static func is_prepared(state: CutOutState) -> bool:
	return state.stability >= SAFE_STABILITY and state.destination_knowledge >= SAFE_KNOWLEDGE


static func validate_state(state: CutOutState) -> StringName:
	if state == null or state.stability < 0 or state.stability > CutOutState.MAX_STABILITY or state.destination_knowledge < 0 or state.destination_knowledge > CutOutState.MAX_KNOWLEDGE:
		return &"invalid_cutout_state"
	return &""


static func validate(state: CutOutState, data: FloorData) -> StringName:
	var error: StringName = validate_state(state)
	if not error.is_empty():
		return error
	if state.destination_candidates.is_empty():
		return &"destination_unavailable"
	var ids: Array[StringName] = []
	for id: StringName in state.destination_candidates:
		var destination: FloorData = data.find_destination(id)
		if destination == null or id.is_empty() or ids.has(id):
			return &"invalid_destination"
		if destination.entry_entity != null:
			error = EntitySystem.validate_definition(destination.entry_entity)
			if not error.is_empty():
				return error
		ids.append(id)
	return &""


static func plan_preparation(result: ActionResult, state: RunState) -> StringName:
	var cutout: CutOutState = state.floor_state.cutout_state
	if state.supply < 1:
		return &"insufficient_supply"
	if cutout.stability == CutOutState.MAX_STABILITY and cutout.destination_knowledge == CutOutState.MAX_KNOWLEDGE:
		return &"preparation_complete"
	result.supply_delta = -1
	plan_gain(result, cutout, 1, 1, &"supply_preparation")
	return &""


static func plan_gain(result: ActionResult, state: CutOutState, stability: int, knowledge: int, reason: StringName) -> void:
	result.stability_delta = mini(stability, CutOutState.MAX_STABILITY - state.stability)
	result.knowledge_delta = mini(knowledge, CutOutState.MAX_KNOWLEDGE - state.destination_knowledge)
	result.preparation_reason = reason


static func plan_attempt(result: ActionResult, state: RunState, data: FloorData, attempt_type: StringName) -> StringName:
	var cutout: CutOutState = state.floor_state.cutout_state
	if attempt_type == &"safe" and not is_prepared(cutout):
		return &"cutout_unprepared"
	var attempt: CutOutAttemptResult = CutOutAttemptResult.new()
	attempt.attempt_type = attempt_type
	attempt.source_floor_id = state.floor_state.floor_id
	attempt.succeeded = true
	# 使用本局 RNG 的副本先计算，只有完整动作提交时才推进权威 RNG。
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = state.rng_seed
	rng.state = state.rng.state
	if attempt_type == &"rushed":
		attempt.roll = rng.randi_range(1, 100)
		attempt.succeeded = attempt.roll <= mini(90, 55 + cutout.stability * 10 + cutout.destination_knowledge * 5)
		result.stress_delta = 1
		if not attempt.succeeded:
			result.threat_delta = mini(1, FloorState.MAX_THREAT - state.floor_state.threat)
			result.threat_reason = &"rushed_cutout_failed"
	elif attempt_type == &"forced":
		# 无 AP、事件、资源、Insight 或生命门槛；保证任何合法驻留状态都有出口。
		result.stress_delta = 2
	if attempt.succeeded:
		var index: int = 0 if attempt_type == &"safe" else rng.randi_range(0, cutout.destination_candidates.size() - 1)
		attempt.destination_id = cutout.destination_candidates[index]
		result.destination = data.find_destination(attempt.destination_id)
		result.next_floor = FloorState.new(result.destination)
		# 新楼层只在私有计划对象上初始化；不改 AP、手牌、管理器或当前楼层。
		if not result.destination.is_placeholder:
			EventSystem.draw_fresh(result.destination, result.next_floor, rng, false)
	result.cutout_attempt = attempt
	result.rng_state_after = rng.state
	result.commit_rng = true
	return &""


static func commit(result: ActionResult, state: RunState) -> void:
	var cutout: CutOutState = state.floor_state.cutout_state
	cutout.stability += result.stability_delta
	cutout.destination_knowledge += result.knowledge_delta
	if not result.preparation_reason.is_empty():
		result.debug_lines.append("[CUTOUT] stability +%d knowledge +%d reason=%s" % [result.stability_delta, result.knowledge_delta, result.preparation_reason])
	if result.cutout_attempt == null:
		return
	state.last_cutout_attempt = result.cutout_attempt
	state.stress += result.stress_delta
	if result.commit_rng:
		state.rng.state = result.rng_state_after
	result.debug_lines.append("[CUTOUT] attempt type=%s roll=%d stress=+%d" % [result.cutout_attempt.attempt_type, result.cutout_attempt.roll, result.stress_delta])
	if result.cutout_attempt.succeeded:
		# 目的地定义和新状态已在规划阶段创建；此处只切换权威状态引用。
		state.floor_state = result.next_floor
		result.debug_lines.append("[CUTOUT] success destination=%s" % result.cutout_attempt.destination_id)
		if state.floor_state.current_event != null:
			result.debug_lines.append("[EVENT] draw %s" % state.floor_state.current_event_id)
		if state.floor_state.entity != null:
			result.debug_lines.append("[ENTITY] spawn %s hp=%d state=%s" % [state.floor_state.entity.entity_id, state.floor_state.entity.hp, state.floor_state.entity.state])
	else:
		result.debug_lines.append("[CUTOUT] failed floor_unchanged")
