class_name FloorMapState
extends RefCounted
## 拓扑始终公开，只有节点内容有迷雾；揭示与结算状态独立。
var nodes: Array[MapNodeState] = []
var edges: Array[Vector2i] = []
var current_node_id: StringName = &"entry"
var generation_seed: int
var generation_version: int = 15
var rule_records: Array[MapRuleRecord] = []
var validation_errors: Array[String] = []
func find(id: StringName) -> MapNodeState:
	for node: MapNodeState in nodes:
		if node.id == id: return node
	return null
func next_ids() -> Array[StringName]:
	var result: Array[StringName] = []
	for edge: Vector2i in edges:
		if nodes[edge.x].id == current_node_id: result.append(nodes[edge.y].id)
	return result
