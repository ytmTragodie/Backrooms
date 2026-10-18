extends SceneTree

const LEVEL_0: FloorData = preload("res://data/floors/floor_level_0.tres")
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
	data.fresh_events = []
	for source: EventData in LEVEL_0.fresh_events:
		var event: EventData = source.duplicate(false) as EventData
		event.completion_insight = source.completion_insight.duplicate(false) as InsightData
		data.fresh_events.append(event)
	return data


func _manager(data: FloorData = LEVEL_0, definitions: Array[CardData] = []) -> TurnManager:
	var manager: TurnManager = TurnManager.new()
	manager.floor_data = data
	manager.starter_deck = DeckData.new()
	manager.starter_deck.cards.assign(definitions if not definitions.is_empty() else DECK.cards)
	root.add_child(manager)
	return manager


func _play(manager: TurnManager, definition: CardData = OBSERVE) -> ActionResult:
	for card: CardInstance in manager.run_state.deck_state.hand:
		if card.definition == definition:
			return manager.request_play_card(card, manager.run_state.floor_state.current_event, manager.run_state.floor_state.board_state)
	_check(false, "Fixture must contain the requested actual hand card")
	return ActionResult.new()


func _test_ownership_and_zones() -> void:
	var first: TurnManager = _manager()
	var second: TurnManager = _manager()
	var floor: FloorState = first.run_state.floor_state
	_check(floor.board_state != second.run_state.floor_state.board_state and floor.current_event != second.run_state.floor_state.current_event, "Each visit owns a distinct BoardState and EventInstance")
	_check(floor.current_event == floor.board_state.active_event and floor.current_event_id == floor.board_state.active_event.event_id, "Legacy reads derive from the exact board instance, never a progress copy")
	var deck: DeckState = first.run_state.deck_state
	_check(deck.hand.size() == 5 and deck.get_card_count() == 10, "Five Player Cards are drawn from the same ten-card deck")
	for pile: Array[CardInstance] in [deck.draw_pile, deck.hand, deck.discard_pile]:
		var identities: Array[int] = []
		for card: CardInstance in pile:
			identities.append(card.get_instance_id())
		_check(not identities.has(floor.current_event.get_instance_id()), "World Event never enters or counts toward a player zone")
	_play(first)
	_check(second.run_state.floor_state.current_event.explore_progress == 0 and LEVEL_0.fresh_events[0].explore_threshold == 6, "Progress is per-instance; another run and shared EventData stay unchanged")
	_check(deck.get_card_count() == 10 and floor.board_state.active_event.explore_progress == 3, "Playing a card changes the board without turning a World Card into a Player Card")
	first.free()
	second.free()


func _test_baseline_and_tag_modifier() -> void:
	var data: FloorData = _fixture()
	data.fresh_events = [data.fresh_events[0]]
	data.fresh_events[0].explore_bonus = 0
	var manager: TurnManager = _manager(data)
	var result: ActionResult = _play(manager)
	_check(OBSERVE.explore_amount == 2 and OBSERVE.ap_cost == 1 and result.explore_base == 2 and result.explore_bonus == 0 and result.explore_applied == 2, "Observe produces a real reusable baseline of two Explore")
	_check(manager.run_state.floor_state.current_event.explore_progress == 2 and manager.run_state.cognition == 0 and manager.run_state.ap == 2, "Baseline Explore commits progress and AP without automatic Cognition")
	manager.free()
	manager = _manager()
	result = _play(manager)
	_check(result.explore_base == 2 and result.explore_bonus == 1 and result.explore_applied == 3, "OBSERVE gains one Explore against Abnormal Hum")
	_check(manager.run_state.floor_state.current_event.event_id == &"event_level0_humming", "The seeded production entry is the configured prototype Situation")
	manager.free()
	var renamed: CardData = OBSERVE.duplicate(false) as CardData
	renamed.id = &"card_different_identity"
	renamed.display_name = "不同名字的调查牌"
	manager = _manager(LEVEL_0, [renamed])
	result = _play(manager, renamed)
	_check(result.explore_applied == 3, "Bonus matches OBSERVE tag despite different stable ID and display name")
	manager.free()
	renamed = OBSERVE.duplicate(false) as CardData
	renamed.tags = []
	manager = _manager(LEVEL_0, [renamed])
	result = _play(manager, renamed)
	_check(result.explore_applied == 2 and not result.clue_revealed, "Matching ID/name without the tag does not receive a Situation modifier")
	manager.free()


func _test_card_risk() -> void:
	var data: FloorData = _fixture()
	data.fresh_events = [data.fresh_events[0]]
	data.fresh_events[0].explore_threshold = 20
	var manager: TurnManager = _manager(data)
	var result: ActionResult = _play(manager, SEARCH)
	_check(result.explore_base == 3 and result.explore_applied == 3 and result.ap_spent == 1 and result.threat_delta == 1, "Search has its own three Explore, one AP and one Threat")
	result = _play(manager, DEEP)
	_check(result.explore_base == 5 and result.explore_applied == 5 and result.ap_spent == 2 and result.threat_delta == 1, "Deep Search has its own five Explore, two AP and one Threat")
	_check(manager.run_state.ap == 0 and manager.run_state.threat == 2 and manager.run_state.floor_state.current_event.explore_progress == 8, "Risk and investigation progress commit in the same normal action economy")
	_check(manager.run_state.supply == 0 and manager.run_state.floor_state.resource_nodes.all(func(node: ResourceNode) -> bool: return node.status == ResourceNode.Status.UNDISCOVERED), "Migrated Deep Search does not secretly execute the old resource-loot action")
	manager.free()
	manager = _manager()
	manager.run_state.floor_state.threat = FloorState.MAX_THREAT
	result = _play(manager, SEARCH)
	_check(result.success and result.threat_delta == 0 and manager.run_state.threat == 10, "Card risk clamps at the existing Threat cap")
	manager.free()


func _test_pressure_and_persistence() -> void:
	var manager: TurnManager = _manager()
	var floor: FloorState = manager.run_state.floor_state
	var event: EventInstance = floor.current_event
	_play(manager)
	var result: ActionResult = manager.end_turn()
	_check(result.pressure_checked and result.pressure_stress == 0 and manager.run_state.stress == 0, "Progress in this turn prevents the declared neglect Pressure")
	_check(floor.current_event == event and event.explore_progress == 3 and event.clue_revealed, "Unresolved Explore and clues persist on the same board object across turns")
	_check(manager.run_state.turn_number == 2 and floor.turn_count == 2 and manager.run_state.ap == 3, "Situation uses the existing turn/AP lifecycle")
	result = manager.end_turn()
	_check(result.pressure_stress == 1 and manager.run_state.stress == 1 and event.pressure_checked_turn == 2, "Ignoring the next turn adds exactly one Stress at end turn")
	_check(event.explore_progress == 3 and floor.current_event == event, "Pressure never clears or replaces unfinished progress")
	result = manager.end_turn()
	_check(result.pressure_stress == 1 and manager.run_state.stress == 2 and result.threat_delta == 1 and floor.threat == 1, "Neglect Pressure and existing turn-three overstay resolve together")
	_check(manager.run_state.player_hp == 30 and manager.run_state.deck_state.hand.size() == 5, "Simple Stress Pressure does not invent environmental damage or a second hand")
	manager.free()
	manager = _manager()
	result = RuleResolver.resolve_exploration(ExplorationCommand.new(&"end_turn"), manager.run_state, LEVEL_0)
	_check(result.pressure_stress == 1 and manager.run_state.stress == 1, "Pressure is a domain result, not a UI-side action")
	result = RuleResolver.resolve_exploration(ExplorationCommand.new(&"end_turn"), manager.run_state, LEVEL_0)
	_check(result.pressure_stress == 0 and manager.run_state.stress == 1, "Repeated resolution of the same floor turn cannot charge Pressure twice")
	manager.free()


func _test_milestones_and_replacement() -> void:
	var manager: TurnManager = _manager()
	var state: RunState = manager.run_state
	var floor: FloorState = state.floor_state
	var event: EventInstance = floor.current_event
	var rng_before: int = state.rng.state
	var notifications: Array[Dictionary] = []
	manager.state_changed.connect(func() -> void: notifications.append(_snapshot(manager)))
	var result: ActionResult = _play(manager)
	_check(result.clue_revealed and event.known_information.size() == 1 and not event.resolved and state.cognition == 0, "Three Explore reveals one clue without completing the Situation")
	result = _play(manager, DEEP)
	_check(result.event_resolved and not result.clue_revealed and event.resolved and event.explore_progress == 6, "Completion is a separate once-only threshold")
	_check(result.explore_base == 5 and result.explore_applied == 3 and state.ap == 0, "Explore is clamped to the current Objective; overflow does not affect another Event")
	_check(event.known_information.size() == 1 and state.cognition == 1 and floor.discovered_insight_ids.size() == 1, "Clue and unique Insight are not duplicated at completion")
	_check(floor.cutout_state.stability == 1 and floor.cutout_state.destination_knowledge == 1 and state.rng.state == rng_before, "Existing Insight preparation gains are preserved without hidden play RNG")
	_check(notifications.size() == 2 and notifications[1] == _snapshot(manager), "UI notification sees complete AP/card/Explore/Threat/Insight/preparation commit")
	var before: Dictionary = _snapshot(manager)
	_reject(_play(manager), &"event_resolved", manager, before)
	_check(notifications.size() == 2, "Rejected resolved target emits no state-change notification")
	result = manager.end_turn()
	_check(result.pressure_stress == 0 and floor.current_event != event and not floor.current_event.resolved and floor.current_event.explore_progress == 0, "Resolved Situation causes no Pressure and next Fresh activates at next turn start")
	_check(floor.seen_event_ids.size() == 2 and floor.remaining_fresh_events.size() == 1 and state.turn_number == 2, "Fresh replacement advances only once and does not replay the old Event")
	var new_card: CardInstance = state.deck_state.hand[0]
	before = _snapshot(manager)
	_reject(manager.request_play_card(new_card, event, floor.board_state), &"invalid_event_target", manager, before)
	_check(event.explore_progress == 6 and event.known_information.size() == 1 and state.cognition == 1, "Old resolved instance cannot receive more Explore after replacement")
	manager.free()
	var powerful: CardData = DEEP.duplicate(false) as CardData
	powerful.explore_amount = 8
	manager = _manager(LEVEL_0, [powerful])
	result = _play(manager, powerful)
	_check(result.clue_revealed and result.event_resolved and result.insight_ids.size() == 1 and manager.run_state.floor_state.current_event.known_information.size() == 1, "One action crossing clue and completion thresholds triggers each outcome once")
	_check(result.explore_applied == 6 and manager.run_state.cognition == 1 and manager.run_state.ap == 1, "Simultaneous milestones still form one AP/card/progress/reward transaction")
	manager.free()


func _test_unique_insights_and_fresh_conditions() -> void:
	var data: FloorData = _fixture()
	for definition: EventData in data.fresh_events:
		definition.completion_insight = data.fresh_events[0].completion_insight
	var manager: TurnManager = _manager(data, [OBSERVE, OBSERVE, OBSERVE, OBSERVE, OBSERVE, OBSERVE, OBSERVE, OBSERVE, OBSERVE, OBSERVE])
	var floor: FloorState = manager.run_state.floor_state
	var deck: DeckState = manager.run_state.deck_state
	var seen: Array[StringName] = []
	for index: int in range(3):
		_check(floor.current_event != null and not seen.has(floor.current_event_id), "Eligible Fresh Situations do not repeat within a floor visit")
		seen.append(floor.current_event_id)
		for action: int in range(3):
			if floor.current_event.resolved or manager.run_state.ap == 0:
				break
			_check(_play(manager).success, "Generic Observe progresses all three prototype Situations")
		_check(floor.current_event.resolved and manager.run_state.cognition == 1, "Multiple Events referencing the same Insight award Cognition only once")
		manager.end_turn()
	_check(floor.current_event == null and floor.remaining_fresh_events.is_empty() and floor.seen_event_ids.size() == 3, "Fresh pool exhausts without reintroducing old rewards or fake Residual content")
	_check(floor.cutout_state.stability == 1 and floor.cutout_state.destination_knowledge == 1 and manager.run_state.deck_state == deck and deck.get_card_count() == 10, "Insight reward deduplication also preserves preparation and the original deck")
	var result: ActionResult = manager.end_turn()
	_check(result.pressure_stress == 0 and floor.current_event == null, "An empty board produces no phantom Situation Pressure")
	_check(EventSystem.draw_fresh(data, floor, manager.run_state.rng).is_empty(), "Repeated empty Fresh scheduling cannot create a World Card")
	var rng_before: int = manager.run_state.rng.state
	EventSystem.draw_fresh(data, floor, manager.run_state.rng)
	_check(manager.run_state.rng.state == rng_before, "No eligible Event consumes no scheduling RNG")
	manager.free()
	data = _fixture()
	data.fresh_events[1].required_flags = [&"unavailable_flag"]
	data.fresh_events = [data.fresh_events[1]]
	manager = _manager(data)
	_check(manager.run_state.floor_state.current_event == null and manager.run_state.floor_state.remaining_fresh_events.size() == 1, "Scheduling filters an ineligible Situation without discarding it")
	var before: Dictionary = _snapshot(manager)
	_reject(_play(manager), &"invalid_event_target", manager, before)
	manager.free()
	manager = _manager()
	manager.run_state.floor_state.cognition = 5
	_play(manager)
	var completed: ActionResult = _play(manager, SEARCH)
	_check(completed.cognition_delta == 0 and manager.run_state.cognition == 5 and manager.run_state.floor_state.discovered_insight_ids.size() == 1, "Completion records unique knowledge at the Cognition cap without exceeding five")
	manager.free()


func _test_transactional_failures() -> void:
	var manager: TurnManager = _manager()
	var state: RunState = manager.run_state
	var floor: FloorState = state.floor_state
	var card: CardInstance = state.deck_state.hand[0]
	var before: Dictionary = _snapshot(manager)
	_reject(RuleResolver.resolve(null, state, manager.card_system, LEVEL_0), &"invalid_command", manager, before)
	_reject(manager.request_play_card(CardInstance.new(OBSERVE), floor.current_event, floor.board_state), &"card_not_in_hand", manager, before)
	_reject(manager.request_play_card(card), &"invalid_event_target", manager, before)
	_reject(manager.request_play_card(card, EventInstance.new(floor.current_event_id), floor.board_state), &"invalid_event_target", manager, before)
	_reject(manager.request_play_card(card, floor.current_event, BoardState.new()), &"invalid_event_target", manager, before)
	var wrong_floor: FloorData = _fixture()
	wrong_floor.id = &"floor_other_visit"
	_reject(RuleResolver.resolve(PlayCardCommand.new(card, floor.current_event, floor.board_state), state, manager.card_system, wrong_floor), &"invalid_floor_context", manager, before)
	var other: TurnManager = _manager()
	_reject(manager.request_play_card(card, other.run_state.floor_state.current_event, other.run_state.floor_state.board_state), &"invalid_event_target", manager, before)
	_check(other.run_state.ap == 3 and other.run_state.floor_state.current_event.explore_progress == 0, "Cross-run target rejection does not mutate the other board")
	other.free()
	state.ap = 0
	before = _snapshot(manager)
	_reject(_play(manager), &"insufficient_ap", manager, before)
	manager.free()
	for invalid_case: String in ["card_explore", "card_risk", "threshold", "clue", "pressure", "bonus", "insight", "progress", "clue_state", "future_pressure"]:
		var data: FloorData = _fixture()
		var definition: CardData = OBSERVE.duplicate(false) as CardData
		manager = _manager(data, [definition])
		var expected: StringName = &"invalid_event_definition"
		match invalid_case:
			"card_explore":
				definition.explore_amount = -1
				expected = &"invalid_card_definition"
			"card_risk":
				definition.threat_cost = -1
				expected = &"invalid_card_definition"
			"threshold":
				data.fresh_events[0].explore_threshold = 0
			"clue":
				data.fresh_events[0].clue_threshold = 7
			"pressure":
				data.fresh_events[0].neglect_stress = -1
			"bonus":
				data.fresh_events[0].bonus_tag = &""
			"insight":
				data.fresh_events[0].completion_insight.id = &""
				expected = &"invalid_insight_definition"
			"progress":
				manager.run_state.floor_state.current_event.explore_progress = 7
				expected = &"invalid_event_state"
			"clue_state":
				manager.run_state.floor_state.current_event.clue_revealed = true
				expected = &"invalid_event_state"
			"future_pressure":
				manager.run_state.floor_state.current_event.pressure_checked_turn = 2
				expected = &"invalid_event_state"
		before = _snapshot(manager)
		_reject(_play(manager, definition), expected, manager, before)
		if expected != &"invalid_card_definition":
			_reject(manager.end_turn(), expected, manager, before)
		manager.free()
	_check(OBSERVE.explore_amount == 2 and LEVEL_0.fresh_events[0].explore_threshold == 6 and LEVEL_0.fresh_events[0].completion_insight.id != &"", "Malformed fixtures never corrupt shared authoring Resources")


func _test_old_command_rejection() -> void:
	var manager: TurnManager = _manager()
	for action: StringName in [&"inspect", &"search_nearby", &"observe", &"deep_search", &"search", &"explore"]:
		var before: Dictionary = _snapshot(manager)
		_reject(manager.request_exploration(action), &"card_required", manager, before)
	_check(manager.run_state.ap == 3 and manager.run_state.floor_state.current_event.explore_progress == 0, "Standalone old exploration APIs cannot bypass Player Cards")
	manager.free()


func _test_main_ui() -> void:
	var main: Control = MAIN.instantiate() as Control
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
	_check((main.get_node("%SituationState") as Label).text.contains("已解决") and manager.run_state.cognition == 1, "Resolved state is visible before the next turn")
	(main.get_node("%EndTurn") as Button).pressed.emit()
	_check(hand.get_child_count() == 5 and (main.get_node("%Objective") as Label).text.contains("0／6") and manager.run_state.turn_number == 2, "Existing End Turn draws from the same deck and supplies next Situation")
	await process_frame
	await process_frame
	var viewport: Rect2 = main.get_viewport_rect()
	_check(viewport.encloses(world.get_global_rect()) and viewport.encloses(hand.get_global_rect()) and viewport.encloses((main.get_node("%EndTurn") as Button).get_global_rect()), "World Card, hand and End Turn remain inside the viewport")
	_check(world.get_global_rect().end.y <= hand.get_global_rect().position.y, "Card-game layout puts the World Card above the player's hand without overlap")
	_check(world.get_global_rect().encloses((main.get_node("%SituationState") as Label).get_global_rect()), "World Card contains the last state label without clipping its information")
	_check_chinese_ui(main)
	# 真正主场景的完整有限流程，不修改进度、AP 或领域实例来跳过玩法。
	var state: RunState = manager.run_state
	var deck: DeckState = state.deck_state
	var floor: FloorState = state.floor_state
	for turn: int in range(10):
		if floor.current_event == null:
			break
		for action: int in range(5):
			if floor.current_event.resolved:
				break
			var playable: int = -1
			for index: int in range(deck.hand.size()):
				if deck.hand[index].definition.ap_cost <= state.ap:
					playable = index
					break
			if playable < 0:
				break
			(hand.get_child(playable) as Button).pressed.emit()
		(main.get_node("%EndTurn") as Button).pressed.emit()
	_check(floor.current_event == null and floor.seen_event_ids.size() == 3 and state.cognition == 3, "Real main-screen hand/turn controls can finish all three unique Situations")
	_check(manager.run_state == state and state.floor_state == floor and state.deck_state == deck and deck.get_card_count() == 10, "Complete exploration preserves one Run, Floor, deck and card inventory")
	_check((main.get_node("%SituationName") as Label).text.contains("调查完毕") and hand.get_children().all(func(node: Node) -> bool: return (node as Button).disabled), "Fresh exhaustion is explicit rather than allowing successful Explore no-ops")
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
	var event: EventInstance = floor.current_event
	var cards: Array = []
	for pile: Array[CardInstance] in [run.deck_state.hand, run.deck_state.draw_pile, run.deck_state.discard_pile]:
		var values: Array = []
		for card: CardInstance in pile:
			var data: CardData = card.definition
			values.append([card.get_instance_id(), data.get_instance_id(), data.id, data.display_name, data.ap_cost, data.explore_amount, data.threat_cost, data.tags.duplicate()])
		cards.append(values)
	var definitions: Array = []
	for data: EventData in manager.floor_data.fresh_events:
		definitions.append([data.get_instance_id(), data.id, data.display_name, data.explore_threshold, data.clue_threshold, data.clue_text, data.neglect_stress, data.bonus_tag, data.explore_bonus, data.completion_insight.get_instance_id(), data.completion_insight.id, data.completion_insight.cutout_stability, data.completion_insight.cutout_knowledge])
	var resources: Array = []
	for node: ResourceNode in floor.resource_nodes:
		resources.append([node.get_instance_id(), node.node_id, node.status])
	var equipment: Array = []
	for item: EquipmentInstance in run.equipment_slots:
		equipment.append([item.get_instance_id(), item.remaining_uses, item.definition.get_instance_id(), item.definition.capacity] if item != null else [])
	return {
		"hp": run.player_hp, "stress": run.stress, "supply": run.supply, "ap": run.ap, "turn": run.turn_number,
		"floor": floor.get_instance_id(), "board": floor.board_state.get_instance_id(), "deck": run.deck_state.get_instance_id(),
		"rng": run.rng.state, "cards": cards, "definitions": definitions, "floor_turn": floor.turn_count,
		"event": [event.get_instance_id(), event.event_id, event.explore_progress, event.clue_revealed, event.resolved, event.last_progress_turn, event.pressure_checked_turn, event.known_information.duplicate()] if event != null else [],
		"fresh": floor.remaining_fresh_events.duplicate(), "seen": floor.seen_event_ids.duplicate(),
		"flags": floor.floor_flags.duplicate(), "insights": floor.discovered_insight_ids.duplicate(),
		"threat": floor.threat, "cognition": floor.cognition, "stability": floor.cutout_state.stability,
		"knowledge": floor.cutout_state.destination_knowledge, "resources": resources, "equipment": equipment,
	}


func _reject(result: ActionResult, reason: StringName, manager: TurnManager, before: Dictionary) -> void:
	_check(not result.success and result.failure_reason == reason, "Expected command rejection: %s" % reason)
	_check(_snapshot(manager) == before, "Failed command changes no AP, cards, Explore, Pressure, Threat, milestones, Insight, definitions, preparation or RNG")
	_check(result.ap_spent == 0 and result.card_played == null and result.event_target == null and result.explore_applied == 0 and not result.clue_revealed and not result.event_resolved and result.insight_ids.is_empty() and result.threat_delta == 0 and result.pressure_stress == 0, "Failed ActionResult has no partial gameplay effects")


func _check(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		push_error("[TEST] %s" % message)
