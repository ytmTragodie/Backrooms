extends RefCounted


static func without_rewards(source: FloorData) -> FloorData:
	# 旧套件验证固定牌数／牌序不变量；显式隔离新增奖励，生产内容由 Phase 9 覆盖。
	var copy: FloorData = source.duplicate(false) as FloorData
	copy.fresh_events = []
	for original: EventData in source.fresh_events:
		var event: EventData = original.duplicate(false) as EventData
		event.completion_reward = null
		copy.fresh_events.append(event)
	for field: String in ["entry_entity", "followup_entity"]:
		var original: EntityData = source.get(field) as EntityData
		if original != null:
			var entity: EntityData = original.duplicate(false) as EntityData
			entity.resolution_reward = null
			copy.set(field, entity)
	return copy
