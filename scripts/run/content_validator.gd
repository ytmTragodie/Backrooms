class_name ContentValidator
extends RefCounted
## 导入/开局的内容契约。拒绝坏资源，而不是让半场战斗才抛类型错误。
static func effect_valid(effect: EffectData) -> bool:
	if effect == null: return false
	if effect.effect_type < EffectData.EffectType.DAMAGE or effect.effect_type > EffectData.EffectType.WITHDRAW or effect.target not in [EffectData.TargetType.SELF,EffectData.TargetType.PLAYER,EffectData.TargetType.ENEMY]: return false
	if effect.effect_type == EffectData.EffectType.APPLY_STATUS:
		return effect.status != null and not effect.status.id.is_empty() and effect.amount > 0 and effect.duration >= 0 and effect.status.max_stacks > 0 and effect.status.default_duration > 0
	if effect.effect_type in [EffectData.EffectType.CHANGE_STRESS, EffectData.EffectType.CHANGE_NOISE]: return effect.amount != 0
	if effect.effect_type == EffectData.EffectType.LIGHT: return effect.amount in [0, 1]
	if effect.effect_type == EffectData.EffectType.WITHDRAW: return true
	return effect.amount > 0

static func validate(game: GameData) -> Array[String]:
	var errors: Array[String] = []
	if game == null: return ["缺少 GameData"]
	if game.starter_deck == null or game.starter_deck.cards.size() < 5: errors.append("初始牌组至少五张")
	if game.floors.is_empty() or game.find_floor(game.starting_floor) == null: errors.append("起始楼层不存在")
	if game.revisit_weight_multiplier <= 0 or game.revisit_weight_multiplier > 1: errors.append("旧楼层权重必须在 (0,1] 内")
	if game.starting_equipment.size() > EquipmentState.SLOT_COUNT: errors.append("起始装备超过三格")
	var cards: Array[CardData] = game.card_pool.duplicate()
	if game.starter_deck != null: cards.append_array(game.starter_deck.cards)
	var card_ids: Dictionary = {}
	for card: CardData in cards:
		if card != null:
			if card_ids.has(card.id) and card_ids[card.id] != card: errors.append("同 ID 不同卡定义：" + String(card.id))
			card_ids[card.id] = card
	for item: EquipmentData in game.starting_equipment:
		validate_equipment(item, errors)
	for card: CardData in cards: validate_card(card, errors)
	var ids: Array[StringName] = []
	for floor: FloorData in game.floors:
		if floor == null:
			errors.append("空楼层")
			continue
		if floor.id.is_empty() or ids.has(floor.id): errors.append("重复/空楼层 ID")
		ids.append(floor.id)
		if floor.map_config == null:
			errors.append("缺少地图配置")
			continue
		if floor.map_config.depth < 3 or floor.map_config.lanes < 2 or floor.map_config.node_weights.size() != 6: errors.append("非法 DAG 配置")
		Phase15Validator.validate_floor(floor,game,errors)
		var total: int = 0
		for weight: int in floor.map_config.node_weights:
			if weight < 0: errors.append("节点权重为负")
			total += weight
		if total <= 0: errors.append("节点权重和为零")
		if floor.encounter_pool.is_empty() or floor.elite_pool.is_empty() or floor.event_pool.is_empty() or floor.shops.is_empty() or floor.cutout_route_pool.is_empty(): errors.append("楼层内容池不完整：" + String(floor.id))
		for enemy: EntityData in floor.encounter_pool + floor.elite_pool: validate_enemy(enemy, errors)
		for event: EventData in floor.event_pool: validate_event(event, errors, [])
		validate_rewards(floor.reward_pool, errors)
		for shop: ShopData in floor.shops:
			if shop.id.is_empty() or shop.offers.is_empty(): errors.append("空商店")
			for offer: ShopOfferData in shop.offers:
				if offer.price < 0: errors.append("负商店价格")
				validate_entry(offer.reward, errors)
		for route: CutOutRouteData in floor.cutout_route_pool:
			if route.id.is_empty() or route.destinations.is_empty(): errors.append("空出口")
			var destinations: Array[StringName] = []
			for destination: CutOutDestinationData in route.destinations:
				if destination.base_weight <= 0 or not is_finite(destination.base_weight): errors.append("非法切出权重")
				if destination.floor_id != &"run_end" and game.find_floor(destination.floor_id) == null: errors.append("不存在的目的地")
				if destination.id.is_empty() or destinations.has(destination.id): errors.append("重复/空连接身份")
				destinations.append(destination.id)
			for modifier: CutOutModifierData in route.modifiers:
				if modifier.multiplier <= 0 or not is_finite(modifier.multiplier) or not destinations.has(modifier.destination_id): errors.append("非法出口修正")
	# 楼层网络允许环，但每个已配置 Level 都必须有通向终局的正权重路线。
	var reaches_end: Array[StringName] = [&"run_end"]
	for iteration: int in range(game.floors.size()):
		for floor: FloorData in game.floors:
			if floor == null or reaches_end.has(floor.id): continue
			for route: CutOutRouteData in floor.cutout_route_pool:
				for destination: CutOutDestinationData in route.destinations:
					var target: FloorData = game.find_floor(destination.floor_id)
					var entrance: FloorEntranceData = target.find_entrance(destination.entrance_id) if target != null else null
					var unconditional: bool = destination.requirements.is_empty() and (destination.floor_id == &"run_end" or (entrance != null and entrance.requirements.is_empty()))
					if unconditional and reaches_end.has(destination.floor_id) and destination.base_weight > 0:
						if not reaches_end.has(floor.id): reaches_end.append(floor.id)
	for floor: FloorData in game.floors:
		if floor != null and not reaches_end.has(floor.id): errors.append("楼层网络无法抵达撤收点：" + String(floor.id))
	return errors

static func validate_card(card: CardData, errors: Array[String]) -> void:
	if card == null or not card.is_valid():
		errors.append("非法卡定义")
		return
	for effect: EffectData in card.effects:
		if not effect_valid(effect): errors.append("非法卡效果：" + String(card.id))
		if effect.target == EffectData.TargetType.ENEMY and card.target_kind != CardData.TargetKind.ENTITY: errors.append("敌方效果缺少实体目标")
	if card.upgrade_to != null:
		if card.upgrade_to == card or card.upgrade_to.upgrade_to != null: errors.append("升级链首版只支持一级")
		elif card.upgrade_to.source != CardData.Source.NORMAL: errors.append("不能升级为装备牌")
		else: validate_card(card.upgrade_to, errors)

static func validate_equipment(item: EquipmentData, errors: Array[String]) -> void:
	if item == null or item.id.is_empty() or item.capacity <= 0:
		errors.append("非法装备")
		return
	for card: CardData in [item.action_card, item.active_action_card]:
		if card != null:
			validate_card(card, errors)
			if card.source != CardData.Source.EQUIPMENT: errors.append("装备动作来源错误")

static func validate_enemy(enemy: EntityData, errors: Array[String]) -> void:
	if enemy == null or enemy.id.is_empty() or enemy.max_hp <= 0 or enemy.escape_damage_min < 0 or enemy.escape_damage_max < enemy.escape_damage_min or enemy.escape_stress < 0 or enemy.damage_reduction < 0:
		errors.append("非法实体")
		return
	if enemy.behavior_data == null or enemy.behavior_data.actions.is_empty():
		errors.append("缺少行为：" + String(enemy.id))
		return
	var ids: Array[StringName] = []
	for action: EntityActionData in enemy.behavior_data.actions:
		if action.id.is_empty() or ids.has(action.id) or action.weight <= 0 or action.cooldown < 0: errors.append("非法/重复行为")
		ids.append(action.id)
		for condition: ConditionData in action.conditions: validate_condition(condition,errors)
		for effect: EffectData in action.effects:
			if not effect_valid(effect): errors.append("非法意图效果")
			if effect.effect_type in [EffectData.EffectType.DRAW, EffectData.EffectType.GAIN_AP, EffectData.EffectType.GAIN_INTEL]: errors.append("敌人不能操作玩家牌区/AP/Intel")
	for weakness: WeaknessData in enemy.weaknesses:
		if weakness == null or weakness.trigger == null or weakness.id.is_empty() or weakness.cooldown < 0: errors.append("非法弱点")
		else:
			for condition: ConditionData in weakness.conditions: validate_condition(condition,errors)
			for effect: EffectData in weakness.effects:
				if not effect_valid(effect): errors.append("非法弱点效果")
	validate_rewards(enemy.reward_data, errors)

static func validate_condition(condition: ConditionData, errors: Array[String]) -> void:
	if condition == null or not is_finite(condition.numeric_value) or condition.type < ConditionData.ConditionType.HP_RATIO or condition.type > ConditionData.ConditionType.LIGHT_ACTIVE or condition.operator < ConditionData.CompareOp.EQ or condition.operator > ConditionData.CompareOp.LTE: errors.append("非法条件")

static func validate_event(event: EventData, errors: Array[String], ancestors: Array[EventData]) -> void:
	if event == null or event.id.is_empty() or event.options.is_empty() or ancestors.has(event):
		errors.append("非法事件/分支环")
		return
	var path: Array[EventData] = ancestors.duplicate()
	path.append(event)
	var has_free: bool = false
	var ids: Array[StringName] = []
	for option: EventOptionData in event.options:
		if option.id.is_empty() or ids.has(option.id) or option.supply_cost < 0 or option.hp_cost < 0 or option.stress_cost < 0 or option.reveal_nodes < 0: errors.append("非法事件选项")
		ids.append(option.id)
		if option.supply_cost == 0 and option.hp_cost == 0 and option.required_knowledge.is_empty(): has_free = true
		if option.encounter != null: validate_enemy(option.encounter, errors)
		validate_rewards(option.rewards, errors)
		if option.next_event != null: validate_event(option.next_event, errors, path)
	if not has_free: errors.append("事件必须保留无资源要求选项")

static func validate_rewards(table: RewardTableData, errors: Array[String]) -> void:
	if table == null: return
	if table.random_count < 0: errors.append("负奖励抽取数")
	for entry: RewardEntryData in table.guaranteed_rewards + table.random_rewards: validate_entry(entry, errors)

static func validate_entry(entry: RewardEntryData, errors: Array[String]) -> void:
	if entry == null or entry.amount <= 0 or entry.weight <= 0 or entry.kind < RewardEntryData.Kind.CARD_CHOICE or entry.kind > RewardEntryData.Kind.CALM:
		errors.append("非法奖励条目")
		return
	if entry.kind == RewardEntryData.Kind.CARD_CHOICE:
		if entry.cards.is_empty(): errors.append("空卡奖励")
		for card: CardData in entry.cards:
			validate_card(card, errors)
			if card.source != CardData.Source.NORMAL: errors.append("奖励池混入装备卡")
	if entry.kind == RewardEntryData.Kind.EQUIPMENT: validate_equipment(entry.equipment, errors)
