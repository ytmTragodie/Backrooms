class_name EventSystem
extends RefCounted


static func conditions_met(required: Array[StringName], blocked: Array[StringName], flags: Array[StringName]) -> bool:
	for flag: StringName in required:
		if not flags.has(flag):
			return false
	for flag: StringName in blocked:
		if flags.has(flag):
			return false
	return true


static func draw_fresh(data: FloorData, state: FloorState, rng: RandomNumberGenerator) -> StringName:
	assert(data.id == state.floor_id, "Event selection requires matching floor data/state")
	# 未完成事件跨回合保留，不能靠结束回合跳过进度或刷新基础交互。
	if state.current_event != null and not state.current_event.resolved:
		return state.current_event_id
	var candidates: Array[EventData] = []
	var total_weight: int = 0
	for event_id: StringName in state.remaining_fresh_events:
		var event: EventData = data.find_event(event_id)
		assert(event != null and event.weight > 0, "Invalid Fresh Event definition")
		if event.once_per_instance and state.seen_event_ids.has(event.id):
			continue
		if not conditions_met(event.required_flags, event.blocked_flags, state.floor_flags):
			continue
		candidates.append(event)
		total_weight += event.weight
	state.current_event = null
	if candidates.is_empty():
		if OS.is_debug_build():
			print("[EVENT] no_eligible_fresh remaining=%d" % state.remaining_fresh_events.size())
		return &""
	# 先过滤条件，再用本局 RNG 加权选择；无候选时不消耗随机数。
	var roll: int = rng.randi_range(1, total_weight)
	for event: EventData in candidates:
		roll -= event.weight
		if roll > 0:
			continue
		state.current_event = EventInstance.new(event.id)
		state.remaining_fresh_events.erase(event.id)
		state.seen_event_ids.append(event.id)
		if OS.is_debug_build():
			print("[EVENT] draw %s" % event.id)
		return event.id
	return &""
