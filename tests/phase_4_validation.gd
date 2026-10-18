extends "res://tests/migration_test_base.gd"

func label() -> String:
	return "Phase 4 migrated: floor events and Insight"

func tests() -> void:
	var data: FloorData = fixture()
	var first: FloorState = FloorState.new(data)
	var second: FloorState = FloorState.new(data)
	check(first.board_state != second.board_state and first.cutout_state != second.cutout_state and first.resource_nodes[0] != second.resource_nodes[0], "Floor visits independently own all runtime objects")
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 7
	for index: int in range(data.fresh_objectives.size()):
		var id: StringName = ObjectiveSystem.draw_fresh(data, first, rng, false)
		check(not id.is_empty() and first.seen_objective_ids.size() == index+1, "Fresh candidates draw without replacement")
		first.current_objective.resolved = true
	check(ObjectiveSystem.draw_fresh(data, first, rng, false).is_empty(), "Exhaustion does not reshuffle once-only content")
	data = fixture()
	data.fresh_objectives[0].required_flags = [&"known"]
	data.fresh_objectives[1].blocked_flags = [&"blocked"]
	data.fresh_objectives[2].required_flags = [&"never"]
	first = FloorState.new(data)
	first.floor_flags = [&"blocked"]
	var before_rng: int = rng.state
	check(ObjectiveSystem.draw_fresh(data, first, rng, false).is_empty() and rng.state == before_rng, "No eligible content consumes no RNG")
	first.floor_flags.append(&"known")
	check(ObjectiveSystem.draw_fresh(data, first, rng, false) == data.fresh_objectives[0].id, "Required/blocked flags filter before weighted draw")
	var owner: TurnManager = manager([OBSERVE, SEARCH, OBSERVE, SEARCH, OBSERVE])
	play(owner, OBSERVE)
	var result: ActionResult = play(owner, SEARCH)
	check(result.objective_resolved and result.clue_revealed == false and owner.run_state.cognition == 1 and owner.run_state.threat == 1, "Cards replace inspect/search buttons while retaining unique Insight/Threat")
	reject(owner, command(owner, OBSERVE), &"objective_resolved")
	owner.end_turn()
	check(owner.run_state.floor_state.current_objective.explore_progress == 0 and owner.run_state.floor_state.seen_objective_ids.size() == 2 and owner.run_state.ap == 3, "Same lifecycle replaces resolved event only at next turn")
	owner.free()
	first = FloorState.new(LEVEL_0)
	for index: int in range(7):
		InsightSystem.confirm(first, StringName("insight_test_%d" % index))
	check(first.cognition == 5 and first.discovered_insight_ids.size() == 7, "Cognition caps at five while unique fact registry retains identities")
	check(InsightSystem.confirm(first, &"insight_test_0") == 0 and first.cognition == 5, "Duplicate fact never increases Cognition")
