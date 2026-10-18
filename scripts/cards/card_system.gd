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
		assert(definition.source == CardData.Source.NORMAL, "Generated cards cannot initialize the normal deck")
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
	for card: CardInstance in deck.hand.duplicate():
		if card.source == CardData.Source.NORMAL:
			move_hand_to_discard(card)
		elif not card.definition.retain:
			deck.hand.erase(card)


func move_hand_to_discard(card: CardInstance) -> void:
	# 这里只提交牌区移动；出牌是否合法、费用和效果由 RuleResolver 决定。
	var deck: DeckState = _run_state.deck_state
	assert(deck.hand.has(card), "Only a card in hand can be moved to discard")
	assert(card.source == CardData.Source.NORMAL, "Only NORMAL cards enter discard")
	deck.hand.erase(card)
	deck.discard_pile.append(card)


func finish_play(card: CardInstance, result: ActionResult) -> void:
	if card.source == CardData.Source.NORMAL:
		move_hand_to_discard(card)
	elif card.source == CardData.Source.EQUIPMENT and card.definition.effect_type in [CardData.EffectType.LIGHT, CardData.EffectType.EXTINGUISH]:
		return
	elif result.cutout_attempt == null or result.cutout_attempt.succeeded:
		_run_state.deck_state.hand.erase(card)
	# 仓促尝试失败属于已结算动作，但保留同一退出机会，不能误删唯一出口。


func refresh_floor_cards(data: FloorData) -> void:
	var deck: DeckState = _run_state.deck_state
	var floor: FloorState = _run_state.floor_state
	for card: CardInstance in deck.hand.duplicate():
		if card.source == CardData.Source.FLOOR_TEMPORARY and (floor == null or data == null or card.source_board != floor.board_state or data.is_placeholder):
			deck.hand.erase(card)
	if floor == null or data == null or data.is_placeholder:
		return
	var exit_card: CardInstance
	for card: CardInstance in deck.hand:
		if card.source != CardData.Source.FLOOR_TEMPORARY:
			continue
		if card.definition.effect_type in [CardData.EffectType.CUTOUT_RUSHED, CardData.EffectType.CUTOUT_SAFE]:
			exit_card = card
	if exit_card != null and exit_card.definition != data.safe_cutout_card and CutOutSystem.is_prepared(floor.cutout_state):
		# 换定义指针，不修改共享 Resource，实例身份及手牌位置都保留。
		exit_card.definition = data.safe_cutout_card
		if OS.is_debug_build():
			print("[CARD] upgrade cutout safe retained=true")
	var capacity: int = HAND_TARGET + (1 if deck.hand.any(func(card: CardInstance) -> bool: return card.source == CardData.Source.EQUIPMENT) else 0)
	if exit_card == null and deck.hand.size() < capacity and CutOutSystem.is_available(floor, data):
		var definition: CardData = data.safe_cutout_card if CutOutSystem.is_prepared(floor.cutout_state) else data.rushed_cutout_card
		_add_floor_card(definition, floor)



func begin_hand(data: FloorData) -> void:
	# 楼层牌先占五张目标中的真实位置，再补 NORMAL，最后最多追加一张装备牌。
	refresh_floor_cards(data)
	refresh_equipment_cards(data)
	draw_to_hand_size()
	generate_equipment_card(data)


func generate_equipment_card(data: FloorData) -> void:
	var deck: DeckState = _run_state.deck_state
	if data == null or data.is_placeholder or deck.equipment_generation_turn == _run_state.turn_number or deck.hand.size() >= HAND_TARGET + 1:
		return
	if not EquipmentSystem.validate_inventory(_run_state).is_empty():
		return
	for offset: int in range(RunState.CARRY_SLOT_COUNT):
		var index: int = (deck.next_equipment_slot + offset) % RunState.CARRY_SLOT_COUNT
		var item: EquipmentInstance = _run_state.equipment_slots[index]
		if item == null:
			continue
		var definition: CardData = EquipmentSystem.current_action_card(item, _run_state.floor_state)
		if definition == null:
			continue
		var card: CardInstance = CardInstance.new(definition)
		card.source_equipment = item
		var board: BoardState = _run_state.floor_state.board_state
		var target: EntityInstance = board.entity if item.definition.effect_type == EquipmentData.EffectType.ATTACK else null
		if not EquipmentSystem.validate_card(PlayCardCommand.new(card, null, board, target), _run_state).is_empty():
			continue
		deck.hand.append(card)
		deck.equipment_generation_turn = _run_state.turn_number
		deck.next_equipment_slot = (index + 1) % RunState.CARRY_SLOT_COUNT
		if OS.is_debug_build():
			print("[CARD] generated source=equipment item=%s turn=%d" % [item.definition.id, _run_state.turn_number])
		return


func _add_floor_card(definition: CardData, floor: FloorState) -> void:
	var card: CardInstance = CardInstance.new(definition)
	card.source_board = floor.board_state
	_run_state.deck_state.hand.append(card)
	if OS.is_debug_build():
		print("[CARD] generated source=floor card=%s retained=%s" % [definition.id, definition.retain])


func refresh_equipment_cards(data: FloorData) -> void:
	# 光照改变后只替换同一机会的定义；不再生成实例、不占第二个装备格。
	var deck: DeckState = _run_state.deck_state
	for card: CardInstance in deck.hand.duplicate():
		if card.source != CardData.Source.EQUIPMENT:
			continue
		var definition: CardData = EquipmentSystem.current_action_card(card.source_equipment, _run_state.floor_state)
		if definition == null or data == null or data.is_placeholder:
			deck.hand.erase(card)
		else:
			card.definition = definition


static func validate_source(command: PlayCardCommand, state: RunState, data: FloorData) -> StringName:
	var card: CardInstance = command.card
	var definition: CardData = card.definition
	if command.definition != definition:
		return &"invalid_card_source"
	match definition.source:
		CardData.Source.NORMAL:
			if card.source_equipment != null or card.source_board != null or definition.effect_type not in [CardData.EffectType.NO_OP, CardData.EffectType.PLACEHOLDER_DAMAGE, CardData.EffectType.ATTACK, CardData.EffectType.BLOCK, CardData.EffectType.RUN]:
				return &"invalid_card_source"
		CardData.Source.EQUIPMENT:
			if data == null or state.floor_state == null or card.source_equipment == null or not state.equipment_slots.has(card.source_equipment):
				return &"invalid_equipment_target"
			var error: StringName = EquipmentSystem.validate_inventory(state)
			if not error.is_empty():
				return error
			if definition not in [card.source_equipment.definition.action_card, card.source_equipment.definition.active_action_card]:
				return &"invalid_card_source"
		CardData.Source.FLOOR_TEMPORARY:
			if data == null or state.floor_state == null or card.source_board != state.floor_state.board_state:
				return &"invalid_card_source"
			if definition not in [data.rushed_cutout_card, data.safe_cutout_card]:
				return &"invalid_card_source"
		_:
			return &"invalid_card_source"
	return &""


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
