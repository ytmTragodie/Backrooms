class_name CutOutSystem
extends RefCounted
static func route(state: RunState) -> CutOutRouteData:
	var node: MapNodeState = state.floor_state.map.find(state.floor_state.map.current_node_id)
	for data: CutOutRouteData in state.floor_state.definition.cutout_route_pool:
		if data.id == node.content_id: return data
	return null

static func _distribution(state: RunState, game: GameData) -> Dictionary:
	var data: CutOutRouteData = route(state)
	var weights: Array[float] = []
	var modifiers: Array[String] = []
	if data == null: return {"weights": weights, "modifiers": modifiers}
	for destination: CutOutDestinationData in data.destinations:
		var weight: float = destination.base_weight
		if state.history.floors.has(destination.floor_id):
			weight *= game.revisit_weight_multiplier
			if not modifiers.has("已访问楼层降低权重"): modifiers.append("已访问楼层降低权重")
		for modifier: CutOutModifierData in data.modifiers:
			if modifier.destination_id != destination.floor_id: continue
			var known: bool = not modifier.knowledge_id.is_empty() and state.player.knowledge.has(modifier.knowledge_id)
			var carried: bool = false
			for item: EquipmentInstance in state.player.equipment.slots:
				if item != null and item.definition.id == modifier.equipment_id and item.remaining_uses > 0: carried = true
			if known or carried:
				weight *= modifier.multiplier
				modifiers.append(modifier.display_name)
		weights.append(weight)
	return {"weights": weights, "modifiers": modifiers}

static func preview(state: RunState, game: GameData) -> CutOutPreview:
	var preview: CutOutPreview = CutOutPreview.new()
	if state.flow.phase != RunFlowState.Phase.CUTOUT: return preview
	var distribution: Dictionary = _distribution(state, game)
	var data: CutOutRouteData = route(state)
	if data == null: return preview
	var total: float = 0
	for weight: float in distribution.weights: total += weight
	if total <= 0: return preview
	preview.allowed = true
	preview.modifiers.assign(distribution.modifiers)
	var unknown: float = 0
	for index: int in range(data.destinations.size()):
		var id: StringName = data.destinations[index].floor_id
		var probability: float = distribution.weights[index] / total
		if id == &"run_end" or state.player.knowledge.floors.has(id) or state.player.knowledge.rules.has(StringName("route_" + String(id))):
			preview.labels.append("M.E.G. 撤收点" if id == &"run_end" else game.find_floor(id).display_name)
			preview.probabilities.append(probability)
		else: unknown += probability
	if unknown > 0:
		preview.labels.append("未知目的地")
		preview.probabilities.append(unknown)
	return preview

static func plan(result: ActionResult, state: RunState, game: GameData, rng: RandomNumberGenerator) -> StringName:
	var node: MapNodeState = state.floor_state.map.find(state.floor_state.map.current_node_id)
	if node.kind != MapNodeState.Kind.EXIT or not preview(state, game).allowed: return &"exit_required"
	var data: CutOutRouteData = route(state)
	var distribution: Dictionary = _distribution(state, game)
	var total: float = 0
	for weight: float in distribution.weights: total += weight
	var roll: float = rng.randf() * total
	var chosen: StringName = data.destinations[-1].floor_id
	for index: int in range(data.destinations.size()):
		roll -= distribution.weights[index]
		if roll < 0:
			chosen = data.destinations[index].floor_id
			break
	result.floor.resolve_current = true
	result.flow.destination = chosen
	result.combat.clear = true
	if chosen == &"run_end":
		result.flow.phase_after = RunFlowState.Phase.RESULT
		result.flow.result_text = "探索完成：已抵达 M.E.G. 撤收点"
	else:
		result.floor.reenter = state.history.floors.has(chosen)
		result.floor.new_floor = not result.floor.reenter
		result.floor.activate = state.history.floors[chosen] if result.floor.reenter else MapSystem.generate(game.find_floor(chosen), rng)
		result.player.knowledge_floors.append(chosen)
		result.flow.phase_after = RunFlowState.Phase.MAP
	return &""
