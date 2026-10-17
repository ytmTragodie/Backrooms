class_name ResourceNodeSystem
extends RefCounted


static func validate(floor: FloorState, data: FloorData) -> StringName:
	if floor.resource_nodes.size() != data.resource_nodes.size():
		return &"invalid_resource_context"
	var ids: Array[StringName] = []
	for definition: ResourceNodeData in data.resource_nodes:
		if definition == null or definition.id.is_empty() or definition.supply_reward < 0 or ids.has(definition.id):
			return &"invalid_resource_definition"
		ids.append(definition.id)
		var node: ResourceNode = floor.find_resource(definition.id)
		if node == null or node.status < ResourceNode.Status.UNDISCOVERED or node.status > ResourceNode.Status.DEPLETED:
			return &"invalid_resource_context"
	return &""


static func plan_discovery(result: ActionResult, state: RunState, data: FloorData, deep: bool) -> void:
	# 深搜优先隐藏节点；每次最多处理一个节点，永远不从已搜刮节点生成奖励。
	var selected: ResourceNodeData
	for definition: ResourceNodeData in data.resource_nodes:
		if state.floor_state.find_resource(definition.id).status != ResourceNode.Status.UNDISCOVERED:
			continue
		if not deep and definition.hidden:
			continue
		if selected == null or (deep and definition.hidden and not selected.hidden):
			selected = definition
	if selected == null:
		return
	result.resource_discovered_id = selected.id
	if deep:
		result.resource_looted_id = selected.id
		result.supply_delta = selected.supply_reward


static func plan_loot(result: ActionResult, state: RunState, data: FloorData, node_id: StringName) -> StringName:
	var node: ResourceNode = state.floor_state.find_resource(node_id)
	var definition: ResourceNodeData = data.find_resource(node_id)
	if node == null or definition == null:
		return &"resource_not_found"
	if node.status == ResourceNode.Status.LOOTED or node.status == ResourceNode.Status.DEPLETED:
		return &"resource_depleted"
	if node.status != ResourceNode.Status.DISCOVERED:
		return &"resource_undiscovered"
	result.resource_looted_id = node_id
	result.supply_delta = definition.supply_reward
	return &""


static func commit(result: ActionResult, state: RunState) -> void:
	if not result.resource_discovered_id.is_empty():
		state.floor_state.find_resource(result.resource_discovered_id).status = ResourceNode.Status.DISCOVERED
		result.debug_lines.append("[RESOURCE] discovered %s" % result.resource_discovered_id)
	if not result.resource_looted_id.is_empty():
		state.floor_state.find_resource(result.resource_looted_id).status = ResourceNode.Status.LOOTED
		result.debug_lines.append("[RESOURCE] looted %s" % result.resource_looted_id)
	if result.supply_delta != 0:
		state.supply += result.supply_delta
		result.debug_lines.append("[RESOURCE] supply %+d total=%d" % [result.supply_delta, state.supply])


static func finish_turn(floor: FloorState) -> void:
	# LOOTED 保留到回合末用于呈现反馈；这两个末态都禁止再次领取奖励。
	for node: ResourceNode in floor.resource_nodes:
		if node.status == ResourceNode.Status.LOOTED:
			node.status = ResourceNode.Status.DEPLETED
			if OS.is_debug_build():
				print("[RESOURCE] depleted %s" % node.node_id)
