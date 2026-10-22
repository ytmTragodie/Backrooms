class_name EquipmentSystem
extends RefCounted
## 持有物品/次数的唯一提交者。生成发生在战斗回合开始的计划内。
static func initialize(state: EquipmentState, definitions: Array[EquipmentData]) -> void:
	for index: int in range(mini(state.slots.size(), definitions.size())):
		state.slots[index] = EquipmentInstance.new(definitions[index])

static func action(item: EquipmentInstance, combat: CombatState) -> CardData:
	if item == null: return null
	if combat.light_active and item.definition.active_action_card != null: return item.definition.active_action_card
	return item.definition.action_card if item.remaining_uses > 0 else null

static func plan_generation(result: ActionResult, state: RunState) -> void:
	var combat: CombatState = result.combat.after
	var equipment: EquipmentState = state.player.equipment
	for offset: int in range(equipment.slots.size()):
		var index: int = (equipment.next_slot + offset) % equipment.slots.size()
		var item: EquipmentInstance = equipment.slots[index]
		var definition: CardData = action(item, combat)
		if definition == null: continue
		var card: CardInstance = CardInstance.new(definition)
		card.source_equipment = item
		combat.deck.hand.append(card)
		result.equipment.next_slot = (index + 1) % equipment.slots.size()
		return

static func validate_card(card: CardInstance, state: RunState) -> StringName:
	var item: EquipmentInstance = card.source_equipment
	if item == null or not state.player.equipment.slots.has(item): return &"invalid_equipment"
	if card.definition != action(item, state.combat): return &"stale_equipment_action"
	if item.remaining_uses < card.definition.equipment_cost: return &"equipment_depleted"
	return &""

static func commit(result: ActionResult, state: RunState) -> void:
	var delta: EquipmentActionResult = result.equipment
	if delta.item != null: delta.item.remaining_uses += delta.uses_delta
	if delta.next_slot >= 0: state.player.equipment.next_slot = delta.next_slot
	if delta.replacement != null: state.player.equipment.slots[delta.slot] = EquipmentInstance.new(delta.replacement)
	if delta.refill:
		for item: EquipmentInstance in state.player.equipment.slots:
			if item != null: item.remaining_uses = item.definition.capacity
