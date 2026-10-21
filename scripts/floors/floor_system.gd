class_name FloorSystem
extends RefCounted

# 楼层统计、Threat、flags、照明和黑暗观察的唯一提交入口。
static func commit(result: ActionResult, state: RunState) -> void:
	if result == null or state == null or state.floor_state == null:
		return
	var floor: FloorState = state.floor_state
	var data: FloorActionResult = result.floor

	if data.dark_observation:
		floor.dark_observation_used = true
		result.debug_lines.append("[FLOOR] darkness first_observation surcharge_applied")
	if data.light_extinguished:
		floor.light_active = false
		result.debug_lines.append("[LIGHT] extinguished")
	if data.light_activated:
		floor.light_active = true
		result.debug_lines.append("[LIGHT] active until=end_turn")
	for flag: StringName in data.floor_flags_added:
		if not floor.floor_flags.has(flag):
			floor.floor_flags.append(flag)
			result.debug_lines.append("[FLOOR] flag %s" % flag)
	if data.total_explore_delta != 0:
		floor.total_explore = maxi(0, floor.total_explore + data.total_explore_delta)
	if data.completed_objectives_delta != 0:
		floor.completed_objectives = maxi(0, floor.completed_objectives + data.completed_objectives_delta)
	if not data.threat_reason.is_empty() and data.threat_delta != 0:
		floor.threat = clampi(floor.threat + data.threat_delta, 0, FloorState.MAX_THREAT)
		result.debug_lines.append("[THREAT] %+d reason=%s total=%d" % [data.threat_delta, data.threat_reason, floor.threat])


# 回合末清理临时环境状态；统计和已发现事实保留。
static func finish_turn(floor: FloorState) -> void:
	if floor == null:
		return
	floor.dark_observation_used = false
	floor.light_active = false