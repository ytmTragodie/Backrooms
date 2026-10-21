extends SceneTree

const LEVEL_0: FloorData = preload("res://tests/fixtures/phase9/floors/floor_level_0.tres")
const LEVEL_6: FloorData = preload("res://tests/fixtures/phase9/floors/floor_level_6.tres")
const DECK: DeckData = preload("res://tests/fixtures/phase9/cards/run_deck.tres")
const OBSERVE: CardData = preload("res://data/cards/card_observe.tres")
const SEARCH: CardData = preload("res://data/cards/card_search.tres")
const DEEP: CardData = preload("res://data/cards/card_deep_search.tres")
const ATTACK: CardData = preload("res://data/cards/card_attack.tres")
const GUARD: CardData = preload("res://data/cards/card_defend.tres")
const RUN: CardData = preload("res://data/cards/card_run.tres")
const FLASH: EquipmentData = preload("res://data/equipment/equip_flashlight.tres")
const CROWBAR: EquipmentData = preload("res://data/equipment/equip_crowbar.tres")
const WATER: EquipmentData = preload("res://data/equipment/equip_almond_water.tres")
const MAIN: PackedScene = preload("res://scenes/main/Main.tscn")
var checks: int = 0
var failures: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	await tests()
	await process_frame
	print("[TEST] %s %s: %d checks" % ["PASS" if failures == 0 else "FAIL", label(), checks])
	quit(0 if failures == 0 else 1)


func label() -> String:
	return "Migration test helpers"


func tests() -> void:
	check(true, "Helper script loads")


func fixture(source: FloorData = LEVEL_0) -> FloorData:
	var data: FloorData = source.duplicate(false) as FloorData
	data.fresh_objectives = []
	for original: ObjectiveData in source.fresh_objectives:
		var event: ObjectiveData = original.duplicate(false) as ObjectiveData
		event.completion_reward = null
		event.completion_insight = original.completion_insight.duplicate(false) as InsightData
		if original.clue_insight != null:
			event.clue_insight = original.clue_insight.duplicate(false) as InsightData
		data.fresh_objectives.append(event)
	# 测试夹具保持旧用例的确定性：首个目标固定为 intro，概率必中，且允许抽完整个夹具池。
	data.objective_spawn_chance = 1.0
	data.max_objectives_per_floor = data.fresh_objectives.size()
	data.intro_objective = data.fresh_objectives[0] if not data.fresh_objectives.is_empty() else null
	data.resource_nodes = []
	for original: ResourceNodeData in source.resource_nodes:
		data.resource_nodes.append(original.duplicate(false) as ResourceNodeData)
	if source.landmark_insight != null:
		data.landmark_insight = source.landmark_insight.duplicate(false) as InsightData
	for field: String in ["entry_entity", "followup_entity"]:
		var original: EntityData = source.get(field) as EntityData
		if original != null:
			var entity: EntityData = original.duplicate(false) as EntityData
			entity.resolution_reward = null
			if original.rule_insight != null:
				entity.rule_insight = original.rule_insight.duplicate(false) as InsightData
			data.set(field, entity)
	return data


func manager(definitions: Array[CardData] = [], data: FloorData = LEVEL_0, gear: bool = true, seed_value: int = 1) -> TurnManager:
	var owner: TurnManager = TurnManager.new()
	owner.floor_data = fixture(data) if data in [LEVEL_0, LEVEL_6] else data
	owner.starter_deck = DeckData.new()
	owner.starter_deck.cards.assign(DECK.cards if definitions.is_empty() else definitions)
	if gear:
		owner.starting_equipment = [FLASH, CROWBAR, WATER]
	owner.run_state.rng_seed = seed_value
	owner.run_state.rng.seed = seed_value
	root.add_child(owner)
	return owner


func hand_card(owner: TurnManager, definition: CardData) -> CardInstance:
	for card: CardInstance in owner.run_state.deck_state.hand:
		if card.definition == definition:
			return card
	check(false, "Requested real card must exist in hand")
	return null


func command(owner: TurnManager, definition: CardData, target_entity: bool = false) -> PlayCardCommand:
	var board: BoardState = owner.run_state.floor_state.board_state
	var event: ObjectiveInstance = board.active_objective if not target_entity and definition.explore_amount > 0 else null
	return PlayCardCommand.new(hand_card(owner, definition), event, board, board.entity if target_entity else null)


func submit(owner: TurnManager, request: PlayCardCommand) -> ActionResult:
	return owner.submit_card_command(request)


func play(owner: TurnManager, definition: CardData, target_entity: bool = false) -> ActionResult:
	return submit(owner, command(owner, definition, target_entity))


func snapshot(owner: TurnManager) -> Dictionary:
	var run: RunState = owner.run_state
	var floor: FloorState = run.floor_state
	var event: ObjectiveInstance = floor.current_objective
	var entity: EntityInstance = floor.entity
	var piles: Array = []
	for pile: Array[CardInstance] in [run.deck_state.hand, run.deck_state.draw_pile, run.deck_state.discard_pile]:
		var ids: Array[int] = []
		for card: CardInstance in pile:
			ids.append(card.get_instance_id())
		piles.append(ids)
	var equipment: Array = []
	for item: EquipmentInstance in run.equipment_slots:
		equipment.append([item.get_instance_id(), item.remaining_uses, item.definition.get_instance_id(), item.definition.capacity] if item != null else [])
	var nodes: Array = []
	for node: ResourceNode in floor.resource_nodes:
		nodes.append([node.get_instance_id(), node.status])
	return {"run": run.get_instance_id(), "hp": run.player_hp, "stress": run.stress, "supply": run.supply, "ap": run.ap, "turn": run.turn_number, "rng": run.rng.state,
		"resolved_entities": floor.resolved_entity_ids.duplicate(),
		"rewards": run.pending_rewards.map(func(reward: CardReward) -> Array: return [reward.get_instance_id(), reward.definition.get_instance_id(), reward.choices.map(func(choice: CardData) -> int: return choice.get_instance_id())]),
		"deck_definitions": [run.deck_state.draw_pile.map(func(card: CardInstance) -> int: return card.definition.get_instance_id()), run.deck_state.hand.map(func(card: CardInstance) -> int: return card.definition.get_instance_id()), run.deck_state.discard_pile.map(func(card: CardInstance) -> int: return card.definition.get_instance_id())],
		"generation": [run.deck_state.equipment_generation_turn, run.deck_state.next_equipment_slot],
		"card_sources": run.deck_state.hand.map(func(card: CardInstance) -> Array: return [card.definition.get_instance_id(), card.source_equipment.get_instance_id() if card.source_equipment != null else 0, card.source_board.get_instance_id() if card.source_board != null else 0]),
		"floor": floor.get_instance_id(), "floor_data": owner.floor_data.get_instance_id(), "board": floor.board_state.get_instance_id(), "deck": run.deck_state.get_instance_id(), "piles": piles, "equipment": equipment, "nodes": nodes,
		"state": [floor.turn_count, floor.threat, floor.cognition, floor.player_block, floor.dark_observation_used, floor.light_active, floor.discovered_insight_ids.duplicate(), floor.remaining_fresh_objectives.duplicate(), floor.seen_objective_ids.duplicate(), floor.floor_flags.duplicate()],
		"event": [event.get_instance_id(), event.explore_progress, event.sequence_index, event.completed_interactions.duplicate(), event.resolved, event.clue_revealed, event.known_information.duplicate(), event.last_progress_turn, event.pressure_checked_turn] if event != null else [],
		"entity": [entity.get_instance_id(), entity.hp, entity.max_hp, entity.state, entity.intent, entity.analysis_progress, entity.revealed_rules.duplicate(), entity.light_exposed] if entity != null else [],
		"cutout": [floor.cutout_state.get_instance_id(), floor.cutout_state.stability, floor.cutout_state.destination_knowledge, floor.cutout_state.destination_candidates.duplicate()],
		"attempt": run.last_cutout_attempt.get_instance_id() if run.last_cutout_attempt != null else 0}


func reject(owner: TurnManager, request: PlayCardCommand, reason: StringName) -> void:
	var before: Dictionary = snapshot(owner)
	var notifications: Array[int] = []
	var listener: Callable = func() -> void: notifications.append(1)
	owner.state_changed.connect(listener)
	var result: ActionResult = submit(owner, request)
	owner.state_changed.disconnect(listener)
	check(not result.success and result.failure_reason == reason, "Expected %s, got %s" % [reason, result.failure_reason])
	check(snapshot(owner) == before and notifications.is_empty(), "Failure preserves all state/RNG/piles/charges and sends no state notification")
	check(result.card.ap_spent == 0 and result.card.card_played == null and result.entity.hp_after == -1 and result.entity.analysis_after == -1 and result.floor.insight_ids.is_empty() and result.equipment.used_equipment == null and result.cutout.destination == null and result.floor.resource_looted_id.is_empty(), "Failure result contains no partial plan")


func generated(owner: TurnManager, action_id: StringName) -> CardInstance:
	var effects: Dictionary = {&"light": CardData.EffectType.LIGHT, &"extinguish": CardData.EffectType.EXTINGUISH, &"crowbar": CardData.EffectType.ATTACK, &"recover": CardData.EffectType.RECOVER, &"rushed": CardData.EffectType.CUTOUT_RUSHED, &"safe": CardData.EffectType.CUTOUT_SAFE}
	for card: CardInstance in owner.run_state.deck_state.hand:
		if card.source != CardData.Source.NORMAL and card.definition.effect_type == effects.get(action_id, -1):
			return card
	return null


func generated_request(owner: TurnManager, action_id: StringName) -> PlayCardCommand:
	var card: CardInstance = generated(owner, action_id)
	check(card != null, "Requested generated card must actually be in hand: %s" % action_id)
	var board: BoardState = owner.run_state.floor_state.board_state
	return PlayCardCommand.new(card, null, board, board.entity if card != null and card.definition.effect_type == CardData.EffectType.ATTACK else null)


func play_generated(owner: TurnManager, action_id: StringName) -> ActionResult:
	return submit(owner, generated_request(owner, action_id))


func click_generated(main: Control, action_id: StringName) -> void:
	var owner: TurnManager = main.get_node("TurnManager") as TurnManager
	var card: CardInstance = generated(owner, action_id)
	check(card != null, "UI can play only an actual generated hand card: %s" % action_id)
	if card == null:
		return
	if card.definition.effect_type == CardData.EffectType.ATTACK:
		(main.get_node("%EntityCard") as Button).pressed.emit()
	var index: int = owner.run_state.deck_state.hand.find(card)
	var button: Button = (main.get_node("%Hand") as HBoxContainer).get_child(index) as Button
	check(not button.disabled, "Generated hand card has a legal primary action")
	button.pressed.emit()


func click_card(main: Control, definition: CardData, entity: bool = false) -> void:
	(main.get_node("%EntityCard" if entity else "%WorldCard") as Button).pressed.emit()
	var owner: TurnManager = main.get_node("TurnManager") as TurnManager
	for index: int in range(owner.run_state.deck_state.hand.size()):
		if owner.run_state.deck_state.hand[index].definition == definition:
			var button: Button = (main.get_node("%Hand") as HBoxContainer).get_child(index) as Button
			check(not button.disabled, "Real single-semantic hand card is playable")
			button.pressed.emit()
			return
	check(false, "UI hand contains requested real card")


func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("[TEST] %s" % message)
