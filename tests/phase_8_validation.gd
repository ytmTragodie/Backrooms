extends "res://tests/rework_c_validation.gd"


func label() -> String:
	return "Phase 8 / Smiler generated LIGHT regression"


func tests() -> void:
	_test_smiler_cards()
	var data: FloorData = fixture(LEVEL_6)
	data.entry_entity = data.followup_entity
	data.followup_entity = null
	data.fresh_events = []
	var owner: TurnManager = _equipment_fixture(data, [FLASH], [OBSERVE, OBSERVE, OBSERVE, OBSERVE, OBSERVE])
	var entity: EntityInstance = owner.run_state.floor_state.entity
	owner.end_turn()
	check(entity.alive and entity.hp == 120 and entity.state == &"WITHDRAWN" and owner.run_state.cognition == 0, "No-light behavior resolves Smiler without inventing discovery")
	owner.free()
	var clues: FloorData = fixture(LEVEL_6)
	clues.entry_entity = clues.followup_entity
	clues.followup_entity = null
	clues.fresh_events[0].clue_threshold = 2
	owner = _equipment_fixture(clues, [FLASH], [OBSERVE, OBSERVE, OBSERVE, OBSERVE, OBSERVE])
	play(owner, OBSERVE)
	check(owner.run_state.cognition == 1, "Situation clue replaces manual landmark investigation with same unique Insight")
	play_generated(owner, &"light")
	owner.end_turn()
	play_generated(owner, &"light")
	play_generated(owner, &"extinguish")
	owner.end_turn()
	check(owner.run_state.cognition == 1 and owner.run_state.floor_state.cutout_state.stability == 1, "Clue then behavior cannot duplicate Insight/preparation")
	owner.free()
	owner = _equipment_fixture(data, [], [ATTACK, OBSERVE, OBSERVE, OBSERVE, OBSERVE])
	entity = owner.run_state.floor_state.entity
	play(owner, ATTACK, true)
	check(entity.hp == 116 and entity.state == &"ATTACKING" and not entity.light_exposed, "Common attack HP does not fabricate LIGHT exposure")
	owner.end_turn()
	check(entity.state == &"WITHDRAWN" and owner.run_state.cognition == 0, "Unexposed withdrawal grants no invented knowledge")
	owner.free()
	owner = _equipment_fixture(clues, [], [ATTACK, OBSERVE, OBSERVE, OBSERVE, OBSERVE])
	entity = owner.run_state.floor_state.entity
	entity.hp = 4
	check(play(owner, ATTACK, true).entity_defeated and entity.hp == 0 and not entity.alive, "Edge-case kill retains common HP/defeat semantics")
	check(play(owner, OBSERVE).success and owner.run_state.cognition == 1, "Killing Smiler leaves automatic clue Insight path available")
	owner.free()
	var mixed: FloorData = fixture(LEVEL_6)
	mixed.entry_entity = mixed.followup_entity
	mixed.followup_entity = null
	owner = _equipment_fixture(mixed, [FLASH], [OBSERVE, OBSERVE, GUARD, GUARD, GUARD])
	# 新生成率下跨三个回合重复照明，保留原警告／攻击和共享 Guard 的规则断言。
	for exposure: int in range(2):
		play_generated(owner, &"light")
		owner.end_turn()
	play_generated(owner, &"light")
	play(owner, GUARD)
	var hp_before: int = owner.run_state.player_hp
	var guarded: ActionResult = owner.end_turn()
	check(guarded.pressure_blocked == 2 and guarded.damage_blocked == 2 and guarded.player_damage == 4 and owner.run_state.player_hp == hp_before - 4, "Situation consumes Guard first; Smiler only uses remaining block")
	owner.free()
	owner = _equipment_fixture(data, [FLASH])
	owner.run_state.equipment_slots[0].remaining_uses = 0
	reject(owner, generated_request(owner, &"light"), &"equipment_depleted")
	check(owner.run_state.floor_state.entity.state == &"HIDDEN" and not owner.run_state.floor_state.entity.light_exposed, "Failed generated LIGHT cannot expose Smiler")
	owner.end_turn()
	check(generated(owner, &"light") == null and owner.run_state.floor_state.entity == null and owner.run_state.floor_state.resolved_entity_ids.has(data.entry_entity.id) and owner.run_state.cognition == 0, "Empty source prevents regenerated LIGHT and fake Insight")
	owner.free()
