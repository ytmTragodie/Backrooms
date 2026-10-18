extends "res://tests/rework_c_validation.gd"


func label() -> String:
	return "Phase 7 / equipment source lifecycle"


func tests() -> void:
	_test_equipment_cards()
	_test_generation_rate()
	var run: RunState = RunState.new()
	check(EquipmentSystem.initialize(run, [FLASH, CROWBAR, WATER, FLASH]) == &"carry_slots_full" and run.equipment_slots.all(func(item: EquipmentInstance) -> bool: return item == null), "Four items fail before any initialization")
	check(EquipmentSystem.initialize(run, [FLASH, CROWBAR, WATER]).is_empty() and run.equipment_slots.size() == 3, "Exactly three physical slots initialize")
	check(EquipmentSystem.initialize(run, []) == &"equipment_already_initialized", "Inventory cannot be silently reinitialized")
	var data: FloorData = fixture(LEVEL_6)
	data.entry_entity = null
	data.followup_entity = null
	data.fresh_objectives = []
	var owner: TurnManager = _equipment_fixture(data, [FLASH])
	var battery: EquipmentInstance = owner.run_state.equipment_slots[0]
	for index: int in range(3):
		check(play_generated(owner, &"light").success and battery.remaining_uses == 2-index, "Each generated activation spends exactly one battery on its own turn")
		owner.end_turn()
	check(generated(owner, &"light") == null and battery.remaining_uses == 0, "Empty flashlight no longer generates lighting")
	for attempt: int in range(12):
		if owner.floor_data.is_placeholder:
			break
		play_generated(owner, &"rushed")
		if not owner.floor_data.is_placeholder:
			owner.end_turn()
	check(owner.floor_data.is_placeholder and owner.run_state.equipment_slots[0] == battery and battery.remaining_uses == 0, "Depleted inventory persists through exit")
	owner.free()
	owner = _equipment_fixture(LEVEL_6, [CROWBAR], [ATTACK, ATTACK, ATTACK, ATTACK, ATTACK])
	owner.run_state.equipment_slots[0].remaining_uses = 0
	reject(owner, generated_request(owner, &"crowbar"), &"equipment_depleted")
	check(play(owner, ATTACK, true).success, "Broken equipment never invalidates normal attack")
	owner.free()
	owner = _equipment_fixture(LEVEL_6, [FLASH])
	owner.run_state.equipment_slots[0].remaining_uses = 4
	reject(owner, generated_request(owner, &"light"), &"invalid_equipment_state")
	owner.free()
