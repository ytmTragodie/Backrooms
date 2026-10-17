class_name RunState
extends RefCounted

const AP_PER_TURN: int = 3

var player_hp: int = 30
var stress: int = 0
# Phase 1 的临时占位值；引入楼层后由 FloorState 持有。
var threat: int = 0
var cognition: int = 0
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
