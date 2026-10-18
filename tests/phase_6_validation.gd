extends "res://tests/migration_test_base.gd"

func label() -> String:
	return "Phase 6 migrated: common Hound loop"

func tests() -> void:
	var owner: TurnManager = manager([ATTACK, GUARD, GUARD, RUN, OBSERVE], LEVEL_6)
	var run: RunState = owner.run_state
	var floor: FloorState = run.floor_state
	var entity: EntityInstance = floor.entity
	check(entity.hp == 18 and entity.max_hp == 18 and entity.state == &"WATCHING" and entity.intent == &"approach", "Common Hound spawn HP/state/intent")
	play(owner, ATTACK, true)
	play(owner, GUARD)
	play(owner, GUARD)
	var result: ActionResult = owner.end_turn()
	check(result.pressure_blocked == 2 and result.damage_blocked == 4 and entity.state == &"STAGGERED" and run.player_hp == 30 and floor.player_block == 0, "Common defense handles Pressure first then fully blocks published bite")
	check(play(owner, RUN, true).success and not entity.active and entity.alive, "Run resolves staggered Hound without fake HP zero")
	check(run.ap == 2 and run.turn_number == 2 and floor.current_objective != null and floor.cutout_state != null, "Combat preserves shared turn/floor/AP/CutOut")
	owner.free()
	owner = manager([ATTACK, ATTACK, ATTACK, ATTACK, ATTACK, ATTACK], LEVEL_6)
	entity = owner.run_state.floor_state.entity
	for index: int in range(3):
		play(owner, ATTACK, true)
	owner.end_turn()
	play(owner, ATTACK, true)
	result = play(owner, ATTACK, true)
	check(result.entity_defeated and entity.hp == 0 and entity.state == &"DEFEATED" and not entity.active, "HP clamp and defeat preserve common entity model")
	reject(owner, command(owner, ATTACK, true), &"invalid_entity_target")
	owner.free()
	owner = manager([OBSERVE, OBSERVE, OBSERVE, OBSERVE, OBSERVE], LEVEL_6)
	result = play(owner, OBSERVE)
	check(result.ap_spent == 2 and owner.run_state.floor_state.dark_observation_used and owner.run_state.cognition == 0, "First dark Observe uses shared cost and gives no automatic Cognition")
	result = play(owner, OBSERVE)
	check(result.ap_spent == 1 and owner.run_state.floor_state.current_objective.explore_progress == 4, "Following Observe costs baseline and preserves Explore")
	owner.run_state.player_hp = 1
	owner.end_turn()
	check(owner.run_state.player_hp == 1, "Progress suppresses environmental Pressure while Hound approaches")
	owner.end_turn()
	check(owner.run_state.player_hp == 0 and owner.run_state.turn_number == 2, "Lethal consequences stop next turn/draw/AP reset")
	reject(owner, command(owner, OBSERVE), &"run_ended")
	owner.free()
