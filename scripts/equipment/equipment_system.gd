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


static func plan_use(result: ActionResult, item: EquipmentInstance, state: RunState) -> StringName:
	var data: EquipmentData = item.definition
	match data.effect_type:
		EquipmentData.EffectType.LIGHT:
			if not state.floor_state.floor_flags.has(&"darkness"):
				return &"light_not_needed"
			if state.floor_state.light_active:
				return &"light_already_active"
			result.light_activated = true
		EquipmentData.EffectType.ATTACK:
			# 装备直接使用通用伤害入口，不构造假卡，也不接触任何牌区。
			var error: StringName = EntitySystem.plan_attack(result, data.effect_value, state)
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
