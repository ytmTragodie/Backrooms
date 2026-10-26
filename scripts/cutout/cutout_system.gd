class_name CutOutSystem
extends RefCounted
static func route(state: RunState) -> CutOutRouteData:
	var node: MapNodeState = state.floor_state.map.find(state.floor_state.map.current_node_id)
	if node.kind != MapNodeState.Kind.EXIT: return null
	for data: CutOutRouteData in state.floor_state.definition.cutout_route_pool:
		if data.id == node.content_id: return data
	return null

static func destination_allowed(destination: CutOutDestinationData, state: RunState, game: GameData) -> bool:
	if not TravelRequirementData.all_satisfied(destination.requirements,state): return false
	if destination.floor_id == &"run_end": return true
	var floor: FloorData = game.find_floor(destination.floor_id)
	if floor == null: return false
	var entrance: FloorEntranceData = floor.find_entrance(destination.entrance_id)
	return entrance != null and TravelRequirementData.all_satisfied(entrance.requirements,state)

static func distribution(data: CutOutRouteData, state: RunState, game: GameData) -> Dictionary:
	# 与网络共用纯查询；预览不抽样、不临时移动玩家或修改 Flow。
	var weights: Array[float] = []
	var modifiers: Array[String] = []
	if data == null: return {"weights":weights,"modifiers":modifiers}
	for destination: CutOutDestinationData in data.destinations:
		var weight: float = destination.base_weight if destination_allowed(destination,state,game) else 0.0
		if state.history.floors.has(destination.floor_id):
			weight *= game.revisit_weight_multiplier
			if not modifiers.has("已访问楼层降低权重"): modifiers.append("已访问楼层降低权重")
		for modifier: CutOutModifierData in data.modifiers:
			if modifier.destination_id != destination.id: continue
			var known: bool = not modifier.knowledge_id.is_empty() and state.player.knowledge.has(modifier.knowledge_id)
			var carried: bool = false
			for item: EquipmentInstance in state.player.equipment.slots:
				if item != null and item.definition.id == modifier.equipment_id and item.remaining_uses > 0: carried = true
			if known or carried:
				weight *= modifier.multiplier
				modifiers.append(modifier.display_name)
		weights.append(weight)
	return {"weights":weights,"modifiers":modifiers}

static func _distribution(state: RunState, game: GameData) -> Dictionary:
	return distribution(route(state),state,game)

static func destination_known(destination: CutOutDestinationData, state: RunState) -> bool:
	return destination.floor_id == &"run_end" or state.player.knowledge.floors.has(destination.floor_id) or state.player.knowledge.rules.has(StringName("route_"+String(destination.floor_id)))

static func preview(state: RunState, game: GameData) -> CutOutPreview:
	var result: CutOutPreview = CutOutPreview.new()
	if state.flow.phase != RunFlowState.Phase.CUTOUT: return result
	var data: CutOutRouteData = route(state)
	if data == null: return result
	var calculated: Dictionary = distribution(data,state,game)
	var total: float = 0
	for weight: float in calculated.weights: total += weight
	if total <= 0: return result
	result.allowed = true
	result.hp_cost = data.hp_cost
	result.stress_cost = data.stress_cost
	result.modifiers.assign(calculated.modifiers)
	var unknown: float = 0
	for index: int in range(data.destinations.size()):
		var destination: CutOutDestinationData = data.destinations[index]
		var probability: float = calculated.weights[index]/total
		if probability <= 0: continue
		if destination_known(destination,state):
			result.labels.append(destination_label(destination,game))
			result.probabilities.append(probability)
		else: unknown += probability
	if unknown > 0:
		result.labels.append("未知目的地")
		result.probabilities.append(unknown)
	return result

static func destination_label(destination: CutOutDestinationData, game: GameData) -> String:
	if destination.floor_id == &"run_end": return "M.E.G. 撤收点"
	var floor: FloorData = game.find_floor(destination.floor_id)
	return floor.display_name + " · " + floor.find_entrance(destination.entrance_id).display_name

static func observe(result: ActionResult, source: FloorData, data: CutOutRouteData, state: RunState, traversed: StringName = &"") -> void:
	result.player.knowledge_exits.append(data.id)
	for destination: CutOutDestinationData in data.destinations:
		if destination.id != traversed and not destination_known(destination,state): continue
		var connection: KnownConnection = KnownConnection.new()
		connection.source_floor = source.id
		connection.route_id = data.id
		connection.destination_id = destination.id
		connection.traversed = destination.id == traversed
		result.player.connections.append(connection)

static func plan(result: ActionResult, state: RunState, game: GameData, rng: RandomNumberGenerator) -> StringName:
	if not preview(state,game).allowed: return &"exit_required"
	var data: CutOutRouteData = route(state)
	result.player.hp_delta -= data.hp_cost
	result.player.stress_delta += data.stress_cost
	result.floor.resolve_current = true
	result.combat.clear = true
	# 致死代价明确结束本局，不留下活着却无法操作的软锁；UI 确认前公开警告。
	if state.player.hp <= data.hp_cost:
		result.flow.phase_after = RunFlowState.Phase.RESULT
		result.flow.result_text = "探索结束：未能承受出口代价"
		return &""
	var calculated: Dictionary = distribution(data,state,game)
	var total: float = 0
	for weight: float in calculated.weights: total += weight
	var roll: float = rng.randf()*total
	var selected: CutOutDestinationData
	for index: int in range(data.destinations.size()):
		roll -= calculated.weights[index]
		if roll < 0:
			selected = data.destinations[index]
			break
	if selected == null: return &"exit_required"
	var chosen: StringName = selected.floor_id
	result.flow.destination = chosen
	observe(result,state.floor_state.definition,data,state,selected.id)
	if chosen == &"run_end":
		result.flow.phase_after = RunFlowState.Phase.RESULT
		result.flow.result_text = "探索完成：已抵达 M.E.G. 撤收点"
	else:
		result.floor.reenter = state.history.floors.has(chosen)
		result.floor.new_floor = not result.floor.reenter
		result.floor.activate = state.history.floors[chosen] if result.floor.reenter else MapSystem.generate(game.find_floor(chosen),rng)
		if not result.floor.activate.map.validation_errors.is_empty(): return &"invalid_map"
		result.player.knowledge_floors.append(chosen)
		result.flow.phase_after = RunFlowState.Phase.MAP
	return &""
