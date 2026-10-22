class_name CardSystem
extends RefCounted
## 永久牌组修改与战斗牌区操作，均在私有草案/初始化中调用。
static func initialize(deck: DeckState, data: DeckData) -> void:
	for definition: CardData in data.cards: deck.cards.append(CardInstance.new(definition))

static func start_combat(deck: DeckState, rng: RandomNumberGenerator) -> CombatDeckState:
	var result: CombatDeckState = CombatDeckState.new()
	for card: CardInstance in deck.cards: result.draw_pile.append(CardInstance.new(card.definition))
	shuffle(result.draw_pile, rng)
	return result

static func shuffle(cards: Array[CardInstance], rng: RandomNumberGenerator) -> void:
	for index: int in range(cards.size() - 1, 0, -1):
		var other: int = rng.randi_range(0, index)
		var card: CardInstance = cards[index]
		cards[index] = cards[other]
		cards[other] = card

static func draw(deck: CombatDeckState, count: int, rng: RandomNumberGenerator) -> void:
	for index: int in range(count):
		if deck.draw_pile.is_empty():
			deck.draw_pile.assign(deck.discard_pile)
			deck.discard_pile.clear()
			shuffle(deck.draw_pile, rng)
		if deck.draw_pile.is_empty(): return
		deck.hand.append(deck.draw_pile.pop_back())

static func next_hand(deck: CombatDeckState, rng: RandomNumberGenerator) -> void:
	var retained: Array[CardInstance] = []
	for card: CardInstance in deck.hand:
		if card.definition.source == CardData.Source.EQUIPMENT: continue
		if card.definition.retain: retained.append(card)
		else: deck.discard_pile.append(card)
	deck.hand = retained
	draw(deck, maxi(0, 5 - retained.size()), rng)

static func commit(result: ActionResult, state: RunState) -> void:
	for definition: CardData in result.deck.add: state.player.deck.cards.append(CardInstance.new(definition))
	if result.deck.remove != null: state.player.deck.cards.erase(result.deck.remove)
	if result.deck.upgrade != null: result.deck.upgrade.definition = result.deck.upgrade.definition.upgrade_to
