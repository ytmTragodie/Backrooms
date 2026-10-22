extends "res://tests/ui_validation.gd"

const REWARDS: CardRewardData = preload("res://data/rewards/reward_cards.tres")
const UPGRADE: CardRewardData = preload("res://data/rewards/reward_upgrade.tres")
const REMOVE: CardRewardData = preload("res://data/rewards/reward_remove.tres")
const COUNTER: CardData = preload("res://data/cards/rewards/card_counter_strike.tres")
const CRISIS: CardData = preload("res://data/cards/rewards/card_crisis_observe.tres")
const WEAKNESS: CardData = preload("res://data/cards/rewards/card_exploit_weakness.tres")


func label() -> String:
	return "Phase 9 / targeting, rewards, upgrades, removal, full production UI run"


func tests() -> void:
	_test_declared_targets()
	_test_retirement_and_reward()
	_test_disengage_reward()
	_test_rewards_and_rng()
	_test_upgrade()
	_test_removal()
	_test_new_cards()
	await _test_target_ui()
	await _test_production_ui_run()


func production_floor(source: FloorData = LEVEL_0) -> FloorData:
	var data: FloorData = fixture(source)
	for index: int in range(source.fresh_objectives.size()):
		data.fresh_objectives[index].completion_reward = source.fresh_objectives[index].completion_reward
	if data.entry_entity != null:
		data.entry_entity.resolution_reward = source.entry_entity.resolution_reward
	return data


func all_cards(state: RunState) -> Array[CardInstance]:
	var cards: Array[CardInstance] = []
	for pile: Array[CardInstance] in [state.player.deck.hand, state.player.deck.draw_pile, state.player.deck.discard_pile]:
		cards.append_array(pile)
	return cards


func reject_reward(owner: TurnManager, command_value: CardRewardCommand, reason: StringName) -> void:
	var before: Dictionary = snapshot(owner)
	var notifications: Array[int] = []
	var listener: Callable = func() -> void: notifications.append(1)
	owner.state_changed.connect(listener)
	var result: ActionResult = owner.submit_reward_command(command_value)
	owner.state_changed.disconnect(listener)
	check(not result.success and result.failure_reason == reason, "Reward rejection reports %s" % reason)
	check(snapshot(owner) == before and notifications.is_empty() and result.deck.card_changed == null, "Rejected reward preserves RNG/AP/all zones/definitions/opportunities/equipment with no notification")


func _test_declared_targets() -> void:
	var owner: TurnManager = manager([SEARCH, DEEP, ATTACK, OBSERVE, OBSERVE], LEVEL_6)
	var board: BoardState = owner.run_state.floor_state.board_state
	reject(owner, PlayCardCommand.new(hand_card(owner, SEARCH), null, board, board.entity), &"invalid_target_kind")
	reject(owner, PlayCardCommand.new(hand_card(owner, DEEP), null, board, board.entity), &"invalid_target_kind")
	reject(owner, PlayCardCommand.new(hand_card(owner, ATTACK), board.active_objective, board), &"invalid_target_kind")
	var observe: CardInstance = hand_card(owner, OBSERVE)
	check(RuleResolver.validate_card_target(PlayCardCommand.new(observe, board.active_objective, board), owner.run_state.floor_state, owner.floor_data, owner.run_state).is_empty(), "Observe declares a live Situation route")
	check(RuleResolver.validate_card_target(PlayCardCommand.new(observe, null, board, board.entity), owner.run_state.floor_state, owner.floor_data, owner.run_state).is_empty(), "Observe declares an analyzable live Entity route")
	check(play(owner, OBSERVE, true).entity.analysis_applied == 2 and play(owner, OBSERVE).objective.progress_applied == 2, "Declared Observe routes share AP and preserve separate knowledge/Explore consumers")
	owner.free()
	var data: FloorData = fixture(LEVEL_6)
	data.entry_entity = data.followup_entity
	data.followup_entity = null
	owner = manager([RUN, OBSERVE, OBSERVE, OBSERVE, OBSERVE], data)
	reject(owner, command(owner, RUN, true), &"entity_state_incompatible")
	owner.free()


func _test_retirement_and_reward() -> void:
	var lethal: CardData = ATTACK.duplicate(false) as CardData
	lethal.effect_value = 18
	var owner: TurnManager = manager([lethal, ATTACK, OBSERVE, SEARCH, GUARD], production_floor(LEVEL_6))
	var state: RunState = owner.run_state
	var board: BoardState = state.floor_state.board_state
	var hound: EntityInstance = board.entity
	var stale: PlayCardCommand = PlayCardCommand.new(hand_card(owner, ATTACK), null, board, hound)
	var notified: Array[bool] = []
	owner.state_changed.connect(func() -> void: notified.append(hound.hp == 0 and board.entity == null and state.flow.pending_rewards.size() == 1))
	var result: ActionResult = play(owner, lethal, true)
	check(result.entity.defeated and not hound.alive and board.entity == null and state.floor_state.resolved_entity_ids == [hound.entity_id] and notified == [true], "Final defeat/reward commit precedes board retirement and observer notification")
	check(state.flow.pending_rewards[0].choices.size() == 3, "Meaningful Hound resolution offers three choices")
	var reward: CardReward = state.flow.pending_rewards[0]
	check(owner.submit_reward_command(CardRewardCommand.new(reward, reward.choices[0])).success, "Resolve actual Hound opportunity")
	reject(owner, stale, &"invalid_entity_target")
	check(play_generated(owner, &"light").success and board.entity != null and board.entity.entity_id == LEVEL_6.followup_entity.id, "LIGHT after removed Hound uses resolved fact to spawn Smiler")
	var smiler: EntityInstance = board.entity
	reject(owner, stale, &"invalid_entity_target")
	check(play_generated(owner, &"extinguish").success, "Same flashlight opportunity gives legal Extinguish after follow-up")
	owner.end_turn()
	check(smiler.alive and smiler.state == &"WITHDRAWN" and board.entity == null and state.floor_state.resolved_entity_ids.has(smiler.entity_id), "Smiler resolves alive and also leaves active board")
	owner.free()


func _event_reward_manager(seed_value: int = 1) -> TurnManager:
	var data: FloorData = production_floor()
	data.fresh_objectives = [data.fresh_objectives[0]]
	return manager([OBSERVE, OBSERVE, SEARCH, ATTACK, GUARD, OBSERVE, SEARCH], data, false, seed_value)


func _test_disengage_reward() -> void:
	var data: FloorData = production_floor(LEVEL_6)
	data.entry_entity.initial_state = &"APPROACHING"
	var owner: TurnManager = manager([GUARD, GUARD, RUN], data, false)
	var hound: EntityInstance = owner.run_state.floor_state.entity
	play(owner, GUARD)
	play(owner, GUARD)
	owner.end_turn()
	check(hound.state == &"STAGGERED", "Published intent can be fully blocked in same loop")
	check(play(owner, RUN, true).success and hound.alive and hound.state == &"DISENGAGED" and owner.run_state.floor_state.entity == null and owner.run_state.flow.pending_rewards.size() == 1, "Data-driven reward also supports meaningful alive disengagement")
	var reward: CardReward = owner.run_state.flow.pending_rewards[0]
	owner.submit_reward_command(CardRewardCommand.new(reward, reward.choices[0]))
	owner.end_turn()
	check(owner.run_state.flow.pending_rewards.is_empty() and owner.run_state.floor_state.entity == null, "Resolved facts cannot repeat reward or respawn Hound")
	owner.free()


func _test_rewards_and_rng() -> void:
	for seed_value: int in range(1, 13):
		var pair: Array[TurnManager] = [_event_reward_manager(seed_value), _event_reward_manager(seed_value)]
		var offered: Array = []
		for owner: TurnManager in pair:
			play(owner, OBSERVE)
			var before_rng: int = owner.run_state.rng.state
			play(owner, OBSERVE)
			var state: RunState = owner.run_state
			check(state.flow.pending_rewards.size() == 1 and state.rng.state != before_rng, "Only declared completion offers reward and commits RNG")
			var reward: CardReward = state.flow.pending_rewards[0]
			check(reward.choices.size() == 3 and reward.choices[0] != reward.choices[1] and reward.choices[1] != reward.choices[2] and reward.choices[0] != reward.choices[2], "Offer contains exactly three distinct choices")
			offered.append(reward.choices.map(func(card: CardData) -> StringName: return card.id))
			check(all_cards(state).all(func(card: CardInstance) -> bool: return not reward.choices.has(card.definition)), "No offered choice enters deck before claim")
			reject(owner, command(owner, SEARCH), &"reward_pending")
			var before: Dictionary = snapshot(owner)
			check(owner.end_turn().failure_reason == &"reward_pending" and snapshot(owner) == before, "Pending choice freezes lifecycle without spending")
			reject_reward(owner, CardRewardCommand.new(reward, LEVEL_0.rushed_cutout_card), &"invalid_reward_choice")
			var selected: CardData = reward.choices[0]
			var result: ActionResult = owner.submit_reward_command(CardRewardCommand.new(reward, selected))
			check(result.success and result.deck.card_changed.definition == selected and state.player.deck.discard_pile.has(result.deck.card_changed) and state.player.deck.get_card_count() == 8 and state.flow.pending_rewards.is_empty(), "One new NORMAL instance enters existing discard for future draws")
			check(all_cards(state).filter(func(card: CardInstance) -> bool: return reward.choices.has(card.definition)).size() == 1, "Unchosen offers never enter any zone")
			check(state.player.ap == before.ap and state.flow.turn_number == before.turn and state.rng.state == before.rng, "Claim does not draw/advance/reset AP or consume extra RNG")
			reject_reward(owner, CardRewardCommand.new(reward, selected), &"invalid_reward")
			var drawn: bool = false
			for turn: int in range(5):
				owner.end_turn()
				drawn = drawn or state.player.deck.hand.has(result.deck.card_changed)
			check(drawn, "Chosen instance is drawn later through existing shuffle lifecycle")
		check(offered[0] == offered[1], "Same seed and commands reproduce exact reward choices")
		for owner: TurnManager in pair:
			owner.free()
	for bad_card: CardData in [FLASH.action_card, LEVEL_0.rushed_cutout_card]:
		var bad: CardRewardData = REWARDS.duplicate(false) as CardRewardData
		bad.pool = [REWARDS.pool[0], REWARDS.pool[1], bad_card]
		check(CardRewardSystem.validate_definition(bad) == &"invalid_reward_definition", "Generated cards cannot contaminate reward pool")
		var data: FloorData = production_floor()
		data.fresh_objectives[0].completion_reward = bad
		var owner: TurnManager = manager([OBSERVE, OBSERVE, OBSERVE, OBSERVE, OBSERVE], data)
		reject(owner, command(owner, OBSERVE), &"invalid_reward_definition")
		owner.free()


func _test_upgrade() -> void:
	var data: FloorData = production_floor()
	data.fresh_objectives = [data.fresh_objectives[1]]
	var owner: TurnManager = manager([OBSERVE, OBSERVE, OBSERVE, ATTACK, ATTACK, SEARCH], data, false)
	for index: int in range(3):
		play(owner, OBSERVE)
	var state: RunState = owner.run_state
	var reward: CardReward = state.flow.pending_rewards[0]
	check(reward.definition == UPGRADE, "Declared Situation offers upgrade rather than extra cards")
	var copies: Array[CardInstance] = state.player.deck.hand.filter(func(card: CardInstance) -> bool: return card.definition == ATTACK)
	var chosen: CardInstance = copies[0]
	var stale: PlayCardCommand = PlayCardCommand.new(chosen, null, state.floor_state.board_state)
	var index_before: int = state.player.deck.hand.find(chosen)
	var inventory: Array[CardInstance] = all_cards(state)
	var result: ActionResult = owner.submit_reward_command(CardRewardCommand.new(reward, null, chosen))
	check(result.success and chosen.definition == ATTACK.upgrade_to and copies[1].definition == ATTACK and ATTACK.effect_value == 4, "Only chosen copy upgrades; other copy and shared CardData unchanged")
	check(state.player.deck.hand.find(chosen) == index_before and state.player.deck.get_card_count() == 6 and all_cards(state) == inventory, "Upgrade preserves exact instance, position and zone ownership")
	reject(owner, stale, &"invalid_card_source")
	reject_reward(owner, CardRewardCommand.new(reward, null, copies[1]), &"invalid_reward")
	owner.free()


func _test_removal() -> void:
	var data: FloorData = production_floor(LEVEL_6)
	data.entry_entity.resolution_reward = null
	var event: ObjectiveData = data.fresh_objectives[0]
	event.progress_threshold = 2
	event.clue_threshold = 2
	event.completion_reward = REMOVE
	var owner: TurnManager = manager([OBSERVE, SEARCH, ATTACK, GUARD, RUN, OBSERVE], data)
	play(owner, OBSERVE)
	var state: RunState = owner.run_state
	var reward: CardReward = state.flow.pending_rewards[0]
	var eligible: Array[CardInstance] = CardRewardSystem.eligible_cards(state, CardRewardData.Kind.REMOVE_CARD)
	check(eligible.size() == 6 and eligible.all(func(card: CardInstance) -> bool: return card.source == CardData.Source.NORMAL), "Removal opportunity enumerates only owned normal instances across all zones")
	for card: CardInstance in state.player.deck.hand:
		if card.source != CardData.Source.NORMAL:
			reject_reward(owner, CardRewardCommand.new(reward, null, card), &"invalid_reward_card")
	check(generated(owner, &"light") != null and generated(owner, &"rushed") != null, "Removal exclusion test includes actual equipment and retained CutOut cards")
	reject_reward(owner, CardRewardCommand.new(reward), &"invalid_reward_card")
	var chosen: CardInstance = eligible[0]
	var stale: PlayCardCommand = PlayCardCommand.new(chosen, null, state.floor_state.board_state)
	check(owner.submit_reward_command(CardRewardCommand.new(reward, null, chosen)).success and state.player.deck.get_card_count() == 5 and not all_cards(state).has(chosen), "Exactly one normal instance leaves run deck")
	reject(owner, stale, &"card_not_in_hand")
	check(CardRewardSystem.eligible_cards(state, CardRewardData.Kind.REMOVE_CARD).is_empty(), "Five-card minimum excludes further removals")
	# 独立机会夹具验证空候选继续边界，不给真实玩家新增自由删牌入口。
	var empty: CardReward = CardReward.new()
	empty.definition = REMOVE
	state.flow.pending_rewards.append(empty)
	check(owner.submit_reward_command(CardRewardCommand.new(empty)).success and state.player.deck.get_card_count() == 5, "Empty removal opportunity can close without trapping run")
	owner.free()


func _test_new_cards() -> void:
	check(REWARDS.pool.size() == 9, "Content expansion stays at nine new normal definitions")
	for definition: CardData in REWARDS.pool:
		check(definition.is_deckbuilding_definition_valid(), "Reward has a reusable real baseline: %s" % definition.id)
		var owner: TurnManager = manager([definition, GUARD, OBSERVE, OBSERVE, OBSERVE], LEVEL_6, false)
		var result: ActionResult = play(owner, definition, definition.target_kinds == CardData.TargetKind.ENTITY)
		check(result.success and result.card.ap_spent == definition.ap_cost + (1 if definition.tags.has(&"OBSERVE") else 0), "Each offered definition resolves its declared semantic")
		check(owner.run_state.floor_state.threat == definition.threat_cost, "Each risk variant commits own Threat cost")
		if definition.explore_amount > 0:
			check(result.objective.progress_applied == definition.explore_amount, "Explore baseline is consumed by generic Situation")
		elif definition.effect_type == CardData.EffectType.ATTACK:
			check(result.entity.damage == definition.effect_value, "Conditional attacks still have baseline damage without synergy")
		owner.free()
	var owner: TurnManager = manager([GUARD, COUNTER, OBSERVE, OBSERVE, OBSERVE], LEVEL_6, false)
	play(owner, GUARD)
	check(play(owner, COUNTER, true).entity.damage == 7, "Guard condition increases same attack semantic")
	owner.free()
	owner = manager([CRISIS, OBSERVE, OBSERVE, OBSERVE, OBSERVE], LEVEL_6, false)
	owner.run_state.floor_state.threat = 4
	check(play(owner, CRISIS).objective.progress_applied == 5, "High Threat condition increases Explore")
	owner.free()
	owner = manager([OBSERVE, OBSERVE, WEAKNESS], LEVEL_6, false)
	play(owner, OBSERVE, true)
	play(owner, OBSERVE, true)
	owner.end_turn()
	check(play(owner, WEAKNESS, true).entity.damage == 7, "Revealed behavior knowledge enables analyzed-target attack bonus")
	owner.free()


func _test_target_ui() -> void:
	var main: Control = MAIN.instantiate() as Control
	(main.get_node("TurnManager") as TurnManager).floor_data = preload("res://tests/fixtures/phase9/floors/floor_level_0.tres")
	(main.get_node("TurnManager") as TurnManager).starter_deck = preload("res://tests/fixtures/phase9/cards/run_deck.tres")
	(main.get_node("TurnManager") as TurnManager).floor_data = fixture(LEVEL_6)
	root.add_child(main)
	var owner: TurnManager = main.get_node("TurnManager") as TurnManager
	var board: BoardState = owner.run_state.floor_state.board_state
	var hand: HBoxContainer = main.get_node("%Hand") as HBoxContainer
	var before: Dictionary = snapshot(owner)
	(main.get_node("%WorldCard") as Button).pressed.emit()
	for index: int in range(owner.run_state.player.deck.hand.size()):
		var card: CardInstance = owner.run_state.player.deck.hand[index]
		if card.source != CardData.Source.NORMAL:
			continue
		var error: StringName = RuleResolver.validate_card_target(PlayCardCommand.new(card, board.active_objective, board) if card.definition.target_kinds != 0 else PlayCardCommand.new(card, null, board), owner.run_state.floor_state, owner.floor_data, owner.run_state)
		check((hand.get_child(index) as Button).disabled == not error.is_empty(), "Situation selection UI agrees with domain target legality")
	var attack: Button = hand.get_child(owner.run_state.player.deck.hand.find(hand_card(owner, ATTACK))) as Button
	check(attack.disabled and attack.tooltip_text.contains("需要实体目标"), "Selected Situation disables Attack with Chinese reason")
	await process_frame
	await _mouse_click(attack)
	check(snapshot(owner) == before, "Actual disabled Attack mouse click cannot spend anything")
	(main.get_node("%EntityCard") as Button).pressed.emit()
	var search: Button = hand.get_child(owner.run_state.player.deck.hand.find(hand_card(owner, SEARCH))) as Button
	check(search.disabled and search.tooltip_text.contains("不能以实体为搜索目标"), "Selected Hound disables environment Search with concise feedback")
	await process_frame
	await _mouse_click(search)
	check(snapshot(owner) == before, "Selecting entity and clicking disabled Search preserve all state")
	main.free()


func claim_ui(main: Control, kinds: Array[int]) -> void:
	var owner: TurnManager = main.get_node("TurnManager") as TurnManager
	while not owner.run_state.flow.pending_rewards.is_empty():
		var opportunity: CardReward = owner.run_state.flow.pending_rewards[0]
		kinds.append(opportunity.definition.kind)
		var options: VBoxContainer = main.get_node("%RewardPanel/Margin/Layout/Scroll/Options") as VBoxContainer
		check((main.get_node("%RewardPanel") as Control).visible and (main.get_node("%EndTurn") as Button).disabled, "Actual opportunity shows modal Chinese panel and blocks normal lifecycle")
		if opportunity.definition.kind == CardRewardData.Kind.ADD_CARD:
			check(options.get_child_count() == 3, "Production reward panel offers exactly three buttons")
		await process_frame
		await process_frame
		check(main.get_viewport_rect().encloses((main.get_node("%RewardPanel") as Control).get_global_rect()), "Reward options remain in viewport at normal window ratio")
		await _mouse_click(options.get_child(0) as Control)
		await process_frame
		check(main.get_viewport_rect().encloses((main.get_node("%Hand") as Control).get_global_rect()), "Upgraded/new-card hand layout remains inside viewport")


func _test_production_ui_run() -> void:
	root.size = Vector2i(1152, 648)
	var main: Control = MAIN.instantiate() as Control
	(main.get_node("TurnManager") as TurnManager).floor_data = preload("res://tests/fixtures/phase9/floors/floor_level_0.tres")
	(main.get_node("TurnManager") as TurnManager).starter_deck = preload("res://tests/fixtures/phase9/cards/run_deck.tres")
	root.add_child(main)
	var owner: TurnManager = main.get_node("TurnManager") as TurnManager
	var state: RunState = owner.run_state
	var deck: DeckState = state.player.deck
	var equipment: Array[EquipmentInstance] = state.player.equipment.slots.duplicate()
	var kinds: Array[int] = []
	for turn: int in range(20):
		for action: int in range(4):
			await claim_ui(main, kinds)
			var event: ObjectiveInstance = state.floor_state.current_objective
			if event == null or event.resolved:
				break
			var chosen: CardData
			for card: CardInstance in deck.hand:
				if card.source == CardData.Source.NORMAL and card.definition.explore_amount > 0 and RuleResolver.card_ap_cost(card.definition, state, owner.floor_data) <= state.player.ap:
					chosen = card.definition
					break
			if chosen == null:
				break
			click_card(main, chosen)
		await claim_ui(main, kinds)
		if state.floor_state.remaining_fresh_objectives.is_empty() and (state.floor_state.current_objective == null or state.floor_state.current_objective.resolved):
			break
		(main.get_node("%EndTurn") as Button).pressed.emit()
	check(kinds.count(0) == 1 and kinds.count(1) == 1 and kinds.count(2) == 1, "Normal production Level 0 route receives add/upgrade/remove through three declared Situations")
	check(deck.get_card_count() == DECK.cards.size(), "One gain plus one removal preserve expected run deck size")
	if state.player.ap < 1:
		(main.get_node("%EndTurn") as Button).pressed.emit()
	click_generated(main, &"safe")
	check(state.floor_state.floor_id == LEVEL_6.id and owner.run_state == state and state.player.deck == deck, "Reward-adjusted deck continues naturally into Level 6 with same Run/deck/AP")
	var hound: EntityInstance = state.floor_state.entity
	for turn: int in range(16):
		await claim_ui(main, kinds)
		if not hound.active or state.player.hp <= 0:
			break
		for action: int in range(4):
			var chosen: CardInstance
			var target_entity: bool = false
			var event: ObjectiveInstance = state.floor_state.current_objective
			# 先抑制环境压力，再用同一手牌防御／攻击；没有 AP 或牌区注入。
			if event != null and not event.resolved and event.last_progress_turn != state.floor_state.turn_count:
				for card: CardInstance in deck.hand:
					if card.source == CardData.Source.NORMAL and card.definition.explore_amount > 0 and RuleResolver.card_ap_cost(card.definition, state, owner.floor_data) <= state.player.ap:
						chosen = card
						break
			if chosen == null and hound.intent in [&"bite", &"lunge"] and state.player.block < 4:
				for card: CardInstance in deck.hand:
					if card.definition.effect_type == CardData.EffectType.BLOCK and card.definition.ap_cost <= state.player.ap:
						chosen = card
						break
			if chosen == null:
				for card: CardInstance in deck.hand:
					if card.definition.effect_type == CardData.EffectType.ATTACK and card.definition.ap_cost <= state.player.ap:
						chosen = card
						target_entity = true
						if card.source == CardData.Source.EQUIPMENT:
							break
			if chosen == null or not hound.active:
				break
			if chosen.source == CardData.Source.EQUIPMENT:
				click_generated(main, &"crowbar")
			else:
				click_card(main, chosen.definition, target_entity)
			await claim_ui(main, kinds)
		if not hound.active:
			break
		(main.get_node("%EndTurn") as Button).pressed.emit()
	check(state.player.hp > 0 and not hound.alive and state.floor_state.entity == null and not (main.get_node("%EntityCard") as Button).visible, "Actual card UI defeats Hound and immediately hides retired World Card")
	check(kinds.count(0) == 2, "Hound offers and UI claims exactly one additional three-card opportunity")
	for turn: int in range(8):
		if generated(owner, &"light") != null and state.player.ap >= 1:
			click_generated(main, &"light")
			break
		(main.get_node("%EndTurn") as Button).pressed.emit()
	var smiler: EntityInstance = state.floor_state.entity
	check(smiler != null and smiler.entity_id == LEVEL_6.followup_entity.id, "Post-retirement LIGHT spawns Smiler through existing world rule")
	if generated(owner, &"extinguish") != null and state.player.ap >= 1:
		click_generated(main, &"extinguish")
	(main.get_node("%EndTurn") as Button).pressed.emit()
	if smiler != null and smiler.active:
		(main.get_node("%EndTurn") as Button).pressed.emit()
	check(smiler != null and smiler.alive and not smiler.active and state.floor_state.entity == null, "Correct behavior resolves Smiler alive; no dead/selectable board residue")
	for attempt: int in range(12):
		if owner.floor_data.is_placeholder:
			break
		if state.player.ap >= 1:
			click_generated(main, &"safe" if generated(owner, &"safe") != null else &"rushed")
		if not owner.floor_data.is_placeholder:
			(main.get_node("%EndTurn") as Button).pressed.emit()
	check(owner.floor_data.is_placeholder and state.player.hp > 0 and state.player.equipment.slots == equipment and state.player.deck == deck, "Production UI completes Level 0 -> rewards/upgrade/removal -> Level 6/Hound/Smiler -> exit")
	for pile: Array[CardInstance] in [deck.draw_pile, deck.discard_pile]:
		check(pile.all(func(card: CardInstance) -> bool: return card.source == CardData.Source.NORMAL), "Reward/upgrade/removal never pollute normal piles with generated cards")
	check(not (main.get_node("%DebugPanel") as Control).visible, "Continuous run never uses debug tools")
	main.free()
