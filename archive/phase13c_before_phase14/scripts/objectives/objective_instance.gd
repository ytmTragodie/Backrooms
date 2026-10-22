class_name ObjectiveInstance
extends RefCounted

# 每次激活目标都创建独立实例；共享 ObjectiveData 不保存调查进度。
var objective_id: StringName

var known_information: Array[String] = []
var resolved: bool = false

var clue_revealed: bool = false
var last_progress_turn: int = 0 # 持续的回合数
var pressure_checked_turn: int = 0
var activated_turn: int = 1

# 目标序列索引，for Sequence
var sequence_index: int = 0
# 探索进度，for Progress
var explore_progress: int = 0
# 已完成的交互动作列表，避免重复触发。
var completed_interactions: Array[StringName] = []

var phase: StringName:
	get:
		if resolved:
			return &"resolved"
		return &"unresolved" if explore_progress == 0 and completed_interactions.is_empty() and known_information.is_empty() else &"partially_explored"


func _init(id: StringName) -> void:
	objective_id = id


func can_interact(action: StringName) -> bool:
	return not resolved and not completed_interactions.has(action)
