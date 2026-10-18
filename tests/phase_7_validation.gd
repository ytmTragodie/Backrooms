extends SceneTree

const LEVEL_0: FloorData = preload("res://data/floors/floor_level_0_legacy.tres")
const LEVEL_6: FloorData = preload("res://data/floors/floor_level_6_legacy.tres")
const FLASHLIGHT: EquipmentData = preload("res://data/equipment/equip_flashlight.tres")
const CROWBAR: EquipmentData = preload("res://data/equipment/equip_crowbar.tres")
const WATER: EquipmentData = preload("res://data/equipment/equip_almond_water.tres")
const OBSERVE: CardData = preload("res://data/cards/card_observe.tres")
const WAIT: CardData = preload("res://data/cards/card_wait.tres")
const MAIN: PackedScene = preload("res://scenes/main/LegacyMain.tscn")

var _checks: int = 0
var _failures: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_slots_and_initialization()
	_test_light_and_observation()
	_test_empty_battery()
	_test_crowbar_and_durability()
	_test_recovery()
	_test_floor_persistence()
	_test_transactional_failures()
	await _test_main_ui()
	await process_frame
	if _failures == 0:
		print("[TEST] PASS Phase 7: %d checks (carry slots, equipment, charges, light, attacks, recovery, persistence, deck separation, transactions, UI)" % _checks)
	else:
		push_error("[TEST] FAIL Phase 7: %d of %d checks failed" % [_failures, _checks])
	quit(0 if _failures == 0 else 1)


func _manager(data: FloorData = LEVEL_6) -> TurnManager:
	var manager: TurnManager = TurnManager.new()
	manager.floor_data = data
	manager.starting_equipment.assign([FLASHLIGHT, CROWBAR, WATER])
	manager.starter_deck = DeckData.new()
	manager.starter_deck.cards.assign([OBSERVE, OBSERVE, WAIT, WAIT, WAIT])
	root.add_child(manager)
	return manager


func _test_slots_and_initialization() -> void:
	var state: RunState = RunState.new()
	_check(state.equipment_slots.size() == 3 and state.equipment_slots.all(func(item: EquipmentInstance) -> bool: return item == null), "RunState owns exactly three initially empty carry slots")
	var excessive: Array[EquipmentData] = [FLASHLIGHT, CROWBAR, WATER, FLASHLIGHT]
	_check(EquipmentSystem.initialize(state, excessive) == &"carry_slots_full", "A fourth initial item is rejected")
	_check(state.equipment_slots.size() == 3 and state.equipment_slots.all(func(item: EquipmentInstance) -> bool: return item == null), "Over-capacity initialization has no partial inventory writes")
	var invalid: EquipmentData = WATER.duplicate(false) as EquipmentData
	invalid.capacity = 0
	var malformed: Array[EquipmentData] = [FLASHLIGHT, CROWBAR, invalid]
	_check(EquipmentSystem.initialize(state, malformed) == &"invalid_equipment_definition", "A malformed later definition rejects the whole initial loadout")
	_check(state.equipment_slots.all(func(item: EquipmentInstance) -> bool: return item == null), "Valid items are not partially equipped before a later validation failure")
	var definitions: Array[EquipmentData] = [FLASHLIGHT, CROWBAR, WATER]
	_check(EquipmentSystem.initialize(state, definitions).is_empty(), "Three authored definitions fit in the three slots")
	for index: int in range(3):
		_check(state.equipment_slots[index].definition == definitions[index] and state.equipment_slots[index].remaining_uses == definitions[index].capacity, "Each occupied slot has a runtime counter and shared static definition")
	var original: Array[EquipmentInstance] = state.equipment_slots.duplicate()
	_check(EquipmentSystem.initialize(state, definitions) == &"equipment_already_initialized" and state.equipment_slots == original, "Reinitialization cannot silently refill or replace carried items")
	var other: RunState = RunState.new()
	EquipmentSystem.initialize(other, definitions)
	state.equipment_slots[0].remaining_uses = 2
	_check(state.equipment_slots[0] != other.equipment_slots[0] and other.equipment_slots[0].remaining_uses == 3 and FLASHLIGHT.capacity == 3, "Two runs never share battery state or mutate EquipmentData")
	_check(state.deck_state.get_card_count() == 0 and other.deck_state.get_card_count() == 0, "Equipping definitions creates no cards")


func _test_light_and_observation() -> void:
	var manager: TurnManager = _manager()
	var state: RunState = manager.run_state
	var floor: FloorState = state.floor_state
	var before_cards: Array = _deck_snapshot(state)
	var notifications: Array[Dictionary] = []
	manager.state_changed.connect(func() -> void: notifications.append(_snapshot(manager)))
	_check(RuleResolver.card_ap_cost(OBSERVE, state, LEVEL_6) == 2, "Unlit Level 6 retains the Phase 6 first-observation surcharge")
	var result: ActionResult = manager.request_use_equipment(0)
	_check(result.success and result.ap_spent == 1 and state.ap == 2 and state.equipment_slots[0].remaining_uses == 2, "Flashlight success commits one AP and one battery together")
	_check(floor.light_active and result.light_activated and RuleResolver.card_ap_cost(OBSERVE, state, LEVEL_6) == 1, "Equipment light removes the darkness observation surcharge")
	_check(_deck_snapshot(state) == before_cards and result.card_played == null, "Flashlight neither draws a card nor moves one between piles")
	_check(notifications.size() == 1 and notifications[0] == _snapshot(manager), "State notification observes the completed AP/battery/light commit")
	var before: Dictionary = _snapshot(manager)
	_reject(manager.request_use_equipment(0), &"light_already_active", manager, before)
	_check(notifications.size() == 1, "Rejected repeat activation emits no state-change signal")
	var observe: CardInstance = state.deck_state.hand[0]
	result = manager.request_play_card(observe)
	_check(result.success and result.ap_spent == 1 and result.cognition_delta == 1 and floor.cognition == 1, "Lit Observe directly verifies the existing event Insight without prior evidence")
	_check(state.deck_state.discard_pile.has(observe) and not state.deck_state.hand.has(observe), "Equipment-supported action still obeys the real card lifecycle")
	manager.request_play_card(state.deck_state.hand[0])
	_check(floor.cognition == 1 and floor.discovered_insight_ids.size() == 1, "Light and repeated observation cannot duplicate an Insight")
	manager.end_turn()
	_check(not floor.light_active and state.equipment_slots[0].remaining_uses == 2 and RuleResolver.card_ap_cost(OBSERVE, state, LEVEL_6) == 2, "Turn end expires light without refilling or charging equipment again")
	manager.free()


func _test_empty_battery() -> void:
	var manager: TurnManager = _manager()
	for remaining: int in [2, 1, 0]:
		var result: ActionResult = manager.request_use_equipment(0)
		_check(result.success and manager.run_state.equipment_slots[0].remaining_uses == remaining and manager.run_state.floor_state.light_active, "Each successful flashlight activation spends exactly one finite battery")
		manager.end_turn()
	var before: Dictionary = _snapshot(manager)
	_reject(manager.request_use_equipment(0), &"equipment_depleted", manager, before)
	_check(not manager.run_state.floor_state.light_active and FLASHLIGHT.capacity == 3, "Empty flashlight cannot relight the floor or change shared capacity")
	manager.free()


func _test_crowbar_and_durability() -> void:
	var manager: TurnManager = _manager()
	var before_cards: Array = _deck_snapshot(manager.run_state)
	var entity: EntityInstance = manager.run_state.floor_state.entity
	for expected_hp: int in [14, 10, 6]:
		var result: ActionResult = manager.request_use_equipment(1)
		_check(result.success and result.entity_damage == 4 and result.equipment_uses_spent == 1 and entity.hp == expected_hp, "Crowbar resolves four damage through the same entity pipeline")
		_check(_deck_snapshot(manager.run_state) == before_cards, "Equipment attack needs no attack card and never touches a pile")
	_check(manager.run_state.ap == 0 and manager.run_state.equipment_slots[1].remaining_uses == 0, "Three successful attacks exhaust durability and normal AP")
	var before: Dictionary = _snapshot(manager)
	_reject(manager.request_use_equipment(1), &"equipment_depleted", manager, before)
	manager.end_turn()
	before = _snapshot(manager)
	_reject(manager.request_use_equipment(1), &"equipment_depleted", manager, before)
	_check(CROWBAR.capacity == 3 and CROWBAR.effect_value == 4, "Shared crowbar definition remains unchanged after damage and breakage")
	manager.free()
	manager = _manager(LEVEL_0)
	before = _snapshot(manager)
	_reject(manager.request_use_equipment(1), &"no_active_entity", manager, before)
	_reject(manager.request_use_equipment(0), &"light_not_needed", manager, before)
	manager.free()
	manager = _manager()
	entity = manager.run_state.floor_state.entity
	entity.hp = 4
	var lethal: ActionResult = manager.request_use_equipment(1)
	_check(lethal.entity_defeated and not entity.alive and entity.state == &"DEFEATED", "Equipment damage shares the normal one-time defeat transition")
	before = _snapshot(manager)
	_reject(manager.request_use_equipment(1), &"no_active_entity", manager, before)
	_check(manager.run_state.equipment_slots[1].remaining_uses == 2, "Attack against a defeated target cannot spend another durability")
	manager.free()


func _test_recovery() -> void:
	var manager: TurnManager = _manager()
	manager.run_state.stress = 4
	manager.run_state.player_hp = 20
	var cards_before: Array = _deck_snapshot(manager.run_state)
	var result: ActionResult = manager.request_use_equipment(2)
	_check(result.success and result.stress_restored == 2 and result.hp_restored == 0 and manager.run_state.stress == 2 and manager.run_state.player_hp == 20, "Almond Water follows the GDD Stress reduction without unconditional healing")
	_check(manager.run_state.ap == 2 and manager.run_state.equipment_slots[2].remaining_uses == 0 and _deck_snapshot(manager.run_state) == cards_before, "The consumable spends one AP and its only carried charge, not a card")
	var before: Dictionary = _snapshot(manager)
	_reject(manager.request_use_equipment(2), &"equipment_depleted", manager, before)
	manager.free()
	manager = _manager()
	manager.run_state.stress = 7
	manager.run_state.player_hp = 29
	result = manager.request_use_equipment(2)
	_check(result.stress_restored == 2 and result.hp_restored == 1 and manager.run_state.stress == 5 and manager.run_state.player_hp == 30, "Pre-use Stress threshold grants the authored extra HP")
	manager.free()
	manager = _manager()
	manager.run_state.stress = 8
	result = manager.request_use_equipment(2)
	_check(result.hp_restored == 0 and manager.run_state.player_hp == RunState.MAX_PLAYER_HP, "Recovery cannot exceed maximum HP")
	manager.free()
	manager = _manager()
	manager.run_state.stress = 1
	result = manager.request_use_equipment(2)
	_check(result.stress_restored == 1 and manager.run_state.stress == 0, "Stress recovery clamps at zero")
	manager.free()
	manager = _manager()
	manager.run_state.player_hp = 20
	before = _snapshot(manager)
	_reject(manager.request_use_equipment(2), &"nothing_to_restore", manager, before)
	_check(WATER.capacity == 1 and WATER.effect_value == 2 and WATER.conditional_heal == 1, "Consumable use never edits the shared recovery definition")
	manager.free()


func _test_floor_persistence() -> void:
	var manager: TurnManager = _manager(LEVEL_0)
	var state: RunState = manager.run_state
	var equipment: Array[EquipmentInstance] = state.equipment_slots.duplicate()
	var cards_before: Array = _deck_snapshot(state)
	manager.request_exploration(&"cutout_forced")
	_check(state.floor_state.floor_id == &"floor_level_6" and state.equipment_slots == equipment, "Zero-to-six transition preserves the exact carried instances")
	var rng_before: int = state.rng.state
	manager.request_use_equipment(0)
	manager.request_use_equipment(1)
	manager.request_use_equipment(2)
	_check(state.equipment_slots[0].remaining_uses == 2 and state.equipment_slots[1].remaining_uses == 2 and state.equipment_slots[2].remaining_uses == 0, "All three uses persist in run inventory")
	_check(state.floor_state.light_active and state.rng.state == rng_before and _deck_snapshot(state) == cards_before, "Equipment effects consume no hidden RNG or card movements")
	manager.request_exploration(&"cutout_forced")
	_check(manager.floor_data.is_placeholder and not state.floor_state.light_active and state.equipment_slots == equipment, "Leaving six expires floor-local light while preserving inventory")
	_check(state.equipment_slots[0].remaining_uses == 2 and state.equipment_slots[1].remaining_uses == 2 and state.equipment_slots[2].remaining_uses == 0, "Destination entry cannot refill equipment or consumables")
	var before: Dictionary = _snapshot(manager)
	_reject(manager.request_use_equipment(0), &"floor_inactive", manager, before)
	manager.free()


func _test_transactional_failures() -> void:
	var manager: TurnManager = _manager()
	var before: Dictionary = _snapshot(manager)
	_reject(manager.request_use_equipment(-1), &"invalid_equipment_slot", manager, before)
	_reject(manager.request_use_equipment(3), &"invalid_equipment_slot", manager, before)
	_reject(RuleResolver.resolve_equipment(null, manager.run_state, LEVEL_6), &"invalid_command", manager, before)
	_reject(RuleResolver.resolve_equipment(UseEquipmentCommand.new(0), manager.run_state, LEVEL_0), &"invalid_floor_context", manager, before)
	manager.run_state.stress = 8
	manager.run_state.ap = 0
	before = _snapshot(manager)
	for index: int in range(3):
		_reject(manager.request_use_equipment(index), &"insufficient_ap", manager, before)
	manager.run_state.ap = 3
	manager.run_state.equipment_slots[0].remaining_uses = 4
	before = _snapshot(manager)
	_reject(manager.request_use_equipment(0), &"invalid_equipment_state", manager, before)
	manager.run_state.equipment_slots[0].remaining_uses = 3
	manager.run_state.equipment_slots[1] = manager.run_state.equipment_slots[0]
	before = _snapshot(manager)
	_reject(manager.request_use_equipment(0), &"invalid_equipment_state", manager, before)
	manager.free()
	manager = _manager()
	manager.run_state.equipment_slots.append(EquipmentInstance.new(FLASHLIGHT))
	before = _snapshot(manager)
	_reject(manager.request_use_equipment(0), &"invalid_equipment_state", manager, before)
	manager.free()
	manager = _manager()
	var invalid: EquipmentData = FLASHLIGHT.duplicate(false) as EquipmentData
	invalid.ap_cost = -1
	manager.run_state.equipment_slots[0].definition = invalid
	before = _snapshot(manager)
	_reject(manager.request_use_equipment(0), &"invalid_equipment_definition", manager, before)
	manager.free()
	manager = _manager()
	manager.run_state.player_hp = 0
	before = _snapshot(manager)
	_reject(manager.request_use_equipment(2), &"run_ended", manager, before)
	manager.free()
	manager = TurnManager.new()
	manager.floor_data = LEVEL_6
	root.add_child(manager)
	before = _snapshot(manager)
	_reject(manager.request_use_equipment(0), &"equipment_unavailable", manager, before)
	manager.free()


func _test_main_ui() -> void:
	var main: Control = MAIN.instantiate() as Control
	root.add_child(main)
	var manager: TurnManager = main.get_node("TurnManager") as TurnManager
	var slots: VBoxContainer = main.get_node("%EquipmentSlots") as VBoxContainer
	var hand: VBoxContainer = main.get_node("%Hand") as VBoxContainer
	var tabs: TabContainer = main.get_node("%FloorTabs") as TabContainer
	_check(slots.get_child_count() == 3 and tabs.get_tab_title(3) == "携带装备", "UI displays exactly three carry slots in its Chinese equipment tab")
	_check((slots.get_child(0).get_node("Info") as Label).text.contains("手电筒") and (slots.get_child(0).get_node("Info") as Label).text.contains("电量：3／3"), "Flashlight slot displays name and runtime battery")
	_check((slots.get_child(1).get_node("Info") as Label).text.contains("耐久：3／3") and (slots.get_child(2).get_node("Info") as Label).text.contains("次数：1／1"), "Other slots display the correct durability and consumable counter")
	_check(not hand.is_ancestor_of(slots) and manager.run_state.deck_state.get_card_count() == 10, "Carry UI is outside the hand and does not enlarge the demo deck")
	var before: Dictionary = _snapshot(manager)
	_use_button(slots, 0).pressed.emit()
	_check(_snapshot(manager) == before and (main.get_node("%Status") as Label).text.contains("这里不需要额外照明"), "UI forwards an invalid light request without consuming battery")
	(main.get_node("%ForcedCutOut") as Button).pressed.emit()
	tabs.current_tab = 3
	_use_button(slots, 0).pressed.emit()
	_check(manager.run_state.ap == 2 and manager.run_state.equipment_slots[0].remaining_uses == 2 and (hand.get_child(0) as Button).text.contains("行动点：1"), "Flashlight button updates the real counter and actual card cost")
	(hand.get_child(0) as Button).pressed.emit()
	_check(manager.run_state.cognition == 1 and manager.run_state.ap == 1, "Real hand uses the data-authored light confirmation route")
	_use_button(slots, 1).pressed.emit()
	_check(manager.run_state.floor_state.entity.hp == 14 and manager.run_state.equipment_slots[1].remaining_uses == 2 and manager.run_state.ap == 0, "Crowbar button resolves shared AP, damage and durability")
	before = _snapshot(manager)
	_use_button(slots, 1).pressed.emit()
	_check(_snapshot(manager) == before and (main.get_node("%Status") as Label).text.contains("行动点不足"), "Failed UI equipment use changes neither durability nor target")
	(main.get_node("%EndTurn") as Button).pressed.emit()
	_use_button(slots, 2).pressed.emit()
	_check(manager.run_state.stress == 0 and manager.run_state.equipment_slots[2].remaining_uses == 0 and _use_button(slots, 2).disabled, "Consumed Almond Water is visibly empty and cannot normally be clicked again")
	before = _snapshot(manager)
	_use_button(slots, 2).pressed.emit()
	_check(_snapshot(manager) == before, "Bypassing the disabled consume button is still rejected in the domain")
	await process_frame
	await process_frame
	_check(main.get_viewport_rect().encloses(_use_button(slots, 2).get_global_rect()), "All three equipment action rows fit in the viewport")
	await process_frame
	main.free()
	main = MAIN.instantiate() as Control
	manager = main.get_node("TurnManager") as TurnManager
	manager.starting_equipment = []
	root.add_child(main)
	slots = main.get_node("%EquipmentSlots") as VBoxContainer
	for index: int in range(3):
		_check(_use_button(slots, index).disabled and (slots.get_child(index).get_node("Info") as Label).text.contains("空"), "Empty carry slots remain visible and disabled")
	await process_frame
	main.free()


func _use_button(slots: VBoxContainer, index: int) -> Button:
	return slots.get_child(index).get_node("UseEquipment") as Button


func _deck_snapshot(state: RunState) -> Array:
	var result: Array = []
	for pile: Array[CardInstance] in [state.deck_state.hand, state.deck_state.draw_pile, state.deck_state.discard_pile]:
		var values: Array = []
		for card: CardInstance in pile:
			values.append([card.get_instance_id(), card.definition.get_instance_id(), card.definition.id, card.definition.ap_cost, card.definition.effect_type, card.definition.effect_value, card.definition.exploration_action])
		result.append(values)
	return result


func _snapshot(manager: TurnManager) -> Dictionary:
	var state: RunState = manager.run_state
	var floor: FloorState = state.floor_state
	var inventory: Array = []
	for item: EquipmentInstance in state.equipment_slots:
		if item == null:
			inventory.append(null)
			continue
		var data: EquipmentData = item.definition
		inventory.append([item.get_instance_id(), item.remaining_uses, data.get_instance_id(), data.id, data.display_name, data.action_name, data.counter_kind, data.capacity, data.ap_cost, data.effect_type, data.effect_value, data.conditional_heal, data.heal_stress_threshold, data.tags.duplicate()])
	var nodes: Array = []
	for node: ResourceNode in floor.resource_nodes:
		nodes.append([node.get_instance_id(), node.node_id, node.status])
	var entity: EntityInstance = floor.entity
	var attempt: CutOutAttemptResult = state.last_cutout_attempt
	return {
		"hp": state.player_hp, "stress": state.stress, "supply": state.supply, "ap": state.ap,
		"turn": state.turn_number, "rng": state.rng.state, "floor": floor.get_instance_id(),
		"data": manager.floor_data.get_instance_id(), "floor_turn": floor.turn_count,
		"equipment": inventory, "cards": _deck_snapshot(state), "deck_id": state.deck_state.get_instance_id(), "resources": nodes,
		"light": floor.light_active, "dark_observation": floor.dark_observation_used,
		"entity": [entity.get_instance_id(), entity.hp, entity.max_hp, entity.state, entity.intent] if entity != null else [],
		"block": floor.player_block, "threat": floor.threat, "cognition": floor.cognition,
		"flags": floor.floor_flags.duplicate(), "insights": floor.discovered_insight_ids.duplicate(),
		"fresh": floor.remaining_fresh_events.duplicate(), "seen": floor.seen_event_ids.duplicate(),
		"event": floor.current_event_id,
		"interactions": floor.current_event.completed_interactions.duplicate() if floor.current_event != null else [],
		"information": floor.current_event.known_information.duplicate() if floor.current_event != null else [],
		"resolved": floor.current_event.resolved if floor.current_event != null else false,
		"stability": floor.cutout_state.stability, "knowledge": floor.cutout_state.destination_knowledge,
		"candidates": floor.cutout_state.destination_candidates.duplicate(),
		"attempt": [attempt.get_instance_id(), attempt.attempt_type, attempt.source_floor_id, attempt.destination_id, attempt.roll, attempt.succeeded] if attempt != null else [],
	}


func _reject(result: ActionResult, reason: StringName, manager: TurnManager, before: Dictionary) -> void:
	_check(not result.success and result.failure_reason == reason, "Rejected equipment request reports expected reason: %s" % reason)
	_check(_snapshot(manager) == before, "Failed equipment use preserves inventory/definitions, HP/Stress, AP, target, floor, cards and RNG")
	_check(result.ap_spent == 0 and result.equipment_used == null and result.equipment_uses_spent == 0 and not result.light_activated and result.hp_restored == 0 and result.stress_restored == 0 and result.entity_damage == 0, "Failed result contains no equipment or recovery effects")


func _check(condition: bool, description: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		push_error("[TEST] %s" % description)
