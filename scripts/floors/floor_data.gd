class_name FloorData
extends Resource

@export var id: StringName
@export var display_name: String
@export var fresh_events: Array[EventData] = []
@export var overstay_start_turn: int = 3
@export var overstay_interval: int = 2


func find_event(event_id: StringName) -> EventData:
	for event: EventData in fresh_events:
		if event.id == event_id:
			return event
	return null


func find_insight(insight_id: StringName) -> InsightData:
	for event: EventData in fresh_events:
		for rule: EventActionData in event.action_results:
			if rule.insight != null and rule.insight.id == insight_id:
				return rule.insight
	return null
