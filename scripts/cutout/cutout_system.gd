class_name CutOutSystem
extends RefCounted

const SAFE_STABILITY: int = 2
const SAFE_KNOWLEDGE: int = 1
const MINIMUM_EXIT_TURN: int = 2


static func is_available(floor: FloorState, data: FloorData) -> bool:
	# 有准备可提前出现；无事件／资源／认知时，第二个驻留回合也必有仓促出口。
	return not data.is_placeholder and not floor.cutout_state.destination_candidates.is_empty() and (floor.cutout_state.stability > 0 or floor.turn_count >= MINIMUM_EXIT_TURN)


static func validate_card_definitions(data: FloorData) -> StringName:
	var definitions: Array[CardData] = [data.rushed_cutout_card, data.safe_cutout_card]
	var effects: Array[CardData.EffectType] = [CardData.EffectType.CUTOUT_RUSHED, CardData.EffectType.CUTOUT_SAFE]
	for index: int in range(definitions.size()):
		var definition: CardData = definitions[index]
		if definition == null or definition.id.is_empty() or definition.source != CardData.Source.FLOOR_TEMPORARY or definition.effect_type != effects[index] or not definition.retain or definition.ap_cost != 1:
			return &"invalid_cutout_card"
	return &""


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
	error = validate_card_definitions(data)
	if not error.is_empty():
		return error
	if state.destination_candidates.is_empty():
		return &"destination_unavailable"
	var ids: Array[StringName] = []
	for id: StringName in state.destination_candidates:
		var destination: FloorData = data.find_destination(id)
		if destination == null or id.is_empty() or ids.has(id):
			return &"invalid_destination"
		# 在创建任何下一层实例／消耗 RNG 之前验证完整落地内容。
		if destination.overstay_start_turn < 3 or destination.overstay_interval < 1 or destination.dark_observe_surcharge < 0:
			return &"invalid_floor_definition"
		if not destination.is_placeholder and (not destination.card_first_exploration or destination.cutout_destinations.is_empty()):
			return &"invalid_destination"
		if not destination.is_placeholder:
			error = validate_card_definitions(destination)
			if not error.is_empty():
				return error
		if destination.entry_entity != null and destination.followup_entity != null and destination.entry_entity.id == destination.followup_entity.id:
			return &"invalid_entity_definition"
		var event_ids: Array[StringName] = []
		for event: EventData in destination.fresh_events:
			if event == null or event.id.is_empty() or event.weight <= 0 or event_ids.has(event.id):
				return &"invalid_event_definition"
			if destination.card_first_exploration:
				error = EventSystem.validate_situation(event)
				if not error.is_empty():
					return error
			event_ids.append(event.id)
		var node_ids: Array[StringName] = []
		for node: ResourceNodeData in destination.resource_nodes:
			if node == null or node.id.is_empty() or node.supply_reward < 0 or node_ids.has(node.id):
				return &"invalid_resource_definition"
			node_ids.append(node.id)
		var destination_ids: Array[StringName] = []
		for resource: Resource in destination.cutout_destinations:
			var next: FloorData = resource as FloorData
			if next == null or next.id.is_empty() or destination_ids.has(next.id):
				return &"invalid_destination"
			destination_ids.append(next.id)
		if destination.entry_entity != null:
			error = EntitySystem.validate_definition(destination.entry_entity)
			if not error.is_empty():
				return error
		if destination.followup_entity != null:
			error = EntitySystem.validate_definition(destination.followup_entity)
			if not error.is_empty():
				return error
		for entity: EntityData in [destination.entry_entity, destination.followup_entity]:
			if entity != null and entity.behavior_type == EntityData.BehaviorType.LIGHT_REACTIVE and not destination.initial_flags.has(&"darkness"):
				return &"invalid_entity_context"
		if destination.landmark_insight != null:
			error = InsightSystem.validate_definition(destination.landmark_insight)
			if not error.is_empty():
				return error
		ids.append(id)
	return &""


static func plan_gain(result: ActionResult, state: CutOutState, stability: int, knowledge: int, reason: StringName) -> void:
	result.stability_delta = mini(result.stability_delta + stability, CutOutState.MAX_STABILITY - state.stability)
	result.knowledge_delta = mini(result.knowledge_delta + knowledge, CutOutState.MAX_KNOWLEDGE - state.destination_knowledge)
	result.preparation_reason = reason


static func plan_attempt(result: ActionResult, state: RunState, data: FloorData, attempt_type: StringName) -> StringName:
	var cutout: CutOutState = state.floor_state.cutout_state
	if attempt_type not in [&"safe", &"rushed"]:
		return &"invalid_cutout_attempt"
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
	# RNG 由 RuleResolver 与奖励草案一起提交，避免两个系统分别写同一随机状态。
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
