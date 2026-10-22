extends "res://tests/migration_test_base.gd"

const REWARD: CardRewardData = preload("res://data/rewards/reward_cards.tres")


func label() -> String:
	return "Phase 13C / composed run state ownership and lifecycle"


func tests() -> void:
	_test_composition_root()
	_test_ap_and_block_ownership()
	_test_player_cross_floor()
	_test_deck_and_equipment_identity()
	_test_equipment_generation_budget()
	_test_reward_fifo()
	_test_failure_atomicity()
	_test_ui_reads_composed_state()


func _test_composition_root() -> void:
	var first: RunState = RunState.new(101)
	var second: RunState = RunState.new(202)
	check(first.player != null and first.flow != null and first.metrics != null, "RunState initializes all composed domains")
	check(first.player.deck != null and first.player.equipment != null, "PlayerState owns a real DeckState and EquipmentState")
	check(first.player.equipment.slots.size() == EquipmentState.SLOT_COUNT, "EquipmentState creates exactly three physical slots")
	check(first.player.hp == PlayerState.MAX_HP and first.player.max_hp == PlayerState.MAX_HP, "PlayerState owns HP and max HP")
	check(first.player.stress == 0 and first.player.supply == 0 and first.player.block == 0, "Player resources start at zero")
	check(first.player.ap == PlayerState.AP_PER_TURN and first.flow.turn_number == 1, "Player owns initial AP and flow owns turn number")
	check(first.flow.pending_rewards.is_empty(), "Flow owns the empty reward queue")
	check(first.player.deck != second.player.deck and first.player.equipment != second.player.equipment and first.flow != second.flow, "New runs receive independent sub-states")
	first.player.hp = 7
	first.flow.pending_rewards.append(CardReward.new())
	check(second.player.hp == PlayerState.MAX_HP and second.flow.pending_rewards.is_empty(), "Mutating one run does not leak into another")
	var flat_fields: Array[StringName] = [&"player_hp", &"stress", &"supply", &"ap", &"deck_state", &"equipment_slots", &"pending_rewards", &"turn_number", &"last_cutout_attempt"]
	var names: Array[StringName] = []
	for property: Dictionary in first.get_property_list():
		names.append(StringName(property.name))
	for field: StringName in flat_fields:
		check(not names.has(field), "RunState exposes no migrated flat field: %s" % field)
	var deck_names: Array[StringName] = []
	for property: Dictionary in first.player.deck.get_property_list():
		deck_names.append(StringName(property.name))
	check(not deck_names.has(&"equipment_generation_turn") and not deck_names.has(&"next_equipment_slot"), "DeckState no longer owns equipment generation scheduling")


func _test_ap_and_block_ownership() -> void:
	var owner: TurnManager = manager([], LEVEL_0, false)
	var state: RunState = owner.run_state
	var player_id: int = state.player.get_instance_id()
	check(state.player.ap == PlayerState.AP_PER_TURN, "Initial AP is owned by PlayerState")
	var result: ActionResult = play(owner, OBSERVE)
	check(result.success and state.player.ap == PlayerState.AP_PER_TURN - 1 and state.metrics.cards_played == 1, "Card cost and metrics commit through composed player state")
	state.player.block = 4
	owner.end_turn()
	check(state.player.get_instance_id() == player_id, "Turn lifecycle does not replace PlayerState")
	check(state.player.ap == PlayerState.AP_PER_TURN, "End Turn restores AP through PlayerSystem")
	check(state.player.block == 0, "End Turn clears temporary block after consequences")
	state.player.ap = 0
	owner.end_turn()
	check(state.player.ap == PlayerState.AP_PER_TURN, "Exhausted AP is restored without carrying over")
	owner.free()


func _test_player_cross_floor() -> void:
	var owner: TurnManager = manager([], LEVEL_0, false)
	var state: RunState = owner.run_state
	state.player.hp = 17
	state.player.stress = 3
	state.player.supply = 2
	state.player.block = 4
	state.player.ap = 1
	var player_id: int = state.player.get_instance_id()
	var deck_id: int = state.player.deck.get_instance_id()
	var equipment_id: int = state.player.equipment.get_instance_id()
	var old_floor: FloorState = state.floor_state
	var destination: FloorData = fixture(LEVEL_6)
	var attempt: CutOutAttemptResult = CutOutAttemptResult.new()
	attempt.attempt_type = &"safe"
	attempt.source_floor_id = old_floor.floor_id
	attempt.succeeded = true
	var result: ActionResult = ActionResult.new()
	result.cutout.attempt = attempt
	result.cutout.destination = destination
	result.cutout.next_floor = FloorState.new(destination)
	CutOutSystem.commit(result, state)
	check(state.floor_state != old_floor and state.floor_state.floor_id == LEVEL_6.id, "Cut-out replaces only FloorState")
	check(state.player.get_instance_id() == player_id and state.player.deck.get_instance_id() == deck_id and state.player.equipment.get_instance_id() == equipment_id, "Floor transition preserves PlayerState, DeckState and EquipmentState identity")
	check(state.player.hp == 17 and state.player.stress == 3 and state.player.supply == 2 and state.player.block == 4 and state.player.ap == 1, "HP/Stress/Supply/Block/AP survive floor transition")
	check(state.floor_state.current_objective == null, "New floor starts with its own empty board state")
	owner.free()


func _test_deck_and_equipment_identity() -> void:
	var owner: TurnManager = manager([], LEVEL_0)
	var state: RunState = owner.run_state
	var deck: DeckState = state.player.deck
	var equipment: EquipmentState = state.player.equipment
	var slot_id: int = equipment.slots[0].get_instance_id()
	owner.end_turn()
	check(state.player.deck == deck and state.player.equipment == equipment, "Turn transition keeps the same DeckState and EquipmentState references")
	check(state.player.equipment.slots[0].get_instance_id() == slot_id, "Equipment instances are not recreated by turn cleanup")
	owner.free()


func _test_equipment_generation_budget() -> void:
	var owner: TurnManager = manager([], LEVEL_0, false)
	var state: RunState = owner.run_state
	check(EquipmentSystem.initialize(state.player.equipment, [WATER]).is_empty(), "Empty equipment state accepts one starting item")
	state.player.hp = 29
	state.player.stress = 5
	owner.card_system.generate_equipment_card(owner.floor_data)
	check(_equipment_card_count(state) == 1, "One eligible equipment card is generated per turn")
	check(state.player.equipment.generation_turn == state.flow.turn_number, "Equipment generation turn is stored on EquipmentState")
	var generation_turn: int = state.player.equipment.generation_turn
	owner.card_system.generate_equipment_card(owner.floor_data)
	owner.card_system.generate_equipment_card(owner.floor_data)
	check(_equipment_card_count(state) == 1 and state.player.equipment.generation_turn == generation_turn, "Repeated synchronization cannot exceed the one-card budget")
	owner.end_turn()
	check(_equipment_card_count(state) == 1 and state.player.equipment.generation_turn == state.flow.turn_number, "Next turn receives a fresh one-card generation budget")
	owner.free()


func _test_reward_fifo() -> void:
	var owner: TurnManager = manager([], LEVEL_0, false)
	var state: RunState = owner.run_state
	var first: CardReward = _reward()
	var second: CardReward = _reward()
	state.flow.pending_rewards.append(first)
	state.flow.pending_rewards.append(second)
	var first_id: int = first.get_instance_id()
	var claim: ActionResult = owner.submit_reward_command(CardRewardCommand.new(first, first.choices[0]))
	check(claim.success and state.flow.pending_rewards.size() == 1 and state.flow.pending_rewards[0] == second, "Reward claim consumes only the FIFO front")
	var before: Dictionary = snapshot(owner)
	var duplicate: ActionResult = owner.submit_reward_command(CardRewardCommand.new(first, first.choices[0]))
	check(not duplicate.success and snapshot(owner) == before and state.flow.pending_rewards.size() == 1, "Duplicate/stale claim is rejected without consuming the next reward")
	var second_claim: ActionResult = owner.submit_reward_command(CardRewardCommand.new(second, second.choices[0]))
	check(second_claim.success and state.flow.pending_rewards.is_empty() and state.player.deck.discard_pile.any(func(card: CardInstance) -> bool: return card.get_instance_id() == second_claim.deck.card_added.get_instance_id()), "Second claim is applied by CardSystem after the queue advances")
	check(first_id != second.get_instance_id(), "Reward instances retain distinct identities")
	owner.free()


func _test_failure_atomicity() -> void:
	var owner: TurnManager = manager([], LEVEL_0, false)
	var state: RunState = owner.run_state
	var outside: CardInstance = CardInstance.new(OBSERVE)
	reject(owner, PlayCardCommand.new(outside, null, state.floor_state.board_state), &"card_not_in_hand")
	check(state.player.ap == PlayerState.AP_PER_TURN, "Failed command leaves AP untouched")
	owner.free()


func _test_ui_reads_composed_state() -> void:
	var main: Control = MAIN.instantiate() as Control
	var owner: TurnManager = main.get_node("TurnManager") as TurnManager
	owner.floor_data = fixture(LEVEL_0)
	owner.starter_deck = DECK
	root.add_child(main)
	var stats: Label = main.get_node("%RunStats") as Label
	check(stats.text.contains("生命：30") and stats.text.contains("防护：0") and stats.text.contains("行动点：3"), "UI reads HP, block and AP from composed PlayerState")
	var run: RunState = owner.run_state
	run.player.block = 2
	owner.state_changed.emit()
	check(stats.text.contains("防护：2"), "UI refreshes block from PlayerState")
	main.free()


func _equipment_card_count(state: RunState) -> int:
	var count: int = 0
	for card: CardInstance in state.player.deck.hand:
		if card.source == CardData.Source.EQUIPMENT:
			count += 1
	return count


func _reward() -> CardReward:
	var reward: CardReward = CardReward.new()
	reward.definition = REWARD
	for index: int in range(CardRewardSystem.CHOICE_COUNT):
		reward.choices.append(REWARD.pool[index])
	return reward