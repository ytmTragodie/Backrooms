extends SceneTree

const STARTER_DECK: DeckData = preload("res://data/cards/starter_deck.tres")
const OBSERVE: CardData = preload("res://data/cards/card_observe.tres")
const MAIN_SCENE: PackedScene = preload("res://scenes/main/Main.tscn")

var _checks: int = 0
var _failures: int = 0
var _observed_manager: TurnManager
var _observed_results: Array[ActionResult] = []
var _notified_ap: Array[int] = []
var _notified_hand_sizes: Array[int] = []
var _notified_discard_sizes: Array[int] = []


func _initialize() -> void:
	call_deferred("_run_validation")


func _run_validation() -> void:
	_test_success_and_replay()
	_test_placeholder_effects()
	_test_invalid_requests()
	_test_invalid_definitions()
	_test_explicit_state_context()
	_test_notification_order()
	_test_current_deck_reference()
	_test_snapshot_detects_internal_mutation()
	_test_debug_ui()
	await process_frame
	if _failures == 0:
		print("[TEST] PASS Phase 3: %d checks (transactional resolution, results, AP, effects, notifications, UI)" % _checks)
	else:
		push_error("[TEST] FAIL Phase 3: %d of %d checks failed" % [_failures, _checks])
	quit(0 if _failures == 0 else 1)


func _test_success_and_replay() -> void:
	var state: RunState = RunState.new(301)
	var cards: CardSystem = CardSystem.new(state, STARTER_DECK.cards)
	cards.draw_to_hand_size()
	var card: CardInstance = state.deck_state.hand[0]
	var command: PlayCardCommand = PlayCardCommand.new(card)
	var rng_before: int = state.rng.state
	var result: ActionResult = RuleResolver.resolve(command, state, cards)
	_check(result.success and result.failure_reason.is_empty(), "Valid command returns structured success")
	_check(result.ap_spent == 1 and state.ap == 2, "Final AP cost is applied exactly once")
	_check(result.card_played == card, "Result identifies the played runtime instance")
	_check(state.deck_state.hand.count(card) == 0 and state.deck_state.discard_pile.count(card) == 1, "Commit moves the card to discard exactly once")
	_check(state.deck_state.get_card_count() == 9, "Resolution preserves the card inventory")
	_check(result.effect == &"no_op" and result.damage_requested == 0, "Observe resolves one no-op placeholder")
	_check(state.cognition == 0 and state.player_hp == 30, "Observe changes neither Cognition nor HP")
	_check(state.rng.state == rng_before, "Card play consumes no shuffle RNG")
	_check(result.debug_lines.size() == 6, "Successful resolution has a single ordered trace")
	_check(result.debug_lines[0] == "[COMMAND] play_card card_observe", "Trace identifies the command")
	_check(result.debug_lines[1] == "[RULE] validation success" and result.debug_lines[2] == "[RULE] final_cost=1", "Validation and cost precede commit trace")
	_check(result.debug_lines[3] == "[AP] 3 -> 2" and result.debug_lines[4] == "[CARD] hand -> discard card_observe", "Trace records the AP and lifecycle commit")
	_check(result.debug_lines[5].begins_with("[RESULT] success"), "One final effect/result is reported")
	var before_replay: Dictionary = _snapshot(state)
	var replay: ActionResult = RuleResolver.resolve(command, state, cards)
	_check_failure(replay, &"card_not_in_hand", state, before_replay)
	_check(replay != result and result.success and result.ap_spent == 1, "Rejection never rewrites an earlier result")
	_check(state.deck_state.discard_pile.count(card) == 1, "Replayed request cannot discard a second time")


func _test_placeholder_effects() -> void:
	var state: RunState = RunState.new()
	var cards: CardSystem = CardSystem.new(state, STARTER_DECK.cards)
	cards.draw_to_hand_size()
	var struggle: CardInstance = state.deck_state.hand[1]
	var wait: CardInstance = state.deck_state.hand[4]
	var result: ActionResult = RuleResolver.resolve(PlayCardCommand.new(struggle), state, cards)
	_check(result.success and result.effect == &"placeholder_damage", "Struggle resolves the data-defined damage placeholder")
	_check(result.damage_requested == 2 and result.ap_spent == 1, "Struggle returns 2 requested damage and costs 1 AP")
	_check(state.player_hp == 30 and state.cognition == 0 and state.threat == 0 and state.stress == 0, "Requested damage is never applied to fake targets or other state")
	# Test fixture: exhaust AP without adding new gameplay actions.
	state.ap = 0
	var free_result: ActionResult = RuleResolver.resolve(PlayCardCommand.new(wait), state, cards)
	_check(free_result.success and free_result.ap_spent == 0 and state.ap == 0, "Zero-cost Wait succeeds at zero AP")
	_check(free_result.effect == &"no_op" and free_result.damage_requested == 0, "Wait returns only a no-op")
	var observe: CardInstance = state.deck_state.hand[0]
	var before: Dictionary = _snapshot(state)
	_check_failure(RuleResolver.resolve(PlayCardCommand.new(observe), state, cards), &"insufficient_ap", state, before)
	_check(state.deck_state.hand.has(observe), "Unaffordable Observe remains in hand")


func _test_invalid_requests() -> void:
	var state: RunState = RunState.new()
	var cards: CardSystem = CardSystem.new(state, STARTER_DECK.cards)
	cards.draw_to_hand_size()
	var before: Dictionary = _snapshot(state)
	_check_failure(RuleResolver.resolve(null, state, cards), &"invalid_command", state, before)
	_check_failure(RuleResolver.resolve(PlayCardCommand.new(), state, cards), &"invalid_command", state, before)
	var unknown: CardInstance = CardInstance.new(null)
	_check_failure(RuleResolver.resolve(PlayCardCommand.new(unknown), state, cards), &"card_not_in_hand", state, before)
	var forged_copy: CardInstance = CardInstance.new(OBSERVE)
	_check_failure(RuleResolver.resolve(PlayCardCommand.new(forged_copy), state, cards), &"card_not_in_hand", state, before)
	var undrawn: CardInstance = state.deck_state.draw_pile[0]
	_check_failure(RuleResolver.resolve(PlayCardCommand.new(undrawn), state, cards), &"card_not_in_hand", state, before)
	# Malformed runtime data must also fail safely after membership is established.
	var card: CardInstance = state.deck_state.hand[0]
	var original_definition: CardData = card.definition
	card.definition = null
	_check_failure(RuleResolver.resolve(PlayCardCommand.new(card), state, cards), &"invalid_card_definition", state, _snapshot(state))
	card.definition = original_definition
	_check(OBSERVE.ap_cost == 1 and OBSERVE.placeholder_damage == 0, "Request validation leaves the shared definition unchanged")


func _test_invalid_definitions() -> void:
	for invalid_case: String in ["negative_cost", "negative_damage", "unknown_effect", "contradictory_effect", "missing_id"]:
		# Corrupt a private copy of an existing prototype definition, never shared content.
		var definition: CardData = OBSERVE.duplicate() as CardData
		var definitions: Array[CardData] = [definition]
		var state: RunState = RunState.new()
		var cards: CardSystem = CardSystem.new(state, definitions)
		cards.draw_to_hand_size()
		var expected_reason: StringName = &"invalid_card_definition"
		match invalid_case:
			"negative_cost":
				definition.ap_cost = -1
			"negative_damage":
				definition.placeholder_damage = -1
			"unknown_effect":
				definition.set("effect_type", 999)
				expected_reason = &"unsupported_effect"
			"contradictory_effect":
				definition.placeholder_damage = 2
			"missing_id":
				definition.id = &""
		var before: Dictionary = _snapshot(state)
		var command: PlayCardCommand = PlayCardCommand.new(state.deck_state.hand[0])
		_check_failure(RuleResolver.resolve(command, state, cards), expected_reason, state, before)
	_check(OBSERVE.ap_cost == 1 and OBSERVE.placeholder_damage == 0 and OBSERVE.effect_type == CardData.EffectType.NO_OP, "Invalid-definition fixtures do not alter shared Resources")


func _test_explicit_state_context() -> void:
	var first: RunState = RunState.new(301)
	var second: RunState = RunState.new(302)
	var first_cards: CardSystem = CardSystem.new(first, STARTER_DECK.cards)
	var second_cards: CardSystem = CardSystem.new(second, STARTER_DECK.cards)
	first_cards.draw_to_hand_size()
	second_cards.draw_to_hand_size()
	var first_command: PlayCardCommand = PlayCardCommand.new(first.deck_state.hand[0])
	var second_command: PlayCardCommand = PlayCardCommand.new(second.deck_state.hand[0])
	var first_before: Dictionary = _snapshot(first)
	var second_before: Dictionary = _snapshot(second)
	_check_failure(RuleResolver.resolve(first_command, first, second_cards), &"invalid_state_context", first, first_before)
	_check(_snapshot(second) == second_before, "Mismatched context does not move cards in the other run")
	_check_failure(RuleResolver.resolve(first_command, null, first_cards), &"invalid_state_context", first, first_before)
	_check_failure(RuleResolver.resolve(first_command, first, null), &"invalid_state_context", first, first_before)
	_check_failure(RuleResolver.resolve(second_command, first, first_cards), &"card_not_in_hand", first, first_before)
	_check(RuleResolver.resolve(first_command, first, first_cards).success, "Resolver accepts an explicitly supplied first run")
	_check(first.ap == 2 and _snapshot(second) == second_before, "Resolving one run never mutates the other")
	_check(RuleResolver.resolve(second_command, second, second_cards).success and second.ap == 2, "Same stateless resolver independently resolves another run")


func _test_notification_order() -> void:
	_observed_manager = TurnManager.new()
	root.add_child(_observed_manager)
	_observed_manager.state_changed.connect(_on_state_changed)
	_observed_manager.action_resolved.connect(_on_action_resolved)
	var card: CardInstance = _observed_manager.run_state.deck_state.hand[0]
	var result: ActionResult = _observed_manager.request_play_card(card)
	_check(_observed_results.size() == 1 and _observed_results[0] == result, "One request publishes its single structured effect/result exactly once")
	_check(_notified_ap == [2] and _notified_hand_sizes == [4] and _notified_discard_sizes == [1], "State notification observes the complete AP and card commit")
	var before: Dictionary = _snapshot(_observed_manager.run_state)
	var rejected: ActionResult = _observed_manager.request_play_card(card)
	_check_failure(rejected, &"card_not_in_hand", _observed_manager.run_state, before)
	_check(_observed_results.size() == 2 and not _observed_results[1].success, "Failure publishes one rejected result without an effect")
	_check(_notified_ap.size() == 1, "Failed command emits no state-change notification")
	var next_card: CardInstance = _observed_manager.run_state.deck_state.hand[0]
	_check(_observed_manager.request_play_card(next_card).success, "A second command uses the same entry")
	_check(_observed_results.size() == 3 and _observed_results[2].damage_requested == 2, "Each successful command publishes its single effect")
	_check(_notified_ap == [2, 1], "Each command deducts AP only once")
	_observed_manager.free()


func _test_current_deck_reference() -> void:
	var state: RunState = RunState.new()
	var cards: CardSystem = CardSystem.new(state, STARTER_DECK.cards)
	cards.draw_to_hand_size()
	var original_deck: DeckState = state.deck_state
	var original_hand: Array[CardInstance] = original_deck.hand.duplicate()
	var original_draw: Array[CardInstance] = original_deck.draw_pile.duplicate()
	var current_deck: DeckState = DeckState.new()
	current_deck.hand.assign(original_hand)
	current_deck.draw_pile.assign(original_draw)
	# 仅测试夹具替换牌堆，用来验证系统不会继续操作旧的集合引用。
	state.deck_state = current_deck
	cards.discard_hand()
	_check(current_deck.hand.is_empty() and current_deck.discard_pile.size() == 5, "Discard uses RunState's current deck")
	_check(original_deck.hand == original_hand and original_deck.discard_pile.is_empty(), "Discard leaves the old deck untouched")
	cards.draw_to_hand_size()
	_check(current_deck.hand.size() == 5 and current_deck.get_card_count() == 9, "Draw and reshuffle use the current deck")
	_check(original_deck.draw_pile == original_draw, "Draw does not consume the old deck")
	var command: PlayCardCommand = PlayCardCommand.new(current_deck.hand[0])
	_check(RuleResolver.resolve(command, state, cards).success, "Resolver and CardSystem agree on the current deck")
	_check(current_deck.hand.size() == 4 and current_deck.discard_pile.size() == 1, "Play commits to the same current deck")
	_check(original_deck.hand == original_hand and original_deck.discard_pile.is_empty(), "Play never writes the old deck")


func _test_snapshot_detects_internal_mutation() -> void:
	var definition: CardData = OBSERVE.duplicate() as CardData
	var definitions: Array[CardData] = [definition, definition]
	var state: RunState = RunState.new()
	var cards: CardSystem = CardSystem.new(state, definitions)
	cards.draw_to_hand_size()
	var card: CardInstance = state.deck_state.hand[0]
	var before: Dictionary = _snapshot(state)
	card.definition = definition.duplicate() as CardData
	_check(_snapshot(state) != before, "Snapshot detects a different definition with identical field values")
	card.definition = null
	_check(_snapshot(state) != before, "Snapshot detects a missing definition")
	card.definition = definition
	_check(_snapshot(state) == before, "Restoring the definition restores the snapshot")
	# 修改私有 Resource 副本，验证共享字段变化也能被快照检测，而非仅比较对象引用。
	var changed_values: Dictionary = {
		"id": &"changed_observe",
		"display_name": "Changed Observe",
		"ap_cost": 2,
		"effect_type": CardData.EffectType.PLACEHOLDER_DAMAGE,
		"placeholder_damage": 2,
		"explore_amount": 4,
		"threat_cost": 1,
	}
	for property_name: String in changed_values:
		var original_value: Variant = definition.get(property_name)
		definition.set(property_name, changed_values[property_name])
		_check(_snapshot(state) != before, "Snapshot detects changed definition field: %s" % property_name)
		definition.set(property_name, original_value)
	_check(_snapshot(state) == before, "Restoring definition fields restores the snapshot")


func _on_state_changed() -> void:
	_notified_ap.append(_observed_manager.run_state.ap)
	_notified_hand_sizes.append(_observed_manager.run_state.deck_state.hand.size())
	_notified_discard_sizes.append(_observed_manager.run_state.deck_state.discard_pile.size())


func _on_action_resolved(result: ActionResult) -> void:
	_observed_results.append(result)
	if result.success:
		_check(_observed_manager.run_state.deck_state.discard_pile.has(result.card_played), "Result notification runs after card movement")
		_check(_notified_ap.size() == _observed_results.filter(func(item: ActionResult) -> bool: return item.success).size(), "Result notification follows the state notification")


func _test_debug_ui() -> void:
	var main: Control = MAIN_SCENE.instantiate() as Control
	(main.get_node("TurnManager") as TurnManager).floor_data = preload("res://tests/legacy_fixture.gd").without_rewards(preload("res://data/floors/floor_level_0.tres"))
	root.add_child(main)
	var manager: TurnManager = main.get_node("TurnManager") as TurnManager
	var hand: HBoxContainer = main.get_node("%Hand") as HBoxContainer
	var status: Label = main.get_node("%Status") as Label
	var stats: Label = main.get_node("%RunStats") as Label
	var end_turn: Button = main.get_node("%EndTurn") as Button
	(hand.get_child(0) as Button).pressed.emit()
	_check(status.text.contains("已打出观察") and status.text.contains("调查：+3") and manager.run_state.ap == 2, "UI presents the actual Explore result and cost")
	_check(manager.run_state.cognition == 0, "Clue progress is not automatic Cognition")
	(hand.get_child(0) as Button).pressed.emit()
	_check(status.text.contains("已打出搜索") and status.text.contains("认知：+1") and manager.run_state.ap == 1, "Completion commits real Insight and AP before UI refresh")
	var before_failure: Dictionary = _snapshot(manager.run_state)
	(hand.get_child(0) as Button).pressed.emit()
	_check(status.text.contains("行动失败") and _snapshot(manager.run_state) == before_failure, "Unavailable investigation UI request has no partial card/AP commit")
	end_turn.pressed.emit()
	_check(manager.run_state.turn_number == 2 and manager.run_state.ap == 3 and hand.get_child_count() == 5, "Resolver integration preserves End Turn and redraw")
	manager.run_state.ap = 0
	before_failure = _snapshot(manager.run_state)
	(hand.get_child(0) as Button).pressed.emit()
	_check(status.text == "行动失败：行动点不足。" and _snapshot(manager.run_state) == before_failure, "Unaffordable Player Card reports rejection without gameplay mutation")
	end_turn.pressed.emit()
	_check(stats.text.contains("回合：3") and stats.text.contains("行动点：3"), "UI refresh remains synchronized with the same RunState")
	main.free()


func _snapshot(state: RunState) -> Dictionary:
	return {
		"hp": state.player_hp,
		"stress": state.stress,
		"threat": state.threat,
		"cognition": state.cognition,
		"turn": state.turn_number,
		"ap": state.ap,
		"rng_seed": state.rng_seed,
		"rng_state": state.rng.state,
		"deck_identity": state.deck_state.get_instance_id(),
		"draw": _snapshot_cards(state.deck_state.draw_pile),
		"hand": _snapshot_cards(state.deck_state.hand),
		"discard": _snapshot_cards(state.deck_state.discard_pile),
	}


func _snapshot_cards(pile: Array[CardInstance]) -> Array[Dictionary]:
	# 显式复制身份和字段值，避免浅拷贝仍引用同一个可变实例或 Resource。
	var snapshots: Array[Dictionary] = []
	for card: CardInstance in pile:
		var record: Dictionary = {"instance_identity": card.get_instance_id(), "definition_identity": 0}
		var definition: CardData = card.definition
		if definition != null:
			record["definition_identity"] = definition.get_instance_id()
			record["id"] = definition.id
			record["display_name"] = definition.display_name
			record["ap_cost"] = definition.ap_cost
			record["effect_type"] = definition.effect_type
			record["effect_value"] = definition.effect_value
			record["exploration_action"] = definition.exploration_action
			record["placeholder_damage"] = definition.placeholder_damage
			record["explore_amount"] = definition.explore_amount
			record["threat_cost"] = definition.threat_cost
			record["tags"] = definition.tags.duplicate()
		snapshots.append(record)
	return snapshots


func _check_failure(result: ActionResult, reason: StringName, state: RunState, before: Dictionary) -> void:
	_check(not result.success and result.failure_reason == reason, "Invalid action returns the expected failure reason: %s" % reason)
	_check(result.ap_spent == 0 and result.card_played == null, "Failure reports no AP spent or played card")
	_check(result.effect.is_empty() and result.damage_requested == 0, "Failure produces no placeholder effect")
	_check(_snapshot(state) == before, "Invalid action causes zero partial state mutation")
	_check(result.debug_lines.size() == 3 and result.debug_lines[1] == "[RULE] validation failed reason=%s" % reason, "Failure trace has no cost, commit, or effect entry")


func _check(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		push_error("[TEST] %s" % message)
