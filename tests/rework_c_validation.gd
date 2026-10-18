extends "res://tests/migration_test_base.gd"


func label() -> String:
	return "REWORK C / single-semantic cards"


func tests() -> void:
	_test_resource_cards()
	_test_equipment_cards()
	_test_generation_rate()
	_test_smiler_cards()
	_test_cutout_cards()
	_test_anti_soft_lock()
	_test_invalid_modes()
	_test_failure_matrix()
	_test_retired_inputs()
	await _test_full_ui_run()


func _equipment_fixture(data: FloorData, gear: Array[EquipmentData], definitions: Array[CardData] = []) -> TurnManager:
	var owner: TurnManager = TurnManager.new()
	owner.floor_data = data
	owner.starter_deck = DeckData.new()
	owner.starter_deck.cards.assign(DECK.cards if definitions.is_empty() else definitions)
	owner.starting_equipment = gear
	root.add_child(owner)
	return owner


func _assert_zones(owner: TurnManager, normal_count: int) -> void:
	var deck: DeckState = owner.run_state.deck_state
	check(deck.get_card_count() == normal_count, "Permanent NORMAL inventory is conserved independently of generated actions")
	for pile: Array[CardInstance] in [deck.draw_pile, deck.discard_pile]:
		for card: CardInstance in pile:
			check(card.source == CardData.Source.NORMAL, "Generated equipment/floor cards never enter draw or discard")
	check(deck.hand.size() <= CardSystem.HAND_TARGET + 1, "Unified hand has at most five base slots plus one equipment action")


func _test_resource_cards() -> void:
	var data: FloorData = fixture()
	data.fresh_objectives = [data.fresh_objectives[0]]
	data.fresh_objectives[0].explore_threshold = 100
	data.fresh_objectives[0].clue_threshold = 90
	var owner: TurnManager = manager([SEARCH, SEARCH, SEARCH, SEARCH, SEARCH], data, false)
	var state: RunState = owner.run_state
	var node: ResourceNode = state.floor_state.resource_nodes[0]
	var result: ActionResult = play(owner, SEARCH)
	check(result.success and result.explore_applied == 3 and result.threat_delta == 1 and result.resource_looted_id == node.node_id and state.supply == 2 and node.status == ResourceNode.Status.LOOTED and state.ap == 2, "Single Search atomically grants Explore, finite reward, Threat, AP and normal discard")
	play(owner, SEARCH)
	play(owner, SEARCH)
	check(state.supply == 3 and state.floor_state.current_objective.explore_progress == 9, "Ordinary search collects visible caches once, then still meaningfully explores")
	owner.end_turn()
	check(node.status == ResourceNode.Status.DEPLETED, "Collected nodes deplete in existing turn lifecycle")
	play(owner, SEARCH)
	check(state.supply == 3, "Depleted node cannot repeat its reward")
	_assert_zones(owner, 5)
	owner.free()
	data = fixture()
	data.fresh_objectives = []
	owner = manager([DEEP, DEEP, DEEP, DEEP, DEEP], data, false)
	var total: int = 0
	for definition: ResourceNodeData in data.resource_nodes:
		total += definition.supply_reward
	for index: int in range(3):
		result = play(owner, DEEP)
		check(result.success and not result.resource_discovered_id.is_empty() and not result.resource_looted_id.is_empty() and result.ap_spent == 2 and result.threat_delta == 1, "Deep Search directly collects a finite environment reward without a mode or second Loot verb")
		if index == 0:
			check(data.find_resource(result.resource_looted_id).hidden, "Deep Search preserves hidden-cache priority as a declared modifier")
		owner.end_turn()
	check(owner.run_state.supply == total and owner.run_state.floor_state.resource_nodes.all(func(value: ResourceNode) -> bool: return value.status == ResourceNode.Status.DEPLETED), "All finite resources pay exactly their declared total")
	reject(owner, command(owner, DEEP), &"resources_exhausted")
	owner.free()


func _test_equipment_cards() -> void:
	var invalid_flash: EquipmentData = FLASH.duplicate(false) as EquipmentData
	invalid_flash.action_card = null
	var empty_run: RunState = RunState.new()
	check(EquipmentSystem.initialize(empty_run, [invalid_flash]) == &"invalid_equipment_definition" and empty_run.equipment_slots.all(func(item: EquipmentInstance) -> bool: return item == null), "Partial flashlight template pair is rejected before it can generate a card of the wrong source")
	var owner: TurnManager = _equipment_fixture(LEVEL_6, [FLASH])
	var state: RunState = owner.run_state
	var card: CardInstance = generated(owner, &"light")
	check(card != null and card.source == CardData.Source.EQUIPMENT and card.source_equipment == state.equipment_slots[0] and state.deck_state.hand.size() == 6, "Flashlight exposes a real explicit Lighting equipment card")
	state.ap = 0
	reject(owner, generated_request(owner, &"light"), &"insufficient_ap")
	state.ap = 3
	var stale: PlayCardCommand = generated_request(owner, &"light")
	var result: ActionResult = play_generated(owner, &"light")
	check(result.success and result.card_definition.effect_type == CardData.EffectType.LIGHT and state.ap == 2 and state.equipment_slots[0].remaining_uses == 2 and state.floor_state.light_active, "Lighting consumes one battery and snapshots the played semantic before replacement")
	check(generated(owner, &"light") == null and generated(owner, &"extinguish") == card and state.deck_state.discard_pile.is_empty(), "LIGHT on replaces same hand instance with explicit Extinguish, never a popup or second slot")
	reject(owner, stale, &"invalid_card_source")
	owner.card_system.generate_equipment_card(LEVEL_6)
	check(state.deck_state.hand.size() == 6, "Replacing flashlight definition does not bypass generation budget")
	result = play_generated(owner, &"extinguish")
	check(result.success and not state.floor_state.light_active and state.equipment_slots[0].remaining_uses == 2 and generated(owner, &"light") == card and state.ap == 1, "Extinguish has one semantic, costs AP and no battery, and exposes Lighting when off")
	play_generated(owner, &"light")
	check(state.ap == 0 and state.equipment_slots[0].remaining_uses == 1, "Same opportunity can perform declared state-specific cards within shared AP")
	owner.end_turn()
	check(not state.deck_state.hand.has(card) and generated(owner, &"light") != null, "Turn cleanup expires flashlight opportunity and next turn can generate a new instance")
	play_generated(owner, &"light")
	check(state.equipment_slots[0].remaining_uses == 0 and generated(owner, &"extinguish") != null, "Last battery still leaves an explicit Extinguish response")
	play_generated(owner, &"extinguish")
	check(generated(owner, &"light") == null and generated(owner, &"extinguish") == null, "Empty unlit flashlight cannot regenerate Lighting")
	_assert_zones(owner, DECK.cards.size())
	owner.free()
	owner = _equipment_fixture(LEVEL_6, [CROWBAR])
	state = owner.run_state
	card = generated(owner, &"crowbar")
	var request: PlayCardCommand = generated_request(owner, &"crowbar")
	request.target_entity = EntitySystem.spawn(LEVEL_6.entry_entity)
	reject(owner, request, &"invalid_entity_target")
	result = play_generated(owner, &"crowbar")
	check(result.success and result.damage_requested == 8 and state.floor_state.entity.hp == 10 and state.equipment_slots[0].remaining_uses == 2 and state.floor_state.entity.state == &"CHASING", "Dedicated Crowbar Strike preserves 8 damage, one durability and actual NOISE")
	check(not state.deck_state.hand.has(card) and state.deck_state.discard_pile.is_empty() and CROWBAR.capacity == 3, "Crowbar action disappears without changing shared EquipmentData")
	owner.free()
	for stress: int in [1, 6, 7, 9]:
		owner = _equipment_fixture(LEVEL_0, [WATER], [GUARD, GUARD, GUARD, GUARD, GUARD])
		state = owner.run_state
		check(generated(owner, &"recover") == null, "Water with no recovery purpose is skipped")
		state.stress = stress
		state.player_hp = 29
		owner.card_system.generate_equipment_card(LEVEL_0)
		card = generated(owner, &"recover")
		result = play_generated(owner, &"recover")
		check(result.success and state.stress == maxi(0, stress - 2) and state.player_hp == (30 if stress >= 7 else 29) and state.equipment_slots[0].remaining_uses == 0, "Dedicated Water card preserves recovery and consumes one physical charge")
		reject(owner, PlayCardCommand.new(card, null, state.floor_state.board_state), &"card_not_in_hand")
		owner.end_turn()
		check(generated(owner, &"recover") == null, "Consumed water cannot generate another action")
		owner.free()


func _test_generation_rate() -> void:
	var data: FloorData = fixture(LEVEL_6)
	data.fresh_objectives = []
	var owner: TurnManager = manager([], data)
	var first: CardInstance = generated(owner, &"light")
	check(first != null, "Round robin starts with first eligible carry slot")
	owner.run_state.stress = 5
	for turn: int in range(3):
		owner.card_system.generate_equipment_card(data)
		owner.card_system.generate_equipment_card(data)
		var equipment_cards: Array[CardInstance] = []
		for card: CardInstance in owner.run_state.deck_state.hand:
			if card.source == CardData.Source.EQUIPMENT:
				equipment_cards.append(card)
		check(equipment_cards.size() == 1, "Three carried items never flood the hand; repeated synchronization adds no duplicates")
		check(equipment_cards[0].source_equipment == owner.run_state.equipment_slots[turn], "Deterministic rotation visits eligible slots without RNG")
		_assert_zones(owner, DECK.cards.size())
		owner.end_turn()
	check(not owner.run_state.deck_state.hand.has(first), "Unplayed equipment action expires at turn cleanup")
	owner.free()


func _test_smiler_cards() -> void:
	var data: FloorData = fixture(LEVEL_6)
	data.fresh_objectives = []
	var owner: TurnManager = _equipment_fixture(data, [CROWBAR, FLASH], [ATTACK, ATTACK, ATTACK, OBSERVE, OBSERVE])
	var state: RunState = owner.run_state
	play_generated(owner, &"crowbar")
	play(owner, ATTACK, true)
	play(owner, ATTACK, true)
	var hound: EntityInstance = state.floor_state.entity
	check(hound.hp == 2 and hound.active, "Active Hound is not replaced by an unrelated pursuit command")
	owner.end_turn()
	play_generated(owner, &"light")
	check(state.floor_state.entity == hound, "LIGHT never overwrites active Hound")
	var result: ActionResult = play(owner, ATTACK, true)
	var smiler: EntityInstance = state.floor_state.entity
	check(result.entity_defeated and not hound.active and smiler != hound and smiler.entity_id == data.followup_entity.id and smiler.hp == 120 and smiler.alive and smiler.state == &"OBSERVING", "Resolved Hound + actual LIGHT automatically spawns common Smiler atomically without copying lethal damage")
	play_generated(owner, &"extinguish")
	owner.end_turn()
	check(smiler.alive and not smiler.active and smiler.state == &"WITHDRAWN" and state.cognition == 1, "Correct explicit Extinguish resolves Smiler alive and confirms unique behavior Insight")
	owner.end_turn()
	check(state.floor_state.entity == null and state.floor_state.resolved_entity_ids.has(smiler.entity_id) and state.cognition == 1, "World follow-up cannot repeatedly respawn or repeat unique reward")
	owner.free()
	data = fixture(LEVEL_6)
	data.entry_entity = data.followup_entity
	data.followup_entity = null
	data.fresh_objectives = []
	owner = _equipment_fixture(data, [FLASH], [OBSERVE, OBSERVE, OBSERVE, GUARD, GUARD])
	smiler = owner.run_state.floor_state.entity
	for exposure: int in range(3):
		check(play_generated(owner, &"light").success, "Explicit generated Lighting can expose Smiler")
		if exposure == 0:
			check(smiler.state == &"OBSERVING" and smiler.light_exposed, "First LIGHT exposes deterministic observation")
		if exposure == 1:
			check(smiler.state == &"AGITATED" and smiler.intent == &"warn_light", "Repeated LIGHT publishes warning")
		result = owner.end_turn()
		if exposure == 2:
			check(result.player_damage == 6 and smiler.hp == 120, "Continued LIGHT still resolves common attack pipeline")
	owner.end_turn()
	check(smiler.state == &"WITHDRAWN" and smiler.alive and owner.run_state.cognition == 1, "Stopping light preserves behavioral solution and unique knowledge")
	owner.free()
	data = fixture(LEVEL_6)
	data.entry_entity = null
	data.followup_entity = null
	owner = _equipment_fixture(data, [], [OBSERVE, OBSERVE, OBSERVE, OBSERVE, OBSERVE])
	play(owner, OBSERVE)
	result = play(owner, OBSERVE)
	check(result.clue_revealed and owner.run_state.floor_state.discovered_insight_ids.has(data.fresh_objectives[0].clue_insight.id) and owner.run_state.cognition == 1, "Situation clue supplies same light Insight with no Smiler/pursuit/landmark input")
	owner.end_turn()
	play(owner, OBSERVE)
	check(owner.run_state.cognition == 1, "Revisiting known clue cannot duplicate Insight")
	owner.free()


func _test_cutout_cards() -> void:
	var owner: TurnManager = manager([OBSERVE, OBSERVE, OBSERVE, OBSERVE, OBSERVE], LEVEL_0, false)
	var state: RunState = owner.run_state
	var deck: DeckState = state.deck_state
	check(generated(owner, &"rushed") == null and not CutOutSystem.is_available(state.floor_state, LEVEL_0), "No exit before minimum condition")
	play(owner, OBSERVE)
	var exit_card: CardInstance = generated(owner, &"rushed")
	check(exit_card != null and exit_card.definition.retain and state.floor_state.cutout_state.stability == 1 and state.supply == 0, "Declared clue improves preparation and creates retained exit without supply/preparation card")
	owner.end_turn()
	check(generated(owner, &"rushed") == exit_card and deck.hand.size() == 5 and deck.hand[0] == exit_card, "Retained exit occupies one base slot across normal cleanup/refill")
	var stale: PlayCardCommand = generated_request(owner, &"rushed")
	var index: int = deck.hand.find(exit_card)
	var result: ActionResult = play(owner, OBSERVE)
	check(result.objective_resolved and generated(owner, &"safe") == exit_card and generated(owner, &"rushed") == null and deck.hand.find(exit_card) == index and state.cognition == 1, "Normal investigation and Insight automatically upgrade same retained exit in place")
	reject(owner, stale, &"invalid_card_source")
	state.floor_state.cutout_state.stability = 1
	reject(owner, generated_request(owner, &"safe"), &"cutout_unprepared")
	state.floor_state.cutout_state.stability = 2
	var observed: Array[bool] = []
	owner.state_changed.connect(func() -> void: observed.append(owner.floor_data.id == state.floor_state.floor_id and not deck.hand.has(exit_card)))
	result = play_generated(owner, &"safe")
	check(result.success and result.cutout_attempt.succeeded and owner.floor_data == LEVEL_6 and state.ap == 1 and observed == [true], "Safe transition removes temporary card and synchronizes destination before notification without AP reset")
	check(not deck.hand.has(exit_card) and generated(owner, &"safe") == null and generated(owner, &"rushed") == null, "New visit has no stale exit")
	owner.end_turn()
	var next_exit: CardInstance = generated(owner, &"rushed")
	check(next_exit != null and next_exit != exit_card and next_exit.source_board == state.floor_state.board_state, "Next visit generates a fresh retained opportunity")
	_assert_zones(owner, 5)
	owner.free()


func _test_anti_soft_lock() -> void:
	var successes: int = 0
	var failures_seen: int = 0
	for seed_value: int in range(1, 30):
		var zero: FloorData = fixture()
		var six: FloorData = fixture(LEVEL_6)
		for data: FloorData in [zero, six]:
			data.fresh_objectives = []
			data.resource_nodes = []
			data.entry_entity = null
			data.followup_entity = null
			data.landmark_insight = null
		zero.cutout_destinations = [six]
		var owner: TurnManager = manager([ATTACK, ATTACK, ATTACK, ATTACK, ATTACK], zero, false, seed_value)
		var state: RunState = owner.run_state
		var deck: DeckState = state.deck_state
		owner.end_turn()
		var retained: CardInstance = generated(owner, &"rushed")
		check(retained != null and state.cognition == 0 and state.supply == 0, "Missing all events/Insights/resources/gear still deterministically generates an exit by floor turn two")
		owner.end_turn()
		check(generated(owner, &"rushed") == retained and deck.hand.size() == 5, "Ordinary draw/reshuffle cannot discard or strand retained exit")
		for attempt: int in range(30):
			var source: FloorState = state.floor_state
			var card: CardInstance = generated(owner, &"rushed")
			var stress_before: int = state.stress
			var threat_before: int = source.threat
			var result: ActionResult = play_generated(owner, &"rushed")
			check(result.success and result.ap_spent == 1, "Rushed attempt is a paid generated-card action even when its outcome fails")
			if result.cutout_attempt.succeeded:
				successes += 1
				check(state.floor_state != source and not deck.hand.has(card), "Only successful cut-out removes card and changes floor")
				if owner.floor_data.is_placeholder:
					break
			else:
				failures_seen += 1
				check(state.floor_state == source and deck.hand.has(card) and generated(owner, &"rushed") == card and state.stress == stress_before + 1 and source.threat == mini(FloorState.MAX_THREAT, threat_before + 1), "Failed rushed attempt preserves exact exit and original Stress/Threat risk")
			owner.end_turn()
		check(owner.floor_data.is_placeholder and owner.run_state == state and state.deck_state == deck and state.cognition == 0, "Deterministic seed route reaches terminal through both floors with no content or gear")
		_assert_zones(owner, 5)
		owner.free()
	check(successes >= 58 and failures_seen > 0, "Seed set covers successes and failed attempts with retained retry")


func _test_invalid_modes() -> void:
	var owner: TurnManager = manager()
	var fields: Array[StringName] = []
	for field: Dictionary in OBSERVE.get_property_list():
		fields.append(field.name)
	check(not fields.has(&"actions") and not fields.has(&"primary_action") and OBSERVE.analyzes_entities and not OBSERVE.collects_resources, "Observe has one investigation semantic, not unrelated action declarations")
	fields.clear()
	for field: Dictionary in PlayCardCommand.new().get_property_list():
		fields.append(field.name)
	for removed: StringName in [&"mode", &"equipment", &"resource_node"]:
		check(not fields.has(removed), "Player command cannot select a gameplay verb/source: %s" % removed)
	for path: String in ["res://scripts/cards/card_action_data.gd", "res://scripts/cards/card_action_system.gd", "res://data/cards/generated/card_cutout_prepare.tres", "res://data/cards/actions/discover.tres", "res://data/cards/actions/loot.tres", "res://data/cards/actions/encounter.tres", "res://data/cards/actions/landmark.tres", "res://data/cards/actions/forced.tres"]:
		check(not FileAccess.file_exists(path), "Retired selector/interpreter/preparation source is removed: %s" % path)
	check(not owner.has_method("request_exploration") and not owner.has_method("request_use_equipment"), "No standalone gameplay command remains")
	var forged: CardInstance = CardInstance.new(LEVEL_0.rushed_cutout_card)
	forged.source_board = owner.run_state.floor_state.board_state
	owner.run_state.deck_state.hand.append(forged)
	reject(owner, PlayCardCommand.new(forged, null, forged.source_board), &"cutout_unavailable")
	owner.run_state.deck_state.hand.erase(forged)
	owner.free()


func _test_failure_matrix() -> void:
	for failure: String in ["bad_resource", "bad_clue", "foreign_event"]:
		var data: FloorData = fixture()
		var owner: TurnManager = manager([SEARCH, SEARCH, SEARCH, SEARCH, SEARCH], data, false)
		var request: PlayCardCommand = command(owner, SEARCH)
		var expected: StringName
		match failure:
			"bad_resource":
				data.resource_nodes[0].supply_reward = -1
				expected = &"invalid_resource_definition"
			"bad_clue":
				data.fresh_objectives[0].clue_stability = -1
				expected = &"invalid_objective_definition"
			"foreign_event":
				request.target_objective = ObjectiveInstance.new(request.target_objective.objective_id)
				expected = &"invalid_objective_target"
		reject(owner, request, expected)
		check(owner.run_state.supply == 0 and owner.run_state.floor_state.current_objective.explore_progress == 0, "Rejected Search cannot partially collect reward or advance its Situation")
		owner.free()
	for failure: String in ["ap", "removed_item", "duplicate_item", "empty_item", "bad_item", "stale_board", "dead", "wrong_source"]:
		var owner: TurnManager = _equipment_fixture(LEVEL_6, [CROWBAR])
		var request: PlayCardCommand = generated_request(owner, &"crowbar")
		var expected: StringName
		match failure:
			"ap":
				owner.run_state.ap = 0
				expected = &"insufficient_ap"
			"removed_item":
				owner.run_state.equipment_slots[0] = null
				expected = &"invalid_equipment_target"
			"duplicate_item":
				owner.run_state.equipment_slots[1] = owner.run_state.equipment_slots[0]
				expected = &"invalid_equipment_state"
			"empty_item":
				owner.run_state.equipment_slots[0].remaining_uses = 0
				expected = &"equipment_depleted"
			"bad_item":
				var item: EquipmentInstance = owner.run_state.equipment_slots[0]
				item.definition = item.definition.duplicate(false) as EquipmentData
				item.definition.effect_value = -1
				expected = &"invalid_equipment_definition"
			"stale_board":
				request.target_board = FloorState.new(LEVEL_6).board_state
				expected = &"invalid_objective_target"
			"dead":
				owner.run_state.player_hp = 0
				expected = &"run_ended"
			"wrong_source":
				request.definition = LEVEL_6.safe_cutout_card
				expected = &"invalid_card_source"
		reject(owner, request, expected)
		owner.free()
	for failure: String in ["bad_candidate", "bad_event", "bad_entity", "bad_darkness", "missing_exit", "bad_card"]:
		var data: FloorData = fixture()
		var destination: FloorData = fixture(LEVEL_6)
		data.cutout_destinations = [destination]
		var owner: TurnManager = manager([], data, false)
		owner.end_turn()
		var request: PlayCardCommand = generated_request(owner, &"rushed")
		var expected: StringName
		match failure:
			"bad_candidate":
				owner.run_state.floor_state.cutout_state.destination_candidates = [&"missing"]
				expected = &"invalid_destination"
			"bad_event":
				destination.fresh_objectives[0].explore_threshold = -1
				expected = &"invalid_objective_definition"
			"bad_entity":
				destination.followup_entity.id = destination.entry_entity.id
				expected = &"invalid_entity_definition"
			"bad_darkness":
				destination.initial_flags = []
				expected = &"invalid_entity_context"
			"missing_exit":
				destination.cutout_destinations = []
				expected = &"invalid_destination"
			"bad_card":
				destination.rushed_cutout_card = null
				expected = &"invalid_cutout_card"
		reject(owner, request, expected)
		owner.free()


func _test_retired_inputs() -> void:
	var owner: TurnManager = manager()
	check(not owner.has_method("request_exploration") and not owner.has_method("request_use_equipment"), "Direct player gameplay methods remain absent")
	var resolver: Script = load("res://scripts/rules/rule_resolver.gd") as Script
	for method: Dictionary in resolver.get_script_method_list():
		check(method.name not in [&"resolve_equipment", &"resolve_exploration", &"_prepare_floor_command", &"_prepare_floor_action"], "Resolver exposes no retired command interpreter")
	for path: String in ["res://scenes/main/LegacyMain.tscn", "res://scripts/ui/legacy_main.gd", "res://scripts/rules/use_equipment_command.gd", "res://scripts/rules/exploration_command.gd"]:
		check(not FileAccess.file_exists(path), "Old bypass scene/command source remains absent")
	owner.free()


func _test_full_ui_run() -> void:
	var main: Control = MAIN.instantiate() as Control
	(main.get_node("TurnManager") as TurnManager).floor_data = preload("res://tests/fixtures/phase9/floors/floor_level_0.tres")
	(main.get_node("TurnManager") as TurnManager).starter_deck = preload("res://tests/fixtures/phase9/cards/run_deck.tres")
	var legacy: FloorData = fixture(LEVEL_0)
	legacy.cutout_destinations = [fixture(LEVEL_6)]
	(main.get_node("TurnManager") as TurnManager).floor_data = legacy
	root.add_child(main)
	var owner: TurnManager = main.get_node("TurnManager") as TurnManager
	var state: RunState = owner.run_state
	var deck: DeckState = state.deck_state
	var equipment: Array[EquipmentInstance] = state.equipment_slots.duplicate()
	click_card(main, SEARCH)
	check(state.supply == 2 and generated(owner, &"rushed") != null, "One normal Search both collects finite reward and reveals exit clue")
	click_card(main, OBSERVE)
	check(generated(owner, &"safe") != null, "Normal investigation upgrades exit without any prepare action")
	(main.get_node("%EndTurn") as Button).pressed.emit()
	(main.get_node("%EndTurn") as Button).pressed.emit()
	click_generated(main, &"recover")
	click_generated(main, &"safe")
	check(state.floor_state.floor_id == LEVEL_6.id and state.ap == 1, "Explicit Water and Safe cards share AP and transition without scenario controls")
	(main.get_node("%EndTurn") as Button).pressed.emit()
	var hound: EntityInstance = state.floor_state.entity
	for turn: int in range(12):
		if not hound.active or state.player_hp == 0:
			break
		for action: int in range(5):
			if state.ap == 0:
				break
			if generated(owner, &"light") != null and equipment[0].remaining_uses == 3:
				click_generated(main, &"light")
			elif generated(owner, &"crowbar") != null and hound.active:
				click_generated(main, &"crowbar")
			elif hound.active and deck.hand.any(func(card: CardInstance) -> bool: return card.definition == ATTACK):
				click_card(main, ATTACK, true)
			elif state.floor_state.current_objective != null and not state.floor_state.current_objective.resolved and deck.hand.any(func(card: CardInstance) -> bool: return card.definition == SEARCH):
				click_card(main, SEARCH)
			elif hound.active and deck.hand.any(func(card: CardInstance) -> bool: return card.definition == GUARD):
				click_card(main, GUARD)
			else:
				break
		if not hound.active:
			break
		(main.get_node("%EndTurn") as Button).pressed.emit()
	check(state.player_hp > 0 and not hound.active, "One-semantic normal/equipment cards defeat Hound using common AP/turn loop")
	for turn: int in range(8):
		if state.floor_state.entity != null and state.floor_state.entity.entity_id == LEVEL_6.followup_entity.id:
			break
		if generated(owner, &"light") != null and state.ap >= 1:
			click_generated(main, &"light")
			break
		(main.get_node("%EndTurn") as Button).pressed.emit()
	var smiler: EntityInstance = state.floor_state.entity
	check(smiler != hound and smiler.entity_id == LEVEL_6.followup_entity.id and smiler.hp == 120, "Actual LIGHT/world condition introduces Smiler without pursuit command")
	if generated(owner, &"extinguish") != null and state.ap >= 1:
		click_generated(main, &"extinguish")
	(main.get_node("%EndTurn") as Button).pressed.emit()
	if smiler.active:
		(main.get_node("%EndTurn") as Button).pressed.emit()
	check(smiler.alive and smiler.state == &"WITHDRAWN" and state.player_hp > 0, "Explicit light response resolves Smiler alive")
	check(equipment[0].remaining_uses < 3 and equipment[1].remaining_uses < 3 and equipment[2].remaining_uses == 0, "Continuous UI route uses all three actual equipment sources")
	for attempt: int in range(12):
		if owner.floor_data.is_placeholder:
			break
		click_generated(main, &"safe" if generated(owner, &"safe") != null else &"rushed")
		if not owner.floor_data.is_placeholder:
			(main.get_node("%EndTurn") as Button).pressed.emit()
	check(owner.floor_data.is_placeholder and (main.get_node("%Status") as Label).text.contains("本局完成"), "Dedicated exit card reaches terminal result")
	check(owner.run_state == state and state.deck_state == deck and state.equipment_slots == equipment, "Full run preserves Run/deck/equipment identity")
	_assert_zones(owner, DECK.cards.size())
	await process_frame
	await process_frame
	check((main.get_node("%RunSummary") as Control).visible and not (main.get_node("%Hand") as Control).is_visible_in_tree(), "Terminal summary replaces live hand without showing reset floor counters")
	main.free()
