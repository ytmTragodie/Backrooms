class_name InsightSystem
extends RefCounted


static func confirm(state: FloorState, insight_id: StringName) -> int:
	if insight_id.is_empty() or state.discovered_insight_ids.has(insight_id):
		return 0
	# 多个事件/动作可指向同一 ID；唯一确认记录是防止重复认知收益的依据。
	state.discovered_insight_ids.append(insight_id)
	var previous: int = state.cognition
	state.cognition = mini(FloorState.MAX_COGNITION, previous + 1)
	return state.cognition - previous
