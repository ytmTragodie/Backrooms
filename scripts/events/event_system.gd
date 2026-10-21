class_name EventSystem
extends RefCounted


static func validate_definitions(data: FloorData) -> StringName:
	var ids: Array[StringName] = []
	for event: EventData in data.events:
		if event == null or event.id.is_empty() or ids.has(event.id) or event.duration < 1 or event.stress_per_turn < 0 or event.damage_per_turn < 0 or event.ap_modifier < 0:
			return &"invalid_event_definition"
		ids.append(event.id)
		if event.category not in [EventData.Category.DEBUFF, EventData.Category.OMEN, EventData.Category.OPPORTUNITY]:
			return &"invalid_event_definition"
		if event.ap_modifier > 0 and event.modifier_tag.is_empty():
			return &"invalid_event_definition"
		if event.category == EventData.Category.OMEN and (event.spawn_entity == null or data.find_entity(event.spawn_entity.id) != event.spawn_entity):
			return &"invalid_event_definition"
		if event.requires_resolved_entity != null and data.find_entity(event.requires_resolved_entity.id) != event.requires_resolved_entity:
			return &"invalid_event_definition"
		if event.spawn_entity != null and not EntitySystem.validate_definition(event.spawn_entity).is_empty():
			return &"invalid_event_definition"
		if event.category == EventData.Category.OPPORTUNITY and (event.required_actions < 1 or event.condition_tag.is_empty() or event.supply_reward < 0 or (event.supply_reward == 0 and event.insight == null and event.card_reward == null)):
			return &"invalid_event_definition"
		if (event.insight != null and not InsightSystem.validate_definition(event.insight).is_empty()) or not CardRewardSystem.validate_definition(event.card_reward).is_empty():
			return &"invalid_event_definition"
	return &""


static func validate_board(floor: FloorState, data: FloorData) -> StringName:
	var error: StringName = validate_definitions(data)
	if not error.is_empty(): return error
	if floor.board_state.active_events.size() > BoardState.EVENT_CAPACITY:
		return &"invalid_event_state"
	var ids: Array[StringName] = []
	for event: EventInstance in floor.board_state.active_events:
		if event == null or not data.events.has(event.definition) or event.retired or event.remaining_turns < 0 or event.remaining_turns > event.definition.duration or event.matching_actions < 0 or event.checked_turn > floor.turn_count or ids.has(event.definition.id):
			return &"invalid_event_state"
		ids.append(event.definition.id)
	return &""


static func fill_slots(floor: FloorState, data: FloorData) -> void:
	# 满额候选保留，按资源数组顺序延后补位；不随机覆盖、也不重洗已出现事件。
	for definition: EventData in data.events:
		if floor.board_state.active_events.size() >= BoardState.EVENT_CAPACITY: return
		if floor.seen_event_ids.has(definition.id): continue
		if definition.requires_resolved_entity != null and not floor.resolved_entity_ids.has(definition.requires_resolved_entity.id): continue
		floor.board_state.active_events.append(EventInstance.new(definition))
		floor.seen_event_ids.append(definition.id)


static func ap_modifier(card: CardData, floor: FloorState) -> int:
	var amount: int = 0
	for event: EventInstance in floor.board_state.active_events:
		if not event.retired and card.tags.has(event.definition.modifier_tag):
			amount += event.definition.ap_modifier
	return amount


static func has_damage(floor: FloorState) -> bool:
	return floor.board_state.active_events.any(func(event: EventInstance) -> bool: return not event.retired and event.definition.damage_per_turn > 0)


static func plan_card(result: ActionResult, card: CardData, state: RunState) -> void:
	if result.cutout.destination != null: return
	for event: EventInstance in state.floor_state.board_state.active_events:
		var change: EventChange = EventChange.new(event)
		var definition: EventData = event.definition
		if definition.category == EventData.Category.OMEN:
			for tag: StringName in definition.accelerate_tags:
				# LIGHT 必须确实生效，印刷标签或失败开灯不算曝光。
				if (tag == &"LIGHT" and result.floor.light_activated) or (tag != &"LIGHT" and card.tags.has(tag)):
					change.remaining_turns = maxi(0, change.remaining_turns - 1)
			_trigger_omen(change, result, state)
		elif definition.category == EventData.Category.OPPORTUNITY and card.tags.has(definition.condition_tag):
			change.matching_actions += 1
			if change.matching_actions >= definition.required_actions:
				change.retired = true
				change.reason = &"condition_met"
				result.player.supply_delta += definition.supply_reward
				if definition.insight != null: InsightSystem.plan_confirmation(result, definition.insight, state.floor_state)
				if definition.card_reward != null: result.event.reward_definitions.append(definition.card_reward)
		result.event.changes.append(change)


static func plan_end_turn(result: ActionResult, state: RunState) -> void:
	var floor: FloorState = state.floor_state
	for event: EventInstance in floor.board_state.active_events:
		if event.checked_turn == floor.turn_count: continue
		var change: EventChange = EventChange.new(event)
		change.checked_turn = floor.turn_count
		change.remaining_turns = maxi(0, change.remaining_turns - 1)
		var definition: EventData = event.definition
		if definition.category == EventData.Category.DEBUFF:
			result.player.pressure_stress += definition.stress_per_turn
			result.player.stress_delta += definition.stress_per_turn
			# 压力共享同一临时防护池；用累计 block_delta 计算剩余 Guard。
			var remaining_block: int = maxi(0, state.player.block + result.player.block_delta)
			var blocked: int = mini(remaining_block, definition.damage_per_turn)
			var damage: int = definition.damage_per_turn - blocked
			result.player.pressure_blocked += blocked
			result.player.block_delta -= blocked
			result.player.pressure_damage += damage
			result.player.hp_delta -= damage
		if definition.category == EventData.Category.OMEN:
			_trigger_omen(change, result, state)
		elif change.remaining_turns == 0:
			change.retired = true
			change.reason = &"expired"
		result.event.changes.append(change)


static func _trigger_omen(change: EventChange, result: ActionResult, state: RunState) -> void:
	if change.remaining_turns > 0: return
	var definition: EntityData = change.target.definition.spawn_entity
	var floor: FloorState = state.floor_state
	if floor.resolved_entity_ids.has(definition.id):
		change.retired = true
		change.reason = &"already_resolved"
		return
	# 槽被占用时保持零倒计时等待，绝不覆盖实体或丢失预告。
	var old_retiring: bool = result.entity.defeated or result.entity.state_after in [&"DISENGAGED", &"WITHDRAWN"]
	if result.entity.spawned != null or (floor.entity != null and floor.entity.active and not old_retiring): return
	result.entity.spawned = EntitySystem.spawn(definition)
	result.entity.spawned.spawned_turn = floor.turn_count
	if definition.behavior_type == EntityData.BehaviorType.LIGHT_REACTIVE and (floor.light_active or result.floor.light_activated) and not result.floor.light_extinguished:
		result.entity.spawned.state = &"OBSERVING"
		result.entity.spawned.intent = EntitySystem.INTENTS[&"OBSERVING"]
		result.entity.spawned.light_exposed = true
	change.retired = true
	change.reason = &"omen_triggered"


static func commit(result: ActionResult, state: RunState) -> void:
	var board: BoardState = state.floor_state.board_state
	# 只提交仍归当前 Board 所有的实例；外部旧引用不能重新入场或发奖。
	for change: EventChange in result.event.changes:
		if not board.active_events.has(change.target) or change.target.retired: continue
		change.target.remaining_turns = change.remaining_turns
		change.target.matching_actions = change.matching_actions
		change.target.checked_turn = change.checked_turn
		change.target.retired = change.retired
		result.debug_lines.append("[EVENT] %s timer=%d actions=%d reason=%s" % [change.target.definition.id, change.remaining_turns, change.matching_actions, change.reason])
		if change.retired: board.active_events.erase(change.target)
	# 玩家压力由 PlayerSystem 提交；EventSystem 只拥有 EventInstance。
