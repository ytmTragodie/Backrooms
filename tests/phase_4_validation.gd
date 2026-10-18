extends SceneTree

const LEVEL_0: FloorData = preload("res://data/floors/floor_level_0_legacy.tres")
const MAIN_SCENE: PackedScene = preload("res://scenes/main/LegacyMain.tscn")
const OBSERVE: CardData = preload("res://data/cards/card_observe.tres")
const DEEP_SEARCH: CardData = preload("res://data/cards/card_deep_search.tres")
const WAIT: CardData = preload("res://data/cards/card_wait.tres")

var _checks: int = 0
var _failures: int = 0


func _initialize() -> void:
	call_deferred("_run_validation")


func _run_validation() -> void:
	_test_floor_instances()
	_test_fresh_events_and_conditions()
	_test_scene_interactions()
	_test_event_snapshot_values()
	_test_insight_confirmation()
	_test_alternate_paths_and_cap()
	_test_threat_and_turns()
	_test_transactional_failures()
	_test_notifications_and_exhaustion()
	await _test_debug_ui()
	await process_frame
	if _failures == 0:
		print("[TEST] PASS Phase 4: %d checks (floors, events, insights, threat, transactions, RNG, UI)" % _checks)
	else:
		push_error("[TEST] FAIL Phase 4: %d of %d checks failed" % [_failures, _checks])
	quit(0 if _failures == 0 else 1)


func _manager(data: FloorData = LEVEL_0) -> TurnManager:
	var manager: TurnManager = TurnManager.new()
	manager.floor_data = data
	# 五张固定夹具保证跨回合总能抽到两种调查牌，不依赖随机碰巧抽中。
	manager.starter_deck = DeckData.new()
	manager.starter_deck.cards = [OBSERVE, OBSERVE, OBSERVE, DEEP_SEARCH, WAIT]
	root.add_child(manager)
	return manager


func _play_action(manager: TurnManager, action: StringName) -> ActionResult:
	for card: CardInstance in manager.run_state.deck_state.hand:
		if card.definition.exploration_action == action:
			return manager.request_play_card(card)
	_check(false, "Fixture must contain requested card in hand: %s" % action)
	return manager.request_play_card(null)


func _floor_fixture() -> FloorData:
	# Resource 数组中的嵌套对象可能仍共享；坏数据夹具显式逐层复制，避免污染正式内容。
	var data: FloorData = LEVEL_0.duplicate(false) as FloorData
	data.fresh_events = []
	for original_event: EventData in LEVEL_0.fresh_events:
		var event: EventData = original_event.duplicate(false) as EventData
		event.action_results = []
		for original_rule: EventActionData in original_event.action_results:
			var rule: EventActionData = original_rule.duplicate(false) as EventActionData
			if original_rule.insight != null:
				rule.insight = original_rule.insight.duplicate(false) as InsightData
			event.action_results.append(rule)
		data.fresh_events.append(event)
	return data


func _test_floor_instances() -> void:
	var first: FloorState = FloorState.new(LEVEL_0)
	var second: FloorState = FloorState.new(LEVEL_0)
	_check(first != second and first.floor_id == &"floor_level_0", "Each visit creates a new Level 0 FloorState")
	_check(first.threat == 0 and first.cognition == 0 and first.turn_count == 1, "Floor starts at Threat 0, Cognition 0, turn 1")
	_check(first.remaining_fresh_events.size() == 3 and first.discovered_insight_ids.is_empty(), "New floor has three Fresh Events and no Insights")
	first.floor_flags.append(&"fixture_flag")
	first.remaining_fresh_events.pop_front()
	first.discovered_insight_ids.append(&"insight_level0_hum_changes")
	first.cognition = 1
	_check(second.floor_flags.is_empty() and second.remaining_fresh_events.size() == 3 and second.cognition == 0, "Floor instances never share mutable lists or values")
	_check(LEVEL_0.fresh_events.size() == 3, "Runtime removal never mutates FloorData")
	var manager: TurnManager = _manager()
	_check(manager.run_state.floor_state != first and manager.run_state.floor_state.current_event_id != &"", "Floor startup creates state and reveals a Fresh Event")
	_check(manager.run_state.threat == manager.run_state.floor_state.threat and manager.run_state.cognition == manager.run_state.floor_state.cognition, "Legacy reads forward to the authoritative floor values")
	manager.free()


func _event_order(seed_value: int) -> Array[StringName]:
	var floor: FloorState = FloorState.new(LEVEL_0)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	var order: Array[StringName] = []
	for index: int in range(3):
		var event_id: StringName = EventSystem.draw_fresh(LEVEL_0, floor, rng)
		_check(not event_id.is_empty() and not order.has(event_id), "Fresh Events never repeat")
		order.append(event_id)
		floor.current_event.resolved = true
	var rng_before: int = rng.state
	_check(EventSystem.draw_fresh(LEVEL_0, floor, rng).is_empty(), "Exhausted Fresh pool produces no fake Residual Event")
	_check(floor.remaining_fresh_events.is_empty() and floor.seen_event_ids.size() == 3, "Fresh removal and history agree")
	_check(rng.state == rng_before, "Exhaustion does not consume RNG")
	return order


func _test_fresh_events_and_conditions() -> void:
	_check(_event_order(404) == _event_order(404), "Fixed run seed reproduces Fresh Event order")
	var data: FloorData = _floor_fixture()
	data.fresh_events[0].required_flags = [&"ready"]
	data.fresh_events[1].blocked_flags = [&"blocked"]
	data.fresh_events[2].required_flags = [&"ready"]
	var floor: FloorState = FloorState.new(data)
	floor.floor_flags.append(&"blocked")
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 405
	var rng_before: int = rng.state
	_check(EventSystem.draw_fresh(data, floor, rng).is_empty(), "Required and blocked conditions filter invalid events")
	_check(floor.remaining_fresh_events.size() == 3 and rng.state == rng_before, "Ineligible events remain available for a later valid state")
	floor.floor_flags.append(&"ready")
	var selected: StringName = EventSystem.draw_fresh(data, floor, rng)
	_check(selected != data.fresh_events[1].id and not selected.is_empty(), "Only condition-valid candidates enter weighted selection")
	floor.floor_flags.erase(&"blocked")
	floor.current_event.resolved = true
	var remaining: Array[StringName] = []
	for index: int in range(2):
		remaining.append(EventSystem.draw_fresh(data, floor, rng))
		floor.current_event.resolved = true
	_check(remaining.has(data.fresh_events[1].id), "A previously blocked event becomes selectable when its condition changes")
	_check(LEVEL_0.fresh_events[0].required_flags.is_empty() and LEVEL_0.fresh_events[1].blocked_flags.is_empty(), "Condition fixtures leave shared event Resources unchanged")


func _test_scene_interactions() -> void:
	var manager: TurnManager = _manager()
	var state: RunState = manager.run_state
	var floor: FloorState = state.floor_state
	var instance: EventInstance = floor.current_event
	var cards_before: Array = _snapshot(manager)["cards"]
	_check(instance.phase == &"unresolved" and instance.can_interact(&"inspect"), "Event starts unresolved with available basic interactions")
	var inspect: ActionResult = manager.request_exploration(&"inspect")
	_check(inspect.success and inspect.ap_spent == 1 and state.ap == 2, "Inspect costs 1 AP")
	_check(floor.cognition == 0 and floor.threat == 0 and inspect.insight_ids.is_empty(), "Basic inspection provides evidence without Insight or Threat")
	_check(instance.phase == &"partially_explored" and instance.completed_interactions == [&"inspect"] and not instance.known_information.is_empty(), "Inspection records instance progress and revealed information")
	_check(not instance.can_interact(&"inspect") and instance.can_interact(&"search_nearby"), "Only unused basic interaction remains available")
	_check(_snapshot(manager)["cards"] == cards_before, "Basic interactions never create cards or enter any pile")
	var before_failure: Dictionary = _snapshot(manager)
	_check_failure(manager.request_exploration(&"inspect"), &"interaction_used", manager, before_failure)
	var event_rng: int = state.rng.state
	var remaining_before: Array[StringName] = floor.remaining_fresh_events.duplicate()
	_check(EventSystem.draw_fresh(LEVEL_0, floor, state.rng) == instance.event_id and state.rng.state == event_rng, "Attempting another draw cannot replace an unresolved event or consume RNG")
	manager.end_turn()
	_check(floor.current_event == instance and floor.remaining_fresh_events == remaining_before, "An unresolved event survives End Turn without consuming another Fresh Event")
	_check(not instance.can_interact(&"inspect"), "End Turn does not refresh an already used basic interaction")
	var search: ActionResult = manager.request_exploration(&"search_nearby")
	_check(search.success and search.ap_spent == 1 and state.ap == 2, "Search Nearby also costs 1 AP")
	_check(floor.cognition == 0 and floor.threat == 0 and search.insight_ids.is_empty(), "Normal search does not guarantee an Insight")
	_check(instance.resolved and instance.phase == &"resolved" and search.event_resolved, "Using both basic interactions can resolve the prototype event")
	_check(instance.known_information.size() == 2, "Both basic interactions reveal their distinct partial information")
	_check(not instance.can_interact(&"inspect") and not instance.can_interact(&"search_nearby"), "Resolved event exposes no reusable basic interactions")
	before_failure = _snapshot(manager)
	_check_failure(manager.request_exploration(&"search_nearby"), &"interaction_used", manager, before_failure)
	manager.end_turn()
	_check(floor.current_event != instance and floor.current_event_id != instance.event_id, "A resolved event advances only at the next turn start")
	_check(floor.current_event.phase == &"unresolved" and floor.current_event.completed_interactions.is_empty(), "The next event owns fresh independent runtime progress")
	manager.free()


func _test_insight_confirmation() -> void:
	var manager: TurnManager = _manager()
	var state: RunState = manager.run_state
	var floor: FloorState = state.floor_state
	var before_failure: Dictionary = _snapshot(manager)
	_check_failure(manager.request_play_card(CardInstance.new(OBSERVE)), &"card_not_in_hand", manager, before_failure)
	var first: ActionResult = _play_action(manager, &"observe")
	_check(first.success and first.ap_spent == 1 and state.ap == 2, "Observe card uses the CardData AP cost")
	_check(floor.cognition == 0 and first.insight_ids.is_empty() and floor.floor_flags.size() == 1, "First Observe records evidence without automatic Cognition")
	_check(floor.threat == 0 and first.threat_delta == 0, "Low-risk Observe adds zero Threat")
	_check(not state.deck_state.hand.has(first.card_played) and state.deck_state.discard_pile.has(first.card_played), "Observe must leave hand and enter discard")
	var second: ActionResult = _play_action(manager, &"observe")
	_check(second.success and second.cognition_delta == 1 and floor.cognition == 1, "Verifying an event's evidence confirms exactly one Insight")
	_check(second.insight_ids.size() == 1 and floor.discovered_insight_ids == second.insight_ids, "Result records the unique confirmed Insight ID")
	_check(floor.current_event.resolved and second.event_resolved, "Enhanced observation resolves the event on confirmation")
	var third: ActionResult = _play_action(manager, &"observe")
	_check(third.success and third.cognition_delta == 0 and floor.cognition == 1 and floor.discovered_insight_ids.size() == 1, "Repeated confirmation never adds Cognition twice")
	# 测试夹具恢复 AP，继续验证同一事件的另一发现路径不会重复发奖。
	state.ap = 3
	var search: ActionResult = _play_action(manager, &"deep_search")
	_check(search.success and search.insight_ids.is_empty() and floor.cognition == 1, "Deep Search rediscovers the same ID without duplicate Cognition")
	_check(search.threat_delta == 1 and floor.threat == 1 and state.ap == 1, "Deep Search costs 2 AP and adds 1 Threat")
	_check(search.threat_reason == &"deep_search" and _has_trace(search, "[THREAT] +1 reason=deep_search total=1"), "Threat result and log carry the action reason")
	_check(search.card_played.definition == DEEP_SEARCH and state.deck_state.discard_pile.has(search.card_played), "Deep Search is a real played card with normal discard lifecycle")
	before_failure = _snapshot(manager)
	_check_failure(manager.request_play_card(search.card_played), &"card_not_in_hand", manager, before_failure)
	manager.free()
	# 两种基础线索都可交给观察牌验证；基础交互本身不直接发认知奖励。
	for basic_action: StringName in [&"inspect", &"search_nearby"]:
		manager = _manager()
		manager.request_exploration(basic_action)
		var verification: ActionResult = _play_action(manager, &"observe")
		_check(verification.cognition_delta == 1 and manager.run_state.ap == 1, "Observe enhances either basic clue into a unique confirmed Insight")
		_check(manager.run_state.floor_state.current_event.resolved, "Basic clue plus enhanced card resolves the event")
		var unused: StringName = &"search_nearby" if basic_action == &"inspect" else &"inspect"
		before_failure = _snapshot(manager)
		_check_failure(manager.request_exploration(unused), &"event_resolved", manager, before_failure)
		manager.free()


func _test_event_snapshot_values() -> void:
	var manager: TurnManager = _manager()
	var instance: EventInstance = manager.run_state.floor_state.current_event
	var before: Dictionary = _snapshot(manager)
	instance.completed_interactions.append(&"inspect")
	_check(_snapshot(manager) != before and before["interactions"].is_empty(), "Failure snapshots copy interaction values rather than sharing the live array")
	instance.completed_interactions.clear()
	instance.known_information.append("夹具线索")
	_check(_snapshot(manager) != before and before["information"].is_empty(), "Failure snapshots detect information changes without changing the original snapshot")
	instance.known_information.clear()
	instance.resolved = true
	_check(_snapshot(manager) != before and not before["resolved"], "Failure snapshots detect event resolution changes")
	manager.free()


func _test_alternate_paths_and_cap() -> void:
	var data: FloorData = _floor_fixture()
	var shared_insight: InsightData = data.fresh_events[0].action_results[2].insight
	for event: EventData in data.fresh_events:
		event.action_results[2].insight = shared_insight
	var manager: TurnManager = _manager(data)
	var first: ActionResult = _play_action(manager, &"deep_search")
	manager.end_turn()
	var second: ActionResult = _play_action(manager, &"deep_search")
	_check(first.event_id != second.event_id and first.cognition_delta == 1 and second.cognition_delta == 0, "Different events can target one Insight without duplicate rewards")
	_check(manager.run_state.floor_state.discovered_insight_ids.size() == 1, "Cross-event discovery is deduplicated by stable Insight ID")
	manager.free()
	manager = _manager()
	var floor: FloorState = manager.run_state.floor_state
	# 当前原型只有三个 Insight；从 4 起步的夹具验证通用上限，不添加新内容。
	floor.cognition = 4
	var fifth: ActionResult = _play_action(manager, &"deep_search")
	_check(fifth.cognition_delta == 1 and floor.cognition == 5, "Unique confirmation can reach Cognition 5")
	manager.end_turn()
	var capped: ActionResult = _play_action(manager, &"deep_search")
	_check(capped.insight_ids.size() == 1 and capped.cognition_delta == 0 and floor.cognition == 5, "Additional unique Insight is recorded but cannot exceed Cognition 5")
	if not capped.insight_ids.is_empty():
		_check(InsightSystem.confirm(floor, capped.insight_ids[0]) == 0 and floor.cognition == 5, "InsightSystem also rejects duplicate confirmation at the cap")
	_check(InsightSystem.confirm(floor, &"") == 0, "Empty Insight IDs cannot grant Cognition")
	manager.free()


func _test_threat_and_turns() -> void:
	var manager: TurnManager = _manager()
	for ended_turn: int in range(1, 7):
		var before: int = manager.run_state.floor_state.threat
		var result: ActionResult = manager.end_turn()
		var expected_delta: int = 1 if ended_turn == 3 or ended_turn == 5 else 0
		_check(result.success and result.threat_delta == expected_delta, "Overstay applies only at the end of floor turns 3, 5, 7...")
		_check(manager.run_state.floor_state.threat == before + expected_delta, "Overstay commits the reported Threat exactly once")
		_check(manager.run_state.floor_state.turn_count == ended_turn + 1 and manager.run_state.turn_number == ended_turn + 1, "TurnManager advances floor and run lifecycle")
		_check(manager.run_state.ap == 3 and manager.run_state.deck_state.hand.size() == 5, "End Turn still restores AP and draws to 5")
		if expected_delta > 0:
			_check(result.threat_reason == &"overstay" and _has_trace(result, "reason=overstay"), "Overstay Threat includes a reason")
		else:
			_check(result.threat_reason.is_empty(), "No implicit Threat is hidden in other turns")
	manager.run_state.floor_state.threat = 10
	var capped: ActionResult = _play_action(manager, &"deep_search")
	_check(capped.success and capped.threat_delta == 0 and manager.run_state.floor_state.threat == 10, "Threat cannot exceed the GDD limit of 10")
	_check(capped.threat_reason == &"deep_search" and _has_trace(capped, "reason=deep_search total=10"), "A capped Threat request still records its reason")
	manager.free()


func _test_transactional_failures() -> void:
	var manager: TurnManager = _manager()
	manager.run_state.ap = 0
	var before: Dictionary = _snapshot(manager)
	_check_failure(_play_action(manager, &"deep_search"), &"insufficient_ap", manager, before)
	_check_failure(manager.request_exploration(&"inspect"), &"insufficient_ap", manager, before)
	_check_failure(manager.request_play_card(manager.run_state.deck_state.hand[0]), &"insufficient_ap", manager, before)
	manager.run_state.ap = 3
	before = _snapshot(manager)
	_check_failure(manager.request_exploration(&"unknown_action"), &"unknown_action", manager, before)
	_check_failure(manager.request_exploration(&"observe"), &"unknown_action", manager, before)
	_check_failure(manager.request_exploration(&"deep_search"), &"unknown_action", manager, before)
	_check_failure(RuleResolver.resolve_exploration(null, manager.run_state, LEVEL_0), &"invalid_command", manager, before)
	var mismatched: FloorData = _floor_fixture()
	mismatched.id = &"invalid_floor_fixture"
	_check_failure(RuleResolver.resolve_exploration(ExplorationCommand.new(&"inspect"), manager.run_state, mismatched), &"invalid_floor_context", manager, before)
	manager.free()
	# 无效事件内容必须在扣 AP、记录旗标和确认 Insight 之前被拒绝。
	var data: FloorData = _floor_fixture()
	manager = _manager(data)
	var event: EventData = data.find_event(manager.run_state.floor_state.current_event_id)
	event.action_results[2].insight.id = &""
	before = _snapshot(manager)
	_check_failure(_play_action(manager, &"deep_search"), &"invalid_insight_definition", manager, before)
	manager.free()
	data = _floor_fixture()
	manager = _manager(data)
	event = data.find_event(manager.run_state.floor_state.current_event_id)
	event.action_results.append(null)
	before = _snapshot(manager)
	_check_failure(manager.request_exploration(&"inspect"), &"invalid_event_definition", manager, before)
	_check_failure(_play_action(manager, &"observe"), &"invalid_event_definition", manager, before)
	manager.free()
	data = _floor_fixture()
	manager = _manager(data)
	data.overstay_interval = 0
	before = _snapshot(manager)
	_check_failure(manager.end_turn(), &"invalid_floor_definition", manager, before)
	manager.free()
	for original_event: EventData in LEVEL_0.fresh_events:
		_check(not original_event.action_results[2].insight.id.is_empty(), "Malformed nested fixtures never corrupt original Insight Resources")


func _test_notifications_and_exhaustion() -> void:
	var manager: TurnManager = _manager()
	var observations: Array[Dictionary] = []
	manager.state_changed.connect(func() -> void: observations.append(_snapshot(manager)))
	var result: ActionResult = _play_action(manager, &"deep_search")
	_check(observations.size() == 1 and observations[0] == _snapshot(manager), "UI notification observes the complete AP/card/event/Insight/Threat commit")
	_check(result.cognition_delta == 1 and result.threat_delta == 1 and result.ap_spent == 2 and result.event_resolved, "One card result describes all committed changes")
	var before_failure: Dictionary = _snapshot(manager)
	_check_failure(manager.request_play_card(result.card_played), &"card_not_in_hand", manager, before_failure)
	_check(observations.size() == 1, "Failed card play emits no state-change notification")
	for index: int in range(3):
		manager.end_turn()
		if index < 2:
			_play_action(manager, &"deep_search")
	_check(manager.run_state.floor_state.current_event_id.is_empty() and manager.run_state.floor_state.remaining_fresh_events.is_empty(), "Three resolved Fresh Events are exhausted without recycling")
	var before_cognition: int = manager.run_state.floor_state.cognition
	var observe: ActionResult = _play_action(manager, &"observe")
	_check(observe.success and observe.insight_ids.is_empty() and manager.run_state.floor_state.cognition == before_cognition, "Observe without a current clue cannot farm Cognition")
	before_failure = _snapshot(manager)
	_check_failure(manager.request_exploration(&"inspect"), &"interaction_unavailable", manager, before_failure)
	_check_failure(manager.request_exploration(&"search_nearby"), &"interaction_unavailable", manager, before_failure)
	manager.free()


func _test_debug_ui() -> void:
	var main: Control = MAIN_SCENE.instantiate() as Control
	var manager: TurnManager = main.get_node("TurnManager") as TurnManager
	# 保留九张探索牌夹具，避免 Phase 6 新增牌序改变早期探索路径断言。
	manager.starter_deck = preload("res://data/cards/starter_deck.tres")
	root.add_child(main)
	var info: Label = main.get_node("FloorMargin/FloorTabs/FloorPanel/FloorInfo") as Label
	var event_info: Label = main.get_node("FloorMargin/FloorTabs/FloorPanel/EventInfo") as Label
	var insights: Label = main.get_node("FloorMargin/FloorTabs/FloorPanel/InsightList") as Label
	var inspect: Button = main.get_node("FloorMargin/FloorTabs/FloorPanel/InspectAction") as Button
	var search: Button = main.get_node("FloorMargin/FloorTabs/FloorPanel/SearchNearbyAction") as Button
	var end_turn: Button = main.get_node("CenterContainer/Messages/EndTurn") as Button
	var hand: VBoxContainer = main.get_node("CenterContainer/Messages/Hand") as VBoxContainer
	var status: Label = main.get_node("CenterContainer/Messages/Status") as Label
	_check(info.text.contains("当前楼层：零层") and info.text.contains("楼层回合：1"), "UI displays the Chinese floor name and floor turn")
	var event: EventData = LEVEL_0.find_event(manager.run_state.floor_state.current_event_id)
	_check(event_info.text.contains(event.display_name) and not event_info.text.contains(String(event.id)), "UI displays the event name rather than its internal ID")
	_check(hand.get_child_count() == 5 and not hand.is_ancestor_of(inspect) and not hand.is_ancestor_of(search), "Basic interaction buttons are separate from the real hand")
	_check(main.find_child("ObserveAction", true, false) == null and main.find_child("DeepSearchAction", true, false) == null, "Permanent Observe and Deep Search buttons have been removed")
	var before_cards: Array = _snapshot(manager)["cards"]
	inspect.pressed.emit()
	_check(manager.run_state.floor_state.cognition == 0 and manager.run_state.ap == 2, "Inspect button forwards a basic evidence request")
	_check(inspect.disabled and not search.disabled and inspect.text.contains("已完成"), "Used basic interaction disables and changes its label")
	_check(_snapshot(manager)["cards"] == before_cards and hand.get_child_count() == 5, "Scene buttons never alter hand or piles")
	var before_failure: Dictionary = _snapshot(manager)
	inspect.pressed.emit()
	_check(_snapshot(manager) == before_failure and status.text == "行动失败：本次事件中已完成此交互。", "Bypassing a disabled button is still rejected without mutation")
	_press_card(manager, hand, &"observe")
	_check(manager.run_state.floor_state.cognition == 1 and manager.run_state.ap == 1 and hand.get_child_count() == 4, "Observe card verifies the basic clue and leaves hand")
	_check(search.disabled and event_info.text.contains("已解决"), "Resolved event disables all basic interactions")
	var discovered: StringName = manager.run_state.floor_state.discovered_insight_ids[0]
	_check(insights.text.contains(LEVEL_0.find_insight(discovered).display_name) and not insights.text.contains(String(discovered)), "Insight list shows Chinese names and hides IDs")
	before_failure = _snapshot(manager)
	_press_card(manager, hand, &"deep_search")
	_check(_snapshot(manager) == before_failure and status.text == "行动失败：行动点不足。", "Unaffordable Deep Search card preserves cards, AP and event state")
	_check_chinese_ui(main)
	end_turn.pressed.emit()
	_press_card(manager, hand, &"deep_search")
	_check(manager.run_state.floor_state.threat == 1 and manager.run_state.ap == 1 and info.text.contains("威胁：1"), "Real Deep Search card spends 2 AP and adds 1 Threat")
	_check(manager.run_state.floor_state.cognition == 2 and hand.get_child_count() == 4, "Advanced search confirms a new unique Insight and leaves hand")
	_check_chinese_ui(main)
	end_turn.pressed.emit()
	inspect.pressed.emit()
	search.pressed.emit()
	end_turn.pressed.emit()
	_check(event_info.text.contains("新鲜事件已耗尽"), "UI clearly reports Fresh exhaustion in Chinese")
	_check(inspect.disabled and search.disabled, "No event means no available scene interactions")
	_check_chinese_ui(main)
	# 错误码只在技术日志出现；所有已知失败路径均有中文玩家反馈。
	for reason: StringName in main.FAILURE_MESSAGES:
		var failed: ActionResult = ActionResult.new()
		failed.failure_reason = reason
		main._on_action_resolved(failed)
		_check_chinese_text(status.text)
	_check(ProjectSettings.get_setting("application/config/name") == "后室：切出 Demo", "Application title is Chinese")
	_check(OBSERVE.id == &"card_observe" and DEEP_SEARCH.id == &"card_deep_search" and LEVEL_0.id == &"floor_level_0", "Display translation preserves stable content IDs")
	for definition: EventData in LEVEL_0.fresh_events:
		_check(String(definition.id).begins_with("event_level0_") and definition.has_action(&"inspect") and definition.has_action(&"search_nearby"), "Existing stable event IDs expose data-defined basic interactions")
		for rule: EventActionData in definition.action_results:
			if rule.insight != null:
				_check(String(rule.insight.id).begins_with("insight_level0_"), "Stable Insight IDs remain English")
	await process_frame
	await process_frame
	var viewport_rect: Rect2 = main.get_viewport_rect()
	_check(viewport_rect.encloses(search.get_global_rect()) and viewport_rect.encloses(end_turn.get_global_rect()), "Both debug action panels remain inside the viewport")
	main.free()


func _press_card(manager: TurnManager, hand: VBoxContainer, action: StringName) -> void:
	for index: int in range(manager.run_state.deck_state.hand.size()):
		if manager.run_state.deck_state.hand[index].definition.exploration_action == action:
			var button: Button = hand.get_child(index) as Button
			button.pressed.emit()
			return
	_check(false, "UI fixture must have requested card in hand")


func _check_chinese_ui(node: Node) -> void:
	if node is Label:
		_check_chinese_text((node as Label).text)
	elif node is Button:
		_check_chinese_text((node as Button).text)
	for child: Node in node.get_children():
		_check_chinese_ui(child)


func _check_chinese_text(value: String) -> void:
	var latin: RegEx = RegEx.create_from_string("[A-Za-z_]")
	_check(latin.search(value.replace("Demo", "")) == null, "Player-facing text is Chinese with no raw technical IDs: %s" % value)


func _snapshot(manager: TurnManager) -> Dictionary:
	var state: RunState = manager.run_state
	var floor: FloorState = state.floor_state
	var card_locations: Array = []
	for pile: Array[CardInstance] in [state.deck_state.draw_pile, state.deck_state.hand, state.deck_state.discard_pile]:
		var entries: Array = []
		for card: CardInstance in pile:
			entries.append([card.get_instance_id(), card.definition.get_instance_id(), card.definition.id, card.definition.ap_cost, card.definition.effect_type, card.definition.placeholder_damage, card.definition.exploration_action])
		card_locations.append(entries)
	return {
		"hp": state.player_hp, "stress": state.stress, "ap": state.ap, "turn": state.turn_number,
		"rng_state": state.rng.state, "floor_id": floor.floor_id, "floor_turn": floor.turn_count,
		"threat": floor.threat, "cognition": floor.cognition,
		"flags": floor.floor_flags.duplicate(), "insights": floor.discovered_insight_ids.duplicate(),
		"remaining": floor.remaining_fresh_events.duplicate(), "seen": floor.seen_event_ids.duplicate(),
		"event": floor.current_event_id, "cards": card_locations,
		"event_identity": floor.current_event.get_instance_id() if floor.current_event != null else 0,
		"interactions": floor.current_event.completed_interactions.duplicate() if floor.current_event != null else [],
		"information": floor.current_event.known_information.duplicate() if floor.current_event != null else [],
		"resolved": floor.current_event.resolved if floor.current_event != null else false,
	}


func _check_failure(result: ActionResult, reason: StringName, manager: TurnManager, before: Dictionary) -> void:
	_check(not result.success and result.failure_reason == reason, "Invalid exploration returns the expected failure: %s" % reason)
	_check(result.ap_spent == 0 and result.threat_delta == 0 and result.cognition_delta == 0 and result.insight_ids.is_empty() and result.floor_flags_added.is_empty() and result.event_interaction.is_empty() and result.event_information.is_empty() and not result.event_resolved, "Failed result reports no AP, Threat, Cognition, Insight or flag effect")
	_check(_snapshot(manager) == before, "Failed action preserves cards, AP, floor flags, Insights, events and RNG")


func _has_trace(result: ActionResult, fragment: String) -> bool:
	for line: String in result.debug_lines:
		if line.contains(fragment):
			return true
	return false


func _check(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		push_error("[TEST] %s" % message)
