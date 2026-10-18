extends SceneTree

const FLOOR: FloorData = preload("res://data/floors/floor_level_6.tres")
const DECK: DeckData = preload("res://data/cards/mixed_deck.tres")
const OBSERVE: CardData = preload("res://data/cards/card_observe.tres")
const SEARCH: CardData = preload("res://data/cards/card_search.tres")
const DEEP: CardData = preload("res://data/cards/card_deep_search.tres")
const ATTACK: CardData = preload("res://data/cards/card_attack.tres")
const GUARD: CardData = preload("res://data/cards/card_defend.tres")
const RUN: CardData = preload("res://data/cards/card_run.tres")
const MAIN: PackedScene = preload("res://scenes/main/Main.tscn")
var _checks: int = 0
var _failures: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_mixed_economy()
	_test_pressure_intents_order()
	_test_shared_guard_and_disengage()
	_test_entity_knowledge()
	_test_noise_and_defeat()
	_test_target_failures()
	_test_legacy_rejection()
	_test_deck_composition()
	await _test_ui()
	await _test_ui_full_encounter()
	await process_frame
	if _failures == 0:
		print("[TEST] PASS REWORK B: %d checks (mixed board, shared economy, pressure/intent order, Guard, entity knowledge, noise, defeat, targets, atomicity, UI)" % _checks)
	else:
		push_error("[TEST] FAIL REWORK B: %d of %d checks failed" % [_failures, _checks])
	quit(0 if _failures == 0 else 1)


func _fixture() -> FloorData:
	var data: FloorData = FLOOR.duplicate(false) as FloorData
	data.entry_entity = FLOOR.entry_entity.duplicate(false) as EntityData
	data.entry_entity.rule_insight = FLOOR.entry_entity.rule_insight.duplicate(false) as InsightData
	data.entry_entity.resolution_reward = null
	data.fresh_events = []
	for source: EventData in FLOOR.fresh_events:
		var event: EventData = source.duplicate(false) as EventData
		event.completion_reward = null
		data.fresh_events.append(event)
	return data


func _manager(definitions: Array[CardData] = [], data: FloorData = FLOOR) -> TurnManager:
	var manager: TurnManager = TurnManager.new()
	manager.floor_data = preload("res://tests/legacy_fixture.gd").without_rewards(data) if data == FLOOR else data
	manager.starter_deck = DeckData.new()
	manager.starter_deck.cards.assign(DECK.cards if definitions.is_empty() else definitions)
	root.add_child(manager)
	return manager


func _card(manager: TurnManager, definition: CardData) -> CardInstance:
	for card: CardInstance in manager.run_state.deck_state.hand:
		if card.definition == definition:
			return card
	_check(false, "Fixture must have requested real hand card")
	return null


func _play(manager: TurnManager, definition: CardData, entity: bool = false) -> ActionResult:
	var board: BoardState = manager.run_state.floor_state.board_state
	var self_guard: bool = definition.effect_type == CardData.EffectType.BLOCK
	return manager.request_play_card(_card(manager, definition), board.active_event if not entity and not self_guard else null, board, board.entity if entity and not self_guard else null)


func _test_mixed_economy() -> void:
	var manager: TurnManager = _manager()
	var run: RunState = manager.run_state
	var floor: FloorState = run.floor_state
	var board: BoardState = floor.board_state
	var deck: DeckState = run.deck_state
	_check(board.active_event != null and not board.active_event.resolved and board.entity.active, "Unresolved Situation and active Hound coexist deterministically at entry")
	_check(board.entity.hp == 18 and board.entity.state == &"WATCHING" and board.entity.intent == &"approach", "Hound retains common HP and readable state/intent")
	_check(run.ap == 3 and deck.hand.size() == 5 and deck.get_card_count() == 10, "One ordinary hand and AP pool")
	var result: ActionResult = _play(manager, OBSERVE)
	_check(result.success and result.ap_spent == 2 and board.active_event.explore_progress == 2 and run.ap == 1, "Situation Explore works while Hound exists; Level 6 darkness still affects first Observe")
	result = _play(manager, ATTACK, true)
	_check(result.success and run.ap == 0 and board.entity.hp == 14 and board.active_event.explore_progress == 2, "Entity attack spends remaining shared AP without pausing/erasing Explore")
	var before: Dictionary = _snapshot(manager)
	_fail_unchanged(manager, PlayCardCommand.new(_card(manager, GUARD), null, board), &"insufficient_ap", before)
	result = manager.end_turn()
	_check(result.player_damage == 4 and result.pressure_damage == 0 and run.player_hp == 26, "Published Hound intent resolves while progressed Situation stays active")
	_check(manager.run_state == run and run.floor_state == floor and floor.board_state == board and run.deck_state == deck and floor.cutout_state != null, "No new combat Run/Floor/Board/deck/CutOut state is created")
	_check(board.active_event.explore_progress == 2 and run.turn_number == 2 and floor.turn_count == 2 and run.ap == 3 and deck.hand.size() == 5, "Same turn lifecycle preserves Explore and restores only the normal AP")
	for pile: Array[CardInstance] in [deck.hand, deck.draw_pile, deck.discard_pile]:
		for card: CardInstance in pile:
			_check(card.get_instance_id() != board.entity.get_instance_id() and card.get_instance_id() != board.active_event.get_instance_id(), "World instances never enter player piles")
	manager.free()


func _test_pressure_intents_order() -> void:
	var manager: TurnManager = _manager()
	var floor: FloorState = manager.run_state.floor_state
	var event: EventInstance = floor.current_event
	var first: ActionResult = manager.end_turn()
	_check(first.pressure_damage == 2 and first.intent_resolved == &"approach" and manager.run_state.player_hp == 28, "Pressure and harmless initial intent both resolve")
	var second: ActionResult = manager.end_turn()
	_check(second.pressure_damage == 2 and second.player_damage == 4 and manager.run_state.player_hp == 22, "Pressure and damaging intent coexist on an unresolved Situation")
	var third: ActionResult = manager.end_turn()
	_check(third.pressure_damage == 2 and third.player_damage == 5 and third.threat_delta == 1 and floor.threat == 1, "Overstay still runs during mixed encounter")
	_check(_line(third, "[PRESSURE]") < _line(third, "[ENTITY] intent=") and _line(third, "[ENTITY] intent=") < _line(third, "[THREAT]") and _line(third, "[THREAT]") < _line(third, "[TURN] cleanup"), "Commit logs prove Pressure -> intent -> overstay -> cleanup")
	_check(floor.current_event == event and event.explore_progress == 0 and floor.seen_event_ids.size() == 1, "Entity actions do not replace or reshuffle an unresolved Situation")
	manager.free()
	manager = _manager()
	manager.run_state.player_hp = 1
	var deck: DeckState = manager.run_state.deck_state
	var hand: Array[CardInstance] = deck.hand.duplicate()
	var lethal: ActionResult = manager.end_turn()
	_check(lethal.pressure_damage == 1 and lethal.intent_resolved.is_empty() and manager.run_state.player_hp == 0, "Lethal Pressure suppresses later intent and clamps HP")
	_check(manager.run_state.turn_number == 1 and deck.hand == hand and manager.run_state.ap == 3, "Lethal consequence never refills AP, discards or starts next turn")
	manager.free()


func _test_shared_guard_and_disengage() -> void:
	var manager: TurnManager = _manager([ATTACK, GUARD, GUARD, RUN, OBSERVE])
	_play(manager, ATTACK, true)
	_play(manager, GUARD)
	var result: ActionResult = manager.end_turn()
	_check(result.pressure_blocked == 2 and result.damage_blocked == 2 and result.player_damage == 2 and manager.run_state.player_hp == 28, "Four Guard blocks two environment then two bite damage; no double spending")
	_check(manager.run_state.floor_state.player_block == 0, "All temporary Guard expires after consequences")
	manager.free()
	manager = _manager([ATTACK, GUARD, GUARD, RUN, OBSERVE])
	_play(manager, ATTACK, true)
	_play(manager, GUARD)
	_play(manager, GUARD)
	result = manager.end_turn()
	_check(result.pressure_blocked == 2 and result.damage_blocked == 4 and result.player_damage == 0 and manager.run_state.floor_state.entity.state == &"STAGGERED", "Enough remaining Guard fully blocks bite and preserves Hound stagger behavior")
	var departed: EntityInstance = manager.run_state.floor_state.entity
	var hp: int = departed.hp
	result = _play(manager, RUN, true)
	_check(result.success and manager.run_state.floor_state.entity == null and departed.state == &"DISENGAGED" and departed.hp == hp and manager.run_state.threat == 1, "Real Run card disengages staggered Hound without killing it")
	result = manager.end_turn()
	_check(result.intent_resolved.is_empty() and result.pressure_damage == 2 and not manager.run_state.floor_state.current_event.resolved, "Resolving Entity does not stop Situation Pressure")
	manager.free()
	var data: FloorData = _fixture()
	data.entry_entity = null
	manager = _manager([GUARD, GUARD, GUARD, GUARD, GUARD], data)
	_play(manager, GUARD)
	result = manager.end_turn()
	_check(result.pressure_blocked == 2 and result.player_damage == 0 and manager.run_state.player_hp == 30, "Guard has a meaningful pure-environment route without any creature")
	manager.free()


func _test_entity_knowledge() -> void:
	var data: FloorData = _fixture()
	data.fresh_events[0].explore_threshold = 4
	var manager: TurnManager = _manager([OBSERVE, OBSERVE, OBSERVE, OBSERVE, OBSERVE], data)
	var entity: EntityInstance = manager.run_state.floor_state.entity
	var first: ActionResult = _play(manager, OBSERVE, true)
	_check(first.analysis_applied == 2 and entity.analysis_progress == 2 and entity.hp == 18 and entity.revealed_rules.is_empty() and manager.run_state.cognition == 0, "Observe on Entity advances actual knowledge, never Damage or Situation progress")
	var second: ActionResult = _play(manager, OBSERVE, true)
	_check(second.success and entity.analysis_progress == 4 and entity.revealed_rules == [data.entry_entity.analysis_rule] and manager.run_state.cognition == 1, "Entity knowledge threshold exposes noise/control rule and unique Insight")
	manager.end_turn()
	var before: Dictionary = _snapshot(manager)
	_fail_unchanged(manager, PlayCardCommand.new(_card(manager, OBSERVE), null, manager.run_state.floor_state.board_state, entity), &"analysis_complete", before)
	_play(manager, OBSERVE)
	var resolved: ActionResult = _play(manager, OBSERVE)
	_check(resolved.event_resolved and resolved.cognition_delta == 1 and manager.run_state.cognition == 2 and entity.revealed_rules.size() == 1, "Situation clue adds distinct light Insight while shared completion fact does not repeat entity knowledge")
	_check(FLOOR.entry_entity.analysis_threshold == 4 and FLOOR.entry_entity.max_hp == 18, "Shared EntityData remains static")
	manager.free()


func _test_noise_and_defeat() -> void:
	var manager: TurnManager = _manager([DEEP, ATTACK, GUARD, OBSERVE, SEARCH])
	var result: ActionResult = _play(manager, DEEP)
	var floor: FloorState = manager.run_state.floor_state
	_check(result.success and floor.current_event.explore_progress == 5 and floor.entity.state == &"CHASING" and floor.entity.intent == &"lunge" and floor.entity.hp == 18, "Noise from real Situation Explore provokes Hound without fake damage")
	_check(manager.run_state.threat == 1 and manager.run_state.ap == 1, "Deep Search keeps its own one Threat/two AP cost, no duplicate noise cost")
	result = manager.end_turn()
	_check(result.player_damage == 5 and result.pressure_damage == 0, "Noise-updated public intent resolves in same ordinary lifecycle")
	manager.free()
	manager = _manager([DEEP, DEEP, DEEP, DEEP, DEEP])
	manager.run_state.ap = 1
	var board: BoardState = manager.run_state.floor_state.board_state
	var failed_before: Dictionary = _snapshot(manager)
	_fail_unchanged(manager, PlayCardCommand.new(_card(manager, DEEP), board.active_event, board), &"insufficient_ap", failed_before)
	_check(board.entity.state == &"WATCHING", "Failed noisy card cannot provoke any Entity reaction")
	manager.free()
	manager = _manager([ATTACK, ATTACK, ATTACK, ATTACK, ATTACK, ATTACK])
	var entity: EntityInstance = manager.run_state.floor_state.entity
	for index: int in range(3):
		_play(manager, ATTACK, true)
	manager.end_turn()
	_play(manager, ATTACK, true)
	var notifications: Array[int] = []
	manager.state_changed.connect(func() -> void: notifications.append(entity.hp))
	result = _play(manager, ATTACK, true)
	_check(result.entity_defeated and result.entity_damage == 2 and entity.hp == 0 and not entity.active and not entity.alive and entity.intent == &"none", "Common HP reaches zero once and defeats Hound")
	_check(notifications == [0] and manager.run_state.ap == 1 and manager.run_state.deck_state.discard_pile.has(result.card_played), "Observer sees only fully committed HP/AP/card result")
	var before: Dictionary = _snapshot(manager)
	_fail_unchanged(manager, PlayCardCommand.new(_card(manager, ATTACK), null, manager.run_state.floor_state.board_state, entity), &"invalid_entity_target", before)
	_check(result.debug_lines.count("[ENTITY] defeated entity_hound") == 1, "One defeat log, no duplicate reward/defeat on rejected further attack")
	manager.free()


func _test_target_failures() -> void:
	var manager: TurnManager = _manager()
	var other: TurnManager = _manager()
	var board: BoardState = manager.run_state.floor_state.board_state
	var entity: EntityInstance = board.entity
	var attack: CardInstance = _card(manager, ATTACK)
	var observe: CardInstance = _card(manager, OBSERVE)
	var clone: EntityInstance = EntitySystem.spawn(FLOOR.entry_entity)
	var before: Dictionary = _snapshot(manager)
	_fail_unchanged(manager, PlayCardCommand.new(attack, null, board, clone), &"invalid_entity_target", before)
	_fail_unchanged(manager, PlayCardCommand.new(attack, null, other.run_state.floor_state.board_state, entity), &"invalid_entity_target", before)
	_fail_unchanged(manager, PlayCardCommand.new(attack, null, board, other.run_state.floor_state.entity), &"invalid_entity_target", before)
	_fail_unchanged(manager, PlayCardCommand.new(attack, board.active_event, board), &"invalid_target_kind", before)
	_fail_unchanged(manager, PlayCardCommand.new(attack, null, board), &"invalid_entity_target", before)
	_fail_unchanged(manager, PlayCardCommand.new(attack, null, null, entity), &"invalid_entity_target", before)
	_fail_unchanged(manager, PlayCardCommand.new(observe, board.active_event, board, entity), &"invalid_target_kind", before)
	board.entity = clone
	before = _snapshot(manager)
	_fail_unchanged(manager, PlayCardCommand.new(attack, null, board, entity), &"invalid_entity_target", before)
	board.entity = null
	before = _snapshot(manager)
	_fail_unchanged(manager, PlayCardCommand.new(attack, null, board, clone), &"invalid_entity_target", before)
	board.entity = entity
	var old_event: EventInstance = board.active_event
	board.active_event = EventInstance.new(old_event.event_id)
	before = _snapshot(manager)
	_fail_unchanged(manager, PlayCardCommand.new(observe, old_event, board), &"invalid_event_target", before)
	manager.run_state.ap = 0
	before = _snapshot(manager)
	_fail_unchanged(manager, PlayCardCommand.new(observe, null, board, entity), &"insufficient_ap", before)
	manager.free()
	other.free()
	var data: FloorData = _fixture()
	manager = _manager([], data)
	data.entry_entity.rule_insight.id = &""
	board = manager.run_state.floor_state.board_state
	before = _snapshot(manager)
	_fail_unchanged(manager, PlayCardCommand.new(_card(manager, ATTACK), null, board, board.entity), &"invalid_insight_definition", before)
	manager.free()


func _test_legacy_rejection() -> void:
	var manager: TurnManager = _manager()
	_check(not manager.has_method("request_exploration") and not manager.has_method("request_use_equipment"), "No deprecated gameplay method survives as a parallel input path")
	manager.free()


func _test_deck_composition() -> void:
	# 穷举十张牌中所有五张组合：卡池比例保险，不引入未批准的换牌规则。
	var explore_count: int = 0
	var attack_count: int = 0
	for card: CardData in DECK.cards:
		if card.explore_amount > 0:
			explore_count += 1
		if card.effect_type == CardData.EffectType.ATTACK:
			attack_count += 1
	_check(explore_count == 4 and attack_count == 3 and DECK.cards.size() == 10, "Mixed deck has four Explore, three Damage, two Guard, one Run")
	for mask: int in range(1 << DECK.cards.size()):
		var selected: Array[CardData] = []
		for index: int in range(DECK.cards.size()):
			if mask & (1 << index):
				selected.append(DECK.cards[index])
		if selected.size() != 5:
			continue
		_check(selected.any(func(card: CardData) -> bool: return card.explore_amount > 0 or card.effect_type == CardData.EffectType.BLOCK), "Every full hand has Situation Explore or Pressure defense after Hound resolves")
		_check(selected.any(func(card: CardData) -> bool: return card.effect_type != CardData.EffectType.NO_OP), "Every full hand has a creature-facing action after Situation/analysis resolves")


func _test_ui() -> void:
	var main: Control = MAIN.instantiate() as Control
	(main.get_node("TurnManager") as TurnManager).floor_data = preload("res://tests/legacy_fixture.gd").without_rewards(FLOOR)
	(main.get_node("TurnManager") as TurnManager).starter_deck = DECK
	root.add_child(main)
	var manager: TurnManager = main.get_node("TurnManager") as TurnManager
	var hand: HBoxContainer = main.get_node("%Hand") as HBoxContainer
	var world: Button = main.get_node("%WorldCard") as Button
	var creature: Button = main.get_node("%EntityCard") as Button
	var information: Label = main.get_node("%EntityInformation") as Label
	_check(manager.floor_data.id == FLOOR.id and creature.visible and information.text.contains("猎犬") and information.text.contains("18／18") and hand.get_child_count() == 6, "Same screen starts mixed board, five normal cards and one generated equipment action")
	_check((hand.get_child(1) as Button).disabled, "Explicit Situation selection disables incompatible Attack; no silent retargeting")
	var before: Dictionary = _snapshot(manager)
	creature.pressed.emit()
	_check(_snapshot(manager) == before and not (hand.get_child(1) as Button).disabled and information.text.contains("已选"), "Entity selection changes only presentation")
	(hand.get_child(1) as Button).pressed.emit()
	_check(manager.run_state.floor_state.entity.hp == 14 and information.text.contains("撕咬") and manager.run_state.ap == 2, "Real hand attack updates Entity World Card intent/HP")
	(hand.get_child(0) as Button).pressed.emit()
	_check(information.text.contains("2／4") and manager.run_state.floor_state.current_event.explore_progress == 0 and manager.run_state.ap == 0, "Real Observe targets Entity knowledge using remaining AP")
	before = _snapshot(manager)
	world.pressed.emit()
	_check(_snapshot(manager) == before, "Situation selection also commits no gameplay")
	(main.get_node("%EndTurn") as Button).pressed.emit()
	_check(manager.run_state.player_hp == 24 and manager.run_state.turn_number == 2 and hand.get_child_count() == 6, "Actual End Turn resolves environment and bite; one generated equipment card supplements the five-slot hand")
	await process_frame
	await process_frame
	_check(main.get_viewport_rect().encloses(world.get_global_rect()) and main.get_viewport_rect().encloses(creature.get_global_rect()) and world.get_global_rect().end.x <= creature.get_global_rect().position.x, "Both World Cards fit side by side in viewport")
	_check(world.get_global_rect().encloses((main.get_node("%SituationState") as Label).get_global_rect()) and creature.get_global_rect().encloses(information.get_global_rect()) and creature.get_global_rect().end.y <= hand.get_global_rect().position.y, "World details stay inside cards, above hand")
	for name: String in ["AttackAction", "DefendAction", "EncounterAction", "InspectAction", "SearchNearbyAction"]:
		_check(main.find_child(name, true, false) == null, "No standalone gameplay button: %s" % name)
	_check_chinese(main)
	_check(not (main.get_node("%DebugPanel") as Control).visible, "Mixed fixture renders through the same normal screen with developer tools hidden")
	main.free()


func _test_ui_full_encounter() -> void:
	var main: Control = MAIN.instantiate() as Control
	(main.get_node("TurnManager") as TurnManager).floor_data = preload("res://tests/legacy_fixture.gd").without_rewards(FLOOR)
	(main.get_node("TurnManager") as TurnManager).starter_deck = DECK
	root.add_child(main)
	var manager: TurnManager = main.get_node("TurnManager") as TurnManager
	var run: RunState = manager.run_state
	var floor: FloorState = run.floor_state
	var deck: DeckState = run.deck_state
	# 只操作真实屏幕控件，不修改 HP、AP、牌序或目标领域状态。
	for turn: int in range(20):
		if run.player_hp == 0 or (floor.current_event == null and floor.entity == null):
			break
		for action: int in range(5):
			var event: EventInstance = floor.current_event
			var situation_active: bool = event != null and not event.resolved
			var chosen: CardData
			var target_entity: bool = false
			if situation_active and event.last_progress_turn != floor.turn_count:
				for definition: CardData in [SEARCH, DEEP, OBSERVE]:
					if _available(manager, definition):
						chosen = definition
						break
			if chosen == null and floor.entity != null and floor.entity.active and floor.entity.state == &"STAGGERED" and _available(manager, RUN):
				chosen = RUN
				target_entity = true
			var impending: int = 0 if floor.entity == null else (FLOOR.entry_entity.aggressive_damage if floor.entity.intent == &"lunge" else (FLOOR.entry_entity.normal_damage if floor.entity.intent == &"bite" else 0))
			if situation_active and event.last_progress_turn != floor.turn_count:
				impending += 2
			if chosen == null and floor.player_block < impending and _available(manager, GUARD):
				chosen = GUARD
			if chosen == null and floor.entity != null and floor.entity.active and _available(manager, ATTACK):
				chosen = ATTACK
				target_entity = true
			if chosen == null and situation_active:
				for definition: CardData in [SEARCH, DEEP, OBSERVE]:
					if _available(manager, definition):
						chosen = definition
						break
			if chosen == null:
				break
			_press_card(main, chosen, target_entity)
		(main.get_node("%EndTurn") as Button).pressed.emit()
	_check(run.player_hp > 0 and floor.current_event == null and floor.entity == null, "Real hand/target/End Turn controls can finish both demands alive")
	_check(manager.run_state == run and run.floor_state == floor and run.deck_state == deck and deck.get_card_count() == 10, "Entire mixed playthrough preserves one Run/Floor/deck/ten-card inventory")
	_check(floor.discovered_insight_ids.has(FLOOR.entry_entity.rule_insight.id) and floor.discovered_insight_ids.has(FLOOR.fresh_events[0].clue_insight.id) and floor.cognition == 2, "Playable Situation provides Hound knowledge plus alternate light clue without manual pursuit/landmark actions")
	await process_frame
	main.free()


func _available(manager: TurnManager, definition: CardData) -> bool:
	return RuleResolver.card_ap_cost(definition, manager.run_state, manager.floor_data) <= manager.run_state.ap and manager.run_state.deck_state.hand.any(func(card: CardInstance) -> bool: return card.definition == definition)


func _press_card(main: Control, definition: CardData, entity: bool) -> void:
	(main.get_node("%EntityCard" if entity else "%WorldCard") as Button).pressed.emit()
	var manager: TurnManager = main.get_node("TurnManager") as TurnManager
	var hand: HBoxContainer = main.get_node("%Hand") as HBoxContainer
	for index: int in range(manager.run_state.deck_state.hand.size()):
		if manager.run_state.deck_state.hand[index].definition == definition:
			var button: Button = hand.get_child(index) as Button
			_check(not button.disabled, "Deterministic UI playthrough chooses a legal hand card")
			button.pressed.emit()
			return
	_check(false, "Playable hand button must exist")


func _snapshot(manager: TurnManager) -> Dictionary:
	var run: RunState = manager.run_state
	var floor: FloorState = run.floor_state
	var event: EventInstance = floor.current_event
	var entity: EntityInstance = floor.entity
	var piles: Array = []
	for pile: Array[CardInstance] in [run.deck_state.hand, run.deck_state.draw_pile, run.deck_state.discard_pile]:
		var ids: Array[int] = []
		for card: CardInstance in pile:
			ids.append(card.get_instance_id())
		piles.append(ids)
	var equipment: Array = []
	for item: EquipmentInstance in run.equipment_slots:
		equipment.append([item.get_instance_id(), item.remaining_uses] if item != null else [])
	return {"run": run.get_instance_id(), "hp": run.player_hp, "stress": run.stress, "supply": run.supply, "ap": run.ap, "turn": run.turn_number, "rng": run.rng.state,
		"floor": floor.get_instance_id(), "board": floor.board_state.get_instance_id(), "deck": run.deck_state.get_instance_id(), "piles": piles, "equipment": equipment,
		"floor_state": [floor.turn_count, floor.threat, floor.cognition, floor.player_block, floor.dark_observation_used, floor.light_active, floor.discovered_insight_ids.duplicate(), floor.remaining_fresh_events.duplicate(), floor.seen_event_ids.duplicate(), floor.floor_flags.duplicate()],
		"event": [event.get_instance_id(), event.explore_progress, event.resolved, event.clue_revealed, event.known_information.duplicate(), event.last_progress_turn, event.pressure_checked_turn] if event != null else [],
		"entity": [entity.get_instance_id(), entity.hp, entity.max_hp, entity.state, entity.intent, entity.analysis_progress, entity.revealed_rules.duplicate(), entity.light_exposed] if entity != null else [],
		"cutout": [floor.cutout_state.get_instance_id(), floor.cutout_state.stability, floor.cutout_state.destination_knowledge, floor.cutout_state.destination_candidates.duplicate()]}


func _fail_unchanged(manager: TurnManager, command: PlayCardCommand, reason: StringName, before: Dictionary) -> void:
	var notifications: Array[int] = []
	var listener: Callable = func() -> void: notifications.append(1)
	manager.state_changed.connect(listener)
	var result: ActionResult = manager.request_play_card(command.card, command.target_event, command.target_board, command.target_entity)
	manager.state_changed.disconnect(listener)
	_check(not result.success and result.failure_reason == reason, "Expected failure: %s, got %s" % [reason, result.failure_reason])
	_check(result.ap_spent == 0 and result.card_played == null and result.entity_hp_after == -1 and result.analysis_after == -1 and result.threat_delta == 0 and result.insight_ids.is_empty(), "Rejected action contains no partially planned gameplay result")
	_check(_snapshot(manager) == before and notifications.is_empty(), "Failure preserves AP/cards/world/knowledge/gear/RNG and emits no state notification")


func _line(result: ActionResult, prefix: String) -> int:
	for index: int in range(result.debug_lines.size()):
		if result.debug_lines[index].begins_with(prefix):
			return index
	_check(false, "Expected trace prefix: %s" % prefix)
	return -1


func _check_chinese(node: Node) -> void:
	var value: String = (node as Label).text if node is Label else ((node as Button).text if node is Button else "")
	if not value.is_empty():
		_check(RegEx.create_from_string("[A-Za-z_]").search(value) == null, "Visible text is Chinese: %s" % value)
	for child: Node in node.get_children():
		_check_chinese(child)


func _check(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		push_error(message)
