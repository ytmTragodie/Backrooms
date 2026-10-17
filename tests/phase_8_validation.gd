extends SceneTree

const LEVEL_0: FloorData = preload("res://data/floors/floor_level_0.tres")
const LEVEL_6: FloorData = preload("res://data/floors/floor_level_6.tres")
const SMILER: EntityData = preload("res://data/entities/entity_smiler.tres")
const LIGHT_RULE: InsightData = preload("res://data/insights/insight_level6_light_attracts.tres")
const FLASHLIGHT: EquipmentData = preload("res://data/equipment/equip_flashlight.tres")
const ATTACK: CardData = preload("res://data/cards/card_attack.tres")
const DEFEND: CardData = preload("res://data/cards/card_defend.tres")
const RUN: CardData = preload("res://data/cards/card_run.tres")
const MAIN: PackedScene = preload("res://scenes/main/Main.tscn")

var _checks: int = 0
var _failures: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_common_model()
	_test_avoidance()
	_test_repeated_light()
	_test_correction()
	_test_insight_routes()
	_test_damage_and_run()
	_test_followup()
	_test_failures()
	await _test_main_ui()
	await process_frame
	if _failures == 0:
		print("[TEST] PASS Phase 8: %d checks (Smiler, shared HP, light states, withdrawal, unique Insight, alternate route, transactions, Hound, UI)" % _checks)
	else:
		push_error("[TEST] FAIL Phase 8: %d of %d checks failed" % [_failures, _checks])
	quit(0 if _failures == 0 else 1)


func _smiler_floor() -> FloorData:
	var data: FloorData = LEVEL_6.duplicate(false) as FloorData
	data.entry_entity = SMILER
	data.followup_entity = null
	return data


func _manager(data: FloorData = null, cards: Array[CardData] = [ATTACK, DEFEND, RUN, ATTACK, DEFEND]) -> TurnManager:
	var manager: TurnManager = TurnManager.new()
	manager.floor_data = data if data != null else _smiler_floor()
	manager.starting_equipment.assign([FLASHLIGHT])
	manager.starter_deck = DeckData.new()
	manager.starter_deck.cards.assign(cards)
	root.add_child(manager)
	return manager


func _play(manager: TurnManager, definition: CardData) -> ActionResult:
	for card: CardInstance in manager.run_state.deck_state.hand:
		if card.definition == definition:
			return manager.request_play_card(card)
	_check(false, "Fixture must have the requested real card in hand")
	return ActionResult.new()


func _test_common_model() -> void:
	var entity: EntityInstance = EntitySystem.spawn(SMILER)
	var other: EntityInstance = EntitySystem.spawn(SMILER)
	_check(entity is EntityInstance and entity.entity_id == &"entity_smiler", "Smiler uses the common runtime EntityInstance")
	_check(entity.hp == 120 and entity.max_hp == 120 and entity.alive and entity.active, "Rule-focused entity still has technical HP")
	_check(entity.state == &"HIDDEN" and entity.intent == &"remain_hidden", "Smiler starts with a deterministic readable intent")
	entity.hp -= 4
	_check(other.hp == 120 and SMILER.max_hp == 120 and other != entity, "Independent HP never mutates shared EntityData")
	_check(LEVEL_6.followup_entity == SMILER and LEVEL_6.landmark_insight == SMILER.rule_insight, "Entity and independent landmark reference the same unique Insight")
	_check(LEVEL_6.find_entity(&"entity_hound") == LEVEL_6.entry_entity and LEVEL_6.find_entity(&"entity_smiler") == SMILER and LEVEL_6.find_insight(LIGHT_RULE.id) == LIGHT_RULE, "Floor resolves authored definitions without UI or ID branches")


func _test_avoidance() -> void:
	var manager: TurnManager = _manager()
	var state: RunState = manager.run_state
	var floor: FloorState = state.floor_state
	var entity: EntityInstance = floor.entity
	var deck: DeckState = state.deck_state
	var result: ActionResult = manager.end_turn()
	_check(result.success and result.intent_resolved == &"remain_hidden" and result.player_damage == 0, "Remaining in darkness avoids escalation and damage")
	_check(entity.state == &"WITHDRAWN" and not entity.active and entity.alive and entity.hp == 120, "Encounter resolves through withdrawal without killing")
	_check(state.cognition == 0 and result.insight_ids.is_empty(), "No experiment means no automatic light-rule Insight")
	_check(state.floor_state == floor and state.deck_state == deck and state.turn_number == 2 and state.ap == 3, "Avoidance advances only the normal exploration turn")
	var hp: int = state.player_hp
	manager.end_turn()
	_check(state.player_hp == hp and floor.entity == entity and entity.intent == &"none", "Withdrawn entity stays inactive without respawning")
	manager.free()


func _test_repeated_light() -> void:
	var manager: TurnManager = _manager()
	var state: RunState = manager.run_state
	var floor: FloorState = state.floor_state
	var entity: EntityInstance = floor.entity
	var result: ActionResult = manager.request_use_equipment(0)
	_check(result.success and entity.state == &"OBSERVING" and entity.intent == &"watch_light" and floor.threat == 0, "First strong light draws observation without surprise damage")
	var before: Dictionary = _snapshot(manager)
	_reject(manager.request_use_equipment(0), &"light_already_active", manager, before)
	result = manager.end_turn()
	_check(result.player_damage == 0 and entity.state == &"OBSERVING" and not floor.light_active, "First lit end turn keeps the warning, then expires temporary light")
	result = manager.request_use_equipment(0)
	_check(result.success and entity.state == &"AGITATED" and entity.intent == &"warn_light" and floor.threat == 1, "Next-turn strong light escalates state and reasoned Threat")
	_check(result.threat_reason == &"repeated_strong_light" and state.cognition == 0, "Escalation is logged and not an automatic Cognition reward")
	result = manager.end_turn()
	_check(result.player_damage == 0 and entity.state == &"ATTACKING" and entity.intent == &"light_strike", "Ignoring the light warning prepares the published attack before damage")
	manager.request_use_equipment(0)
	_play(manager, DEFEND)
	result = manager.end_turn()
	_check(result.intent_resolved == &"light_strike" and result.damage_blocked == 4 and result.player_damage == 2 and state.player_hp == 28, "Lit attack uses common damage/block pipeline with deterministic six damage")
	_check(entity.state == &"ATTACKING" and floor.player_block == 0 and floor.threat == 3, "Entity rule and overstay Threat coexist without Hound stagger states")
	_check(state.equipment_slots[0].remaining_uses == 0 and state.turn_number == 4 and state.ap == 3, "Only three finite activations and one normal turn lifecycle are used")
	result = manager.end_turn()
	_check(result.player_damage == 0 and entity.state == &"WITHDRAWN" and entity.hp == 120 and state.player_hp == 28, "With an exhausted flashlight, darkness still safely resolves the encounter")
	_check(state.cognition == 1 and floor.discovered_insight_ids == [LIGHT_RULE.id] and floor.cutout_state.stability == 1, "Observed withdrawal confirms one unique Insight and its preparation gain")
	manager.free()
	manager = _manager(null, [DEFEND, DEFEND, DEFEND, DEFEND, DEFEND])
	manager.request_use_equipment(0)
	manager.end_turn()
	manager.request_use_equipment(0)
	manager.end_turn()
	manager.request_use_equipment(0)
	_play(manager, DEFEND)
	_play(manager, DEFEND)
	result = manager.end_turn()
	_check(result.damage_blocked == 6 and result.player_damage == 0 and manager.run_state.player_hp == 30, "Ordinary stacked defense can fully prevent Smiler damage")
	_check(manager.run_state.floor_state.entity.state == &"ATTACKING" and manager.run_state.floor_state.player_block == 0, "Full block expires normally without converting Smiler into a Hound stagger")
	manager.free()


func _test_correction() -> void:
	# 包括零 AP 的第三次暴露：纠正行为不能依赖再抽一张牌或剩余电量。
	for exposures: int in [1, 2, 3]:
		var manager: TurnManager = _manager()
		var state: RunState = manager.run_state
		for index: int in range(exposures):
			_check(manager.request_use_equipment(0).success, "Successful strong-light exposure is a normal equipment command")
			var ap: int = state.ap
			_check(manager.request_exploration(&"extinguish_light").success and state.ap == ap, "Extinguishing costs no extra AP or battery")
		var before: Dictionary = _snapshot(manager)
		_reject(manager.request_exploration(&"extinguish_light"), &"light_not_active", manager, before)
		var result: ActionResult = manager.end_turn()
		_check(result.player_damage == 0 and state.floor_state.entity.state == &"WITHDRAWN" and state.player_hp == 30, "Extinguishing prevents attack and resolves every escalation state")
		_check(state.floor_state.entity.hp == 120 and state.cognition == 1 and result.insight_ids == [LIGHT_RULE.id], "Correct behavior gives understanding without dealing damage")
		_check(state.equipment_slots[0].remaining_uses == 3 - exposures, "Correct behavior never refills or further spends battery")
		var stability: int = state.floor_state.cutout_state.stability
		result = manager.end_turn()
		_check(result.insight_ids.is_empty() and state.cognition == 1 and state.floor_state.cutout_state.stability == stability, "Later turns never duplicate the Insight or preparation reward")
		manager.free()
	var manager: TurnManager = _manager()
	manager.request_use_equipment(0)
	manager.end_turn()
	var result: ActionResult = manager.end_turn()
	_check(result.player_damage == 0 and manager.run_state.floor_state.entity.state == &"WITHDRAWN" and manager.run_state.cognition == 1, "Simply skipping light for a full turn is also a correct route")
	manager.free()


func _test_insight_routes() -> void:
	var data: FloorData = _smiler_floor()
	data.entry_entity = null
	data.fresh_events = []
	var manager: TurnManager = _manager(data)
	manager.run_state.equipment_slots[0].remaining_uses = 0
	var result: ActionResult = manager.request_exploration(&"study_landmark")
	_check(result.success and result.ap_spent == 1 and manager.run_state.cognition == 1 and manager.run_state.floor_state.cutout_state.stability == 1, "Landmark confirms the same Insight without events, entity, or battery")
	var before: Dictionary = _snapshot(manager)
	_reject(manager.request_exploration(&"study_landmark"), &"insight_known", manager, before)
	manager.run_state.ap = 0
	_check(manager.request_exploration(&"cutout_forced").success and manager.floor_data.is_placeholder, "Missing encounter/events and empty equipment never block exit")
	manager.free()
	manager = _manager()
	manager.request_exploration(&"study_landmark")
	manager.request_use_equipment(0)
	manager.request_exploration(&"extinguish_light")
	result = manager.end_turn()
	_check(result.insight_ids.is_empty() and manager.run_state.cognition == 1 and manager.run_state.floor_state.cutout_state.stability == 1, "Entity route after landmark cannot reward the same Insight twice")
	_check(manager.run_state.floor_state.entity.state == &"WITHDRAWN", "Already-known Insight does not prevent behavioral resolution")
	manager.free()
	manager = _manager()
	manager.request_use_equipment(0)
	manager.request_exploration(&"extinguish_light")
	manager.end_turn()
	before = _snapshot(manager)
	_reject(manager.request_exploration(&"study_landmark"), &"insight_known", manager, before)
	manager.free()
	manager = _manager()
	manager.run_state.floor_state.cognition = 5
	manager.request_use_equipment(0)
	manager.request_exploration(&"extinguish_light")
	result = manager.end_turn()
	_check(result.cognition_delta == 0 and manager.run_state.cognition == 5 and manager.run_state.floor_state.discovered_insight_ids.has(LIGHT_RULE.id), "Unique knowledge is recorded even at the Cognition cap, without exceeding it")
	manager.free()


func _test_damage_and_run() -> void:
	var manager: TurnManager = _manager()
	var state: RunState = manager.run_state
	var result: ActionResult = _play(manager, RUN)
	_check(result.success and state.floor_state.entity.state == &"HIDDEN" and state.threat == 1, "Run keeps normal Threat but does not apply Hound chase logic to a different profile")
	result = _play(manager, ATTACK)
	_check(result.success and state.floor_state.entity.hp == 116 and state.floor_state.entity.state == &"ATTACKING" and state.ap == 1, "Common attack damages high HP and provokes aggressive intent")
	_check(state.deck_state.get_card_count() == 5 and state.cognition == 0, "An attack remains a card action and grants no behavioral Insight")
	manager.end_turn()
	_check(state.floor_state.entity.state == &"WITHDRAWN" and state.player_hp == 30 and state.cognition == 0, "Provoked attack still respects darkness but does not invent light-rule evidence")
	manager.free()
	manager = _manager()
	manager.run_state.floor_state.entity.hp = 4
	result = _play(manager, ATTACK)
	_check(result.entity_defeated and manager.run_state.floor_state.entity.hp == 0 and not manager.run_state.floor_state.entity.alive, "Technical edge-case kill uses the common defeat model")
	_check(manager.run_state.cognition == 0, "Killing does not impersonate understanding the light rule")
	var before: Dictionary = _snapshot(manager)
	_reject(_play(manager, ATTACK), &"no_active_entity", manager, before)
	_check(manager.request_exploration(&"study_landmark").success and manager.run_state.cognition == 1, "Even an early kill retains the alternate knowledge route")
	manager.free()


func _test_followup() -> void:
	var manager: TurnManager = _manager(LEVEL_6, [ATTACK, ATTACK, ATTACK, ATTACK, ATTACK])
	var state: RunState = manager.run_state
	var before: Dictionary = _snapshot(manager)
	_reject(manager.request_exploration(&"encounter"), &"encounter_unavailable", manager, before)
	var old_entity: EntityInstance = state.floor_state.entity
	for index: int in range(3):
		_play(manager, ATTACK)
	manager.end_turn()
	_play(manager, ATTACK)
	_play(manager, ATTACK)
	_check(not old_entity.alive and old_entity.hp == 0 and state.player_hp == 26, "Hound retains normal HP, attack reactions, damage and defeat")
	var floor: FloorState = state.floor_state
	var deck: DeckState = state.deck_state
	var rng: int = state.rng.state
	var hand: Array[CardInstance] = deck.hand.duplicate()
	var result: ActionResult = manager.request_exploration(&"encounter")
	_check(result.success and result.ap_spent == 1 and state.ap == 0 and result.entity_spawned == floor.entity, "Followup encounter commits through the command pipeline at normal AP cost")
	_check(floor.entity.entity_id == SMILER.id and floor.entity.hp == 120 and floor.entity.state == &"HIDDEN" and floor.entity != old_entity, "Only an inactive encounter can be replaced by the next authored definition")
	_check(state.floor_state == floor and state.deck_state == deck and deck.hand == hand and state.rng.state == rng and state.turn_number == 2, "Encounter does not reset floor, AP, hand, turn or RNG")
	manager.end_turn()
	before = _snapshot(manager)
	_reject(manager.request_exploration(&"encounter"), &"encounter_unavailable", manager, before)
	_check(manager.request_exploration(&"cutout_forced").success and manager.floor_data.is_placeholder, "Resolving Smiler is followed by the existing cut-out boundary")
	manager.free()
	manager = _manager(LEVEL_6)
	manager.run_state.floor_state.entity.hp = 4
	_play(manager, ATTACK)
	manager.request_use_equipment(0)
	result = manager.request_exploration(&"encounter")
	_check(result.success and manager.run_state.floor_state.entity.state == &"OBSERVING", "Entering an encounter with an existing light correctly counts exposure")
	manager.free()
	manager = _manager(LEVEL_6)
	old_entity = manager.run_state.floor_state.entity
	manager.end_turn()
	_play(manager, DEFEND)
	manager.end_turn()
	_play(manager, RUN)
	_check(old_entity.alive and old_entity.state == &"DISENGAGED", "Normal Hound evade route remains available")
	result = manager.request_exploration(&"encounter")
	_check(result.success and old_entity.hp == 18 and manager.run_state.floor_state.entity.entity_id == SMILER.id, "Followup can be reached through evasion without requiring a Hound kill")
	manager.free()


func _test_failures() -> void:
	var manager: TurnManager = _manager()
	manager.run_state.ap = 0
	var before: Dictionary = _snapshot(manager)
	_reject(manager.request_use_equipment(0), &"insufficient_ap", manager, before)
	_reject(manager.request_exploration(&"study_landmark"), &"insufficient_ap", manager, before)
	manager.run_state.ap = 3
	manager.run_state.equipment_slots[0].remaining_uses = 0
	before = _snapshot(manager)
	_reject(manager.request_use_equipment(0), &"equipment_depleted", manager, before)
	manager.run_state.floor_state.entity.state = &"CHASING"
	manager.run_state.floor_state.entity.intent = &"lunge"
	before = _snapshot(manager)
	_reject(manager.end_turn(), &"invalid_entity_state", manager, before)
	manager.free()
	var data: FloorData = _smiler_floor()
	data.entry_entity = SMILER.duplicate(false) as EntityData
	data.entry_entity.rule_insight = LIGHT_RULE.duplicate(false) as InsightData
	manager = _manager(data)
	data.entry_entity.rule_insight.cutout_stability = -1
	before = _snapshot(manager)
	_reject(manager.request_use_equipment(0), &"invalid_insight_definition", manager, before)
	manager.free()
	data = LEVEL_0.duplicate(false) as FloorData
	var target: FloorData = LEVEL_6.duplicate(false) as FloorData
	target.followup_entity = SMILER.duplicate(false) as EntityData
	target.followup_entity.max_hp = 0
	data.cutout_destinations = [target]
	manager = _manager(data)
	before = _snapshot(manager)
	_reject(manager.request_exploration(&"cutout_forced"), &"invalid_entity_definition", manager, before)
	_check(SMILER.max_hp == 120 and LIGHT_RULE.cutout_stability == 1, "Malformed content fixtures do not mutate shared prototype definitions")
	manager.free()
	manager = _manager()
	manager.request_use_equipment(0)
	manager.request_exploration(&"extinguish_light")
	manager.request_use_equipment(0)
	manager.request_exploration(&"extinguish_light")
	manager.request_use_equipment(0)
	manager.run_state.player_hp = 2
	var ap: int = manager.run_state.ap
	var result: ActionResult = manager.end_turn()
	_check(result.player_damage == 2 and manager.run_state.player_hp == 0 and manager.run_state.ap == ap and manager.run_state.turn_number == 1, "Lethal Smiler intent respects the existing stop-run boundary without refilling AP")
	before = _snapshot(manager)
	_reject(manager.request_exploration(&"extinguish_light"), &"run_ended", manager, before)
	manager.free()


func _test_main_ui() -> void:
	var main: Control = MAIN.instantiate() as Control
	root.add_child(main)
	var manager: TurnManager = main.get_node("TurnManager") as TurnManager
	var encounter: Button = main.get_node("%EncounterAction") as Button
	var extinguish: Button = main.get_node("%ExtinguishLight") as Button
	var landmark: Button = main.get_node("%LandmarkAction") as Button
	_check(not encounter.visible and not landmark.visible and extinguish.disabled, "Non-configured floor does not offer followup or landmark content")
	(main.get_node("%ForcedCutOut") as Button).pressed.emit()
	_check(encounter.visible and encounter.disabled and landmark.visible, "Active Hound prevents starting a second encounter")
	# 使用原主场景与默认种子完成猎犬；不用直接写 HP 来绕开真实入口。
	for turn: int in range(10):
		if not manager.run_state.floor_state.entity.active:
			break
		var hand: Array[CardInstance] = manager.run_state.deck_state.hand.duplicate()
		for card: CardInstance in hand:
			if manager.run_state.floor_state.entity.active and manager.run_state.ap >= card.definition.ap_cost and card.definition.effect_type in [CardData.EffectType.ATTACK, CardData.EffectType.PLACEHOLDER_DAMAGE]:
				manager.request_play_card(card)
		hand = manager.run_state.deck_state.hand.duplicate()
		for card: CardInstance in hand:
			if manager.run_state.floor_state.entity.active and manager.run_state.ap >= card.definition.ap_cost and card.definition.effect_type == CardData.EffectType.BLOCK:
				manager.request_play_card(card)
		if manager.run_state.floor_state.entity.active:
			manager.end_turn()
	_check(not encounter.disabled and manager.run_state.player_hp > 0, "Real Hound completion unlocks a readable optional Smiler encounter")
	if manager.run_state.ap < 2:
		manager.end_turn()
	encounter.pressed.emit()
	var info: Label = main.get_node("%EntityInfo") as Label
	_check(info.text.contains("笑魇") and info.text.contains("生命：120／120") and info.text.contains("潜藏"), "UI displays common HP and translated Smiler state")
	var slots: VBoxContainer = main.get_node("%EquipmentSlots") as VBoxContainer
	(slots.get_child(0).get_node("UseEquipment") as Button).pressed.emit()
	_check(info.text.contains("观察") and info.text.contains("再次开灯") and not extinguish.disabled, "Real equipment button shows the light reaction and readable conditional intent")
	extinguish.pressed.emit()
	(main.get_node("%EndTurn") as Button).pressed.emit()
	_check(info.text.contains("已退去") and info.text.contains("生命：120／120") and manager.run_state.floor_state.discovered_insight_ids.has(LIGHT_RULE.id), "UI command resolves encounter behaviorally and shows surviving withdrawn entity")
	_check(landmark.disabled and (main.get_node("%InsightList") as Label).text.contains(LIGHT_RULE.display_name), "Unique Insight refreshes the existing Chinese knowledge list")
	var before: Dictionary = _snapshot(manager)
	landmark.pressed.emit()
	_check(_snapshot(manager) == before and (main.get_node("%Status") as Label).text.contains("已经确认"), "Bypassing disabled landmark UI still cannot double reward")
	(main.get_node("%FloorTabs") as TabContainer).current_tab = 2
	await process_frame
	await process_frame
	_check(main.get_viewport_rect().encloses(extinguish.get_global_rect()) and main.get_viewport_rect().encloses(info.get_global_rect()), "Entity state and rule-interaction controls fit the viewport")
	(main.get_node("%ForcedCutOut") as Button).pressed.emit()
	_check(manager.floor_data.is_placeholder and manager.run_state.deck_state.get_card_count() == 10, "Production walkthrough exits with the same deck and no separate combat scene")
	await process_frame
	main.free()


func _snapshot(manager: TurnManager) -> Dictionary:
	var state: RunState = manager.run_state
	var floor: FloorState = state.floor_state
	var entity: EntityInstance = floor.entity
	var inventory: Array = []
	for item: EquipmentInstance in state.equipment_slots:
		inventory.append([item.get_instance_id(), item.remaining_uses, item.definition.capacity] if item != null else [])
	var cards: Array = []
	for pile: Array[CardInstance] in [state.deck_state.hand, state.deck_state.draw_pile, state.deck_state.discard_pile]:
		var values: Array = []
		for card: CardInstance in pile:
			values.append(card.get_instance_id())
		cards.append(values)
	return {
		"hp": state.player_hp, "stress": state.stress, "supply": state.supply, "ap": state.ap,
		"turn": state.turn_number, "rng": state.rng.state, "floor": floor.get_instance_id(),
		"deck_id": state.deck_state.get_instance_id(), "data": manager.floor_data.get_instance_id(),
		"floor_turn": floor.turn_count, "equipment": inventory, "cards": cards,
		"light": floor.light_active, "dark_observation": floor.dark_observation_used,
		"entity": [entity.get_instance_id(), entity.entity_id, entity.hp, entity.max_hp, entity.state, entity.intent, entity.light_exposed] if entity != null else [],
		"block": floor.player_block, "threat": floor.threat, "cognition": floor.cognition,
		"flags": floor.floor_flags.duplicate(), "insights": floor.discovered_insight_ids.duplicate(),
		"fresh": floor.remaining_fresh_events.duplicate(), "seen": floor.seen_event_ids.duplicate(),
		"event": floor.current_event_id,
		"interactions": floor.current_event.completed_interactions.duplicate() if floor.current_event != null else [],
		"information": floor.current_event.known_information.duplicate() if floor.current_event != null else [],
		"resolved": floor.current_event.resolved if floor.current_event != null else false,
		"stability": floor.cutout_state.stability, "knowledge": floor.cutout_state.destination_knowledge,
		"candidates": floor.cutout_state.destination_candidates.duplicate(),
	}


func _reject(result: ActionResult, reason: StringName, manager: TurnManager, before: Dictionary) -> void:
	_check(not result.success and result.failure_reason == reason, "Rejected command has the expected failure reason: %s" % reason)
	_check(_snapshot(manager) == before, "Failed command preserves entity, inventory, light, Insight, AP, floor, cards and RNG")
	_check(result.entity_spawned == null and result.entity_state_after.is_empty() and result.insight_ids.is_empty() and result.ap_spent == 0 and result.player_damage == 0 and not result.light_extinguished and not result.light_activated, "Failed result contains no partial encounter or light effect")


func _check(condition: bool, description: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		push_error("[TEST] %s" % description)
