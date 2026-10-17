class_name EventData
extends Resource

@export var id: StringName
@export var display_name: String
@export_multiline var display_text: String
@export var required_flags: Array[StringName] = []
@export var blocked_flags: Array[StringName] = []
@export var once_per_instance: bool = true
@export_range(1, 100, 1, "or_greater") var weight: int = 1
@export var action_results: Array[EventActionData] = []


func has_action(action: StringName) -> bool:
	for rule: EventActionData in action_results:
		if rule != null and rule.action_id == action:
			return true
	return false
