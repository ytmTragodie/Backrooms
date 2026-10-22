extends SceneTree

const LEVEL_0: FloorData = preload("res://tests/fixtures/phase9/floors/floor_level_0.tres")
const DECK: DeckData = preload("res://data/cards/exploration_deck.tres")
const OBSERVE: CardData = preload("res://data/cards/card_observe.tres")
const SEARCH: CardData = preload("res://data/cards/card_search.tres")
const DEEP: CardData = preload("res://data/cards/card_deep_search.tres")
const MAIN: PackedScene = preload("res://scenes/main/Main.tscn")

var _checks: int = 0
var _failures: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_ownership_and_zones()
	_test_baseline_and_tag_modifier()
	_test_card_risk()
	_test_pressure_and_persistence()
	_test_milestones_and_replacement()
	_test_unique_insights_and_fresh_conditions()
	_test_transactional_failures()
	_test_old_command_rejection()
	await _test_main_ui()
	await process_frame
	if _failures == 0:
		print("[TEST] PASS REWORK A: %d checks (board ownership, Explore, tags, Pressure, milestones, Insight, Fresh lifecycle, targets, atomicity, card UI)" % _checks)
	else:
		push_error("[TEST] FAIL REWORK A: %d of %d checks failed" % [_failures, _checks])
	quit(0 if _failures == 0 else 1)


func _fixture() -> FloorData:
	var data: FloorData = LEVEL_0.duplicate(false) as FloorData
	data.fresh_objectives = []
	for source: ObjectiveData in LEVEL_0.fresh_objectives:
		var event: ObjectiveData = source.duplicate(false) as ObjectiveData
		event.completion_insight = source.completion_insight.duplicate(false) as InsightData
		event.completion_reward = null
		data.fresh_objectives.append(event)
	data.objective_spawn_chance = 1.0
	data.max_objectives_per_floor = data.fresh_objectives.size()
	data.intro_objective = data.fresh_objectives[0] if not data.fresh_objectives.is_empty() else null
	return data


func _manager(data: FloorData = LEVEL_0, definitions: Array[CardData] = []) -> TurnManager:
	var manager: TurnManager = TurnManager.new()
	manager.floor_data = preload("res://tests/legacy_fixture.gd").without_rewards(data) if data == LEVEL_0 else data
	manager.starter_deck = DeckData.new()
	manager.starter_deck.cards.assign(definitions if not definitions.is_empty() else DECK.cards)
	root.add_child(manager)
	return manager


func _play(manager: TurnManager, definition: CardData = OBSERVE) -> ActionResult:
	for card: CardInstance in manager.run_state.player.deck.hand:
		if card.definition == definition:
			return manager.request_play_card(card, manager.run_state.floor_state.current_objective, manager.run_state.floor_state.board_state)
	_check(false, "Fixture must contain the requested actual hand card")
	return ActionResult.new()


func _test_ownership_and_zones() -> void:
	var first: TurnManager = _manager()
	var second: TurnManager = _manager()
	var floor: FloorState = first.run_state.floor_state
	_check(floor.board_state != second.run_state.floor_state.board_state and floor.current_objective != second.run_state.floor_state.current_objective, "Each visit owns a distinct BoardState and ObjectiveInstance")
	_check(floor.current_objective == floor.board_state.active_objective and floor.current_objective_id == floor.board_state.active_objective.objective_id, "Legacy reads derive from the exact board instance, never a progress copy")
	var deck: DeckState = first.run_state.player.deck
	_check(deck.hand.size() == 5 and deck.get_card_count() == 10, "Five Player Cards are drawn from the same ten-card deck")
	for pile: Array[CardInstance] in [deck.draw_pile, deck.hand, deck.discard_pile]:
		var identities: Array[int] = []
		for card: CardInstance in pile:
			identities.append(card.get_instance_id())
		_check(not identities.has(floor.current_objective.get_instance_id()), "World Event never enters or counts toward a player zone")
	_play(first)
	_check(second.run_state.floor_state.current_objective.explore_progress == 0 and LEVEL_0.fresh_objectives[0].progress_threshold == 6, "Progress is per-instance; another run and shared ObjectiveData stay unchanged")
	_check(deck.get_card_count() == 10 and floor.board_state.active_objective.explore_progress == 3, "Playing a card changes the board without turning a World Card into a Player Card")
	first.free()
	second.free()


func _test_baseline_and_tag_modifier() -> void:
	var data: FloorData = _fixture()
	data.fresh_objectives = [data.fresh_objectives[0]]
	data.fresh_objectives[0].explore_bonus = 0
	var manager: TurnManager = _manager(data)
	var result: ActionResult = _play(manager)
	_check(OBSERVE.explore_amount == 2 and OBSERVE.ap_cost == 1 and result.objective.progress_base == 2 and result.objective.progress_bonus == 0 and result.objective.progress_applied == 2, "Observe produces a real reusable baseline of two Explore")
	_check(manager.run_state.floor_state.current_objective.explore_progress == 2 and manager.run_state.floor_state.cognition == 0 and manager.run_state.player.ap == 2, "Baseline Explore commits progress and AP without automatic Cognition")
	manager.free()
	manager = _manager()
	result = _play(manager)
	_check(result.objective.progress_base == 2 and result.objective.progress_bonus == 1 and result.objective.progress_applied == 3, "OBSERVE gains one Explore against Abnormal Hum")
	_check(manager.run_state.floor_state.current_objective.objective_id == &"event_level0_humming", "The seeded production entry is the configured prototype Situation")
	manager.free()
	var renamed: CardData = OBSERVE.duplicate(false) as CardData
	renamed.id = &"card_different_identity"
	renamed.display_name = "不同名字的调查牌"
	manager = _manager(LEVEL_0, [renamed])
	result = _play(manager, renamed)
	_check(result.objective.progress_applied == 3, "Bonus matches OBSERVE tag despite different stable ID and display name")
	manager.free()
	renamed = OBSERVE.duplicate(false) as CardData
	renamed.tags = []
	manager = _manager(LEVEL_0, [renamed])
	result = _play(manager, renamed)
	_check(result.objective.progress_applied == 2 and not result.objective.clue_revealed, "Matching ID/name without the tag does not receive a Situation modifier")
	manager.free()


func _test_card_risk() -> void:
	var data: FloorData = _fixture()
	data.fresh_objectives = [data.fresh_objectives[0]]
	data.fresh_objectives[0].progress_threshold = 20
	var manager: TurnManager = _manager(data)
	var result: ActionResult = _play(manager, SEARCH)
	_check(result.objective.progress_base == 3 and result.objective.progress_applied == 3 and result.card.ap_spent == 1 and result.floor.threat_delta == 1, "Search has its own three Explore, one AP and one Threat")
	result = _play(manager, DEEP)
	_check(result.objective.progress_base == 5 and result.objective.progress_applied == 5 and result.card.ap_spent == 2 and result.floor.threat_delta == 1, "Deep Search has its own five Explore, two AP and one Threat")
	_check(manager.run_state.player.ap == 0 and manager.run_state.floor_state.threat == 2 and manager.run_state.floor_state.current_objective.explore_progress == 8, "Risk and investigation progress commit in the same normal action economy")
	_check(manager.run_state.player.supply == 4 and manager.run_state.floor_state.resource_nodes.filter(func(node: ResourceNode) -> bool: return node.status == ResourceNode.Status.LOOTED).size() == 2, "Declared Search outcomes collect two distinct finite rewards in the same exploration transactions")
	manager.free()
	manager = _manager()
	manager.run_state.floor_state.threat = FloorState.MAX_THREAT
	result = _play(manager, SEARCH)
	_check(result.success and result.floor.threat_delta == 0 and manager.run_state.floor_state.threat == 10, "Card risk clamps at the existing Threat cap")
	manager.free()


func _test_pressure_and_persistence() -> void:
	var manager: TurnManager = _manager()
	var floor: FloorState = manager.run_state.floor_state
	var event: ObjectiveInstance = floor.current_objective
	_play(manager)
	var result: ActionResult = manager.end_turn()
	_check(result.objective.pressure_checked and result.player.pressure_stress == 0 and manager.run_state.player.stress == 0, "Progress in this turn prevents the declared neglect Pressure")
	_check(floor.current_objective == event and event.explore_progress == 3 and event.clue_revealed, "Unresolved Explore and clues persist on the same board object across turns")
	_check(manager.run_state.flow.turn_number == 2 and floor.turn_count == 2 and manager.run_state.player.ap == 3, "Situation uses the existing turn/AP lifecycle")
	result = manager.end_turn()
	_check(result.player.pressure_stress == 1 and manager.run_state.player.stress == 1 and event.pressure_checked_turn == 2, "Ignoring the next turn adds exactly one Stress at end turn")
	_check(event.explore_progress == 3 and floor.current_objective == event, "Pressure never clears or replaces unfinished progress")
	result = manager.end_turn()
	_check(result.player.pressure_stress == 1 and manager.run_state.player.stress == 2 and result.floor.threat_delta == 1 and floor.threat == 1, "Neglect Pressure and existing turn-three overstay resolve together")
	_check(manager.run_state.player.hp == 30 and manager.run_state.player.deck.hand.size() == 5, "Simple Stress Pressure does not invent environmental damage or a second hand")
	manager.free()
	manager = _manager()
	result = RuleResolver.resolve_end_turn(manager.run_state, LEVEL_0)
	_check(result.player.pressure_stress == 1 and manager.run_state.player.stress == 1, "Pressure is a domain result, not a UI-side action")
	result = RuleResolver.resolve_end_turn(manager.run_state, LEVEL_0)
	_check(result.player.pressure_stress == 0 and manager.run_state.player.stress == 1, "Repeated resolution of the same floor turn cannot charge Pressure twice")
	manager.free()


func _test_milestones_and_replacement() -> void:
	var manager: TurnManager = _manager()
	var state: RunState = manager.run_state
	var floor: FloorState = state.floor_state
	var event: ObjectiveInstance = floor.current_objective
	var rng_before: int = state.rng.state
	var notifications: Array[Dictionary] = []
	manager.state_changed.connect(func() -> void: notifications.append(_snapshot(manager)))
	var result: ActionResult = _play(manager)
	_check(result.objective.clue_revealed and event.known_information.size() == 1 and not event.resolved and state.floor_state.cognition == 0, "Three Explore reveals one clue without completing the Situation")
	result = _play(manager, DEEP)
	_check(result.objective.newly_resolved and not result.objective.clue_revealed and event.resolved and event.explore_progress == 6, "Completion is a separate once-only threshold")
	_check(result.objective.progress_base == 5 and result.objective.progress_applied == 3 and state.player.ap == 0, "Explore is clamped to the current Objective; overflow does not affect another Event")
	_check(event.known_information.size() == 1 and state.floor_state.cognition == 1 and floor.discovered_insight_ids.size() == 1, "Clue and unique Insight are not duplicated at completion")
	_check(floor.cutout_state.stability == 2 and floor.cutout_state.destination_knowledge == 1 and state.rng.state == rng_before, "Declared clue plus unique Insight improve preparation without consuming RNG")
	_check(notifications.size() == 2 and notifications[1] == _snapshot(manager), "UI notification sees complete AP/card/Explore/Threat/Insight/preparation commit")
	var before: Dictionary = _snapshot(manager)
	_reject(_play(manager), &"objective_resolved", manager, before)
	_check(notifications.size() == 2, "Rejected resolved target emits no state-change notification")
	result = manager.end_turn()
	_check(result.player.pressure_stress == 0 and floor.current_objective != event and not floor.current_objective.resolved and floor.current_objective.explore_progress == 0, "Resolved Situation causes no Pressure and next Fresh activates at next turn start")
	_check(floor.seen_objective_ids.size() == 2 and floor.remaining_fresh_objectives.size() == 1 and state.flow.turn_number == 2, "Fresh replacement advances only once and does not replay the old Event")
	var new_card: CardInstance = state.player.deck.hand.filter(func(card: CardInstance) -> bool: return card.source == CardData.Source.NORMAL)[0]
	before = _snapshot(manager)
	_reject(manager.request_play_card(new_card, event, floor.board_state), &"invalid_objective_target", manager, before)
	_check(event.explore_progress == 6 and event.known_information.size() == 1 and state.floor_state.cognition == 1, "Old resolved instance cannot receive more Explore after replacement")
	manager.free()
	var powerful: CardData = DEEP.duplicate(false) as CardData
	powerful.explore_amount = 8
	manager = _manager(LEVEL_0, [powerful])
	result = _play(manager, powerful)
	_check(result.objective.clue_revealed and result.objective.newly_resolved and result.floor.insight_ids.size() == 1 and manager.run_state.floor_state.current_objective.known_information.size() == 1, "One action crossing clue and completion thresholds triggers each outcome once")
	_check(result.objective.progress_applied == 6 and manager.run_state.floor_state.cognition == 1 and manager.run_state.player.ap == 1, "Simultaneous milestones still form one AP/card/progress/reward transaction")
	manager.free()


func _test_unique_insights_and_fresh_conditions() -> void:
	var data: FloorData = _fixture()
	for definition: ObjectiveData in data.fresh_objectives:
		definition.completion_insight = data.fresh_objectives[0].completion_insight
	var manager: TurnManager = _manager(data, [OBSERVE, OBSERVE, OBSERVE, OBSERVE, OBSERVE, OBSERVE, OBSERVE, OBSERVE, OBSERVE, OBSERVE])
	var floor: FloorState = manager.run_state.floor_state
	var deck: DeckState = manager.run_state.player.deck
	var seen: Array[StringName] = []
	for index: int in range(3):
		_check(floor.current_objective != null and not seen.has(floor.current_objective_id), "Eligible Fresh Situations do not repeat within a floor visit")
		seen.append(floor.current_objective_id)
		for action: int in range(3):
			if floor.current_objective.resolved or manager.run_state.player.ap == 0:
				break
			_check(_play(manager).success, "Generic Observe progresses all three prototype Situations")
		_check(floor.current_objective.resolved and manager.run_state.floor_state.cognition == 1, "Multiple Events referencing the same Insight award Cognition only once")
		manager.end_turn()
	_check(floor.current_objective == null and floor.remaining_fresh_objectives.is_empty() and floor.seen_objective_ids.size() == 3, "Fresh pool exhausts without reintroducing old rewards or fake Residual content")
	_check(floor.cutout_state.stability == CutOutState.MAX_STABILITY and floor.cutout_state.destination_knowledge == 1 and manager.run_state.player.deck == deck and deck.get_card_count() == 10, "Distinct clue milestones add bounded preparation while shared Insight reward remains unique")
	var result: ActionResult = manager.end_turn()
	_check(result.player.pressure_stress == 0 and floor.current_objective == null, "An empty board produces no phantom Situation Pressure")
	_check(ObjectiveSystem.draw_fresh(data, floor, manager.run_state.rng).is_empty(), "Repeated empty Fresh scheduling cannot create a World Card")
	var rng_before: int = manager.run_state.rng.state
	ObjectiveSystem.draw_fresh(data, floor, manager.run_state.rng)
	_check(manager.run_state.rng.state == rng_before, "No eligible Event consumes no scheduling RNG")
	manager.free()
	data = _fixture()
	data.fresh_objectives[1].required_flags = [&"unavailable_flag"]
	data.fresh_objectives = [data.fresh_objectives[1]]
	manager = _manager(data)
	_check(manager.run_state.floor_state.current_objective == null and manager.run_state.floor_state.remaining_fresh_objectives.size() == 1, "Scheduling filters an ineligible Situation without discarding it")
	var before: Dictionary = _snapshot(manager)
	_reject(_play(manager), &"invalid_objective_target", manager, before)
	manager.free()
	manager = _manager()
	manager.run_state.floor_state.cognition = 5
	_play(manager)
	var completed: ActionResult = _play(manager, SEARCH)
	_check(completed.floor.cognition_delta == 0 and manager.run_state.floor_state.cognition == 5 and manager.run_state.floor_state.discovered_insight_ids.size() == 1, "Completion records unique knowledge at the Cognition cap without exceeding five")
	manager.free()


func _test_transactional_failures() -> void:
	var manager: TurnManager = _manager()
	var state: RunState = manager.run_state
	var floor: FloorState = state.floor_state
	var card: CardInstance = state.player.deck.hand[0]
	var before: Dictionary = _snapshot(manager)
	_reject(RuleResolver.resolve(null, state, manager.card_system, LEVEL_0), &"invalid_command", manager, before)
	_reject(manager.request_play_card(CardInstance.new(OBSERVE), floor.current_objective, floor.board_state), &"card_not_in_hand", manager, before)
	_reject(manager.request_play_card(card), &"invalid_objective_target", manager, before)
	_reject(manager.request_play_card(card, ObjectiveInstance.new(floor.current_objective_id), floor.board_state), &"invalid_objective_target", manager, before)
	_reject(manager.request_play_card(card, floor.current_objective, BoardState.new()), &"invalid_objective_target", manager, before)
	var wrong_floor: FloorData = _fixture()
	wrong_floor.id = &"floor_other_visit"
	_reject(RuleResolver.resolve(PlayCardCommand.new(card, floor.current_objective, floor.board_state), state, manager.card_system, wrong_floor), &"invalid_floor_context", manager, before)
	var other: TurnManager = _manager()
	_reject(manager.request_play_card(card, other.run_state.floor_state.current_objective, other.run_state.floor_state.board_state), &"invalid_objective_target", manager, before)
	_check(other.run_state.player.ap == 3 and other.run_state.floor_state.current_objective.explore_progress == 0, "Cross-run target rejection does not mutate the other board")
	other.free()
	state.player.ap = 0
	before = _snapshot(manager)
	_reject(_play(manager), &"insufficient_ap", manager, before)
	manager.free()
	for invalid_case: String in ["card_explore", "card_risk", "threshold", "clue", "pressure", "bonus", "insight", "progress", "clue_state", "future_pressure"]:
		var data: FloorData = _fixture()
		var definition: CardData = OBSERVE.duplicate(false) as CardData
		manager = _manager(data, [definition])
		var expected: StringName = &"invalid_objective_definition"
		match invalid_case:
			"card_explore":
				definition.explore_amount = -1
				expected = &"invalid_card_definition"
			"card_risk":
				definition.threat_cost = -1
				expected = &"invalid_card_definition"
			"threshold":
				data.fresh_objectives[0].progress_threshold = 0
			"clue":
				data.fresh_objectives[0].clue_threshold = 7
			"pressure":
				data.fresh_objectives[0].neglect_stress = -1
			"bonus":
				data.fresh_objectives[0].bonus_tag = &""
			"insight":
				data.fresh_objectives[0].completion_insight.id = &""
				expected = &"invalid_insight_definition"
			"progress":
				manager.run_state.floor_state.current_objective.explore_progress = 7
				expected = &"invalid_objective_state"
			"clue_state":
				manager.run_state.floor_state.current_objective.clue_revealed = true
				expected = &"invalid_objective_state"
			"future_pressure":
				manager.run_state.floor_state.current_objective.pressure_checked_turn = 2
				expected = &"invalid_objective_state"
		before = _snapshot(manager)
		_reject(_play(manager, definition), expected, manager, before)
		if expected != &"invalid_card_definition":
			_reject(manager.end_turn(), expected, manager, before)
		manager.free()
	_check(OBSERVE.explore_amount == 2 and LEVEL_0.fresh_objectives[0].progress_threshold == 6 and LEVEL_0.fresh_objectives[0].completion_insight.id != &"", "Malformed fixtures never corrupt shared authoring Resources")


func _test_old_command_rejection() -> void:
	var manager: TurnManager = _manager()
	_check(not manager.has_method("request_exploration") and not manager.has_method("request_use_equipment"), "Deprecated player gameplay entry points have been removed, not merely hidden")
	manager.free()


func _test_main_ui() -> void:
	var main: Control = MAIN.instantiate() as Control
	(main.get_node("TurnManager") as TurnManager).floor_data = preload("res://tests/fixtures/phase9/floors/floor_level_0.tres")
	(main.get_node("TurnManager") as TurnManager).starter_deck = preload("res://tests/fixtures/phase9/cards/run_deck.tres")
	(main.get_node("TurnManager") as TurnManager).floor_data = preload("res://tests/legacy_fixture.gd").without_rewards(preload("res://tests/fixtures/phase9/floors/floor_level_0.tres"))
	# 十张纯调查夹具继续证明 A 的不变量；正式主屏使用完整 run_deck。
	(main.get_node("TurnManager") as TurnManager).starter_deck = DECK
	root.add_child(main)
	var manager: TurnManager = main.get_node("TurnManager") as TurnManager
	var hand: HBoxContainer = main.get_node("%Hand") as HBoxContainer
	var world: Button = main.get_node("%WorldCard") as Button
	_check(hand.get_child_count() == 5 and (main.get_node("%SituationName") as Label).text.contains("异常嗡鸣"), "Main screen opens with five Player Cards and one Situation World Card")
	_check((main.get_node("%Objective") as Label).text.contains("调查进度：0／6") and (main.get_node("%Pressure") as Label).text.contains("回合末后果"), "World Card displays Objective, actual Explore and declared Pressure in Chinese")
	var before: Dictionary = _snapshot(manager)
	world.pressed.emit()
	_check(_snapshot(manager) == before, "World Card click only inspects/selects and performs no gameplay")
	for old_path: String in ["%InspectAction", "%SearchNearbyAction", "%PrepareCutOut", "%ForcedCutOut", "%EquipmentSlots"]:
		_check(main.get_node_or_null(old_path) == null, "Deprecated gameplay controls are absent from the new main screen")
	(hand.get_child(0) as Button).pressed.emit()
	_check((main.get_node("%Clues") as Label).text.contains("脚步") and (main.get_node("%Objective") as Label).text.contains("3／6"), "Actual Player Card button reveals the first clue and refreshes board progress")
	_check((main.get_node("%Pressure") as Label).text.contains("已推进"), "UI reads the actual current-turn Pressure condition")
	(hand.get_child(0) as Button).pressed.emit()
	_check((main.get_node("%SituationState") as Label).text.contains("已解决") and manager.run_state.floor_state.cognition == 1, "Resolved state is visible before the next turn")
	(main.get_node("%EndTurn") as Button).pressed.emit()
	_check(hand.get_child_count() == 5 and (main.get_node("%Objective") as Label).text.contains("0／6") and manager.run_state.flow.turn_number == 2, "Existing End Turn draws from the same deck and supplies next Situation")
	await process_frame
	await process_frame
	var viewport: Rect2 = main.get_viewport_rect()
	_check(viewport.encloses(world.get_global_rect()) and viewport.encloses(hand.get_global_rect()) and viewport.encloses((main.get_node("%EndTurn") as Button).get_global_rect()), "World Card, hand and End Turn remain inside the viewport")
	_check(world.get_global_rect().end.y <= hand.get_global_rect().position.y, "Card-game layout puts the World Card above the player's hand without overlap")
	_check(world.get_global_rect().encloses((main.get_node("%SituationState") as Label).get_global_rect()), "World Card contains the last state label without clipping its information")
	_check_chinese_ui(main)
	# 真正主场景的完整有限流程，不修改进度、AP 或领域实例来跳过玩法。
	var state: RunState = manager.run_state
	var deck: DeckState = state.player.deck
	var floor: FloorState = state.floor_state
	for turn: int in range(10):
		if floor.current_objective == null:
			break
		for action: int in range(5):
			if floor.current_objective.resolved:
				break
			var playable: int = -1
			for index: int in range(deck.hand.size()):
				if deck.hand[index].source == CardData.Source.NORMAL and deck.hand[index].definition.ap_cost <= state.player.ap:
					playable = index
					break
			if playable < 0:
				break
			(hand.get_child(playable) as Button).pressed.emit()
		(main.get_node("%EndTurn") as Button).pressed.emit()
	_check(floor.current_objective == null and floor.seen_objective_ids.size() == 3 and state.floor_state.cognition == 3, "Real main-screen hand/turn controls can finish all three unique Situations")
	_check(manager.run_state == state and state.floor_state == floor and state.player.deck == deck and deck.get_card_count() == 10, "Complete exploration preserves one Run, Floor, deck and card inventory")
	_check((main.get_node("%SituationName") as Label).text.contains("调查完毕"), "Fresh exhaustion stays explicit; floor exit remains a separate legal action")
	for index: int in range(deck.hand.size()):
		if deck.hand[index].source == CardData.Source.NORMAL and not deck.hand[index].definition.collects_resources:
			_check((hand.get_child(index) as Button).disabled, "Normal Explore cannot succeed as an empty no-op after Fresh exhaustion")
	await process_frame
	main.free()


func _check_chinese_ui(node: Node) -> void:
	var value: String = ""
	if node is Label:
		value = (node as Label).text
	elif node is Button:
		value = (node as Button).text
	if not value.is_empty():
		_check(RegEx.create_from_string("[A-Za-z_]").search(value) == null, "Player-facing text contains no English identifiers: %s" % value)
	for child: Node in node.get_children():
		_check_chinese_ui(child)


func _snapshot(manager: TurnManager) -> Dictionary:
	var run: RunState = manager.run_state
	var floor: FloorState = run.floor_state
	var event: ObjectiveInstance = floor.current_objective
	var cards: Array = []
	for pile: Array[CardInstance] in [run.player.deck.hand, run.player.deck.draw_pile, run.player.deck.discard_pile]:
		var values: Array = []
		for card: CardInstance in pile:
			var data: CardData = card.definition
			values.append([card.get_instance_id(), data.get_instance_id(), data.id, data.display_name, data.ap_cost, data.explore_amount, data.threat_cost, data.tags.duplicate()])
		cards.append(values)
	var definitions: Array = []
	for data: ObjectiveData in manager.floor_data.fresh_objectives:
		definitions.append([data.get_instance_id(), data.id, data.display_name, data.progress_threshold, data.clue_threshold, data.clue_text, data.neglect_stress, data.bonus_tag, data.explore_bonus, data.completion_insight.get_instance_id(), data.completion_insight.id, data.completion_insight.cutout_stability, data.completion_insight.cutout_knowledge])
	var resources: Array = []
	for node: ResourceNode in floor.resource_nodes:
		resources.append([node.get_instance_id(), node.node_id, node.status])
	var equipment: Array = []
	for item: EquipmentInstance in run.player.equipment.slots:
		equipment.append([item.get_instance_id(), item.remaining_uses, item.definition.get_instance_id(), item.definition.capacity] if item != null else [])
	return {
		"hp": run.player.hp, "stress": run.player.stress, "supply": run.player.supply, "ap": run.player.ap, "turn": run.flow.turn_number,
		"floor": floor.get_instance_id(), "board": floor.board_state.get_instance_id(), "deck": run.player.deck.get_instance_id(),
		"rng": run.rng.state, "cards": cards, "definitions": definitions, "floor_turn": floor.turn_count,
		"event": [event.get_instance_id(), event.objective_id, event.explore_progress, event.clue_revealed, event.resolved, event.last_progress_turn, event.pressure_checked_turn, event.known_information.duplicate()] if event != null else [],
		"fresh": floor.remaining_fresh_objectives.duplicate(), "seen": floor.seen_objective_ids.duplicate(),
		"flags": floor.floor_flags.duplicate(), "insights": floor.discovered_insight_ids.duplicate(),
		"threat": floor.threat, "cognition": floor.cognition, "stability": floor.cutout_state.stability,
		"knowledge": floor.cutout_state.destination_knowledge, "resources": resources, "equipment": equipment,
	}


func _reject(result: ActionResult, reason: StringName, manager: TurnManager, before: Dictionary) -> void:
	_check(not result.success and result.failure_reason == reason, "Expected command rejection: %s" % reason)
	_check(_snapshot(manager) == before, "Failed command changes no AP, cards, Explore, Pressure, Threat, milestones, Insight, definitions, preparation or RNG")
	_check(result.card.ap_spent == 0 and result.card.card_played == null and result.objective.target == null and result.objective.progress_applied == 0 and not result.objective.clue_revealed and not result.objective.newly_resolved and result.floor.insight_ids.is_empty() and result.floor.threat_delta == 0 and result.player.pressure_stress == 0, "Failed ActionResult has no partial gameplay effects")


func _check(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		push_error("[TEST] %s" % message)
