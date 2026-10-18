extends "res://tests/ui_validation.gd"

const LIVE_0: FloorData = preload("res://data/floors/floor_level_0.tres")
const LIVE_6: FloorData = preload("res://data/floors/floor_level_6.tres")
const LIVE_DECK: DeckData = preload("res://data/cards/run_deck.tres")
var graphical: bool = false


func label() -> String:
	return "Phase 10 / economy, safe points, resources, balance, production demo"


func tests() -> void:
	_test_content_and_economy()
	_test_safe_points()
	_test_resource_feedback()
	_test_exit_guarantee()
	_test_threat()
	for seed_value: int in [1, 3, 8, 21]:
		await full_run(seed_value)


func live_owner(data: FloorData = LIVE_0, definitions: Array[CardData] = [], gear: bool = true, seed_value: int = 1) -> TurnManager:
	return manager(LIVE_DECK.cards if definitions.is_empty() else definitions, data, gear, seed_value)


func live_copy(source: FloorData) -> FloorData:
	var data: FloorData = source.duplicate(false) as FloorData
	data.fresh_events = source.fresh_events.duplicate()
	data.resource_nodes = source.resource_nodes.duplicate()
	return data


func powerful() -> CardData:
	var definition: CardData = OBSERVE.duplicate(false) as CardData
	definition.explore_amount = 30
	return definition


func full_snapshot(owner: TurnManager) -> Dictionary:
	var record: Dictionary = snapshot(owner)
	var floor: FloorState = owner.run_state.floor_state
	var point: SafePointState = floor.safe_point
	record["point"] = [point.get_instance_id(), point.reached, point.consumed] if point != null else []
	record["progress"] = [floor.total_explore, floor.completed_situations]
	var metrics: RunMetrics = owner.run_state.metrics
	record["metrics"] = [metrics.cards_rewarded, metrics.cards_upgraded, metrics.cards_removed, metrics.cards_played, metrics.insights.duplicate(), metrics.situations.duplicate(true), metrics.floor_exits.duplicate(true)]
	return record


func reject_safe(owner: TurnManager, command_value: SafePointCommand, reason: StringName) -> void:
	var before: Dictionary = full_snapshot(owner)
	var calls: Array[int] = []
	var listener: Callable = func() -> void: calls.append(1)
	owner.state_changed.connect(listener)
	var result: ActionResult = owner.submit_safe_point_command(command_value)
	owner.state_changed.disconnect(listener)
	check(not result.success and result.failure_reason == reason, "Safe point rejects %s" % reason)
	check(before == full_snapshot(owner) and calls.is_empty() and result.safe_point_used == null, "Rejected choice changes no opportunity/AP/RNG/zone/equipment/metrics")


func _test_content_and_economy() -> void:
	var budget: int = 0
	for source: FloorData in [LIVE_0, LIVE_6]:
		check(source.fresh_events.size() == 5 and source.safe_point != null, "Each floor has five declared Situations and at most one Safe Point")
		for event: EventData in source.fresh_events:
			check(EventSystem.validate_situation(event).is_empty(), "Production Situation validates")
			var data: FloorData = live_copy(source)
			data.fresh_events = [event]
			data.intro_event = event
			var big: CardData = powerful()
			var owner: TurnManager = live_owner(data, [big, OBSERVE, ATTACK, GUARD, SEARCH])
			var old: EventInstance = owner.run_state.floor_state.current_event
			var result: ActionResult = play(owner, big)
			check(result.success and result.event_resolved and owner.run_state.floor_state.board_state.active_event == null, "Completed Situation leaves active slot after result commit")
			if event.completion_reward != null:
				budget += 1
				check(event.completion_reward.kind == CardRewardData.Kind.ADD_CARD and owner.run_state.pending_rewards.size() == 1, "Only selected major Situation gives three-card reward")
				var reward: CardReward = owner.run_state.pending_rewards[0]
				owner.submit_reward_command(CardRewardCommand.new(reward, reward.choices[0]))
			else:
				check(owner.run_state.pending_rewards.is_empty(), "Normal Situation never automatically offers a deck modification")
			var before: Dictionary = full_snapshot(owner)
			var stale: ActionResult = owner.request_play_card(hand_card(owner, OBSERVE), old, owner.run_state.floor_state.board_state)
			check(not stale.success and full_snapshot(owner) == before and owner.run_state.pending_rewards.is_empty(), "Stale resolved target cannot repeat reward or consume costs")
			owner.free()
		for entity: EntityData in [source.entry_entity, source.followup_entity]:
			if entity != null and entity.resolution_reward != null:
				budget += 1
	check(budget == 3, "Configured full-demo budget is one Level 0 and two Level 6 opportunities, without global hard cap")
	check(LIVE_6.followup_entity.reward_requires_light_exposure, "Smiler reward requires a meaningful observed encounter")
	var smiler_floor: FloorData = live_copy(LIVE_6)
	smiler_floor.entry_entity = smiler_floor.followup_entity
	smiler_floor.followup_entity = null
	smiler_floor.fresh_events = []
	smiler_floor.intro_event = null
	var owner: TurnManager = live_owner(smiler_floor, [], false)
	owner.end_turn()
	check(owner.run_state.pending_rewards.is_empty(), "Unobserved hidden Smiler withdrawal gives no trivial card reward")
	owner.free()
	owner = live_owner(smiler_floor)
	play_generated(owner, &"light")
	play_generated(owner, &"extinguish")
	owner.end_turn()
	check(owner.run_state.pending_rewards.size() == 1, "Actual LIGHT then correct behavior gives meaningful Smiler reward")
	var opportunity: CardReward = owner.run_state.pending_rewards[0]
	owner.submit_reward_command(CardRewardCommand.new(opportunity, opportunity.choices[0]))
	owner.end_turn()
	check(owner.run_state.pending_rewards.is_empty() and owner.run_state.metrics.cards_rewarded == 1, "Smiler resolution cannot repeatedly award cards")
	owner.free()


func safe_fixture(source: FloorData = LIVE_0) -> TurnManager:
	var data: FloorData = live_copy(source)
	data.fresh_events = [source.fresh_events[0], source.fresh_events[1]]
	data.entry_entity = null
	data.followup_entity = null
	var big: CardData = powerful()
	var owner: TurnManager = live_owner(data, [big, big, ATTACK, ATTACK, OBSERVE, GUARD])
	play(owner, big)
	check(not owner.run_state.floor_state.safe_point.reached, "One normal resolution does not unlock Safe Point")
	owner.end_turn()
	play(owner, big)
	check(SafePointSystem.available(owner.run_state), "Any two declared Situations reach one optional Safe Point")
	return owner


func _test_safe_points() -> void:
	var owner: TurnManager = safe_fixture()
	var state: RunState = owner.run_state
	var point: SafePointState = state.floor_state.safe_point
	var board: BoardState = state.floor_state.board_state
	reject_safe(owner, SafePointCommand.new(board, point, SafePointCommand.Choice.REST), &"nothing_to_restore")
	state.player_hp = 20
	state.stress = 5
	var ap: int = state.ap
	check(owner.submit_safe_point_command(SafePointCommand.new(board, point, SafePointCommand.Choice.REST)).success and state.player_hp == 26 and state.stress == 2 and point.consumed and state.ap == ap, "Rest commits configured HP/Stress and consumes exactly one opportunity without AP reset")
	var card: CardInstance = CardRewardSystem.eligible_cards(state, CardRewardData.Kind.UPGRADE_CARD)[0]
	reject_safe(owner, SafePointCommand.new(board, point, SafePointCommand.Choice.UPGRADE, card), &"safe_point_unavailable")
	owner.free()
	owner = safe_fixture()
	state = owner.run_state
	point = state.floor_state.safe_point
	board = state.floor_state.board_state
	var copies: Array[CardInstance] = CardRewardSystem.eligible_cards(state, CardRewardData.Kind.UPGRADE_CARD).filter(func(value: CardInstance) -> bool: return value.definition == ATTACK)
	var selected: CardInstance = copies[0]
	check(owner.submit_safe_point_command(SafePointCommand.new(board, point, SafePointCommand.Choice.UPGRADE, selected)).success and selected.definition == ATTACK.upgrade_to and copies[1].definition == ATTACK and ATTACK.effect_value == 4 and state.metrics.cards_upgraded == 1, "Safe Point upgrades only selected instance and records one committed change")
	reject_safe(owner, SafePointCommand.new(board, point, SafePointCommand.Choice.REMOVE, copies[1]), &"safe_point_unavailable")
	owner.free()
	owner = safe_fixture(LIVE_6)
	owner.end_turn()
	state = owner.run_state
	point = state.floor_state.safe_point
	board = state.floor_state.board_state
	var generated_count: int = 0
	for value: CardInstance in state.deck_state.hand:
		if value.source == CardData.Source.NORMAL:
			continue
		generated_count += 1
		for choice: SafePointCommand.Choice in [SafePointCommand.Choice.REMOVE, SafePointCommand.Choice.UPGRADE]:
			reject_safe(owner, SafePointCommand.new(board, point, choice, value), &"invalid_reward_card")
	check(generated_count == 2, "Actual equipment and retained floor cards both excluded from Safe Point flows")
	selected = CardRewardSystem.eligible_cards(state, CardRewardData.Kind.REMOVE_CARD)[0]
	check(owner.submit_safe_point_command(SafePointCommand.new(board, point, SafePointCommand.Choice.REMOVE, selected)).success and state.deck_state.get_card_count() == 5 and state.metrics.cards_removed == 1 and CardRewardSystem.eligible_cards(state, CardRewardData.Kind.REMOVE_CARD).is_empty(), "Removal preserves minimum five NORMAL cards and cannot grant a second choice")
	owner.free()
	owner = safe_fixture()
	state = owner.run_state
	owner.end_turn()
	point = state.floor_state.safe_point
	board = state.floor_state.board_state
	var old_equipment: Array[EquipmentInstance] = state.equipment_slots.duplicate()
	var old_deck: DeckState = state.deck_state
	var exit_card: CardInstance = generated(owner, &"safe")
	check(exit_card != null and play_generated(owner, &"safe").success and not point.consumed and state.floor_state.floor_id == LIVE_6.id, "Player may leave without consuming optional Safe Point")
	check(state.deck_state == old_deck and state.equipment_slots == old_equipment and not state.deck_state.hand.has(exit_card), "Run deck/equipment survive, old temporary exit does not")
	reject_safe(owner, SafePointCommand.new(board, point, SafePointCommand.Choice.REST), &"invalid_safe_point")
	owner.free()


func _test_resource_feedback() -> void:
	var data: FloorData = live_copy(LIVE_6)
	data.entry_entity = null
	data.followup_entity = null
	data.fresh_events = []
	data.intro_event = null
	data.resource_nodes = [LIVE_6.resource_nodes[0]]
	var owner: TurnManager = live_owner(data, [SEARCH, SEARCH, SEARCH, SEARCH, SEARCH])
	var state: RunState = owner.run_state
	var battery: EquipmentInstance = state.equipment_slots[0]
	var command_value: PlayCardCommand = PlayCardCommand.new(hand_card(owner, SEARCH), null, state.floor_state.board_state)
	reject(owner, command_value, &"resources_exhausted")
	check(state.floor_state.resource_nodes[0].status == ResourceNode.Status.UNDISCOVERED, "Full equipment does not waste a finite battery cache")
	play_generated(owner, &"light")
	var result: ActionResult = owner.submit_card_command(command_value)
	check(result.success and result.resource_uses_gained == 1 and battery.remaining_uses == 3 and state.floor_state.resource_nodes[0].status == ResourceNode.Status.LOOTED, "Search refills actual battery with capacity cap in same atomic resolution")
	reject(owner, PlayCardCommand.new(hand_card(owner, SEARCH), null, state.floor_state.board_state), &"resources_exhausted")
	owner.end_turn()
	check(state.floor_state.resource_nodes[0].status == ResourceNode.Status.DEPLETED and battery.remaining_uses == 3, "Depleted cache never yields another recharge")
	owner.free()
	for index: int in [1, 2]:
		data = live_copy(LIVE_6)
		data.entry_entity = null
		data.followup_entity = null
		data.resource_nodes = [LIVE_6.resource_nodes[index]]
		owner = live_owner(data, [SEARCH, SEARCH, SEARCH, SEARCH, SEARCH])
		var item: EquipmentInstance = owner.run_state.equipment_slots[index]
		item.remaining_uses = 0
		result = play(owner, SEARCH)
		check(result.success and result.resource_equipment == item and item.remaining_uses == 1, "Declared finite searches restore Crowbar durability / Almond Water count")
		owner.free()


func _test_exit_guarantee() -> void:
	for seed_value: int in range(1, 13):
		var source: FloorData = live_copy(LIVE_0)
		var destination: FloorData = live_copy(LIVE_6)
		for data: FloorData in [source, destination]:
			data.fresh_events = []
			data.intro_event = null
			data.resource_nodes = []
			data.safe_point = null
			data.entry_entity = null
			data.followup_entity = null
		source.cutout_destinations = [destination]
		var owner: TurnManager = live_owner(source, [], false, seed_value)
		for floor_index: int in range(2):
			for turn: int in range(1, 6):
				check(generated(owner, &"rushed") == null, "No immediate entry exit; empty floor waits configured fallback")
				owner.end_turn()
			var retained: CardInstance = generated(owner, &"rushed")
			check(retained != null and owner.run_state.cognition == 0 and owner.run_state.floor_state.turn_count == 6, "Empty/missed-content floor has independent retained exit by fallback")
			for attempt: int in range(20):
				var before: FloorState = owner.run_state.floor_state
				var result: ActionResult = play_generated(owner, &"rushed")
				if result.cutout_attempt != null and result.cutout_attempt.succeeded:
					check(owner.run_state.floor_state != before, "Only successful cut-out changes floor")
					break
				check(generated(owner, &"rushed") == retained, "Failed rush retains exact opportunity")
				owner.end_turn()
		check(owner.floor_data.is_placeholder and owner.run_state.metrics.floor_exits.size() == 2, "Missing all events/resources/Insight never permanently blocks either floor")
		owner.free()


func _test_threat() -> void:
	var owner: TurnManager = live_owner(LIVE_6)
	var state: RunState = owner.run_state
	var entity: EntityInstance = state.floor_state.entity
	entity.state = &"APPROACHING"
	entity.intent = &"bite"
	state.floor_state.threat = 4
	check(EntitySystem.intent_damage(entity, LIVE_6.entry_entity, state.floor_state, LIVE_6) == 5, "Level 6 Threat increases published intent damage")
	var result: ActionResult = owner.end_turn()
	check(result.player_damage == 5 and result.pressure_damage == 1 and state.player_hp == 24, "Published Threat-enhanced damage resolves through original Pressure/intent pipeline")
	owner.free()


func ui_button(main: Control, card: CardInstance) -> Button:
	var owner: TurnManager = main.get_node("TurnManager") as TurnManager
	return (main.get_node("%Hand") as HBoxContainer).get_child(owner.run_state.deck_state.hand.find(card)) as Button


func request_for(owner: TurnManager, card: CardInstance, entity: bool = false) -> PlayCardCommand:
	var board: BoardState = owner.run_state.floor_state.board_state
	return PlayCardCommand.new(card, null if entity or card.definition.target_kinds == 0 else board.active_event, board, board.entity if entity else null)


func candidates(owner: TurnManager, effect: int, explore: bool = false) -> Array[CardInstance]:
	var legal: Array[CardInstance] = []
	for card: CardInstance in owner.run_state.deck_state.hand:
		if (explore and card.definition.explore_amount <= 0) or (not explore and card.definition.effect_type != effect):
			continue
		var request: PlayCardCommand = request_for(owner, card, not explore and effect in [CardData.EffectType.ATTACK, CardData.EffectType.RUN])
		if RuleResolver.command_ap_cost(request, owner.run_state, owner.floor_data) <= owner.run_state.ap and RuleResolver.validate_card_target(request, owner.run_state.floor_state, owner.floor_data, owner.run_state).is_empty():
			legal.append(card)
	legal.sort_custom(func(a: CardInstance, b: CardInstance) -> bool: return a.definition.effect_value > b.definition.effect_value if not explore else float(a.definition.explore_amount) / RuleResolver.card_ap_cost(a.definition, owner.run_state, owner.floor_data) > float(b.definition.explore_amount) / RuleResolver.card_ap_cost(b.definition, owner.run_state, owner.floor_data))
	return legal


func checkpoint(_main: Control, _name_text: String) -> void:
	# 图形入口覆盖此钩子；无窗口测试不会假称已经截图验收。
	await process_frame
	await process_frame
	for node_name: String in ["%WorldCard", "%EntityCard", "%Hand", "%EndTurn"]:
		var node: Control = _main.get_node(node_name) as Control
		if node.is_visible_in_tree():
			check(_main.get_viewport_rect().encloses(node.get_global_rect()), "Production layout fits viewport: %s / %s viewport=%s rect=%s" % [_name_text, node_name, _main.get_viewport_rect(), node.get_global_rect()])


func _claim(main: Control) -> void:
	var owner: TurnManager = main.get_node("TurnManager") as TurnManager
	while not owner.run_state.pending_rewards.is_empty():
		await checkpoint(main, "card_reward")
		var options: VBoxContainer = main.get_node("%RewardPanel/Margin/Layout/Scroll/Options") as VBoxContainer
		check(options.get_child_count() == 3, "Actual reward panel preserves three NORMAL choices")
		await _mouse_click(options.get_child(0) as Control)


func _use_safe(main: Control, choice: SafePointCommand.Choice) -> void:
	var owner: TurnManager = main.get_node("TurnManager") as TurnManager
	if not SafePointSystem.available(owner.run_state):
		return
	(main.get_node("%OpenSafePoint") as Button).pressed.emit()
	await checkpoint(main, "safe_point")
	var options: VBoxContainer = main.get_node("%SafePointPanel/Margin/Layout/Scroll/Options") as VBoxContainer
	var selected: Button = options.get_child(int(choice)) as Button
	if selected.disabled:
		(main.get_node("%SafePointPanel") as Control).hide()
		return
	selected.pressed.emit()
	if choice != SafePointCommand.Choice.REST:
		await process_frame
		await checkpoint(main, "safe_point_candidates")
		check((main.get_node("%SafePointPanel/Margin/Layout/Footer/Back") as Button).visible and main.get_viewport_rect().encloses((main.get_node("%SafePointPanel/Margin/Layout/Footer/Back") as Control).get_global_rect()), "Long candidate list retains visible fixed Back control")
		(options.get_child(0) as Button).pressed.emit()
	check(owner.run_state.floor_state.safe_point.consumed, "Actual Safe Point UI commits one chosen branch")


func full_run(seed_value: int = 1) -> void:
	root.size = Vector2i(1152, 648)
	var main: Control = MAIN.instantiate() as Control
	var owner: TurnManager = main.get_node("TurnManager") as TurnManager
	owner.run_state.rng_seed = seed_value
	owner.run_state.rng.seed = seed_value
	root.add_child(main)
	var state: RunState = owner.run_state
	var deck: DeckState = state.deck_state
	var gear: Array[EquipmentInstance] = state.equipment_slots.duplicate()
	var rewarded_instances: Array[CardInstance] = []
	var drawn_reward: Array[CardInstance] = []
	owner.action_resolved.connect(func(result: ActionResult) -> void:
		if result.deck_change_kind == &"added": rewarded_instances.append(result.deck_card_changed))
	await checkpoint(main, "level0_targeting")
	for global_turn: int in range(80):
		if owner.floor_data.is_placeholder or state.player_hp <= 0:
			break
		for card: CardInstance in deck.hand:
			if rewarded_instances.has(card) and not drawn_reward.has(card): drawn_reward.append(card)
		if generated(owner, &"rushed") != null:
			await checkpoint(main, "rushed_cutout")
		if generated(owner, &"safe") != null:
			await checkpoint(main, "prepared_cutout")
		if owner.floor_data.id == LIVE_6.id and state.floor_state.entity != null and state.floor_state.entity.entity_id == LIVE_6.entry_entity.id:
			(main.get_node("%EntityCard") as Button).pressed.emit()
			await checkpoint(main, "hound_targeting")
		await _claim(main)
		await _use_safe(main, SafePointCommand.Choice.UPGRADE if owner.floor_data.id == LIVE_0.id else SafePointCommand.Choice.REMOVE)
		for action: int in range(5):
			if state.ap == 0:
				break
			var floor: FloorState = state.floor_state
			var entity: EntityInstance = floor.entity
			var event: EventInstance = floor.current_event
			var chosen: CardInstance
			if entity != null and entity.entity_id == LIVE_6.followup_entity.id:
				await checkpoint(main, "smiler")
				var extinguish: Array[CardInstance] = candidates(owner, CardData.EffectType.EXTINGUISH)
				if not extinguish.is_empty(): chosen = extinguish[0]
			if chosen == null and entity != null and entity.entity_id == LIVE_6.entry_entity.id:
				var attacks: Array[CardInstance] = candidates(owner, CardData.EffectType.ATTACK)
				if not attacks.is_empty() and attacks[0].definition.effect_value >= entity.hp: chosen = attacks[0]
			if chosen == null and event != null and event.last_progress_turn != floor.turn_count:
				var explores: Array[CardInstance] = candidates(owner, -1, true)
				if not explores.is_empty(): chosen = explores[0]
			if chosen == null and entity != null:
				var damage: int = EntitySystem.intent_damage(entity, owner.floor_data.find_entity(entity.entity_id), floor, owner.floor_data)
				var guards: Array[CardInstance] = candidates(owner, CardData.EffectType.BLOCK)
				if damage > floor.player_block and not guards.is_empty(): chosen = guards[0]
			if chosen == null and entity != null:
				var attacks: Array[CardInstance] = candidates(owner, CardData.EffectType.ATTACK)
				if not attacks.is_empty(): chosen = attacks[0]
			if chosen == null and entity == null and floor.resolved_entity_ids.has(LIVE_6.entry_entity.id) and not floor.resolved_entity_ids.has(LIVE_6.followup_entity.id) and state.ap >= 2:
				var lights: Array[CardInstance] = candidates(owner, CardData.EffectType.LIGHT)
				if not lights.is_empty(): chosen = lights[0]
			if chosen == null and state.stress >= 2:
				var water: Array[CardInstance] = candidates(owner, CardData.EffectType.RECOVER)
				if not water.is_empty(): chosen = water[0]
			if chosen == null and event != null:
				var explores: Array[CardInstance] = candidates(owner, -1, true)
				if not explores.is_empty(): chosen = explores[0]
			if chosen == null:
				break
			if chosen.definition.target_kinds != 0:
				(main.get_node("%EntityCard" if chosen.definition.effect_type == CardData.EffectType.ATTACK else "%WorldCard") as Button).pressed.emit()
			var button: Button = ui_button(main, chosen)
			check(not button.disabled, "Balanced route uses only actual enabled hand cards")
			var old_entity: EntityInstance = floor.entity
			button.pressed.emit()
			await _claim(main)
			if old_entity != null and not old_entity.active and old_entity.entity_id == LIVE_6.entry_entity.id:
				await checkpoint(main, "hound_removed")
		var floor: FloorState = state.floor_state
		var all_done: bool = floor.remaining_fresh_events.is_empty() and floor.current_event == null and floor.entity == null
		if all_done:
			await _use_safe(main, SafePointCommand.Choice.UPGRADE if owner.floor_data.id == LIVE_0.id else SafePointCommand.Choice.REMOVE)
			var exits: Array[CardInstance] = candidates(owner, CardData.EffectType.CUTOUT_SAFE)
			if exits.is_empty(): exits = candidates(owner, CardData.EffectType.CUTOUT_RUSHED)
			if not exits.is_empty():
				await checkpoint(main, "safe_cutout")
				var old_board: BoardState = floor.board_state
				var old_card: CardInstance = exits[0]
				ui_button(main, old_card).pressed.emit()
				if state.floor_state.board_state != old_board:
					check(state.deck_state == deck and state.equipment_slots == gear and not deck.hand.has(old_card), "Live floor transition preserves persistent objects and removes old exit instance")
					await checkpoint(main, "transition" if not owner.floor_data.is_placeholder else "summary")
		if not owner.floor_data.is_placeholder:
			(main.get_node("%EndTurn") as Button).pressed.emit()
	check(owner.floor_data.is_placeholder and state.player_hp > 0, "Deterministic production UI path reaches Demo Complete alive")
	check(state.metrics.cards_rewarded == 3 and state.metrics.cards_upgraded == 1 and state.metrics.cards_removed == 1, "Full route follows three card rewards and exactly one chosen branch per floor Safe Point")
	check(state.metrics.floor_exits.size() == 2 and state.metrics.insights.size() >= 6 and state.metrics.defeated.has("猎犬") and state.metrics.resolved_alive.has("笑魇"), "Summary contains both floors, unique discoveries, kill and alive resolution")
	check(not drawn_reward.is_empty(), "New persistent reward is actually drawn and experienced before demo ends")
	check(state.metrics.dead_hands == 0 and state.metrics.multiple_option_hands * 2 > state.metrics.hands_checked, "Measured production hands avoid full dead hands and usually offer multiple options")
	check((main.get_node("%RunSummary") as Control).visible and not (main.get_node("Margin") as Control).visible and (main.get_node("%RunSummary/Margin/Layout/Information") as Label).text.contains("最终威胁"), "Chinese final summary replaces reset live counters and reads persistent run facts")
	print("[DEMO] seed=%d turns=%d cards=%d deck=%d hp=%d stress=%d dead_hands=%d/%d multiple=%d encounters=%s" % [seed_value, state.turn_number, state.metrics.cards_rewarded, deck.get_card_count(), state.player_hp, state.stress, state.metrics.dead_hands, state.metrics.hands_checked, state.metrics.multiple_option_hands, state.metrics.entity_encounters])
	await checkpoint(main, "summary")
	(main.get_node("%RunSummary/Margin/Layout/NewRun") as Button).pressed.emit()
	check((main.get_node("TurnManager") as TurnManager).run_state != state and not (main.get_node("%RunSummary") as Control).visible, "Completion screen starts a normal fresh run without prototype switching")
	main.free()
