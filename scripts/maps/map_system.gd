class_name MapSystem
extends RefCounted
## 分层非线性 DAG。所有随机内容在首次生成时固定，揭示不重新抽取。
static func weighted_index(weights: PackedInt32Array, rng: RandomNumberGenerator) -> int:
	var total: int = 0
	for weight: int in weights: total += weight
	var roll: int = rng.randi_range(1, maxi(1, total))
	for index: int in range(weights.size()):
		roll -= weights[index]
		if roll <= 0: return index
	return 0

static func generate(data: FloorData, rng: RandomNumberGenerator) -> FloorState:
	var floor: FloorState = FloorState.new()
	floor.definition = data
	floor.map = FloorMapState.new()
	floor.map.generation_seed = rng.state
	var entry: MapNodeState = MapNodeState.new()
	entry.id = &"entry"
	entry.kind = MapNodeState.Kind.ENTRY
	entry.position = Vector2(0.035, 0.5)
	entry.visibility = MapNodeState.Visibility.REVEALED
	entry.resolution = MapNodeState.Resolution.RESOLVED
	floor.map.nodes.append(entry)
	var previous: Array[int] = [0]
	for layer: int in range(1, data.map_config.depth + 2):
		var current: Array[int] = []
		var count: int = 1 if layer == data.map_config.depth + 1 else rng.randi_range(2, data.map_config.lanes)
		for lane: int in range(count):
			var node: MapNodeState = MapNodeState.new()
			node.id = StringName("node_%d_%d" % [layer, lane])
			node.layer = layer
			node.position = Vector2(0.035 + 0.93 * layer / (data.map_config.depth + 1), (lane + 1.0) / (count + 1) + rng.randf_range(-0.035, 0.035))
			node.kind = MapNodeState.Kind.EXIT if count == 1 else weighted_index(data.map_config.node_weights, rng) as MapNodeState.Kind
			node.content_id = _content(data, node.kind, rng)
			if layer <= data.map_config.reveal_depth or node.kind == MapNodeState.Kind.EXIT: node.visibility = MapNodeState.Visibility.REVEALED
			current.append(floor.map.nodes.size())
			floor.map.nodes.append(node)
		# 每个旧节点有出口，每个新节点有入口；不靠重试碰运气保证连通。
		for index: int in range(previous.size()):
			var target: int = mini(current.size() - 1, int(float(index) * current.size() / previous.size()))
			_connect(floor.map, previous[index], current[target])
			if current.size() > 1 and rng.randf() < 0.55: _connect(floor.map, previous[index], current[(target + 1) % current.size()])
		for index: int in range(current.size()):
			var incoming: bool = false
			for edge: Vector2i in floor.map.edges:
				if edge.y == current[index]: incoming = true
			if not incoming: _connect(floor.map, previous[mini(previous.size() - 1, index)], current[index])
		previous = current
	return floor

static func _connect(map: FloorMapState, from: int, to: int) -> void:
	var edge: Vector2i = Vector2i(from, to)
	if not map.edges.has(edge): map.edges.append(edge)

static func _content(data: FloorData, kind: MapNodeState.Kind, rng: RandomNumberGenerator) -> StringName:
	match kind:
		MapNodeState.Kind.COMBAT: return data.encounter_pool[rng.randi_range(0, data.encounter_pool.size() - 1)].id
		MapNodeState.Kind.ELITE: return data.elite_pool[rng.randi_range(0, data.elite_pool.size() - 1)].id
		MapNodeState.Kind.EVENT: return data.event_pool[rng.randi_range(0, data.event_pool.size() - 1)].id
		MapNodeState.Kind.REWARD: return data.reward_pool.id
		MapNodeState.Kind.SHOP: return data.shops[rng.randi_range(0, data.shops.size() - 1)].id
		MapNodeState.Kind.EXIT: return data.cutout_route_pool[rng.randi_range(0, data.cutout_route_pool.size() - 1)].id
	return &""

static func plan_reveal(result: ActionResult, state: RunState, count: int = 0, from_layer: int = -1) -> void:
	var map: FloorMapState = state.floor_state.map
	var layer: int = map.find(map.current_node_id).layer if from_layer < 0 else from_layer
	var depth: int = state.floor_state.definition.map_config.reveal_depth
	if state.player.knowledge.rules.has(&"map_survey"): depth += 1
	for node: MapNodeState in map.nodes:
		if node.layer <= layer + depth and node.visibility == MapNodeState.Visibility.UNKNOWN: result.floor.reveal.append(node.id)
	for node: MapNodeState in map.nodes:
		if count <= 0: break
		if node.visibility == MapNodeState.Visibility.UNKNOWN and not result.floor.reveal.has(node.id):
			result.floor.reveal.append(node.id)
			count -= 1

static func commit(result: ActionResult, state: RunState) -> void:
	# 先结算旧楼层，后激活目标；历史表保存同一个 FloorState 引用。
	var map: FloorMapState = state.floor_state.map
	if not result.floor.move_to.is_empty():
		map.current_node_id = result.floor.move_to
		var node: MapNodeState = map.find(result.floor.move_to)
		node.visibility = MapNodeState.Visibility.REVEALED
		if node.resolution == MapNodeState.Resolution.UNVISITED: node.resolution = MapNodeState.Resolution.ACTIVE
	if result.floor.resolve_current: map.find(map.current_node_id).resolution = MapNodeState.Resolution.RESOLVED
	for id: StringName in result.floor.reveal: map.find(id).visibility = MapNodeState.Visibility.REVEALED
	if result.floor.activate != null:
		var next: FloorState = result.floor.activate
		if result.floor.new_floor: state.history.floors[next.floor_id] = next
		if result.floor.reenter: next.map.current_node_id = &"entry"
		state.floor_state = next
		state.history.visits[next.floor_id] = int(state.history.visits.get(next.floor_id, 0)) + 1
