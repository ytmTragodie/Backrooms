class_name CardSystem
extends RefCounted

const HAND_TARGET: int = 5

var _run_state: RunState
var _deck: DeckState


func _init(state: RunState, definitions: Array[CardData]) -> void:
	_run_state = state
	_deck = state.deck_state
	assert(_deck.get_card_count() == 0, "Initialize a deck only once per run")
	for definition: CardData in definitions:
		assert(definition != null, "Deck contains a missing card definition")
		assert(not definition.id.is_empty(), "Card definition needs a stable ID")
		assert(definition.ap_cost >= 0, "Card AP cost cannot be negative")
		assert(definition.placeholder_damage >= 0, "Placeholder damage cannot be negative")
		_deck.draw_pile.append(CardInstance.new(definition))


func draw_to_hand_size(target_size: int = HAND_TARGET) -> void:
	while _deck.hand.size() < target_size:
		if _deck.draw_pile.is_empty() and not _reshuffle_discard():
			break
		var card: CardInstance = _deck.draw_pile.pop_front()
		_deck.hand.append(card)
		if OS.is_debug_build():
			print("[CARD] draw %s" % card.definition.id)


func play_card(card: CardInstance) -> bool:
	if card == null or not _deck.hand.has(card):
		if OS.is_debug_build():
			print("[CARD] reject reason=card_not_in_hand")
		return false
	var cost: int = card.definition.ap_cost
	if cost < 0 or _run_state.ap < cost:
		if OS.is_debug_build():
			print("[CARD] reject %s reason=invalid_or_unaffordable_cost cost=%d ap=%d" % [card.definition.id, cost, _run_state.ap])
		return false
	# This temporary command boundary commits only after validation. AP stays in RunState.
	var previous_ap: int = _run_state.ap
	_run_state.ap -= cost
	_discard_card(card)
	if OS.is_debug_build():
		print("[CARD] play %s cost=%d" % [card.definition.id, cost])
		print("[AP] %d -> %d" % [previous_ap, _run_state.ap])
		print("[CARD] result card=%s placeholder_damage=%d" % [card.definition.id, card.definition.placeholder_damage])
	return true


func discard_hand() -> void:
	while not _deck.hand.is_empty():
		_discard_card(_deck.hand[0])


func _discard_card(card: CardInstance) -> void:
	_deck.hand.erase(card)
	_deck.discard_pile.append(card)
	if OS.is_debug_build():
		print("[CARD] discard %s" % card.definition.id)


func _reshuffle_discard() -> bool:
	if _deck.discard_pile.is_empty():
		return false
	if OS.is_debug_build():
		print("[DECK] reshuffle discard_count=%d" % _deck.discard_pile.size())
	_deck.draw_pile.append_array(_deck.discard_pile)
	_deck.discard_pile.clear()
	# Fisher-Yates uses the run RNG, never the global Array.shuffle() source.
	for index: int in range(_deck.draw_pile.size() - 1, 0, -1):
		var swap_index: int = _run_state.rng.randi_range(0, index)
		var card: CardInstance = _deck.draw_pile[index]
		_deck.draw_pile[index] = _deck.draw_pile[swap_index]
		_deck.draw_pile[swap_index] = card
	return true
