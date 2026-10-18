class_name RuleResolver
extends RefCounted


static func card_ap_cost(definition: CardData, state: RunState, data: FloorData) -> int:
	var cost: int = definition.ap_cost
	if data != null and state.floor_state != null and state.floor_state.floor_flags.has(&"darkness") and not state.floor_state.light_active and not state.floor_state.dark_observation_used and definition.exploration_action == &"observe":
		cost += data.dark_observe_surcharge
	return cost


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
	if definition.effect_type not in [CardData.EffectType.NO_OP, CardData.EffectType.PLACEHOLDER_DAMAGE, CardData.EffectType.ATTACK, CardData.EffectType.BLOCK, CardData.EffectType.RUN]:
		return _fail(result, &"unsupported_effect", card_id)
	if definition.effect_type == CardData.EffectType.NO_OP and definition.placeholder_damage != 0:
		return _fail(result, &"invalid_card_definition", card_id)
	if definition.effect_type in [CardData.EffectType.NO_OP, CardData.EffectType.PLACEHOLDER_DAMAGE, CardData.EffectType.RUN] and definition.effect_value != 0:
		return _fail(result, &"invalid_card_definition", card_id)
	if definition.effect_type in [CardData.EffectType.ATTACK, CardData.EffectType.BLOCK] and (definition.effect_value == 0 or definition.placeholder_damage != 0):
		return _fail(result, &"invalid_card_definition", card_id)
	if not definition.exploration_action.is_empty() and definition.effect_type != CardData.EffectType.NO_OP:
		return _fail(result, &"invalid_card_definition", card_id)
	var situation_play: bool = floor_data != null and floor_data.card_first_exploration
	if situation_play:
		if state.floor_state == null:
			return _fail(result, &"floor_required", card_id)
		if definition.explore_amount <= 0 or definition.effect_type != CardData.EffectType.NO_OP:
			return _fail(result, &"unsupported_effect", card_id)
		var target_error: StringName = EventSystem.validate_target(command, state.floor_state)
		if not target_error.is_empty():
			return _fail(result, target_error, card_id)
	elif command.target_event != null or command.target_board != null:
		return _fail(result, &"invalid_event_target", card_id)
	var final_cost: int = card_ap_cost(definition, state, floor_data)
	var dark_observation: bool = state.floor_state != null and state.floor_state.floor_flags.has(&"darkness") and not state.floor_state.light_active and not state.floor_state.dark_observation_used and definition.exploration_action == &"observe"
	if state.ap < final_cost:
		return _fail(result, &"insufficient_ap", card_id)
	if situation_play:
		EventSystem.plan_explore(result, definition, state.floor_state, floor_data)
	elif not definition.exploration_action.is_empty():
		if definition.exploration_action != &"observe" and definition.exploration_action != &"deep_search":
			return _fail(result, &"invalid_card_definition", card_id)
		# 无楼层的早期测试夹具仍保留原型 no-op；有楼层时按事件条件解析。
		if state.floor_state != null:
			var error: StringName = _prepare_floor_action(result, definition.exploration_action, state, floor_data)
			if not error.is_empty():
				return _fail(result, error, card_id)
	var combat_effect: bool = definition.effect_type in [CardData.EffectType.ATTACK, CardData.EffectType.BLOCK, CardData.EffectType.RUN]
	var contextual_attack: bool = definition.effect_type == CardData.EffectType.PLACEHOLDER_DAMAGE and floor_data != null and floor_data.entry_entity != null
	if combat_effect or contextual_attack:
		if state.floor_state == null:
			return _fail(result, &"floor_required", card_id)
		var entity_error: StringName = EntitySystem.plan_card(result, definition, state, floor_data)
		if not entity_error.is_empty():
			return _fail(result, entity_error, card_id)
		result.action_id = &"block" if definition.effect_type == CardData.EffectType.BLOCK else (&"run" if definition.effect_type == CardData.EffectType.RUN else &"attack")

	# 先计算并构建完整结果；占位伤害只进入结果，不修改任何目标的 HP。
	result.success = true
	result.ap_spent = final_cost
	result.card_played = card
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
	result.debug_lines.append("[RULE] validation success")
	result.debug_lines.append("[RULE] final_cost=%d" % final_cost)

	# 验证到提交保持同步，期间不发送信号，避免观察者读到只扣 AP、未移牌的中间状态。
	var previous_ap: int = state.ap
	state.ap -= result.ap_spent
	cards.move_hand_to_discard(card)
	result.debug_lines.append("[AP] %d -> %d" % [previous_ap, state.ap])
	result.debug_lines.append("[CARD] hand -> discard %s" % card_id)
	_commit_floor_result(result, state)
	result.debug_lines.append("[RESULT] success %s effect=%s damage_requested=%d" % [card_id, result.effect, result.damage_requested])
	_write_log(result)
	return result


static func resolve_equipment(command: UseEquipmentCommand, state: RunState, data: FloorData) -> ActionResult:
	var result: ActionResult = ActionResult.new()
	var slot: int = command.slot_index if command != null else -1
	result.debug_lines.append("[COMMAND] use_equipment slot=%d" % slot)
	if command == null or state == null:
		return _fail(result, &"invalid_command", &"use_equipment")
	if state.player_hp <= 0:
		return _fail(result, &"run_ended", &"use_equipment")
	if state.floor_state == null:
		return _fail(result, &"floor_required", &"use_equipment")
	var error: StringName = _validate_floor_context(state, data)
	if not error.is_empty():
		return _fail(result, error, &"use_equipment")
	error = EquipmentSystem.validate_inventory(state)
	if not error.is_empty():
		return _fail(result, error, &"use_equipment")
	if slot < 0 or slot >= RunState.CARRY_SLOT_COUNT:
		return _fail(result, &"invalid_equipment_slot", &"use_equipment")
	var item: EquipmentInstance = state.equipment_slots[slot]
	if item == null:
		return _fail(result, &"equipment_unavailable", &"use_equipment")
	if item.remaining_uses == 0:
		return _fail(result, &"equipment_depleted", item.definition.id)
	if state.ap < item.definition.ap_cost:
		return _fail(result, &"insufficient_ap", item.definition.id)
	error = EquipmentSystem.plan_use(result, item, state, data)
	if not error.is_empty():
		return _fail(result, error, item.definition.id)
	if result.light_activated:
		EntitySystem.plan_light_reaction(result, state, data)
	result.success = true
	result.action_id = &"use_equipment"
	result.effect = &"damage" if item.definition.effect_type == EquipmentData.EffectType.ATTACK else (&"light" if result.light_activated else &"recover")
	result.ap_spent = item.definition.ap_cost
	result.equipment_used = item
	result.equipment_slot = slot
	result.equipment_uses_spent = 1
	result.debug_lines.append("[RULE] validation success")
	result.debug_lines.append("[RULE] final_cost=%d" % result.ap_spent)
	var previous_ap: int = state.ap
	state.ap -= result.ap_spent
	result.debug_lines.append("[AP] %d -> %d" % [previous_ap, state.ap])
	_commit_floor_result(result, state)
	result.debug_lines.append("[RESULT] success use_equipment %s" % item.definition.id)
	_write_log(result)
	return result


static func resolve_exploration(command: ExplorationCommand, state: RunState, data: FloorData) -> ActionResult:
	var result: ActionResult = ActionResult.new()
	var action: StringName = command.action_id if command != null else &""
	result.debug_lines.append("[COMMAND] action %s" % action)
	if command == null or state == null:
		return _fail(result, &"invalid_command", action)
	if state.player_hp <= 0:
		return _fail(result, &"run_ended", action)
	if data != null and data.card_first_exploration and action in [&"inspect", &"search_nearby", &"observe", &"deep_search", &"search", &"explore"]:
		return _fail(result, &"card_required", action)
	var cost: int = 0
	match action:
		&"inspect", &"search_nearby", &"loot", &"prepare_cutout", &"cutout_safe", &"cutout_rushed", &"encounter", &"study_landmark":
			cost = 1
		&"end_turn", &"cutout_forced", &"extinguish_light":
			cost = 0
		_:
			return _fail(result, &"unknown_action", action)
	if state.ap < cost:
		return _fail(result, &"insufficient_ap", action)
	if state.floor_state == null:
		if action != &"end_turn" or data != null:
			return _fail(result, &"floor_required", action)
	else:
		var error: StringName
		if action in [&"loot", &"prepare_cutout", &"cutout_safe", &"cutout_rushed", &"cutout_forced", &"encounter", &"study_landmark", &"extinguish_light"]:
			error = _prepare_floor_command(result, command, state, data)
		else:
			error = _prepare_floor_action(result, action, state, data)
		if not error.is_empty():
			return _fail(result, error, action)
	result.action_id = action
	result.success = true
	result.effect = action
	result.ap_spent = cost
	result.debug_lines.append("[RULE] validation success")
	result.debug_lines.append("[RULE] final_cost=%d" % cost)
	var previous_ap: int = state.ap
	state.ap -= cost
	result.debug_lines.append("[AP] %d -> %d" % [previous_ap, state.ap])
	_commit_floor_result(result, state)
	result.debug_lines.append("[RESULT] success %s" % action)
	_write_log(result)
	return result


static func _validate_floor_context(state: RunState, data: FloorData) -> StringName:
	var floor: FloorState = state.floor_state
	if floor == null or data == null or floor.floor_id != data.id:
		return &"invalid_floor_context"
	if floor.board_state == null:
		return &"invalid_event_context"
	if data.is_placeholder:
		return &"floor_inactive"
	if floor.cognition < 0 or floor.cognition > FloorState.MAX_COGNITION or floor.threat < 0 or floor.threat > FloorState.MAX_THREAT or floor.turn_count < 1:
		return &"invalid_floor_state"
	if data.overstay_start_turn < 3 or data.overstay_interval < 1 or data.dark_observe_surcharge < 0:
		return &"invalid_floor_definition"
	var error: StringName = CutOutSystem.validate_state(floor.cutout_state)
	if not error.is_empty():
		return error
	if data.card_first_exploration:
		error = EventSystem.validate_board(floor, data)
		if not error.is_empty():
			return error
	error = ResourceNodeSystem.validate(floor, data)
	return error if not error.is_empty() else EntitySystem.validate(floor, data)


static func _prepare_floor_command(result: ActionResult, command: ExplorationCommand, state: RunState, data: FloorData) -> StringName:
	var error: StringName = _validate_floor_context(state, data)
	if not error.is_empty():
		return error
	if command.action_id == &"encounter":
		return EntitySystem.plan_followup(result, state, data)
	if command.action_id == &"extinguish_light":
		if not state.floor_state.light_active:
			return &"light_not_active"
		result.light_extinguished = true
		return &""
	if command.action_id == &"study_landmark":
		if data.landmark_insight == null:
			return &"landmark_unavailable"
		if state.floor_state.discovered_insight_ids.has(data.landmark_insight.id):
			return &"insight_known"
		return InsightSystem.plan_confirmation(result, data.landmark_insight, state.floor_state)
	if command.action_id == &"loot":
		return ResourceNodeSystem.plan_loot(result, state, data, command.target_id)
	error = CutOutSystem.validate(state.floor_state.cutout_state, data)
	if not error.is_empty():
		return error
	if command.action_id == &"prepare_cutout":
		return CutOutSystem.plan_preparation(result, state)
	var attempt_type: StringName = &"safe"
	if command.action_id == &"cutout_rushed":
		attempt_type = &"rushed"
	elif command.action_id == &"cutout_forced":
		attempt_type = &"forced"
	return CutOutSystem.plan_attempt(result, state, data, attempt_type)


static func _prepare_floor_action(result: ActionResult, action: StringName, state: RunState, data: FloorData) -> StringName:
	var error: StringName = _validate_floor_context(state, data)
	if not error.is_empty():
		return error
	var floor: FloorState = state.floor_state
	if data.card_first_exploration:
		# REWORK A 的回合后果仍在原解析器内规划；不会启动事件专用回合。
		if action != &"end_turn":
			return &"card_required"
		EventSystem.plan_pressure(result, floor, data)
		if floor.turn_count >= data.overstay_start_turn and (floor.turn_count - data.overstay_start_turn) % data.overstay_interval == 0:
			result.threat_delta = mini(1, FloorState.MAX_THREAT - floor.threat)
			result.threat_reason = &"overstay"
		EntitySystem.plan_end_turn(result, state, data)
		return &""
	var event: EventData = data.find_event(floor.current_event_id)
	if not floor.current_event_id.is_empty() and event == null:
		return &"invalid_event_context"
	# 全部内容校验先完成，再构建计划，失败结果不会携带半成品效果。
	if event != null:
		for rule: EventActionData in event.action_results:
			if rule == null or rule.action_id not in [&"observe", &"deep_search", &"inspect", &"search_nearby"]:
				return &"invalid_event_definition"
			if rule.insight != null and rule.insight.id.is_empty():
				return &"invalid_insight_definition"
			if rule.insight != null and (rule.insight.cutout_stability < 0 or rule.insight.cutout_knowledge < 0):
				return &"invalid_insight_definition"
			for flag: StringName in rule.granted_flags:
				if flag.is_empty():
					return &"invalid_event_definition"
	var basic: bool = action == &"inspect" or action == &"search_nearby"
	if basic:
		if event == null or not event.has_action(action):
			return &"interaction_unavailable"
		if floor.current_event.completed_interactions.has(action):
			return &"interaction_used"
		if floor.current_event.resolved:
			return &"event_resolved"
	result.action_id = action
	result.event_id = floor.current_event_id
	if action == &"deep_search":
		ResourceNodeSystem.plan_discovery(result, state, data, true)
		result.threat_delta = mini(1, FloorState.MAX_THREAT - floor.threat)
		result.threat_reason = &"deep_search"
	elif action == &"end_turn":
		if floor.turn_count >= data.overstay_start_turn and (floor.turn_count - data.overstay_start_turn) % data.overstay_interval == 0:
			result.threat_delta = mini(1, FloorState.MAX_THREAT - floor.threat)
			result.threat_reason = &"overstay"
		EntitySystem.plan_end_turn(result, state, data)
		return &""
	if action == &"search_nearby":
		ResourceNodeSystem.plan_discovery(result, state, data, false)
	if event == null:
		return &""
	# 已理解的事件允许正常出牌，但不再产生线索奖励；卡牌照常消耗并弃置。
	if floor.current_event.resolved:
		return &""
	if basic:
		result.event_interaction = action
		var completed: Array[StringName] = floor.current_event.completed_interactions.duplicate()
		completed.append(action)
		result.event_resolved = completed.has(&"inspect") and completed.has(&"search_nearby")
	var no_blocked_flags: Array[StringName] = []
	for rule: EventActionData in event.action_results:
		if rule.action_id != action or (rule.requires_light and not floor.light_active) or not EventSystem.conditions_met(rule.required_flags, no_blocked_flags, floor.floor_flags):
			continue
		for flag: StringName in rule.granted_flags:
			if not floor.floor_flags.has(flag) and not result.floor_flags_added.has(flag):
				result.floor_flags_added.append(flag)
		if not rule.revealed_text.is_empty() and not floor.current_event.known_information.has(rule.revealed_text) and not result.event_information.has(rule.revealed_text):
			result.event_information.append(rule.revealed_text)
		result.event_resolved = result.event_resolved or rule.resolves_event
		if rule.insight != null:
			InsightSystem.plan_confirmation(result, rule.insight, floor)
	# 所有条件读取动作前的状态；本次刚记录的线索不能立即充当验证依据。
	return &""


static func _commit_floor_result(result: ActionResult, state: RunState) -> void:
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
	if result.action_id == &"end_turn":
		floor.dark_observation_used = false
		if floor.light_active:
			floor.light_active = false
			result.debug_lines.append("[LIGHT] expired reason=end_turn")
	EventSystem.commit_situation(result, state)
	if result.event_target == null and floor.current_event != null and result.action_id != &"end_turn":
		var instance: EventInstance = floor.current_event
		var previous_phase: StringName = instance.phase
		if not result.event_interaction.is_empty():
			instance.completed_interactions.append(result.event_interaction)
			result.debug_lines.append("[EVENT] %s %s" % [result.event_interaction, instance.event_id])
		instance.known_information.append_array(result.event_information)
		instance.resolved = instance.resolved or result.event_resolved
		if instance.phase != previous_phase:
			result.debug_lines.append("[EVENT] state %s -> %s" % [previous_phase, instance.phase])
	for flag: StringName in result.floor_flags_added:
		floor.floor_flags.append(flag)
		result.debug_lines.append("[FLOOR] flag %s" % flag)
	for insight_id: StringName in result.insight_ids:
		var previous: int = floor.cognition
		InsightSystem.confirm(floor, insight_id)
		result.debug_lines.append("[INSIGHT] discovered %s" % insight_id)
		result.debug_lines.append("[COGNITION] %d -> %d" % [previous, floor.cognition])
	if not result.threat_reason.is_empty():
		floor.threat += result.threat_delta
		result.debug_lines.append("[THREAT] +%d reason=%s total=%d" % [result.threat_delta, result.threat_reason, floor.threat])
	ResourceNodeSystem.commit(result, state)
	EntitySystem.commit(result, state)
	EquipmentSystem.commit(result, state)
	CutOutSystem.commit(result, state)


static func _fail(result: ActionResult, reason: StringName, card_id: StringName) -> ActionResult:
	result.failure_reason = reason
	result.debug_lines.append("[RULE] validation failed reason=%s" % reason)
	result.debug_lines.append("[RESULT] failed %s" % card_id)
	_write_log(result)
	return result


static func _write_log(result: ActionResult) -> void:
	if OS.is_debug_build():
		for line: String in result.debug_lines:
			print(line)
