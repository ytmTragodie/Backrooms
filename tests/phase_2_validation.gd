extends SceneTree

const STARTER_DECK: DeckData = preload("res://data/cards/starter_deck.tres")
const OBSERVE: CardData = preload("res://data/cards/card_observe.tres")
const WAIT: CardData = preload("res://data/cards/card_wait.tres")
const STRUGGLE: CardData = preload("res://data/cards/card_struggle.tres")
const MAIN_SCENE: PackedScene = preload("res://scenes/main/Main.tscn")

var _failures: int = 0
var _checks: int = 0


func _initialize() -> void:
	call_deferred("_run_validation")


func _run_validation() -> void:
	_test_draw_play_and_rejection()
	_test_discard_and_short_decks()
	_test_seeded_shuffle()
	_test_turn_integration()
	_test_debug_ui()
	# Flush buttons queued for deletion when the debug hand was rebuilt.
	await process_frame
	if _failures == 0:
		print("[TEST] PASS Phase 2: %d checks (draw/play/discard/reshuffle, AP, conservation, RNG, UI)" % _checks)
	else:
		push_error("[TEST] FAIL Phase 2: %d of %d checks failed" % [_failures, _checks])
	quit(0 if _failures == 0 else 1)


func _test_draw_play_and_rejection() -> void:
	# 迁移到统一命令入口，保留 Phase 2 的出牌、拒绝与守恒断言。
	var manager: TurnManager = TurnManager.new()
	root.add_child(manager)
	var state: RunState = manager.run_state
	var deck: DeckState = state.deck_state
	var inventory: Array[CardInstance] = deck.hand.duplicate()
	inventory.append_array(deck.draw_pile)
	_check(deck.hand.size() == 5 and deck.draw_pile.size() == 4, "Initial draw fills the hand to 5")
	_check(deck.hand[0] != deck.hand[2], "Copies have distinct runtime identities")
	_check(deck.hand[0].definition == deck.hand[2].definition, "Copies share only static definition data")
	var observe: CardInstance = deck.hand[0]
	var struggle: CardInstance = deck.hand[1]
	var second_observe: CardInstance = deck.hand[2]
	var wait: CardInstance = deck.hand[4]
	_check(manager.request_play_card(observe).success, "Observe succeeds")
	_check(state.ap == 2, "One AP card deducts exactly 1 AP")
	_check(not deck.hand.has(observe) and deck.discard_pile.has(observe), "Played card moves from hand to discard")
	_check_inventory(deck, inventory)
	_check(manager.request_play_card(struggle).success, "Struggle succeeds")
	_check(struggle.definition.placeholder_damage == 2, "Struggle reports 2 placeholder damage")
	_check(state.ap == 1, "Struggle costs 1 AP")
	_check(manager.request_play_card(second_observe).success and state.ap == 0, "Final available AP can be spent")
	_check(manager.request_play_card(wait).success and state.ap == 0, "Wait costs zero and can be played at zero AP")
	_check(state.cognition == 0, "Observe never directly changes Cognition")
	_check(state.player_hp == 30 and state.stress == 0 and state.threat == 0, "Prototype plays apply no future gameplay effects")
	var remaining: CardInstance = deck.hand[0]
	var hand_before: Array[CardInstance] = deck.hand.duplicate()
	var draw_before: Array[CardInstance] = deck.draw_pile.duplicate()
	var discard_before: Array[CardInstance] = deck.discard_pile.duplicate()
	var rng_before: int = state.rng.state
	_check(not manager.request_play_card(remaining).success, "Insufficient AP rejects the play")
	_check(not manager.request_play_card(null).success, "Null command is rejected")
	_check(not manager.request_play_card(CardInstance.new(OBSERVE)).success, "An instance outside the hand is rejected")
	_check(not manager.request_play_card(wait).success, "A discarded card cannot be played again")
	_check(state.ap == 0, "Rejected plays do not alter AP")
	_check(deck.hand == hand_before, "Rejected plays preserve the entire hand and order")
	_check(deck.draw_pile == draw_before and deck.discard_pile == discard_before, "Rejected plays preserve both piles")
	_check(state.rng.state == rng_before, "Rejected plays do not consume RNG")
	_check_inventory(deck, inventory)
	_check(OBSERVE.id == &"card_observe" and OBSERVE.ap_cost == 1 and OBSERVE.placeholder_damage == 0, "Observe definition is unchanged")
	_check(WAIT.id == &"card_wait" and WAIT.ap_cost == 0, "Wait definition is unchanged")
	_check(STRUGGLE.id == &"card_struggle" and STRUGGLE.ap_cost == 1 and STRUGGLE.placeholder_damage == 2, "Struggle definition is unchanged")
	manager.free()


func _test_discard_and_short_decks() -> void:
	var state: RunState = RunState.new(202)
	var definitions: Array[CardData] = [OBSERVE, WAIT, STRUGGLE]
	var system: CardSystem = CardSystem.new(state, definitions)
	var deck: DeckState = state.deck_state
	var inventory: Array[CardInstance] = deck.draw_pile.duplicate()
	system.draw_to_hand_size()
	_check(deck.hand.size() == 3 and deck.draw_pile.is_empty(), "A short deck stops when no cards remain to draw")
	system.discard_hand()
	_check(deck.hand.is_empty() and deck.discard_pile.size() == 3, "End-of-turn discard moves every remaining hand card")
	_check_inventory(deck, inventory)
	system.draw_to_hand_size(2)
	_check(deck.hand.size() == 2 and deck.draw_pile.size() == 1 and deck.discard_pile.is_empty(), "Empty draw pile reshuffles discard before drawing")
	var rng_before: int = state.rng.state
	system.draw_to_hand_size(2)
	_check(deck.hand.size() == 2 and state.rng.state == rng_before, "Drawing to an already full hand is a no-op")
	system.draw_to_hand_size()
	_check(deck.hand.size() == 3, "Drawing cannot duplicate cards when both piles run out")
	_check_inventory(deck, inventory)
	var empty_state: RunState = RunState.new()
	var empty_definitions: Array[CardData] = []
	var empty_system: CardSystem = CardSystem.new(empty_state, empty_definitions)
	empty_system.draw_to_hand_size()
	empty_system.discard_hand()
	_check(empty_state.deck_state.get_card_count() == 0, "Empty deck draw/discard terminates without creating cards")


func _shuffle_order(seed_value: int) -> Array[int]:
	var state: RunState = RunState.new(seed_value)
	var system: CardSystem = CardSystem.new(state, STARTER_DECK.cards)
	var deck: DeckState = state.deck_state
	var inventory: Array[CardInstance] = deck.draw_pile.duplicate()
	system.draw_to_hand_size(inventory.size())
	system.discard_hand()
	system.draw_to_hand_size(inventory.size())
	_check_inventory(deck, inventory)
	var order: Array[int] = []
	for card: CardInstance in deck.hand:
		order.append(inventory.find(card))
	return order


func _test_seeded_shuffle() -> void:
	var first_order: Array[int] = _shuffle_order(8675309)
	var second_order: Array[int] = _shuffle_order(8675309)
	var different_order: Array[int] = _shuffle_order(8675310)
	_check(first_order == second_order, "A fixed seed reproduces the same shuffle of runtime instances")
	_check(first_order != different_order, "The deck uses the supplied run seed")
	var state: RunState = RunState.new()
	var other_state: RunState = RunState.new()
	_check(state.deck_state != other_state.deck_state and state.rng != other_state.rng, "Deck and RNG are isolated between runs")


func _test_turn_integration() -> void:
	var manager: TurnManager = TurnManager.new()
	root.add_child(manager)
	var state: RunState = manager.run_state
	var deck: DeckState = state.deck_state
	var inventory: Array[CardInstance] = []
	inventory.append_array(deck.hand)
	inventory.append_array(deck.draw_pile)
	_check(state.turn_number == 1 and state.ap == 3 and deck.hand.size() == 5, "Turn 1 starts with 3 AP and a hand of 5")
	var draw_before: Array[CardInstance] = deck.draw_pile.duplicate()
	_check(manager.request_play_card(deck.hand[0]).success, "TurnManager forwards validated play commands")
	manager.end_turn()
	_check(state.turn_number == 2 and state.ap == 3, "Next turn advances once and restores 3 AP")
	_check(deck.hand.size() == 5, "Next turn draws back to 5")
	for index: int in range(draw_before.size()):
		_check(deck.hand[index] == draw_before[index], "Partial draw consumes existing pile before reshuffling discard")
	_check(deck.draw_pile.size() == 4 and deck.discard_pile.is_empty(), "Partial draw continues through a reshuffle")
	_check_inventory(deck, inventory)
	for expected_turn: int in range(3, 7):
		var current_hand: Array[CardInstance] = deck.hand.duplicate()
		for card: CardInstance in current_hand:
			manager.request_play_card(card)
			_check_inventory(deck, inventory)
		manager.end_turn()
		_check(state.turn_number == expected_turn and state.ap == 3 and deck.hand.size() == 5, "Repeated turns restore AP and refill the hand")
		_check_inventory(deck, inventory)
	_check(state.cognition == 0 and state.threat == 0, "Turn/card integration adds no floor or insight rules")
	manager.free()


func _test_debug_ui() -> void:
	var main: Control = MAIN_SCENE.instantiate() as Control
	(main.get_node("TurnManager") as TurnManager).floor_data = preload("res://tests/legacy_fixture.gd").without_rewards(preload("res://data/floors/floor_level_0.tres"))
	(main.get_node("TurnManager") as TurnManager).starter_deck = preload("res://data/cards/exploration_deck.tres")
	root.add_child(main)
	var manager: TurnManager = main.get_node("TurnManager") as TurnManager
	var hand: HBoxContainer = main.get_node("%Hand") as HBoxContainer
	var counts: Label = main.get_node("%PileCounts") as Label
	var stats: Label = main.get_node("%RunStats") as Label
	var end_turn: Button = main.get_node("%EndTurn") as Button
	_check(hand.get_child_count() == 5 and counts.text == "抽牌堆：5｜弃牌堆：0", "Card UI displays five real Player Cards and pile counts")
	_check((hand.get_child(0) as Button).text.contains("观察") and (hand.get_child(0) as Button).text.contains("行动点：1"), "Player Card shows its name and cost")
	for expected_ap: int in [2, 1]:
		(hand.get_child(0) as Button).pressed.emit()
		_check(manager.run_state.ap == expected_ap and stats.text.contains("行动点：%d" % expected_ap), "Real card commands deduct AP exactly once and refresh UI")
	_check(hand.get_child_count() == 4 and counts.text == "抽牌堆：5｜弃牌堆：2", "Normal plays enter discard; first Insight also generates a retained exit")
	var card_count: int = manager.run_state.deck_state.get_card_count()
	(hand.get_child(0) as Button).pressed.emit()
	_check(hand.get_child_count() == 4 and manager.run_state.ap == 1 and card_count == 10, "Resolved-target rejection preserves AP and the ten-card normal inventory")
	end_turn.pressed.emit()
	_check(manager.run_state.turn_number == 2 and manager.run_state.ap == 3, "UI End Turn preserves Phase 1 lifecycle")
	_check(hand.get_child_count() == 5 and stats.text.contains("回合：2"), "Same deck redraws five cards for the next Situation")
	main.free()


func _check_inventory(deck: DeckState, inventory: Array[CardInstance]) -> void:
	var all_cards: Array[CardInstance] = []
	all_cards.append_array(deck.draw_pile)
	all_cards.append_array(deck.hand)
	all_cards.append_array(deck.discard_pile)
	_check(deck.get_card_count() == inventory.size(), "Total card count is conserved")
	for card: CardInstance in inventory:
		_check(all_cards.count(card) == 1, "Every runtime card exists in exactly one pile or hand")


func _check(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		push_error("[TEST] %s" % message)
