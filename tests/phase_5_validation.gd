extends SceneTree

const LEVEL_0: FloorData = preload("res://data/floors/floor_level_0.tres")
const OBSERVE: CardData = preload("res://data/cards/card_observe.tres")
const DEEP_SEARCH: CardData = preload("res://data/cards/card_deep_search.tres")
const WAIT: CardData = preload("res://data/cards/card_wait.tres")
const MAIN: PackedScene = preload("res://scenes/main/Main.tscn")

var _checks: int = 0
var _failures: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_instances_and_finite_loot()
	_test_deep_search_and_insights()
	_test_supply_preparation_and_safe_exit()
	_test_rushed_outcomes()
	_test_forced_exit_without_content()
	_test_invalid_commands()
	await _test_ui()
	await process_frame
	if _failures == 0:
		print("[TEST] PASS Phase 5: %d checks (resources, preparation, cut-out, transition, anti-soft-lock, transactions, RNG, UI)" % _checks)
	else:
		push_error("[TEST] FAIL Phase 5: %d of %d checks failed" % [_failures, _checks])
	quit(0 if _failures == 0 else 1)


func _manager(data: FloorData = LEVEL_0) -> TurnManager:
	var manager: TurnManager = TurnManager.new()
	# 保留 Phase 5 的通用占位边界回归；真实六层入口由 Phase 6 和下方 UI 测试覆盖。
	var fixture: FloorData = data.duplicate(false) as FloorData
	var placeholder: FloorData = FloorData.new()
	placeholder.id = &"floor_level_6"
	placeholder.display_name = "六层（占位夹具）"
	placeholder.is_placeholder = true
	fixture.cutout_destinations = [placeholder]
	manager.floor_data = fixture
	manager.starter_deck = DeckData.new()
	manager.starter_deck.cards = [OBSERVE, OBSERVE, DEEP_SEARCH, WAIT, WAIT]
	root.add_child(manager)
	return manager


func _play(manager: TurnManager, definition: CardData) -> ActionResult:
	for card: CardInstance in manager.run_state.deck_state.hand:
		if card.definition == definition:
			return manager.request_play_card(card)
	_check(false, "Requested test card must actually be in hand")
	return manager.request_play_card(null)


func _test_instances_and_finite_loot() -> void:
	var first: FloorState = FloorState.new(LEVEL_0)
	var second: FloorState = FloorState.new(LEVEL_0)
	_check(first.resource_nodes.size() == 3 and first.cutout_state != second.cutout_state, "Every visit creates three resources and its own cut-out state")
	for index: int in range(3):
		_check(first.resource_nodes[index] != second.resource_nodes[index] and first.resource_nodes[index].status == ResourceNode.Status.UNDISCOVERED, "Resource instances start undiscovered and are never shared between visits")
	first.resource_nodes[0].status = ResourceNode.Status.DEPLETED
	first.cutout_state.stability = 2
	_check(second.resource_nodes[0].status == ResourceNode.Status.UNDISCOVERED and second.cutout_state.stability == 0, "One visit cannot deplete or prepare another visit")
	var manager: TurnManager = _manager()
	var before: Dictionary = _snapshot(manager)
	_reject(manager.request_exploration(&"loot", &"resource_level0_supply"), &"resource_undiscovered", manager, before)
	var result: ActionResult = manager.request_exploration(&"search_nearby")
	var node_id: StringName = result.resource_discovered_id
	_check(result.success and node_id == &"resource_level0_supply" and manager.run_state.supply == 0, "Basic search locates one surface node without granting its reward")
	_check(manager.run_state.floor_state.find_resource(node_id).status == ResourceNode.Status.DISCOVERED, "Located node becomes discovered")
	result = manager.request_exploration(&"loot", node_id)
	_check(result.success and result.ap_spent == 1 and result.supply_delta == 2 and manager.run_state.supply == 2, "Looting spends 1 AP and commits the authored finite reward")
	_check(manager.run_state.floor_state.find_resource(node_id).status == ResourceNode.Status.LOOTED, "Rewarded node stays looted until turn end")
	before = _snapshot(manager)
	_reject(manager.request_exploration(&"loot", node_id), &"resource_depleted", manager, before)
	manager.end_turn()
	_check(manager.run_state.floor_state.find_resource(node_id).status == ResourceNode.Status.DEPLETED, "Turn end transitions looted nodes to depleted")
	before = _snapshot(manager)
	_reject(manager.request_exploration(&"loot", node_id), &"resource_depleted", manager, before)
	_check(manager.run_state.supply == 2 and LEVEL_0.find_resource(node_id).supply_reward == 2, "Neither exhausted node nor shared definition produces a second reward")
	manager.free()


func _test_deep_search_and_insights() -> void:
	var manager: TurnManager = _manager()
	var result: ActionResult = _play(manager, DEEP_SEARCH)
	var floor: FloorState = manager.run_state.floor_state
	_check(result.success and result.resource_discovered_id == &"resource_level0_battery" and result.resource_looted_id == result.resource_discovered_id, "Deep Search prioritizes and directly loots a hidden node")
	_check(floor.find_resource(result.resource_looted_id).status == ResourceNode.Status.LOOTED and manager.run_state.supply == 2, "Advanced card grants exactly the hidden cache reward")
	_check(result.ap_spent == 2 and result.threat_delta == 1 and manager.run_state.deck_state.discard_pile.has(result.card_played), "Discovery preserves the real card AP/Threat/discard lifecycle")
	_check(result.insight_ids.size() == 1 and result.stability_delta == 1 and result.knowledge_delta == 1, "Unique Insight improves both cut-out preparation values")
	_play(manager, OBSERVE)
	_check(floor.cutout_state.stability == 1 and floor.cutout_state.destination_knowledge == 1 and floor.cognition == 1, "Already confirmed event cannot farm preparation or Cognition")
	manager.end_turn()
	result = _play(manager, DEEP_SEARCH)
	_check(result.insight_ids.size() == 1 and CutOutSystem.is_prepared(floor.cutout_state), "Another event's unique Insight can make safe cut-out available")
	var old_rng: int = manager.run_state.rng.state
	var old_supply: int = manager.run_state.supply
	var old_deck: DeckState = manager.run_state.deck_state
	var notifications: Array[StringName] = []
	manager.state_changed.connect(func() -> void:
		notifications.append(manager.run_state.floor_state.floor_id)
		_check(manager.floor_data.id == manager.run_state.floor_state.floor_id, "State notification sees matching destination definition and runtime state")
	)
	result = manager.request_exploration(&"cutout_safe")
	_check(result.success and result.cutout_attempt.succeeded and result.destination.id == &"floor_level_6", "Prepared cut-out succeeds and targets the configured placeholder")
	_check(manager.run_state.floor_state != floor and floor.floor_id == &"floor_level_0" and notifications == [&"floor_level_6"], "Successful transition switches the floor atomically exactly once")
	_check(manager.run_state.floor_state.threat == 0 and manager.run_state.floor_state.cognition == 0, "Floor-local Threat and Cognition reset at the boundary")
	_check(manager.run_state.supply == old_supply and manager.run_state.deck_state == old_deck and manager.run_state.rng.state == old_rng, "Safe transition preserves run inventory, deck and RNG")
	_check(manager.run_state.last_cutout_attempt == result.cutout_attempt and result.cutout_attempt.source_floor_id == &"floor_level_0", "Attempt outcome remains in domain state after leaving its source floor")
	_check(manager.floor_data.is_placeholder and manager.run_state.floor_state.current_event == null and manager.run_state.floor_state.resource_nodes.is_empty(), "Destination has no Level 6 event, resource or gameplay initialization")
	var before: Dictionary = _snapshot(manager)
	_reject(manager.end_turn(), &"floor_inactive", manager, before)
	_reject(manager.request_exploration(&"cutout_forced"), &"floor_inactive", manager, before)
	_reject(manager.request_play_card(manager.run_state.deck_state.hand[0]), &"floor_inactive", manager, before)
	manager.free()


func _test_supply_preparation_and_safe_exit() -> void:
	var manager: TurnManager = _manager()
	manager.request_exploration(&"search_nearby")
	manager.request_exploration(&"loot", &"resource_level0_supply")
	var first: ActionResult = manager.request_exploration(&"prepare_cutout")
	_check(first.success and first.supply_delta == -1 and manager.run_state.supply == 1, "Preparing consumes actual run Supply exactly once")
	_check(first.stability_delta == 1 and first.knowledge_delta == 1, "Resource use independently improves stability and knowledge")
	manager.end_turn()
	manager.request_exploration(&"prepare_cutout")
	_check(manager.run_state.cognition == 0 and CutOutSystem.is_prepared(manager.run_state.floor_state.cutout_state), "Safe preparation does not require any specific Insight")
	var result: ActionResult = manager.request_exploration(&"cutout_safe")
	_check(result.cutout_attempt != null and result.cutout_attempt.succeeded, "Two supply preparations allow safe exit without event confirmation")
	manager.free()
	manager = _manager()
	manager.run_state.supply = 10
	for index: int in range(3):
		manager.request_exploration(&"prepare_cutout")
	_check(manager.run_state.floor_state.cutout_state.stability == 3 and manager.run_state.floor_state.cutout_state.destination_knowledge == 2, "Preparation values obey prototype caps")
	manager.end_turn()
	var before: Dictionary = _snapshot(manager)
	_reject(manager.request_exploration(&"prepare_cutout"), &"preparation_complete", manager, before)
	manager.free()


func _seed_for_roll(roll: int) -> int:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	for seed_value: int in range(10000):
		rng.seed = seed_value
		if rng.randi_range(1, 100) == roll:
			return seed_value
	_check(false, "A deterministic seed must exist for the requested outcome")
	return 0


func _test_rushed_outcomes() -> void:
	for roll: int in [1, 100]:
		var trace: Array = []
		for repetition: int in range(2):
			var manager: TurnManager = _manager()
			manager.run_state.rng_seed = _seed_for_roll(roll)
			manager.run_state.rng.seed = manager.run_state.rng_seed
			var floor: FloorState = manager.run_state.floor_state
			var source_data: FloorData = manager.floor_data
			var before: Dictionary = _snapshot(manager)
			var result: ActionResult = manager.request_exploration(&"cutout_rushed")
			_check(result.success and result.ap_spent == 1 and result.cutout_attempt.roll == roll, "A legal rushed attempt has a reproducible roll and AP cost")
			_check(manager.run_state.ap == 2 and manager.run_state.stress == 1 and manager.run_state.rng.state != before["rng"], "A legal attempt commits its RNG, cost and risk together")
			trace.append([result.cutout_attempt.succeeded, result.cutout_attempt.destination_id, result.cutout_attempt.roll, manager.run_state.rng.state])
			if roll == 1:
				_check(result.cutout_attempt.succeeded and manager.run_state.floor_state.floor_id == &"floor_level_6", "Successful rushed cut-out changes the floor")
			else:
				_check(not result.cutout_attempt.succeeded and manager.run_state.floor_state == floor and manager.floor_data == source_data, "A failed rushed attempt keeps both floor state and definition unchanged")
				_check(result.threat_delta == 1 and floor.threat == 1 and manager.run_state.last_cutout_attempt == result.cutout_attempt, "Failed rushed attempt records its risk and domain outcome")
				var forced: ActionResult = manager.request_exploration(&"cutout_forced")
				_check(forced.cutout_attempt.succeeded, "Failure never removes the guaranteed forced route")
			manager.free()
		_check(trace[0] == trace[1], "Same initial seed reproduces the whole cut-out outcome")


func _test_forced_exit_without_content() -> void:
	for missing_count: int in [1, 3]:
		var data: FloorData = LEVEL_0.duplicate(false) as FloorData
		data.fresh_events = LEVEL_0.fresh_events.duplicate()
		for index: int in range(missing_count):
			data.fresh_events.pop_back()
		var manager: TurnManager = _manager(data)
		var floor: FloorState = manager.run_state.floor_state
		for node: ResourceNode in floor.resource_nodes:
			node.status = ResourceNode.Status.DEPLETED
		floor.threat = FloorState.MAX_THREAT
		manager.run_state.ap = 0
		manager.run_state.player_hp = 1
		manager.run_state.stress = 10
		var result: ActionResult = manager.request_exploration(&"cutout_forced")
		_check(result.success and result.cutout_attempt.succeeded and result.ap_spent == 0, "Forced cut-out works at zero AP with a missed event or no events")
		_check(floor.cognition == 0 and floor.cutout_state.stability == 0 and manager.run_state.supply == 0, "Exit requires neither Insight, preparation nor remaining resources")
		_check(manager.run_state.floor_state.floor_id == &"floor_level_6" and manager.run_state.stress == 12 and manager.run_state.player_hp == 1, "Forced risk is Stress, preserving even the low-HP escape route")
		manager.free()
	# 缺少所有资源也不能阻断退出；候选目的地由楼层定义直接提供。
	var empty: FloorData = LEVEL_0.duplicate(false) as FloorData
	empty.resource_nodes = []
	empty.fresh_events = []
	var manager: TurnManager = _manager(empty)
	_check(manager.request_exploration(&"cutout_forced").cutout_attempt.succeeded, "Forced route is independent of both event and resource generation")
	manager.free()


func _test_invalid_commands() -> void:
	var manager: TurnManager = _manager()
	var before: Dictionary = _snapshot(manager)
	_reject(manager.request_exploration(&"cutout_safe"), &"cutout_unprepared", manager, before)
	_reject(manager.request_exploration(&"prepare_cutout"), &"insufficient_supply", manager, before)
	_reject(manager.request_exploration(&"loot", &"not_a_node"), &"resource_not_found", manager, before)
	manager.run_state.ap = 0
	before = _snapshot(manager)
	_reject(_play(manager, DEEP_SEARCH), &"insufficient_ap", manager, before)
	_reject(manager.request_exploration(&"cutout_rushed"), &"insufficient_ap", manager, before)
	_reject(manager.request_exploration(&"prepare_cutout"), &"insufficient_ap", manager, before)
	manager.run_state.ap = 3
	manager.run_state.floor_state.cutout_state.destination_candidates = [&"unknown_floor"]
	before = _snapshot(manager)
	_reject(manager.request_exploration(&"cutout_forced"), &"invalid_destination", manager, before)
	manager.run_state.floor_state.cutout_state.destination_candidates = [&"floor_level_6"]
	manager.run_state.floor_state.cutout_state.stability = 4
	before = _snapshot(manager)
	_reject(manager.request_exploration(&"cutout_forced"), &"invalid_cutout_state", manager, before)
	manager.free()
	var data: FloorData = LEVEL_0.duplicate(false) as FloorData
	data.resource_nodes = []
	for original: ResourceNodeData in LEVEL_0.resource_nodes:
		data.resource_nodes.append(original.duplicate(false) as ResourceNodeData)
	manager = _manager(data)
	data.resource_nodes[0].supply_reward = -1
	before = _snapshot(manager)
	_reject(_play(manager, DEEP_SEARCH), &"invalid_resource_definition", manager, before)
	_check(LEVEL_0.resource_nodes[0].supply_reward == 2, "Malformed fixture never modifies shared content")
	manager.free()


func _test_ui() -> void:
	var main: Control = MAIN.instantiate() as Control
	root.add_child(main)
	var manager: TurnManager = main.get_node("TurnManager") as TurnManager
	var tabs: TabContainer = main.get_node("%FloorTabs") as TabContainer
	var search: Button = main.get_node("%SearchNearbyAction") as Button
	var resources: VBoxContainer = main.get_node("%ResourceList") as VBoxContainer
	var prepare: Button = main.get_node("%PrepareCutOut") as Button
	var safe: Button = main.get_node("%SafeCutOut") as Button
	var forced: Button = main.get_node("%ForcedCutOut") as Button
	var end_turn: Button = main.get_node("%EndTurn") as Button
	_check(tabs.get_tab_title(1) == "资源与切出" and not forced.disabled and safe.disabled, "Chinese UI exposes a forced route before preparation")
	search.pressed.emit()
	tabs.current_tab = 1
	_check(resources.get_child(0) is Button, "Located node exposes a scene loot command")
	(resources.get_child(0) as Button).pressed.emit()
	_check(manager.run_state.supply == 2 and (resources.get_child(0) as Label).text.contains("已搜刮"), "Loot UI reads reward and depleted availability from domain state")
	prepare.pressed.emit()
	end_turn.pressed.emit()
	prepare.pressed.emit()
	_check(not safe.disabled and manager.run_state.cognition == 0, "Resource-only preparation enables the safe button")
	_check((main.get_node("%CutOutInfo") as Label).text.contains("已稳定") and not (main.get_node("%CutOutInfo") as Label).text.contains("stability"), "Preparation UI uses Chinese narrative descriptions instead of raw internals")
	await process_frame
	var scroll: ScrollContainer = main.get_node("FloorMargin/FloorTabs/ResourcesCutOut") as ScrollContainer
	scroll.ensure_control_visible(forced)
	await process_frame
	_check(main.get_viewport_rect().encloses(forced.get_global_rect()), "Forced route remains reachable inside the scrollable panel")
	safe.pressed.emit()
	_check(manager.run_state.floor_state.floor_id == &"floor_level_6" and tabs.current_tab == 2, "Safe UI command enters the active Level 6 and shows its entity intent")
	_check(not manager.floor_data.is_placeholder and not end_turn.disabled and not forced.disabled, "Active Level 6 preserves the existing turn and cut-out commands")
	_check(manager.run_state.last_cutout_attempt.succeeded, "UI is not the owner of the transition outcome")
	await process_frame
	main.free()
	# 第二个真实主场景验证仓促失败反馈，以及零 AP 按钮仍能触发兜底过渡。
	main = MAIN.instantiate() as Control
	root.add_child(main)
	manager = main.get_node("TurnManager") as TurnManager
	manager.run_state.rng_seed = _seed_for_roll(100)
	manager.run_state.rng.seed = manager.run_state.rng_seed
	(main.get_node("%RushedCutOut") as Button).pressed.emit()
	_check((main.get_node("%Status") as Label).text.contains("仓促切出未成功") and manager.run_state.floor_state.floor_id == &"floor_level_0", "UI distinguishes a committed failed attempt from successful transition")
	manager.run_state.ap = 0
	main._refresh_state()
	forced = main.get_node("%ForcedCutOut") as Button
	_check(not forced.disabled, "Zero AP never disables the forced UI route")
	forced.pressed.emit()
	_check(manager.run_state.floor_state.floor_id == &"floor_level_6" and manager.run_state.stress == 3, "Forced UI command succeeds after a rushed failure even at zero AP")
	await process_frame
	main.free()


func _snapshot(manager: TurnManager) -> Dictionary:
	var state: RunState = manager.run_state
	var floor: FloorState = state.floor_state
	var nodes: Array = []
	for node: ResourceNode in floor.resource_nodes:
		nodes.append([node.get_instance_id(), node.node_id, node.status])
	var piles: Array = []
	for pile: Array[CardInstance] in [state.deck_state.hand, state.deck_state.draw_pile, state.deck_state.discard_pile]:
		var cards: Array = []
		for card: CardInstance in pile:
			cards.append([card.get_instance_id(), card.definition.get_instance_id(), card.definition.id, card.definition.ap_cost])
		piles.append(cards)
	var attempt: CutOutAttemptResult = state.last_cutout_attempt
	return {
		"hp": state.player_hp, "stress": state.stress, "supply": state.supply, "ap": state.ap,
		"turn": state.turn_number, "rng": state.rng.state, "floor": floor.get_instance_id(),
		"floor_id": floor.floor_id, "data": manager.floor_data.get_instance_id(),
		"floor_turn": floor.turn_count, "threat": floor.threat, "cognition": floor.cognition,
		"nodes": nodes, "piles": piles, "stability": floor.cutout_state.stability,
		"knowledge": floor.cutout_state.destination_knowledge,
		"candidates": floor.cutout_state.destination_candidates.duplicate(),
		"attempt": [attempt.attempt_type, attempt.succeeded, attempt.destination_id, attempt.roll] if attempt != null else [],
		"insights": floor.discovered_insight_ids.duplicate(), "flags": floor.floor_flags.duplicate(),
		"fresh": floor.remaining_fresh_events.duplicate(), "seen": floor.seen_event_ids.duplicate(),
		"event": floor.current_event_id,
		"interactions": floor.current_event.completed_interactions.duplicate() if floor.current_event != null else [],
		"information": floor.current_event.known_information.duplicate() if floor.current_event != null else [],
		"resolved": floor.current_event.resolved if floor.current_event != null else false,
	}


func _reject(result: ActionResult, reason: StringName, manager: TurnManager, before: Dictionary) -> void:
	_check(not result.success and result.failure_reason == reason, "Invalid command reports expected reason: %s" % reason)
	_check(_snapshot(manager) == before, "Rejected command preserves resources, AP, cards, preparation, event, floor and RNG")
	_check(result.ap_spent == 0 and result.supply_delta == 0 and result.stability_delta == 0 and result.knowledge_delta == 0 and result.cutout_attempt == null and result.destination == null and result.resource_looted_id.is_empty(), "Rejected result contains no uncommitted gameplay effects")


func _check(condition: bool, description: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		push_error("[TEST] %s" % description)
