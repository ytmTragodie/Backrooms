class_name InsightSystem
extends RefCounted


static func validate_definition(data: InsightData) -> StringName:
	if data == null or data.id.is_empty() or data.cutout_stability < 0 or data.cutout_knowledge < 0:
		return &"invalid_insight_definition"
	return &""


static func plan_confirmation(result: ActionResult, data: InsightData, floor: FloorState) -> StringName:
	var error: StringName = validate_definition(data)
	if not error.is_empty():
		return error
	if floor.discovered_insight_ids.has(data.id) or result.insight_ids.has(data.id):
		return &""
	# 事件、实体与地标共用一次性确认；规划只写结果，不提前改变认知或切出准备。
	result.insight_ids.append(data.id)
	result.cognition_delta = mini(result.insight_ids.size(), FloorState.MAX_COGNITION - floor.cognition)
	result.stability_delta = mini(result.stability_delta + data.cutout_stability, CutOutState.MAX_STABILITY - floor.cutout_state.stability)
	result.knowledge_delta = mini(result.knowledge_delta + data.cutout_knowledge, CutOutState.MAX_KNOWLEDGE - floor.cutout_state.destination_knowledge)
	if data.cutout_stability > 0 or data.cutout_knowledge > 0:
		result.preparation_reason = &"unique_insight"
	return &""


static func confirm(state: FloorState, insight_id: StringName) -> int:
	if insight_id.is_empty() or state.discovered_insight_ids.has(insight_id):
		return 0
	# 多个事件/动作可指向同一 ID；唯一确认记录是防止重复认知收益的依据。
	state.discovered_insight_ids.append(insight_id)
	var previous: int = state.cognition
	state.cognition = mini(FloorState.MAX_COGNITION, previous + 1)
	return state.cognition - previous
