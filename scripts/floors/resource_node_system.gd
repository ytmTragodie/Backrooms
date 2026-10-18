class_name ResourceNodeSystem
extends RefCounted


static func validate(floor: FloorState, data: FloorData) -> StringName:
	if floor.resource_nodes.size() != data.resource_nodes.size():
		return &"invalid_resource_context"
	var ids: Array[StringName] = []
	for definition: ResourceNodeData in data.resource_nodes:
		if not valid_definition(definition) or ids.has(definition.id):
			return &"invalid_resource_definition"
		ids.append(definition.id)
		var node: ResourceNode = floor.find_resource(definition.id)
		if node == null or node.status < ResourceNode.Status.UNDISCOVERED or node.status > ResourceNode.Status.DEPLETED:
			return &"invalid_resource_context"
	return &""


static func find_discoverable(floor: FloorState, data: FloorData, deep: bool, state: RunState = null) -> ResourceNodeData:
	# 深搜优先隐藏节点；每次最多处理一个节点，永远不从已搜刮节点生成奖励。
	var selected: ResourceNodeData
	for definition: ResourceNodeData in data.resource_nodes:
		if not has_reward(definition, state):
			continue
		if floor.find_resource(definition.id).status != ResourceNode.Status.UNDISCOVERED:
			continue
		if not deep and definition.hidden:
			continue
		if selected == null or (deep and definition.hidden and not selected.hidden):
			selected = definition
	return selected


static func find_search_reward(floor: FloorState, data: FloorData, deep: bool, state: RunState = null) -> ResourceNodeData:
	# 旧访问中已发现但未领取的节点也可由同一搜索语义领取，无需第二个动词。
	for definition: ResourceNodeData in data.resource_nodes:
		if floor.find_resource(definition.id).status == ResourceNode.Status.DISCOVERED and has_reward(definition, state):
			return definition
	return find_discoverable(floor, data, deep, state)


static func plan_search_reward(result: ActionResult, state: RunState, data: FloorData, deep: bool) -> void:
	var selected: ResourceNodeData = find_search_reward(state.floor_state, data, deep, state)
	if selected == null:
		return
	if state.floor_state.find_resource(selected.id).status == ResourceNode.Status.UNDISCOVERED:
		result.resource_discovered_id = selected.id
	result.resource_looted_id = selected.id
	result.supply_delta += selected.supply_reward
	var item: EquipmentInstance = recipient(selected, state)
	if item != null:
		result.resource_equipment = item
		result.resource_uses_gained = mini(selected.uses_reward, item.definition.capacity - item.remaining_uses)
	if result.action_id.is_empty():
		result.action_id = &"search_environment"


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


static func valid_definition(data: ResourceNodeData) -> bool:
	return data != null and not data.id.is_empty() and data.supply_reward >= 0 and data.uses_reward >= 0 and (data.uses_reward == 0 or not data.equipment_id.is_empty())


static func recipient(data: ResourceNodeData, state: RunState) -> EquipmentInstance:
	if state != null and data.uses_reward > 0:
		for item: EquipmentInstance in state.equipment_slots:
			if item != null and item.definition.id == data.equipment_id:
				return item
	return null


static func has_reward(data: ResourceNodeData, state: RunState) -> bool:
	if data.supply_reward > 0:
		return true
	var item: EquipmentInstance = recipient(data, state)
	# 满额／未携带时不浪费有限缓存，稍后搜索仍可领取。
	return item != null and item.remaining_uses < item.definition.capacity


static func finish_turn(floor: FloorState) -> void:
	# LOOTED 保留到回合末用于呈现反馈；这两个末态都禁止再次领取奖励。
	for node: ResourceNode in floor.resource_nodes:
		if node.status == ResourceNode.Status.LOOTED:
			node.status = ResourceNode.Status.DEPLETED
			if OS.is_debug_build():
				print("[RESOURCE] depleted %s" % node.node_id)
