class_name MapGenerationRules
extends RefCounted
## 只修正首次生成的私有草案；规则不在地图通行时重复运行。
static func apply(floor: FloorState, rng: RandomNumberGenerator) -> void:
	var protected: Array[StringName] = []
	var rules: Array[MapRuleData] = floor.definition.map_config.rules
	for rule: MapRuleData in rules:
		if rule.kind == MapRuleData.Kind.PLACE_CONTENT: _place(floor, rule, rng, protected)
	for rule: MapRuleData in rules:
		if rule.kind == MapRuleData.Kind.LIMIT_DANGER: _limit(floor.map, rule, rng, protected)
	# 强制约束先于偏好；后者不能覆盖已被前者占用的节点。
	for required: bool in [true, false]:
		for rule: MapRuleData in rules:
			if rule.required != required: continue
			if rule.kind in [MapRuleData.Kind.INTEL_BEFORE, MapRuleData.Kind.SUPPORT_AFTER]: _relative(floor, rule, rng, protected)
	floor.map.validation_errors.append_array(validate(floor))

static func _record(map: FloorMapState, rule: MapRuleData, anchor: StringName, affected: StringName = &"") -> void:
	var record: MapRuleRecord = MapRuleRecord.new()
	record.rule_id = rule.id
	record.anchor_id = anchor
	record.affected_id = affected
	record.mandatory_path = rule.mandatory_path
	record.applied = not affected.is_empty()
	map.rule_records.append(record)
	if rule.required and not record.applied: map.validation_errors.append("强制规则无法放置：" + String(rule.id))

static func _matches(node: MapNodeState, rule: MapRuleData) -> bool:
	return node.kind == rule.target_kind and (rule.target_content_id.is_empty() or node.content_id == rule.target_content_id) and node.layer >= rule.min_layer and node.layer <= rule.max_layer

static func _place(floor: FloorState, rule: MapRuleData, rng: RandomNumberGenerator, protected: Array[StringName]) -> void:
	if not rule.required and rng.randf() >= rule.probability: return
	var candidates: Array[MapNodeState] = []
	for node: MapNodeState in floor.map.nodes:
		if node.kind not in [MapNodeState.Kind.ENTRY, MapNodeState.Kind.EXIT] and node.layer >= rule.min_layer and node.layer <= rule.max_layer and not protected.has(node.id): candidates.append(node)
	for index: int in range(rule.max_applications):
		if candidates.is_empty():
			_record(floor.map, rule, &"")
			break
		var node: MapNodeState = candidates.pop_at(rng.randi_range(0, candidates.size()-1))
		node.kind = rule.target_kind
		node.content_id = rule.target_content_id
		protected.append(node.id)
		_record(floor.map, rule, node.id, node.id)

static func _streak(map: FloorMapState, node: MapNodeState, counts: Dictionary) -> int:
	if node.kind not in [MapNodeState.Kind.COMBAT, MapNodeState.Kind.ELITE]: return 0
	var previous: int = 0
	for edge: Vector2i in map.edges:
		if map.nodes[edge.y] == node: previous = maxi(previous, int(counts.get(map.nodes[edge.x].id,0)))
	return previous + 1

static func _limit(map: FloorMapState, rule: MapRuleData, rng: RandomNumberGenerator, protected: Array[StringName]) -> void:
	if not rule.required and rng.randf() >= rule.probability: return
	var counts: Dictionary = {}
	for node: MapNodeState in map.nodes:
		var count: int = _streak(map, node, counts)
		if count > rule.max_consecutive and not protected.has(node.id):
			node.kind = MapNodeState.Kind.REST
			node.content_id = &""
			count = 0
			_record(map, rule, node.id, node.id)
		counts[node.id] = count

static func _relative(floor: FloorState, rule: MapRuleData, rng: RandomNumberGenerator, protected: Array[StringName]) -> void:
	var applied: int = 0
	for anchor: MapNodeState in floor.map.nodes:
		if not _matches(anchor, rule) or applied >= rule.max_applications: continue
		if not rule.anchor_rule_id.is_empty():
			var anchored: bool = false
			for record: MapRuleRecord in floor.map.rule_records:
				if record.rule_id == rule.anchor_rule_id and record.affected_id == anchor.id: anchored = true
			if not anchored: continue
		if not rule.required and rng.randf() >= rule.probability: continue
		var candidates: Array[MapNodeState] = []
		for node: MapNodeState in floor.map.nodes:
			if node.kind in [MapNodeState.Kind.ENTRY, MapNodeState.Kind.EXIT] or protected.has(node.id): continue
			var distance: int = MapGraph.distance(floor.map,node.id,anchor.id) if rule.kind == MapRuleData.Kind.INTEL_BEFORE else MapGraph.distance(floor.map,anchor.id,node.id)
			if rule.kind == MapRuleData.Kind.INTEL_BEFORE and distance >= rule.min_distance and distance <= rule.max_distance: candidates.append(node)
			elif rule.kind == MapRuleData.Kind.SUPPORT_AFTER and distance == 1: candidates.append(node)
		if candidates.is_empty():
			_record(floor.map,rule,anchor.id)
			continue
		var selected: MapNodeState = candidates[rng.randi_range(0,candidates.size()-1)]
		if rule.kind == MapRuleData.Kind.INTEL_BEFORE:
			selected.kind = MapNodeState.Kind.EVENT
			selected.content_id = rule.clue_event.id
			if rule.mandatory_path: _corridor(floor.map, selected, anchor)
		else:
			selected.kind = rule.support_kind
			selected.content_id = rule.reward.id if rule.support_kind == MapNodeState.Kind.REWARD else &""
		protected.append(selected.id)
		_record(floor.map,rule,anchor.id,selected.id)
		applied += 1
	if rule.required and applied == 0: _record(floor.map,rule,&"")

static func _corridor(map: FloorMapState, clue: MapNodeState, target: MapNodeState) -> void:
	# 沿真实路径收束目标的来路。其余分支保留，不把整个楼层变成单线。
	var path: Array[StringName] = [clue.id]
	while path[-1] != target.id:
		for next: StringName in MapGraph.successors(map,path[-1]):
			if MapGraph.distance(map,next,target.id) >= 0:
				path.append(next)
				break
	for index: int in range(1,path.size()):
		var edges: Array[Vector2i] = []
		for edge: Vector2i in map.edges:
			if map.nodes[edge.y].id != path[index] or map.nodes[edge.x].id == path[index-1]: edges.append(edge)
		map.edges = edges
	# 删去侧面入口后，为原分支补上非走廊后继，避免生成不可离开的节点。
	for node: MapNodeState in map.nodes:
		if node.kind == MapNodeState.Kind.EXIT or not MapGraph.successors(map,node.id).is_empty(): continue
		for next: MapNodeState in map.nodes:
			if next.layer == node.layer+1 and not path.has(next.id):
				map.edges.append(Vector2i(map.nodes.find(node),map.nodes.find(next)))
				break

static func validate(floor: FloorState) -> Array[String]:
	var errors: Array[String] = MapGraph.validate(floor.map)
	for node: MapNodeState in floor.map.nodes:
		if not floor.definition.has_content(node.kind,node.content_id): errors.append("节点引用不存在的内容：" + String(node.content_id))
	for rule: MapRuleData in floor.definition.map_config.rules:
		if not rule.required: continue
		if rule.kind == MapRuleData.Kind.LIMIT_DANGER:
			var counts: Dictionary = {}
			for node: MapNodeState in floor.map.nodes:
				counts[node.id] = _streak(floor.map,node,counts)
				if int(counts[node.id]) > rule.max_consecutive: errors.append("连续危险超限："+String(rule.id))
		for record: MapRuleRecord in floor.map.rule_records:
			if record.rule_id != rule.id or not record.applied: continue
			var node: MapNodeState = floor.map.find(record.affected_id)
			if rule.kind == MapRuleData.Kind.PLACE_CONTENT and (node.kind != rule.target_kind or node.content_id != rule.target_content_id): errors.append("锚点被覆盖："+String(rule.id))
			if rule.kind == MapRuleData.Kind.INTEL_BEFORE:
				var distance: int = MapGraph.distance(floor.map,node.id,record.anchor_id)
				if node.content_id != rule.clue_event.id or distance < rule.min_distance or distance > rule.max_distance: errors.append("前置情报失效："+String(rule.id))
				if rule.mandatory_path and not MapGraph.dominates(floor.map,node.id,record.anchor_id): errors.append("情报非必经："+String(rule.id))
			if rule.kind == MapRuleData.Kind.SUPPORT_AFTER:
				if node.kind != rule.support_kind or MapGraph.distance(floor.map,record.anchor_id,node.id) != 1: errors.append("战后支援失效："+String(rule.id))
				if rule.support_kind == MapNodeState.Kind.REWARD and node.content_id != rule.reward.id: errors.append("战后奖励被覆盖："+String(rule.id))
	return errors
