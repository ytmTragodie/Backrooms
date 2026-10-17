extends SceneTree

const LEVEL_6: FloorData = preload("res://data/floors/floor_level_6.tres")
const HOUND: EntityData = preload("res://data/entities/entity_hound.tres")
const ATTACK: CardData = preload("res://data/cards/card_attack.tres")
const DEFEND: CardData = preload("res://data/cards/card_defend.tres")
const RUN: CardData = preload("res://data/cards/card_run.tres")
const OBSERVE: CardData = preload("res://data/cards/card_observe.tres")
const WAIT: CardData = preload("res://data/cards/card_wait.tres")
const DEEP_SEARCH: CardData = preload("res://data/cards/card_deep_search.tres")
const MAIN: PackedScene = preload("res://scenes/main/Main.tscn")

var _checks: int = 0
var _failures: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_spawn_and_content()
	_test_attack_and_defeat()
	_test_intents_block_and_disengage()
	_test_darkness_and_insights()
	_test_level6_events()
	_test_turn_threat_and_cutout()
	_test_transactional_failures()
	_test_player_death()
	await _test_production_deck_victory()
	await _test_main_ui()
	await process_frame
	if _failures == 0:
		print("[TEST] PASS Phase 6: %d checks (entity, intent, damage, block, disengage, darkness, shared loop, cut-out, transactions, UI)" % _checks)
	else:
		push_error("[TEST] FAIL Phase 6: %d of %d checks failed" % [_failures, _checks])
	quit(0 if _failures == 0 else 1)


func _manager(data: FloorData = LEVEL_6, definitions: Array[CardData] = []) -> TurnManager:
	var manager: TurnManager = TurnManager.new()
	manager.floor_data = data
	manager.starter_deck = DeckData.new()
	if definitions.is_empty():
		manager.starter_deck.cards.assign([ATTACK, ATTACK, DEFEND, DEFEND, RUN])
	else:
		manager.starter_deck.cards.assign(definitions)
	root.add_child(manager)
	return manager


func _play(manager: TurnManager, definition: CardData) -> ActionResult:
	for card: CardInstance in manager.run_state.deck_state.hand:
		if card.definition == definition:
			return manager.request_play_card(card)
	_check(false, "Requested test card must be in the existing hand")
	return manager.request_play_card(null)


func _test_spawn_and_content() -> void:
	var first: TurnManager = _manager()
	var second: TurnManager = _manager()
	var entity: EntityInstance = first.run_state.floor_state.entity
	_check(entity != second.run_state.floor_state.entity and entity.entity_id == &"entity_hound", "Visits create independent runtime entities using a stable definition ID")
	_check(entity.hp == 18 and entity.max_hp == 18 and entity.alive and entity.active, "Hound starts alive at 18/18 HP")
	_check(entity.state == &"WATCHING" and entity.intent == &"approach", "Initial state has a deterministic readable approach intent")
	_check(LEVEL_6.fresh_events.size() == 3 and first.run_state.floor_state.remaining_fresh_events.size() == 2, "Level 6 activates one of three Fresh Events")
	_check(first.run_state.floor_state.floor_flags.has(&"darkness") and first.run_state.floor_state.cutout_state.destination_candidates == [&"floor_phase6_exit"], "Darkness and a cut-out destination coexist in FloorState")
	var insight_ids: Array[StringName] = []
	for event: EventData in LEVEL_6.fresh_events:
		for rule: EventActionData in event.action_results:
			if rule.insight != null and not insight_ids.has(rule.insight.id):
				insight_ids.append(rule.insight.id)
	_check(insight_ids.size() == 2, "Three Fresh Events reference exactly two unique prototype Insights")
	_check(first.run_state.floor_state.current_event_id == second.run_state.floor_state.current_event_id and first.run_state.rng.state == second.run_state.rng.state, "Fixed-seed Level 6 initialization is reproducible")
	_play(first, ATTACK)
	_check(second.run_state.floor_state.entity.hp == 18 and HOUND.max_hp == 18, "Damage never mutates another visit or the shared definition")
	first.free()
	second.free()


func _test_attack_and_defeat() -> void:
	var manager: TurnManager = _manager(LEVEL_6, [ATTACK, ATTACK, ATTACK, ATTACK, ATTACK])
	var entity: EntityInstance = manager.run_state.floor_state.entity
	var changes: Array[int] = []
	manager.state_changed.connect(func() -> void: changes.append(entity.hp))
	var result: ActionResult = _play(manager, ATTACK)
	_check(result.success and result.entity_damage == 4 and result.damage_requested == 4 and entity.hp == 14, "Data-driven basic attack applies exactly four damage")
	_check(manager.run_state.ap == 2 and manager.run_state.deck_state.discard_pile.has(result.card_played), "Attack spends existing AP and moves its real CardInstance to discard")
	_check(entity.state == &"APPROACHING" and entity.intent == &"bite" and changes == [14], "Complete HP/state/intent commit is visible in one notification")
	_play(manager, ATTACK)
	_play(manager, ATTACK)
	manager.end_turn()
	_play(manager, ATTACK)
	result = _play(manager, ATTACK)
	_check(result.entity_defeated and result.entity_damage == 2 and entity.hp == 0, "Lethal attack clamps applied damage to remaining HP")
	_check(not entity.alive and not entity.active and entity.state == &"DEFEATED" and entity.intent == &"none", "Defeat makes the entity dead and inactive with no intent")
	var defeat_lines: int = 0
	for line: String in result.debug_lines:
		if line.begins_with("[ENTITY] defeated"):
			defeat_lines += 1
	_check(defeat_lines == 1, "A lethal result records defeat once")
	var before: Dictionary = _snapshot(manager)
	_reject(_play(manager, ATTACK), &"no_active_entity", manager, before)
	var hp: int = manager.run_state.player_hp
	manager.end_turn()
	_check(manager.run_state.player_hp == hp and manager.run_state.floor_state.entity == entity and entity.hp == 0, "Dead entity cannot attack or respawn on the next turn")
	manager.free()


func _test_intents_block_and_disengage() -> void:
	var manager: TurnManager = _manager()
	var floor: FloorState = manager.run_state.floor_state
	var result: ActionResult = manager.end_turn()
	_check(result.intent_resolved == &"approach" and result.player_damage == 0 and floor.entity.state == &"APPROACHING", "First published intent approaches without surprise damage")
	_play(manager, DEFEND)
	_check(floor.player_block == 4 and manager.run_state.ap == 2 and floor.entity.intent == &"bite", "Defense adds temporary block without executing the intent early")
	result = manager.end_turn()
	_check(result.damage_blocked == 4 and result.player_damage == 0 and manager.run_state.player_hp == 30, "Four block prevents the visible four-damage bite")
	_check(floor.player_block == 0 and floor.entity.state == &"STAGGERED" and floor.entity.intent == &"recover", "Full block expires and deterministically staggers the attacker")
	result = _play(manager, RUN)
	_check(result.success and floor.entity.state == &"DISENGAGED" and floor.entity.alive and not floor.entity.active, "Running after a stagger disengages without marking the entity dead")
	manager.end_turn()
	_check(manager.run_state.player_hp == 30 and floor.entity.intent == &"none", "Disengaged entity has no subsequent attack")
	manager.free()
	manager = _manager()
	floor = manager.run_state.floor_state
	_play(manager, RUN)
	_check(floor.entity.state == &"CHASING" and floor.entity.intent == &"lunge" and floor.threat == 1, "Risky Run escalates a watching Hound to chase with aggressive intent and reasoned Threat")
	_play(manager, DEFEND)
	result = manager.end_turn()
	_check(result.damage_blocked == 4 and result.player_damage == 1 and manager.run_state.player_hp == 29, "Partial block reduces the five-damage lunge to one")
	_check(floor.entity.state == &"CHASING" and floor.player_block == 0, "Partial block does not grant a full stagger or persist")
	manager.free()
	manager = _manager()
	_play(manager, DEFEND)
	manager.end_turn()
	_check(manager.run_state.floor_state.player_block == 0, "Unused block expires even on a non-damaging intent")
	result = manager.end_turn()
	_check(result.player_damage == 4 and manager.run_state.player_hp == 26, "Expired block cannot protect the following turn")
	manager.free()


func _test_darkness_and_insights() -> void:
	var manager: TurnManager = _manager(LEVEL_6, [OBSERVE, OBSERVE, OBSERVE, WAIT, WAIT])
	var floor: FloorState = manager.run_state.floor_state
	var first: ActionResult = _play(manager, OBSERVE)
	_check(first.ap_spent == 2 and manager.run_state.ap == 1 and floor.dark_observation_used and floor.cognition == 0, "Darkness charges the first Observe one extra AP without automatic Insight")
	var second: ActionResult = _play(manager, OBSERVE)
	_check(second.ap_spent == 1 and floor.cognition == 1 and floor.cutout_state.stability == 1, "Subsequent Observe uses normal cost and confirms a unique prepared Insight")
	var before: Dictionary = _snapshot(manager)
	_reject(_play(manager, OBSERVE), &"insufficient_ap", manager, before)
	manager.end_turn()
	_check(not floor.dark_observation_used and manager.run_state.ap == 3, "The existing End Turn resets the darkness surcharge once")
	manager.run_state.ap = 1
	before = _snapshot(manager)
	_reject(_play(manager, OBSERVE), &"insufficient_ap", manager, before)
	_check(not floor.dark_observation_used, "Unaffordable observation never consumes the first-observation flag")
	manager.free()
	manager = _manager(LEVEL_6, [OBSERVE, OBSERVE, WAIT, WAIT, WAIT])
	manager.request_exploration(&"inspect")
	_check(manager.run_state.cognition == 0 and manager.run_state.ap == 2, "Dark scene inspection only reveals surface information at its basic cost")
	var result: ActionResult = _play(manager, OBSERVE)
	_check(result.success and result.cognition_delta == 1 and manager.run_state.ap == 0, "Inspection plus a darkness-adjusted Observe is another valid discovery path")
	manager.free()


func _test_turn_threat_and_cutout() -> void:
	var manager: TurnManager = _manager()
	var run_state: RunState = manager.run_state
	var floor: FloorState = run_state.floor_state
	var deck: DeckState = run_state.deck_state
	_play(manager, RUN)
	for ended_turn: int in range(1, 4):
		var before: int = run_state.threat
		var result: ActionResult = manager.end_turn()
		_check(run_state == manager.run_state and floor == run_state.floor_state and deck == run_state.deck_state, "Entity intents preserve the same run, FloorState and deck")
		_check(run_state.turn_number == ended_turn + 1 and floor.turn_count == ended_turn + 1 and run_state.ap == 3 and deck.hand.size() == 5, "Combat advances exactly one existing turn with 3 AP and five cards")
		_check(result.player_damage == 5 and run_state.threat == before + (1 if ended_turn == 3 else 0), "Entity damage and existing overstay Threat both resolve in the same end turn")
	run_state.ap = 0
	var entity_hp: int = floor.entity.hp
	var result: ActionResult = manager.request_exploration(&"cutout_forced")
	_check(result.success and result.cutout_attempt.succeeded and manager.floor_data.is_placeholder, "CutOut remains available at zero AP while the Hound chases")
	_check(run_state.floor_state.floor_id == &"floor_phase6_exit" and floor.entity.hp == entity_hp and run_state.floor_state.entity == null, "Exit changes only the current floor boundary without killing the old entity or starting another fight")
	manager.free()


func _test_level6_events() -> void:
	var manager: TurnManager = _manager(LEVEL_6, [DEEP_SEARCH, DEEP_SEARCH, DEEP_SEARCH, DEEP_SEARCH, DEEP_SEARCH])
	var floor: FloorState = manager.run_state.floor_state
	var events: Array[StringName] = []
	for index: int in range(3):
		_check(not floor.current_event_id.is_empty() and not events.has(floor.current_event_id), "Level 6 Fresh Events never repeat")
		events.append(floor.current_event_id)
		var result: ActionResult = _play(manager, DEEP_SEARCH)
		_check(result.success and floor.current_event.resolved, "Deep Search remains an alternative Insight route during the encounter")
		manager.end_turn()
	_check(floor.current_event == null and floor.remaining_fresh_events.is_empty(), "All three resolved Level 6 events exhaust without recycling")
	_check(floor.cognition == 2 and floor.discovered_insight_ids.size() == 2 and floor.cutout_state.stability == 2, "Repeated discovery routes produce exactly two unique Insights and preparation gains")
	_check(floor.entity.alive and manager.run_state.player_hp > 0, "Exploration can finish while entity intents continue in the same loop")
	manager.free()


func _test_production_deck_victory() -> void:
	var main: Control = MAIN.instantiate() as Control
	root.add_child(main)
	var manager: TurnManager = main.get_node("TurnManager") as TurnManager
	manager.request_exploration(&"cutout_forced")
	var entity: EntityInstance = manager.run_state.floor_state.entity
	# 使用实际主场景牌组与默认种子；只选择已有攻击牌，再用剩余 AP 防御。
	for turn: int in range(10):
		if not entity.active or manager.run_state.player_hp <= 0:
			break
		var hand: Array[CardInstance] = manager.run_state.deck_state.hand.duplicate()
		for card: CardInstance in hand:
			if entity.active and card.definition.effect_type in [CardData.EffectType.ATTACK, CardData.EffectType.PLACEHOLDER_DAMAGE] and manager.run_state.ap >= card.definition.ap_cost:
				manager.request_play_card(card)
		hand = manager.run_state.deck_state.hand.duplicate()
		for card: CardInstance in hand:
			if entity.active and card.definition.effect_type == CardData.EffectType.BLOCK and manager.run_state.ap >= card.definition.ap_cost:
				manager.request_play_card(card)
		if entity.active:
			manager.end_turn()
	_check(not entity.alive and entity.state == &"DEFEATED" and manager.run_state.player_hp > 0, "Default production deck can defeat the Hound while keeping the player alive")
	_check(manager.run_state.floor_state.floor_id == &"floor_level_6" and manager.run_state.deck_state.get_card_count() == 10, "Actual victory uses the same exploration floor and conserves the ten-card deck")
	var result: ActionResult = manager.request_exploration(&"cutout_forced")
	_check(result.success and manager.run_state.floor_state.floor_id == &"floor_phase6_exit", "The real encounter can be followed by the existing cut-out to the test endpoint")
	await process_frame
	main.free()


func _test_transactional_failures() -> void:
	var manager: TurnManager = _manager()
	var before: Dictionary = _snapshot(manager)
	_reject(manager.request_play_card(CardInstance.new(ATTACK)), &"card_not_in_hand", manager, before)
	manager.run_state.ap = 0
	before = _snapshot(manager)
	_reject(_play(manager, ATTACK), &"insufficient_ap", manager, before)
	_reject(_play(manager, DEFEND), &"insufficient_ap", manager, before)
	_reject(_play(manager, RUN), &"insufficient_ap", manager, before)
	manager.run_state.ap = 3
	manager.run_state.floor_state.entity.intent = &"lunge"
	before = _snapshot(manager)
	_reject(manager.end_turn(), &"invalid_entity_state", manager, before)
	_reject(_play(manager, ATTACK), &"invalid_entity_state", manager, before)
	manager.free()
	var data: FloorData = LEVEL_6.duplicate(false) as FloorData
	data.entry_entity = HOUND.duplicate(false) as EntityData
	manager = _manager(data)
	data.entry_entity.normal_damage = -1
	before = _snapshot(manager)
	_reject(manager.end_turn(), &"invalid_entity_definition", manager, before)
	_check(HOUND.normal_damage == 4 and HOUND.max_hp == 18, "Malformed fixture never alters shared Hound data")
	manager.free()
	var bad: CardData = ATTACK.duplicate(false) as CardData
	bad.effect_value = -1
	manager = _manager(LEVEL_6, [bad])
	before = _snapshot(manager)
	_reject(_play(manager, bad), &"invalid_card_definition", manager, before)
	manager.free()
	var source: FloorData = preload("res://data/floors/floor_level_0.tres").duplicate(false) as FloorData
	data = LEVEL_6.duplicate(false) as FloorData
	data.entry_entity = HOUND.duplicate(false) as EntityData
	data.entry_entity.max_hp = 0
	source.cutout_destinations = [data]
	manager = _manager(source)
	before = _snapshot(manager)
	_reject(manager.request_exploration(&"cutout_forced"), &"invalid_entity_definition", manager, before)
	manager.free()


func _test_player_death() -> void:
	var manager: TurnManager = _manager()
	_play(manager, RUN)
	manager.run_state.player_hp = 2
	var old_ap: int = manager.run_state.ap
	var result: ActionResult = manager.end_turn()
	_check(result.success and result.player_damage == 2 and manager.run_state.player_hp == 0, "Lethal intent clamps HP at zero through the rule pipeline")
	_check(manager.run_state.turn_number == 1 and manager.run_state.ap == old_ap, "Fatal end-turn damage does not start another turn or refill AP")
	var before: Dictionary = _snapshot(manager)
	_reject(manager.end_turn(), &"run_ended", manager, before)
	_reject(manager.request_exploration(&"cutout_forced"), &"run_ended", manager, before)
	_reject(_play(manager, ATTACK), &"run_ended", manager, before)
	manager.free()


func _test_main_ui() -> void:
	var main: Control = MAIN.instantiate() as Control
	root.add_child(main)
	var manager: TurnManager = main.get_node("TurnManager") as TurnManager
	var run_state: RunState = manager.run_state
	var deck: DeckState = run_state.deck_state
	var hand_before: Array[CardInstance] = deck.hand.duplicate()
	(main.get_node("%ForcedCutOut") as Button).pressed.emit()
	var floor: FloorState = run_state.floor_state
	_check(manager.run_state == run_state and run_state.deck_state == deck and deck.hand == hand_before and run_state.ap == 3 and run_state.turn_number == 1, "Real transition preserves the same TurnManager, RunState, hand and AP")
	_check(floor.floor_id == &"floor_level_6" and floor.current_event != null and floor.entity.hp == 18, "Production Level 0 destination initializes the active Level 6 slice")
	var info: Label = main.get_node("%EntityInfo") as Label
	var tabs: TabContainer = main.get_node("%FloorTabs") as TabContainer
	_check(tabs.current_tab == 2 and info.text.contains("猎犬") and info.text.contains("生命：18／18") and info.text.contains("凝视") and info.text.contains("回合末靠近"), "Debug UI shows Chinese entity HP, state and readable intent on entry")
	var hand: VBoxContainer = main.get_node("%Hand") as VBoxContainer
	# 原有挣扎在无目标时仍是占位，有实际实体时通过同一解析器应用其 2 点伤害。
	(hand.get_child(1) as Button).pressed.emit()
	_check(floor.entity.hp == 16 and run_state.ap == 2 and (main.get_node("%Status") as Label).text.contains("造成伤害：2"), "Existing Struggle uses the real target without replacing the hand")
	_check((hand.get_child(0) as Button).text.contains("行动点：2"), "Hand cost display uses the same darkness cost query as RuleResolver")
	(hand.get_child(0) as Button).pressed.emit()
	var end_turn: Button = main.get_node("%EndTurn") as Button
	end_turn.pressed.emit()
	_check(run_state.player_hp == 26 and run_state.turn_number == 2 and run_state.ap == 3, "Existing End Turn button resolves the advertised bite and starts the next normal turn")
	_press_ui_card(manager, hand, ATTACK)
	_press_ui_card(manager, hand, DEFEND)
	_press_ui_card(manager, hand, RUN)
	_check(floor.entity.hp == 12 and floor.entity.state == &"CHASING" and floor.player_block == 4 and run_state.ap == 0, "Attack, defense and risky Run all use the original hand and three AP")
	end_turn.pressed.emit()
	_check(run_state.player_hp == 25 and floor.player_block == 0 and run_state.floor_state == floor, "UI turn resolves partial block without replacing exploration FloorState")
	_check(not (main.get_node("%ForcedCutOut") as Button).disabled and (main.get_node("%FloorInfo") as Label).text.contains("黑暗"), "Darkness and CutOut stay available alongside the Hound")
	await process_frame
	await process_frame
	_check(main.get_viewport_rect().encloses(end_turn.get_global_rect()) and main.get_viewport_rect().encloses(info.get_global_rect()), "Intent and turn controls stay within the viewport")
	run_state.player_hp = 1
	end_turn.pressed.emit()
	_check((main.get_node("%Status") as Label).text.contains("本局结束") and end_turn.disabled and (main.get_node("%ForcedCutOut") as Button).disabled, "UI reads terminal HP and disables commands without owning the death rule")
	await process_frame
	main.free()


func _press_ui_card(manager: TurnManager, hand: VBoxContainer, definition: CardData) -> void:
	for index: int in range(manager.run_state.deck_state.hand.size()):
		if manager.run_state.deck_state.hand[index].definition == definition:
			(hand.get_child(index) as Button).pressed.emit()
			return
	_check(false, "Production hand must contain the requested combat card")


func _snapshot(manager: TurnManager) -> Dictionary:
	var state: RunState = manager.run_state
	var floor: FloorState = state.floor_state
	var entity: EntityInstance = floor.entity
	var cards: Array = []
	for pile: Array[CardInstance] in [state.deck_state.hand, state.deck_state.draw_pile, state.deck_state.discard_pile]:
		var values: Array = []
		for card: CardInstance in pile:
			values.append([card.get_instance_id(), card.definition.get_instance_id(), card.definition.id, card.definition.ap_cost, card.definition.effect_type, card.definition.effect_value])
		cards.append(values)
	return {
		"hp": state.player_hp, "stress": state.stress, "supply": state.supply, "ap": state.ap,
		"turn": state.turn_number, "floor_turn": floor.turn_count, "floor": floor.get_instance_id(),
		"data": manager.floor_data.get_instance_id(), "rng": state.rng.state, "cards": cards,
		"entity": [entity.get_instance_id(), entity.entity_id, entity.hp, entity.max_hp, entity.state, entity.intent, entity.alive, entity.active] if entity != null else [],
		"block": floor.player_block, "dark_observation": floor.dark_observation_used,
		"flags": floor.floor_flags.duplicate(), "event": floor.current_event_id,
		"fresh": floor.remaining_fresh_events.duplicate(), "seen": floor.seen_event_ids.duplicate(),
		"interactions": floor.current_event.completed_interactions.duplicate() if floor.current_event != null else [],
		"information": floor.current_event.known_information.duplicate() if floor.current_event != null else [],
		"resolved": floor.current_event.resolved if floor.current_event != null else false,
		"insights": floor.discovered_insight_ids.duplicate(), "cognition": floor.cognition, "threat": floor.threat,
		"stability": floor.cutout_state.stability, "knowledge": floor.cutout_state.destination_knowledge,
		"candidates": floor.cutout_state.destination_candidates.duplicate(),
	}


func _reject(result: ActionResult, reason: StringName, manager: TurnManager, before: Dictionary) -> void:
	_check(not result.success and result.failure_reason == reason, "Rejected action reports expected reason: %s" % reason)
	_check(_snapshot(manager) == before, "Failed action preserves entity, HP, block, AP, cards, floor, event and RNG")
	_check(result.ap_spent == 0 and result.player_damage == 0 and result.entity_damage == 0 and not result.entity_defeated and result.block_gained == 0 and result.entity_state_after.is_empty() and not result.dark_observation, "Failed result contains no combat or darkness effects")


func _check(condition: bool, description: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		push_error("[TEST] %s" % description)
