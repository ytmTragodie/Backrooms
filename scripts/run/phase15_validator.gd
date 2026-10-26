class_name Phase15Validator
extends RefCounted
## 配置契约验证，不参与游戏规则计算。
static func weights_valid(weights: PackedInt32Array) -> bool:
	var total: int = 0
	for weight: int in weights:
		if weight < 0: return false
		total += weight
	return weights.size() == 6 and total > 0

static func validate_floor(floor: FloorData, game: GameData, errors: Array[String]) -> void:
	var config: MapGenerationData = floor.map_config
	if config.depth > 12 or config.lanes > 4: errors.append("地图尺寸超出支持范围")
	if config.exit_count < 1 or config.exit_count > 3 or floor.cutout_route_pool.size() < config.exit_count: errors.append("出口数量超过已配置路线")
	if floor.find_entrance(&"entry") == null: errors.append("缺少原图入口定义")
	var entrance_ids: Array[StringName] = []
	for entrance: FloorEntranceData in floor.entrances:
		if entrance.id.is_empty() or entrance_ids.has(entrance.id): errors.append("重复/空入口")
		entrance_ids.append(entrance.id)
		_validate_requirements(entrance.requirements,errors)
	var layers: Array[int] = []
	for region: MapRegionData in config.regions:
		if region.first_layer < 1 or region.last_layer < region.first_layer or region.last_layer > config.depth or not weights_valid(region.node_weights): errors.append("非法区域范围/权重")
		for layer: int in range(region.first_layer,region.last_layer+1):
			if layers.has(layer): errors.append("重叠地图区域")
			layers.append(layer)
		for id: StringName in region.event_ids:
			if not floor.has_content(MapNodeState.Kind.EVENT,id): errors.append("区域事件不在楼层池")
		for id: StringName in region.encounter_ids:
			if not floor.has_content(MapNodeState.Kind.COMBAT,id): errors.append("区域实体不在楼层池")
		for id: StringName in region.elite_ids:
			if not floor.has_content(MapNodeState.Kind.ELITE,id): errors.append("区域精英不在楼层池")
	var rule_ids: Array[StringName] = []
	for rule: MapRuleData in config.rules:
		if rule == null:
			errors.append("空地图规则")
			continue
		if rule.id.is_empty() or rule_ids.has(rule.id) or rule.probability < 0 or rule.probability > 1 or not is_finite(rule.probability) or rule.max_applications < 1: errors.append("非法地图规则身份/概率")
		if rule.kind < MapRuleData.Kind.PLACE_CONTENT or rule.kind > MapRuleData.Kind.LIMIT_DANGER or rule.min_layer < 1 or rule.max_layer < rule.min_layer: errors.append("非法地图规则类型/层范围")
		rule_ids.append(rule.id)
		if rule.kind == MapRuleData.Kind.PLACE_CONTENT and not floor.has_content(rule.target_kind,rule.target_content_id): errors.append("放置目标不在池中")
		if rule.kind == MapRuleData.Kind.PLACE_CONTENT and (rule.target_kind in [MapNodeState.Kind.ENTRY,MapNodeState.Kind.EXIT] or rule.min_layer > config.depth): errors.append("不能替换入口/出口或放在地图之外")
		if rule.kind == MapRuleData.Kind.INTEL_BEFORE:
			if rule.clue_event == null or not floor.has_content(MapNodeState.Kind.EVENT,rule.clue_event.id) or rule.min_distance < 1 or rule.max_distance < rule.min_distance: errors.append("非法前置情报")
		if rule.kind == MapRuleData.Kind.SUPPORT_AFTER:
			if rule.support_kind not in [MapNodeState.Kind.REST,MapNodeState.Kind.REWARD]: errors.append("不支持的战后支援")
			elif rule.support_kind == MapNodeState.Kind.REWARD and (rule.reward == null or floor.find_reward(rule.reward.id) == null): errors.append("支援奖励未接入楼层")
		if rule.kind == MapRuleData.Kind.LIMIT_DANGER and rule.max_consecutive < 1: errors.append("连续危险限制必须为正")
	for table: RewardTableData in floor.additional_rewards: ContentValidator.validate_rewards(table,errors)
	for route: CutOutRouteData in floor.cutout_route_pool:
		if route.hp_cost < 0 or route.stress_cost < 0: errors.append("负出口代价")
		var fallback: bool = false
		for destination: CutOutDestinationData in route.destinations:
			_validate_requirements(destination.requirements,errors)
			var entrance: FloorEntranceData
			if destination.floor_id != &"run_end":
				var target: FloorData = game.find_floor(destination.floor_id)
				if target != null: entrance = target.find_entrance(destination.entrance_id)
				if entrance == null: errors.append("连接入口不存在")
			if destination.requirements.is_empty() and (destination.floor_id == &"run_end" or (entrance != null and entrance.requirements.is_empty())) and destination.base_weight > 0: fallback = true
		if not fallback: errors.append("每个末端出口必须保留无条件目的地")

static func _validate_requirements(requirements: Array[TravelRequirementData], errors: Array[String]) -> void:
	for requirement: TravelRequirementData in requirements:
		if requirement == null or requirement.id.is_empty() or requirement.kind < 0 or requirement.kind > TravelRequirementData.Kind.EVENT_OUTCOME: errors.append("非法旅行条件")
