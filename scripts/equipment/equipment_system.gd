class_name EquipmentSystem
extends RefCounted


static func validate_definition(data: EquipmentData) -> StringName:
	if data == null or data.id.is_empty() or data.capacity <= 0 or data.ap_cost < 0 or data.effect_value < 0 or data.conditional_heal < 0 or data.heal_stress_threshold < 0:
		return &"invalid_equipment_definition"
	if data.counter_kind not in [&"battery", &"durability", &"charges"]:
		return &"invalid_equipment_definition"
	if data.effect_type not in [EquipmentData.EffectType.LIGHT, EquipmentData.EffectType.ATTACK, EquipmentData.EffectType.RECOVER]:
		return &"invalid_equipment_definition"
	if data.effect_type == EquipmentData.EffectType.LIGHT and (data.effect_value != 0 or data.conditional_heal != 0):
		return &"invalid_equipment_definition"
	if data.effect_type != EquipmentData.EffectType.LIGHT and data.effect_value == 0:
		return &"invalid_equipment_definition"
	if data.effect_type == EquipmentData.EffectType.ATTACK and data.conditional_heal != 0:
		return &"invalid_equipment_definition"
	if data.action_card == null and data.active_action_card != null:
		return &"invalid_equipment_definition"
	if data.action_card != null:
		var expected: CardData.EffectType = CardData.EffectType.LIGHT if data.effect_type == EquipmentData.EffectType.LIGHT else (CardData.EffectType.ATTACK if data.effect_type == EquipmentData.EffectType.ATTACK else CardData.EffectType.RECOVER)
		if not _valid_action_card(data.action_card, expected):
			return &"invalid_equipment_definition"
		if expected == CardData.EffectType.LIGHT and not _valid_action_card(data.active_action_card, CardData.EffectType.EXTINGUISH):
			return &"invalid_equipment_definition"
	if data.effect_type != EquipmentData.EffectType.LIGHT and data.active_action_card != null:
		return &"invalid_equipment_definition"
	return &""


static func _valid_action_card(card: CardData, effect: CardData.EffectType) -> bool:
	return card != null and not card.id.is_empty() and not card.display_name.is_empty() and card.source == CardData.Source.EQUIPMENT and not card.retain and card.ap_cost >= 1 and card.effect_type == effect and (card.effect_value > 0 if effect == CardData.EffectType.ATTACK else card.effect_value == 0)


static func current_action_card(item: EquipmentInstance, floor: FloorState) -> CardData:
	if item == null or item.definition == null or floor == null:
		return null
	if item.definition.effect_type == EquipmentData.EffectType.LIGHT:
		if not floor.floor_flags.has(&"darkness"):
			return null
		if floor.light_active:
			# 电量已经耗尽时，仍须允许关闭实际已开启的光源。
			return item.definition.active_action_card
	return item.definition.action_card if item.remaining_uses > 0 else null


static func validate_card(command: PlayCardCommand, state: RunState) -> StringName:
	var floor: FloorState = state.floor_state
	if command.target_board != floor.board_state:
		return &"invalid_objective_target"
	if command.target_objective != null:
		return &"invalid_target_kind"
	var error: StringName = validate_inventory(state)
	if not error.is_empty():
		return error
	var item: EquipmentInstance = command.card.source_equipment
	if item == null or not state.equipment_slots.has(item):
		return &"invalid_equipment_target"
	var effect: CardData.EffectType = command.card.definition.effect_type
	if command.card.definition not in [item.definition.action_card, item.definition.active_action_card]:
		return &"invalid_card_source"
	if effect == CardData.EffectType.ATTACK:
		error = EntitySystem.validate_target(command, floor)
		if not error.is_empty():
			return error
	elif command.target_entity != null:
		return &"invalid_target_kind"
	if effect == CardData.EffectType.EXTINGUISH:
		return &"" if item.definition.effect_type == EquipmentData.EffectType.LIGHT and floor.light_active else &"light_not_active"
	if item.remaining_uses == 0:
		return &"equipment_depleted"
	if effect == CardData.EffectType.LIGHT:
		if not floor.floor_flags.has(&"darkness"):
			return &"light_not_needed"
		if floor.light_active:
			return &"light_already_active"
	if effect == CardData.EffectType.RECOVER and state.stress == 0 and (state.stress < item.definition.heal_stress_threshold or item.definition.conditional_heal == 0 or state.player_hp >= RunState.MAX_PLAYER_HP):
		return &"nothing_to_restore"
	return &""


static func plan_card(result: ActionResult, command: PlayCardCommand, state: RunState, floor_data: FloorData) -> StringName:
	var item: EquipmentInstance = command.card.source_equipment
	result.action_id = command.card.definition.id
	if command.card.definition.effect_type == CardData.EffectType.EXTINGUISH:
		result.light_extinguished = true
	else:
		var error: StringName = plan_use(result, item, state, floor_data, command.card.definition.effect_value)
		if not error.is_empty():
			return error
		result.equipment_uses_spent = 1
	result.equipment_used = item
	result.equipment_slot = state.equipment_slots.find(item)
	if result.light_activated:
		EntitySystem.plan_light_reaction(result, state, floor_data)
	return &""


static func initialize(state: RunState, definitions: Array[EquipmentData]) -> StringName:
	# 开局也先验证全部内容再赋值，超过三格或坏定义不会留下半份初始装备。
	if definitions.size() > RunState.CARRY_SLOT_COUNT:
		return &"carry_slots_full"
	if state.equipment_slots.size() != RunState.CARRY_SLOT_COUNT:
		return &"invalid_equipment_state"
	for existing: EquipmentInstance in state.equipment_slots:
		if existing != null:
			return &"equipment_already_initialized"
	for data: EquipmentData in definitions:
		var error: StringName = validate_definition(data)
		if not error.is_empty():
			return error
	var slots: Array[EquipmentInstance] = []
	slots.resize(RunState.CARRY_SLOT_COUNT)
	for index: int in range(definitions.size()):
		slots[index] = EquipmentInstance.new(definitions[index])
	state.equipment_slots.assign(slots)
	if OS.is_debug_build():
		for index: int in range(definitions.size()):
			print("[EQUIPMENT] equipped %s slot=%d uses=%d" % [definitions[index].id, index, slots[index].remaining_uses])
	return &""


static func validate_inventory(state: RunState) -> StringName:
	if state.equipment_slots.size() != RunState.CARRY_SLOT_COUNT:
		return &"invalid_equipment_state"
	var seen: Array[EquipmentInstance] = []
	for item: EquipmentInstance in state.equipment_slots:
		if item == null:
			continue
		if seen.has(item):
			return &"invalid_equipment_state"
		seen.append(item)
		var error: StringName = validate_definition(item.definition)
		if not error.is_empty():
			return error
		if item.remaining_uses < 0 or item.remaining_uses > item.definition.capacity:
			return &"invalid_equipment_state"
	return &""


static func plan_use(result: ActionResult, item: EquipmentInstance, state: RunState, floor_data: FloorData, attack_damage: int = 0) -> StringName:
	var data: EquipmentData = item.definition
	match data.effect_type:
		EquipmentData.EffectType.LIGHT:
			if not state.floor_state.floor_flags.has(&"darkness"):
				return &"light_not_needed"
			if state.floor_state.light_active:
				return &"light_already_active"
			result.light_activated = true
		EquipmentData.EffectType.ATTACK:
			# 专用攻击牌声明总伤害；物品仅提供来源与耐久，不再选择增强分支。
			var entity: EntityInstance = state.floor_state.entity
			var target: EntityData = floor_data.find_entity(entity.entity_id) if entity != null else null
			var error: StringName = EntitySystem.plan_attack(result, attack_damage if attack_damage > 0 else data.effect_value, state, target)
			if not error.is_empty():
				return error
		EquipmentData.EffectType.RECOVER:
			if state.stress < 0:
				return &"invalid_state_context"
			result.stress_restored = mini(data.effect_value, state.stress)
			if state.stress >= data.heal_stress_threshold:
				result.hp_restored = mini(data.conditional_heal, maxi(0, RunState.MAX_PLAYER_HP - state.player_hp))
			if result.stress_restored == 0 and result.hp_restored == 0:
				return &"nothing_to_restore"
	return &""


static func commit(result: ActionResult, state: RunState) -> void:
	# 搜索只规划补充值；物理计数仍统一由装备系统提交。
	if result.resource_uses_gained > 0:
		result.resource_equipment.remaining_uses += result.resource_uses_gained
		result.debug_lines.append("[RESOURCE] replenished %s +%d" % [result.resource_equipment.definition.id, result.resource_uses_gained])
	if result.equipment_used == null:
		return
	# 与 AP、伤害和照明在同一次同步结算内提交；UI 通知只发生在全部完成后。
	result.equipment_used.remaining_uses -= result.equipment_uses_spent
	state.stress -= result.stress_restored
	state.player_hp += result.hp_restored
	if result.light_activated:
		state.floor_state.light_active = true
		result.debug_lines.append("[LIGHT] active until=end_turn")
	result.debug_lines.append("[EQUIPMENT] used %s uses -%d remaining=%d" % [result.equipment_used.definition.id, result.equipment_uses_spent, result.equipment_used.remaining_uses])
	if result.stress_restored > 0 or result.hp_restored > 0:
		result.debug_lines.append("[RECOVERY] stress -%d hp +%d" % [result.stress_restored, result.hp_restored])
