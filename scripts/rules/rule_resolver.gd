class_name RuleResolver
extends RefCounted


static func card_ap_cost(definition: CardData, state: RunState, data: FloorData) -> int:
	var cost: int = definition.ap_cost
	if _is_dark_observation(definition, state, data):
		cost += data.dark_observe_surcharge
	if state.floor_state != null:
		cost += EventSystem.ap_modifier(definition, state.floor_state)
	return cost


static func command_ap_cost(command: PlayCardCommand, state: RunState, data: FloorData) -> int:
	return card_ap_cost(command.card.definition, state, data)


static func _is_dark_observation(definition: CardData, state: RunState, data: FloorData) -> bool:
	if data == null or state.floor_state == null:
		return false
	# 新路径按语义标签识别观察，不再借用旧独立动作名。
	var observing: bool = definition.tags.has(&"OBSERVE") if data.card_first_exploration else definition.exploration_action == &"observe"
	return observing and state.floor_state.floor_flags.has(&"darkness") and not state.floor_state.light_active and not state.floor_state.dark_observation_used


static func resolve(command: PlayCardCommand, state: RunState, cards: CardSystem, floor_data: FloorData = null) -> ActionResult:
	# 解析器不持有 RunState；调用者必须显式提供同一局的状态与牌堆系统。
	var result: ActionResult = ActionResult.new()
	var card: CardInstance = command.card if command != null else null
	var card_id: StringName = &"<invalid>"
	if card != null and card.definition != null:
		card_id = card.definition.id
	result.debug_lines.append("[COMMAND] play_card %s" % card_id)
	# 所有失败分支都位于玩法写入之前，因此无需失败后的回滚。
	if command == null or card == null:
		return _fail(result, &"invalid_command", card_id)
	if state == null or state.deck_state == null or cards == null or not cards.is_bound_to(state):
		return _fail(result, &"invalid_state_context", card_id)
	if state.player_hp <= 0:
		return _fail(result, &"run_ended", card_id)
	if not state.pending_rewards.is_empty():
		return _fail(result, &"reward_pending", card_id)
	if not state.deck_state.hand.has(card):
		return _fail(result, &"card_not_in_hand", card_id)
	if floor_data != null and floor_data.is_placeholder:
		return _fail(result, &"floor_inactive", card_id)
	if state.floor_state != null:
		var context_error: StringName = _validate_floor_context(state, floor_data)
		if not context_error.is_empty():
			return _fail(result, context_error, card_id)
	var definition: CardData = card.definition
	if definition == null or definition.id.is_empty():
		return _fail(result, &"invalid_card_definition", card_id)
	if definition.ap_cost < 0 or definition.placeholder_damage < 0 or definition.effect_value < 0 or definition.explore_amount < 0 or definition.threat_cost < 0:
		return _fail(result, &"invalid_card_definition", card_id)
	if definition.conditional_bonus < 0 or definition.condition_threshold < 0 or definition.bonus_condition not in [CardData.BonusCondition.NONE, CardData.BonusCondition.GUARDED, CardData.BonusCondition.HIGH_THREAT, CardData.BonusCondition.ANALYZED_TARGET]:
		return _fail(result, &"invalid_card_definition", card_id)
	if definition.target_kinds < 0 or definition.target_kinds > 3 or (definition.target_kinds != 0 and not definition.requires_active_target):
		return _fail(result, &"invalid_card_definition", card_id)
	if definition.effect_type not in [CardData.EffectType.NO_OP, CardData.EffectType.PLACEHOLDER_DAMAGE, CardData.EffectType.ATTACK, CardData.EffectType.BLOCK, CardData.EffectType.RUN, CardData.EffectType.LIGHT, CardData.EffectType.EXTINGUISH, CardData.EffectType.CUTOUT_RUSHED, CardData.EffectType.CUTOUT_SAFE, CardData.EffectType.RECOVER]:
		return _fail(result, &"unsupported_effect", card_id)
	if definition.effect_type == CardData.EffectType.NO_OP and definition.placeholder_damage != 0:
		return _fail(result, &"invalid_card_definition", card_id)
	if definition.effect_type in [CardData.EffectType.NO_OP, CardData.EffectType.PLACEHOLDER_DAMAGE, CardData.EffectType.RUN] and definition.effect_value != 0:
		return _fail(result, &"invalid_card_definition", card_id)
	if definition.effect_type in [CardData.EffectType.ATTACK, CardData.EffectType.BLOCK] and (definition.effect_value == 0 or definition.placeholder_damage != 0):
		return _fail(result, &"invalid_card_definition", card_id)
	if not definition.exploration_action.is_empty() and definition.effect_type != CardData.EffectType.NO_OP:
		return _fail(result, &"invalid_card_definition", card_id)
	var source_error: StringName = CardSystem.validate_source(command, state, floor_data)
	if not source_error.is_empty():
		return _fail(result, source_error, card_id)
	var situation_play: bool = floor_data != null and floor_data.card_first_exploration
	if situation_play:
		if state.floor_state == null:
			return _fail(result, &"floor_required", card_id)
		var target_error: StringName = validate_card_target(command, state.floor_state, floor_data, state)
		if not target_error.is_empty():
			return _fail(result, target_error, card_id)
	elif command.target_objective != null or command.target_board != null or command.target_entity != null:
		return _fail(result, &"invalid_objective_target", card_id)
	var final_cost: int = command_ap_cost(command, state, floor_data)
	var dark_observation: bool = _is_dark_observation(definition, state, floor_data)
	if state.ap < final_cost:
		return _fail(result, &"insufficient_ap", card_id)
	# 所有非平凡效果统一写私有草案，失败不会泄露半份资源／实体／奖励计划。
	var failure_result: ActionResult = result
	var draft: ActionResult = ActionResult.new()
	draft.debug_lines.assign(result.debug_lines)
	if definition.source == CardData.Source.EQUIPMENT:
		var equipment_error: StringName = EquipmentSystem.plan_card(draft, command, state, floor_data)
		if not equipment_error.is_empty():
			return _fail(result, equipment_error, card_id)
	elif definition.source == CardData.Source.FLOOR_TEMPORARY:
		var attempt: StringName = &"safe" if definition.effect_type == CardData.EffectType.CUTOUT_SAFE else &"rushed"
		var cutout_error: StringName = CutOutSystem.plan_attempt(draft, state, floor_data, attempt)
		if not cutout_error.is_empty():
			return _fail(result, cutout_error, card_id)
		draft.action_id = attempt
	elif situation_play and definition.explore_amount > 0:
		if command.target_entity != null:
			EntitySystem.plan_analysis(draft, definition, state.floor_state, floor_data)
		elif command.target_objective != null:
			ObjectiveSystem.plan_explore(draft, definition, state.floor_state, floor_data)
		if definition.collects_resources:
			var inventory_error: StringName = EquipmentSystem.validate_inventory(state)
			if not inventory_error.is_empty():
				return _fail(failure_result, inventory_error, card_id)
			ResourceNodeSystem.plan_search_reward(draft, state, floor_data, definition.search_hidden_first)
	result = draft
	var combat_effect: bool = definition.effect_type in [CardData.EffectType.ATTACK, CardData.EffectType.BLOCK, CardData.EffectType.RUN]
	var contextual_attack: bool = definition.effect_type == CardData.EffectType.PLACEHOLDER_DAMAGE and floor_data != null and floor_data.entry_entity != null
	if definition.source == CardData.Source.NORMAL and (combat_effect or contextual_attack):
		if state.floor_state == null:
			return _fail(result, &"floor_required", card_id)
		var entity_error: StringName = EntitySystem.plan_card(result, definition, state, floor_data)
		if not entity_error.is_empty():
			return _fail(failure_result, entity_error, card_id)
		result.action_id = &"block" if definition.effect_type == CardData.EffectType.BLOCK else (&"run" if definition.effect_type == CardData.EffectType.RUN else &"attack")
	if situation_play:
		result.entity_target = command.target_entity
		var risk: int = definition.threat_cost
		if risk > 0:
			result.threat_delta = mini(risk, FloorState.MAX_THREAT - state.floor_state.threat)
			result.threat_reason = &"card_risk"
		# 成功效果的噪音才触发反应；任何失败都不会进入提交。
		EntitySystem.plan_noise_reaction(result, definition.tags, state.floor_state, floor_data)
		if result.light_activated and definition.source != CardData.Source.EQUIPMENT:
			EntitySystem.plan_light_reaction(result, state, floor_data)

		EntitySystem.plan_world_followup(result, state, floor_data)
		EventSystem.plan_card(result, definition, state)
		CardRewardSystem.plan(result, state, floor_data)

	# 先计算并构建完整结果；占位伤害只进入结果，不修改任何目标的 HP。
	result.success = true
	result.ap_spent = final_cost
	result.card_played = card
	result.card_definition = definition
	result.dark_observation = dark_observation
	match definition.effect_type:
		CardData.EffectType.NO_OP:
			result.effect = &"explore" if situation_play else &"no_op"
		CardData.EffectType.PLACEHOLDER_DAMAGE:
			result.effect = &"damage" if contextual_attack else &"placeholder_damage"
			result.damage_requested = definition.placeholder_damage
		CardData.EffectType.ATTACK:
			result.effect = &"damage"
		CardData.EffectType.BLOCK:
			result.effect = &"block"
		CardData.EffectType.RUN:
			result.effect = &"run"
	if definition.source == CardData.Source.EQUIPMENT:
		result.effect = definition.id
	elif definition.source == CardData.Source.FLOOR_TEMPORARY:
		result.effect = result.action_id
	result.debug_lines.append("[RULE] validation success")
	result.debug_lines.append("[RULE] final_cost=%d" % final_cost)

	# 验证到提交保持同步，期间不发送信号，避免观察者读到只扣 AP、未移牌的中间状态。
	var previous_ap: int = state.ap
	state.ap -= result.ap_spent
	cards.finish_play(card, result)
	result.debug_lines.append("[AP] %d -> %d" % [previous_ap, state.ap])
	result.debug_lines.append("[CARD] hand -> discard %s" % card_id if card.source == CardData.Source.NORMAL else "[CARD] source=%d resolved %s" % [card.source, card_id])
	_commit_floor_result(result, state, floor_data)
	if result.commit_rng:
		state.rng.state = result.rng_state_after
	# 生成／升级／换层清理也在同一通知边界内完成，不由 UI 刷新触发。
	cards.refresh_floor_cards(result.destination if result.destination != null else floor_data)
	cards.refresh_equipment_cards(result.destination if result.destination != null else floor_data)
	if result.destination != null:
		cards.generate_equipment_card(result.destination)
	result.debug_lines.append("[RESULT] success %s effect=%s damage_requested=%d" % [card_id, result.effect, result.damage_requested])
	_write_log(result)
	return result


static func validate_card_target(command: PlayCardCommand, floor: FloorState, data: FloorData, state: RunState = null) -> StringName:
	# UI 可只读查询合法性；完整上下文、费用与手牌归属仍由 resolve 重新校验。
	if command == null or command.card == null or command.card.definition == null:
		return &"invalid_command"
	var definition: CardData = command.card.definition
	if command.target_objective != null and command.target_entity != null:
		return &"invalid_target_kind"
	if command.target_objective != null and (definition.target_kinds & CardData.TargetKind.OBJECTIVE) == 0:
		return &"invalid_target_kind"
	if command.target_entity != null and (definition.target_kinds & CardData.TargetKind.ENTITY) == 0:
		return &"invalid_target_kind"
	if definition.requires_active_target and command.target_board == floor.board_state:
		if command.target_objective != null and command.target_objective == floor.board_state.active_objective and command.target_objective.resolved:
			return &"objective_resolved"
		if command.target_entity != null and command.target_entity == floor.board_state.entity and not command.target_entity.active:
			return &"no_active_entity"
	if command.target_entity != null and not definition.target_entity_states.is_empty():
		var identity_error: StringName = EntitySystem.validate_target(command, floor)
		if not identity_error.is_empty():
			return identity_error
		if not definition.target_entity_states.has(command.target_entity.state):
			return &"entity_state_incompatible"
	if definition.source == CardData.Source.EQUIPMENT:
		return &"invalid_state_context" if state == null else EquipmentSystem.validate_card(command, state)
	if definition.source == CardData.Source.FLOOR_TEMPORARY:
		if command.target_board != floor.board_state:
			return &"invalid_objective_target"
		if command.target_objective != null or command.target_entity != null:
			return &"invalid_target_kind"
		var error: StringName = CutOutSystem.validate(floor.cutout_state, data)
		if not error.is_empty():
			return error
		if definition.effect_type == CardData.EffectType.CUTOUT_SAFE:
			return &"" if CutOutSystem.is_prepared(floor.cutout_state) else &"cutout_unprepared"
		return &"" if CutOutSystem.is_available(floor, data) else &"cutout_unavailable"
	if command.target_objective != null and command.target_entity != null:
		return &"invalid_target_kind"
	if definition.explore_amount > 0 and definition.effect_type == CardData.EffectType.NO_OP:
		if command.target_entity == null:
			if command.target_objective == null and definition.collects_resources and (floor.board_state.active_objective == null or floor.board_state.active_objective.resolved):
				if command.target_board != floor.board_state:
					return &"invalid_objective_target"
				return &"" if ResourceNodeSystem.find_search_reward(floor, data, definition.search_hidden_first, state) != null else &"resources_exhausted"
			return ObjectiveSystem.validate_target(command, floor)
		if not definition.analyzes_entities:
			return &"invalid_target_kind"
		var error: StringName = EntitySystem.validate_target(command, floor)
		if not error.is_empty():
			return error
		var entity_data: EntityData = data.find_entity(command.target_entity.entity_id)
		if entity_data == null or entity_data.analysis_threshold == 0:
			return &"analysis_unavailable"
		return &"analysis_complete" if command.target_entity.analysis_progress >= entity_data.analysis_threshold else &""
	if definition.explore_amount != 0:
		return &"unsupported_effect"
	if definition.effect_type in [CardData.EffectType.ATTACK, CardData.EffectType.RUN]:
		if command.target_objective != null:
			return &"invalid_target_kind"
		return EntitySystem.validate_target(command, floor)
	if definition.effect_type == CardData.EffectType.BLOCK:
		# Guard 作用于玩家，不能把失效的显式目标悄悄当作无目标。
		if command.target_objective != null or command.target_entity != null:
			return &"invalid_target_kind"
		if command.target_board != floor.board_state:
			return &"invalid_objective_target"
		var event: ObjectiveInstance = floor.board_state.active_objective
		var entity: EntityInstance = floor.board_state.entity
		var pressure_exists: bool = event != null and not event.resolved and event.last_progress_turn != floor.turn_count and event.pressure_checked_turn != floor.turn_count and data.find_objective(event.objective_id).neglect_damage > 0
		return &"" if pressure_exists or EventSystem.has_damage(floor) or (entity != null and entity.active) else &"guard_unneeded"
	return &"unsupported_effect"


static func resolve_end_turn(state: RunState, data: FloorData = null) -> ActionResult:
	var result: ActionResult = ActionResult.new()
	result.debug_lines.append("[COMMAND] end_turn")
	if state == null:
		return _fail(result, &"invalid_command", &"end_turn")
	if state.player_hp <= 0:
		return _fail(result, &"run_ended", &"end_turn")
	if not state.pending_rewards.is_empty():
		return _fail(result, &"reward_pending", &"end_turn")
	if state.floor_state != null:
		var error: StringName = _validate_floor_context(state, data)
		if not error.is_empty():
			return _fail(result, error, &"end_turn")
		var floor: FloorState = state.floor_state
		# 固定顺序而非信号链：事件先用 Guard，目标后果再用，实体只读余额。
		EventSystem.plan_end_turn(result, state)
		ObjectiveSystem.plan_pressure(result, floor, data)
		result.pressure_damage = mini(result.pressure_damage, state.player_hp)
		EntitySystem.plan_end_turn(result, state, data)
		if floor.turn_count >= data.overstay_start_turn and (floor.turn_count - data.overstay_start_turn) % data.overstay_interval == 0:
			result.threat_delta = mini(1, FloorState.MAX_THREAT - floor.threat)
			result.threat_reason = &"overstay"
	elif data != null:
		return _fail(result, &"floor_required", &"end_turn")
	result.action_id = &"end_turn"
	result.effect = &"end_turn"
	result.success = true
	if state.floor_state != null:
		CardRewardSystem.plan(result, state, data)
	_commit_floor_result(result, state, data)
	if result.commit_rng:
		state.rng.state = result.rng_state_after
	result.debug_lines.append("[RESULT] success end_turn")
	_write_log(result)
	return result


static func _validate_floor_context(state: RunState, data: FloorData) -> StringName:
	var floor: FloorState = state.floor_state
	if floor == null or data == null or floor.floor_id != data.id:
		return &"invalid_floor_context"
	if floor.board_state == null:
		return &"invalid_objective_context"
	if data.is_placeholder:
		return &"floor_inactive"
	if not data.card_first_exploration:
		return &"legacy_floor_unsupported"
	if floor.cognition < 0 or floor.cognition > FloorState.MAX_COGNITION or floor.threat < 0 or floor.threat > FloorState.MAX_THREAT or floor.turn_count < 1:
		return &"invalid_floor_state"
	if data.overstay_start_turn < 3 or data.overstay_interval < 1 or data.dark_observe_surcharge < 0:
		return &"invalid_floor_definition"
	if data.minimum_exit_turn < 1 or data.minimum_exit_explore < 0 or data.fallback_exit_turn < data.minimum_exit_turn or data.threat_damage_step < 0 or data.max_threat_damage_bonus < 0:
		return &"invalid_floor_definition"
	var safe_error: StringName = SafePointSystem.validate(data.safe_point)
	if not safe_error.is_empty():
		return safe_error
	var error: StringName = CutOutSystem.validate_state(floor.cutout_state)
	if not error.is_empty():
		return error
	error = EventSystem.validate_board(floor, data)
	if not error.is_empty():
		return error
	error = CutOutSystem.validate_card_definitions(data)
	if not error.is_empty():
		return error
	if data.card_first_exploration:
		error = ObjectiveSystem.validate_board(floor, data)
		if not error.is_empty():
			return error
	error = ResourceNodeSystem.validate(floor, data)
	return error if not error.is_empty() else EntitySystem.validate(floor, data)


static func _commit_floor_result(result: ActionResult, state: RunState, data: FloorData) -> void:
	if result.action_id.is_empty():
		return
	result.debug_lines.append("[ACTION] %s" % result.action_id)
	var floor: FloorState = state.floor_state
	if floor == null:
		return
	if result.light_extinguished:
		floor.light_active = false
		result.debug_lines.append("[LIGHT] extinguished reason=player_command")
	if result.dark_observation:
		floor.dark_observation_used = true
		result.debug_lines.append("[FLOOR] darkness first_observation surcharge_applied")
	ObjectiveSystem.commit(result, state)
	EventSystem.commit(result, state)
	for flag: StringName in result.floor_flags_added:
		floor.floor_flags.append(flag)
		result.debug_lines.append("[FLOOR] flag %s" % flag)
	for insight_id: StringName in result.insight_ids:
		var previous: int = floor.cognition
		InsightSystem.confirm(floor, insight_id)
		result.debug_lines.append("[INSIGHT] discovered %s" % insight_id)
		result.debug_lines.append("[COGNITION] %d -> %d" % [previous, floor.cognition])
	# 完整环境计划已提交；之后才提交实体、滞留与临时状态清理。
	ResourceNodeSystem.commit(result, state)
	CardRewardSystem.commit(result, state)
	EntitySystem.commit(result, state)
	if not result.threat_reason.is_empty():
		floor.threat += result.threat_delta
		result.debug_lines.append("[THREAT] +%d reason=%s total=%d" % [result.threat_delta, result.threat_reason, floor.threat])
	EquipmentSystem.commit(result, state)
	if result.light_activated:
		floor.light_active = true
	SafePointSystem.reach(state, result)
	state.metrics.record_action(result, state, data)
	if data.retire_resolved_objectives and floor.board_state.active_objective != null and floor.board_state.active_objective.resolved:
		floor.board_state.active_objective = null
	CutOutSystem.commit(result, state)
	if result.action_id == &"end_turn":
		if result.expire_block:
			EntitySystem.finish_turn(floor)
		result.debug_lines.append("[TURN] cleanup")
		floor.dark_observation_used = false
		if floor.light_active:
			floor.light_active = false
			result.debug_lines.append("[LIGHT] expired reason=end_turn")


static func _fail(result: ActionResult, reason: StringName, card_id: StringName) -> ActionResult:
	result.failure_reason = reason
	result.debug_lines.append("[RULE] validation failed reason=%s" % reason)
	result.debug_lines.append("[RESULT] failed %s" % card_id)
	_write_log(result)
	return result


static func resolve_reward(command: CardRewardCommand, state: RunState) -> ActionResult:
	var result: ActionResult = CardRewardSystem.resolve(command, state)
	if result.success:
		state.metrics.record_deck_change(result)
	_write_log(result)
	return result


static func resolve_safe_point(command: SafePointCommand, state: RunState) -> ActionResult:
	var result: ActionResult = SafePointSystem.resolve(command, state)
	if result.success:
		state.metrics.record_deck_change(result)
	_write_log(result)
	return result


static func legal_hand_options(state: RunState, data: FloorData) -> int:
	var count: int = 0
	var board: BoardState = state.floor_state.board_state
	for card: CardInstance in state.deck_state.hand:
		if card_ap_cost(card.definition, state, data) > state.ap:
			continue
		var candidates: Array[PlayCardCommand] = [PlayCardCommand.new(card, null, board)]
		if board.active_objective != null:
			candidates.append(PlayCardCommand.new(card, board.active_objective, board))
		if board.entity != null:
			candidates.append(PlayCardCommand.new(card, null, board, board.entity))
		if candidates.any(func(command: PlayCardCommand) -> bool: return validate_card_target(command, state.floor_state, data, state).is_empty()):
			count += 1
	return count


static func _write_log(result: ActionResult) -> void:
	if OS.is_debug_build():
		for line: String in result.debug_lines:
			print(line)
