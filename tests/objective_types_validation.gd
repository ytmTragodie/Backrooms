extends "res://tests/migration_test_base.gd"

const REWARD_CARDS: CardRewardData = preload("res://data/rewards/reward_cards.tres")

var _observe: CardData
var _search: CardData


func label() -> String:
	return "Phase 13B / Objective types"


func tests() -> void:
	_observe = _test_card(OBSERVE, &"test_observe", [&"OBSERVE"])
	_search = _test_card(SEARCH, &"test_search", [&"SEARCH"])
	_test_definition_rules()
	_test_progress_gate()
	_test_condition()
	_test_zero_explore_condition()
	_test_sequence()
	_test_cap_and_intro()
	_test_completion_reward_once()


func _test_card(source: CardData, id: StringName, tags: Array[StringName]) -> CardData:
	var card: CardData = source.duplicate(false) as CardData
	card.id = id
	card.display_name = "测试%s" % id
	card.tags = tags
	card.collects_resources = false
	card.explore_amount = 2
	card.target_kinds = CardData.TargetKind.OBJECTIVE
	return card


func _objective(id: StringName, type: ObjectiveData.ObjectiveType, threshold: int = 0) -> ObjectiveData:
	var objective: ObjectiveData = ObjectiveData.new()
	objective.id = id
	objective.asset_id = &"objective_level0_damp_wall"
	objective.display_name = "测试目标"
	objective.display_text = "测试目标说明"
	objective.objective_text = "测试目标提示"
	objective.objective_type = type
	objective.progress_threshold = threshold
	objective.clue_threshold = 0
	objective.completion_supply = 2
	objective.neglect_stress = 0
	objective.neglect_damage = 0
	objective.weight = 1
	return objective


func _data(objectives: Array[ObjectiveData], chance: float = 1.0, max_count: int = 1) -> FloorData:
	var data: FloorData = fixture()
	data.fresh_objectives.clear()
	for objective: ObjectiveData in objectives:
		data.fresh_objectives.append(objective)
	data.events.clear()
	data.resource_nodes.clear()
	data.entry_entity = null
	data.followup_entity = null
	data.safe_point = null
	data.intro_objective = objectives[0] if not objectives.is_empty() else null
	data.objective_spawn_chance = chance
	data.max_objectives_per_floor = max_count
	data.retire_resolved_objectives = false
	return data


func _condition_data(steps: Array[StringName], reward: CardRewardData = null) -> FloorData:
	var objective: ObjectiveData = _objective(&"test_condition", ObjectiveData.ObjectiveType.CONDITION)
	objective.required_actions = steps
	objective.completion_reward = reward
	return _data([objective])


func _sequence_data(steps: Array[StringName]) -> FloorData:
	var objective: ObjectiveData = _objective(&"test_sequence", ObjectiveData.ObjectiveType.SEQUENCE)
	objective.sequence_actions = steps
	return _data([objective])


func _test_definition_rules() -> void:
	var progress: ObjectiveData = _objective(&"test_progress", ObjectiveData.ObjectiveType.PROGRESS, 4)
	check(ObjectiveSystem.validate_definition(progress).is_empty(), "Progress definition accepts canonical progress_threshold")
	progress.progress_threshold = 0
	check(ObjectiveSystem.validate_definition(progress) == &"invalid_objective_definition", "Progress requires a positive threshold")
	var condition: ObjectiveData = _objective(&"test_condition", ObjectiveData.ObjectiveType.CONDITION)
	condition.required_actions = [&"OBSERVE", &"SEARCH"]
	check(ObjectiveSystem.validate_definition(condition).is_empty(), "Condition definition accepts distinct tag steps")
	condition.required_actions = [&"OBSERVE", &"OBSERVE"]
	check(ObjectiveSystem.validate_definition(condition) == &"invalid_objective_definition", "Condition rejects duplicate tag steps")
	var sequence: ObjectiveData = _objective(&"test_sequence", ObjectiveData.ObjectiveType.SEQUENCE)
	sequence.sequence_actions = [&"OBSERVE", &"OBSERVE"]
	check(ObjectiveSystem.validate_definition(sequence).is_empty(), "Sequence permits repeated tags in fixed order")
	sequence.sequence_actions = []
	check(ObjectiveSystem.validate_definition(sequence) == &"invalid_objective_definition", "Sequence rejects an empty step list")
	check(ObjectiveData.new().get("explore_threshold") == null, "Legacy explore_threshold no longer exists on ObjectiveData")
	check(LEVEL_6.fresh_objectives[0].progress_threshold > 0 and ObjectiveSystem.validate_definition(LEVEL_6.fresh_objectives[0]).is_empty(), "Production resources load with progress_threshold")


func _test_progress_gate() -> void:
	var data: FloorData = _data([_objective(&"test_progress", ObjectiveData.ObjectiveType.PROGRESS, 4)])
	var owner: TurnManager = manager([_observe, _observe, _observe, _observe, _observe], data, false)
	var event: ObjectiveInstance = owner.run_state.floor_state.current_objective
	var planned: ActionResult = ActionResult.new()
	var before: int = event.explore_progress
	check(ObjectiveSystem.plan_interaction(planned, _observe, owner.run_state.floor_state, data).is_empty() and event.explore_progress == before, "Progress plan is pure and does not mutate the ObjectiveInstance")
	var result: ActionResult = play(owner, _observe)
	check(result.success and result.objective.progress_applied == 2 and event.explore_progress == 2 and not event.resolved, "Progress commits only its own domain after the plan")
	var second: ActionResult = play(owner, _observe)
	check(second.success and second.objective.newly_resolved and event.resolved and owner.run_state.supply == 2, "Progress completion records one new resolution and planned supply")
	reject(owner, command(owner, _observe), &"objective_resolved")
	owner.free()


func _test_condition() -> void:
	var data: FloorData = _condition_data([&"SEARCH", &"OBSERVE"])
	var owner: TurnManager = manager([_search, _observe, _observe, _observe, _observe], data, false)
	var event: ObjectiveInstance = owner.run_state.floor_state.current_objective
	var plan: ActionResult = ActionResult.new()
	check(ObjectiveSystem.plan_interaction(plan, _search, owner.run_state.floor_state, data).is_empty() and event.completed_interactions.is_empty(), "Condition plan does not write completed interactions")
	var first: ActionResult = play(owner, _search)
	check(first.success and first.objective.completed_conditions.has(&"SEARCH") and event.completed_interactions == [&"SEARCH"] and not event.resolved, "Condition step is legal in any order and commits once")
	check(first.objective.progress_applied == 0 and event.explore_progress == 0, "Condition does not fake Progress")
	var second: ActionResult = play(owner, _observe)
	check(second.success and second.objective.newly_resolved and event.resolved and owner.run_state.supply == 2, "Condition completion happens only after all distinct steps")
	reject(owner, command(owner, _observe), &"objective_resolved")
	owner.free()


func _test_zero_explore_condition() -> void:
	var utility: CardData = _observe.duplicate(false) as CardData
	utility.id = &"test_touch"
	utility.display_name = "测试触碰"
	utility.tags = [&"TOUCH"]
	utility.explore_amount = 0
	utility.effect_type = CardData.EffectType.NO_OP
	utility.placeholder_damage = 0
	var data: FloorData = _condition_data([&"TOUCH"])
	var owner: TurnManager = manager([utility, utility, utility, utility, utility], data, false)
	var board: BoardState = owner.run_state.floor_state.board_state
	var result: ActionResult = submit(owner, PlayCardCommand.new(hand_card(owner, utility), board.active_objective, board))
	check(result.success and result.objective.newly_resolved and owner.run_state.floor_state.current_objective.resolved, "Zero-Explore tagged card can advance a Condition without Progress")
	check(result.card.effect == &"no_op" and owner.run_state.floor_state.total_explore == 0, "Zero-Explore condition does not fabricate Explore")
	owner.free()


func _test_sequence() -> void:
	var data: FloorData = _sequence_data([&"OBSERVE", &"SEARCH"])
	var owner: TurnManager = manager([_search, _observe, _observe, _observe, _observe], data, false)
	var event: ObjectiveInstance = owner.run_state.floor_state.current_objective
	reject(owner, command(owner, _search), &"objective_step_incompatible")
	check(event.sequence_index == 0 and owner.run_state.ap == 3 and owner.run_state.deck_state.hand.size() == 5, "Wrong sequence step rejects before AP/card/RNG")
	var plan: ActionResult = ActionResult.new()
	check(ObjectiveSystem.plan_interaction(plan, _observe, owner.run_state.floor_state, data).is_empty() and event.sequence_index == 0, "Sequence plan computes sequence_after without mutating the instance")
	var first: ActionResult = play(owner, _observe)
	check(first.success and first.objective.sequence_after == 1 and event.sequence_index == 1 and not event.resolved, "Sequence advances exactly one step")
	var second: ActionResult = play(owner, _search)
	check(second.success and second.objective.newly_resolved and event.sequence_index == 2 and event.resolved and owner.run_state.supply == 2, "Sequence completes only in declared order")
	reject(owner, command(owner, _observe), &"objective_resolved")
	owner.free()

	var repeated: FloorData = _sequence_data([&"OBSERVE", &"OBSERVE"])
	var repeated_owner: TurnManager = manager([_observe, _observe, _observe, _observe, _observe], repeated, false)
	var repeated_event: ObjectiveInstance = repeated_owner.run_state.floor_state.current_objective
	check(play(repeated_owner, _observe).success and repeated_event.sequence_index == 1, "Repeated sequence tag accepts its first occurrence")
	check(play(repeated_owner, _observe).success and repeated_event.resolved and repeated_event.sequence_index == 2, "Repeated sequence tag accepts the second occurrence in order")
	repeated_owner.free()


func _test_cap_and_intro() -> void:
	var first: ObjectiveData = _objective(&"test_cap_0", ObjectiveData.ObjectiveType.PROGRESS, 4)
	var second: ObjectiveData = _objective(&"test_cap_1", ObjectiveData.ObjectiveType.PROGRESS, 4)
	var data: FloorData = _data([first, second], 0.0, 2)
	var floor: FloorState = FloorState.new(data)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 9
	check(ObjectiveSystem.draw_fresh(data, floor, rng, false) == first.id, "First intro objective appears without consuming spawn chance")
	floor.current_objective.resolved = true
	check(ObjectiveSystem.draw_fresh(data, floor, rng, false).is_empty() and floor.remaining_fresh_objectives.size() == 1, "Failed spawn chance leaves the pool for the next turn")
	data.objective_spawn_chance = 1.0
	check(ObjectiveSystem.draw_fresh(data, floor, rng, false) == second.id, "Successful chance draw selects the remaining candidate")
	floor.current_objective.resolved = true
	check(ObjectiveSystem.draw_fresh(data, floor, rng, false).is_empty() and floor.remaining_fresh_objectives.is_empty(), "Per-visit maximum clears the remaining pool")


func _test_completion_reward_once() -> void:
	var data: FloorData = _condition_data([&"OBSERVE", &"SEARCH"], REWARD_CARDS)
	var owner: TurnManager = manager([_observe, _search, _observe, _search, _observe], data, false)
	check(play(owner, _observe).success, "First condition step does not create a reward")
	var result: ActionResult = play(owner, _search)
	check(result.success and result.objective.newly_resolved and result.run.reward_created.size() == 1 and owner.run_state.pending_rewards.size() == 1 and owner.run_state.pending_rewards[0].definition == REWARD_CARDS, "New completion creates exactly one reward opportunity")
	var pending_before: int = owner.run_state.pending_rewards.size()
	var replay: ActionResult = play(owner, _observe)
	check(not replay.success and owner.run_state.pending_rewards.size() == pending_before, "Resolved objective cannot create a second reward")
	owner.free()