class_name CardSystem
extends RefCounted

const HAND_TARGET: int = 5

var _run_state: RunState


func _init(state: RunState, definitions: Array[CardData]) -> void:
	_run_state = state
	var deck: DeckState = _run_state.deck_state
	assert(deck.get_card_count() == 0, "Initialize a deck only once per run")
	for definition: CardData in definitions:
		assert(definition != null, "Deck contains a missing card definition")
		assert(not definition.id.is_empty(), "Card definition needs a stable ID")
		assert(definition.ap_cost >= 0, "Card AP cost cannot be negative")
		assert(definition.placeholder_damage >= 0, "Placeholder damage cannot be negative")
		deck.draw_pile.append(CardInstance.new(definition))


func draw_to_hand_size(target_size: int = HAND_TARGET) -> void:
	# 牌区只以 RunState 中的当前 DeckState 为准，避免长期缓存旧引用。
	var deck: DeckState = _run_state.deck_state
	while deck.hand.size() < target_size:
		if deck.draw_pile.is_empty() and not _reshuffle_discard():
			break
		var card: CardInstance = deck.draw_pile.pop_front()
		deck.hand.append(card)
		if OS.is_debug_build():
			print("[CARD] draw %s" % card.definition.id)


func is_bound_to(state: RunState) -> bool:
	return _run_state == state


func discard_hand() -> void:
	var deck: DeckState = _run_state.deck_state
	while not deck.hand.is_empty():
		var card: CardInstance = deck.hand[0]
		move_hand_to_discard(card)
		if OS.is_debug_build():
			print("[CARD] discard %s" % card.definition.id)


func move_hand_to_discard(card: CardInstance) -> void:
	# 这里只提交牌区移动；出牌是否合法、费用和效果由 RuleResolver 决定。
	var deck: DeckState = _run_state.deck_state
	assert(deck.hand.has(card), "Only a card in hand can be moved to discard")
	deck.hand.erase(card)
	deck.discard_pile.append(card)


func _reshuffle_discard() -> bool:
	var deck: DeckState = _run_state.deck_state
	if deck.discard_pile.is_empty():
		return false
	if OS.is_debug_build():
		print("[DECK] reshuffle discard_count=%d" % deck.discard_pile.size())
	deck.draw_pile.append_array(deck.discard_pile)
	deck.discard_pile.clear()
	# Fisher-Yates 只消耗本局 RNG，固定种子与操作顺序可以复现洗牌结果。
	for index: int in range(deck.draw_pile.size() - 1, 0, -1):
		var swap_index: int = _run_state.rng.randi_range(0, index)
		var card: CardInstance = deck.draw_pile[index]
		deck.draw_pile[index] = deck.draw_pile[swap_index]
		deck.draw_pile[swap_index] = card
	return true
