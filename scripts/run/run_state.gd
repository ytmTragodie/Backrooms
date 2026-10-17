class_name RunState
extends RefCounted

const AP_PER_TURN: int = 3

var player_hp: int = 30
var stress: int = 0
var floor_state: FloorState
# 兼容旧调试读取；这里只转发楼层值，不再保存第二份 Threat / Cognition。
var threat: int:
	get:
		return floor_state.threat if floor_state != null else 0
var cognition: int:
	get:
		return floor_state.cognition if floor_state != null else 0
var turn_number: int = 1
# AP 的唯一权威值：TurnManager 在新回合恢复，RuleResolver 在合法出牌时扣除。
var ap: int = AP_PER_TURN
var deck_state: DeckState = DeckState.new()
var rng_seed: int = 1
var rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _init(seed_value: int = 1) -> void:
	# 每局持有独立 RNG，牌堆系统不得调用全局随机源。
	rng_seed = seed_value
	rng.seed = rng_seed
