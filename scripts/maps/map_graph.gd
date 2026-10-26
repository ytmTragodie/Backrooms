class_name MapGraph
extends RefCounted
## 纯图查询；不读取坐标，不改变地图或 RNG。
static func successors(map: FloorMapState, id: StringName) -> Array[StringName]:
	var result: Array[StringName] = []
	for edge: Vector2i in map.edges:
		if map.nodes[edge.x].id == id: result.append(map.nodes[edge.y].id)
	return result

static func distance(map: FloorMapState, from: StringName, to: StringName, blocked: StringName = &"") -> int:
	if from == blocked or to == blocked: return -1
	var queue: Array[StringName] = [from]
	var distances: Dictionary = {from:0}
	while not queue.is_empty():
		var current: StringName = queue.pop_front()
		if current == to: return distances[current]
		for next: StringName in successors(map,current):
			if next == blocked or distances.has(next): continue
			distances[next] = int(distances[current])+1
			queue.append(next)
	return -1

static func dominates(map: FloorMapState, clue: StringName, target: StringName) -> bool:
	return distance(map,&"entry",clue) >= 0 and distance(map,clue,target) > 0 and distance(map,&"entry",target,clue) < 0

static func validate(map: FloorMapState) -> Array[String]:
	var errors: Array[String] = []
	if map.find(&"entry") == null: return ["缺少入口"]
	var ids: Array[StringName] = []
	var exits: Array[StringName] = []
	for node: MapNodeState in map.nodes:
		if node.id.is_empty() or ids.has(node.id): errors.append("重复/空节点 ID")
		if node.kind < MapNodeState.Kind.COMBAT or node.kind > MapNodeState.Kind.ENTRY: errors.append("非法节点类型")
		if (node.kind == MapNodeState.Kind.ENTRY) != (node.id == &"entry") or (node.id == &"entry" and node.layer != 0): errors.append("入口身份/层错误")
		ids.append(node.id)
		if node.kind == MapNodeState.Kind.EXIT: exits.append(node.id)
	for edge: Vector2i in map.edges:
		if edge.x < 0 or edge.y < 0 or edge.x >= map.nodes.size() or edge.y >= map.nodes.size():
			errors.append("无效连线引用")
			continue
		if map.nodes[edge.x].layer >= map.nodes[edge.y].layer: errors.append("连线必须前向")
	if not errors.is_empty(): return errors
	if exits.is_empty(): errors.append("没有出口")
	for node: MapNodeState in map.nodes:
		if distance(map,&"entry",node.id) < 0: errors.append("入口不可达节点："+String(node.id))
		var can_exit: bool = false
		for exit_id: StringName in exits:
			if distance(map,node.id,exit_id) >= 0: can_exit = true
		if not can_exit: errors.append("无前向出口："+String(node.id))
	return errors
