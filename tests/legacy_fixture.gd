extends RefCounted


static func without_rewards(source: FloorData) -> FloorData:
	# 旧套件验证固定牌数／牌序不变量；显式隔离新增奖励，生产内容由 Phase 9 覆盖。
	var copy: FloorData = source.duplicate(false) as FloorData
	copy.fresh_objectives = []
	for original: ObjectiveData in source.fresh_objectives:
		var event: ObjectiveData = original.duplicate(false) as ObjectiveData
		event.completion_reward = null
		copy.fresh_objectives.append(event)
	copy.objective_spawn_chance = 1.0
	copy.max_objectives_per_floor = copy.fresh_objectives.size()
	copy.intro_objective = copy.fresh_objectives[0] if not copy.fresh_objectives.is_empty() else null
	for field: String in ["entry_entity", "followup_entity"]:
		var original: EntityData = source.get(field) as EntityData
		if original != null:
			var entity: EntityData = original.duplicate(false) as EntityData
			entity.resolution_reward = null
			copy.set(field, entity)
	return copy
