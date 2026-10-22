class_name RunState
extends RefCounted
## 整局组合根，不展开任何玩家/战斗/地图业务字段。
var player: PlayerState = PlayerState.new()
var floor_state: FloorState
var history: FloorHistoryState = FloorHistoryState.new()
var flow: RunFlowState = RunFlowState.new()
var combat: CombatState
var metrics: RunMetrics = RunMetrics.new()
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var rng_seed: int
# 每次完整提交递增；陈旧 UI/重复请求原子拒绝。
var revision: int = 0
func _init(seed_value: int = 1) -> void:
	rng_seed = seed_value
	rng.seed = seed_value
