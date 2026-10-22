class_name CombatState
extends RefCounted
## 单场战斗的唯一临时状态；地图中不存在 AP 或战斗牌区。
enum Phase { PLAYER, FINISHED }
enum Outcome { NONE, VICTORY, DEFEAT, ESCAPE }
var phase: Phase = Phase.PLAYER
var outcome: Outcome = Outcome.NONE
var turn_number: int = 1
var ap: int = 3
# 下一回合恢复的基础值；GAIN_AP 可以临时超过基础量。
var max_ap: int = 3
var block: int = 0
var intel: int = 0
var noise: int = 0
var light_active: bool = false
var deck: CombatDeckState = CombatDeckState.new()
var enemies: Array[EntityInstance] = []
var statuses: Array[StatusInstance] = []

func copy() -> CombatState:
	var next: CombatState = CombatState.new()
	next.phase = phase
	next.outcome = outcome
	next.turn_number = turn_number
	next.ap = ap
	next.max_ap = max_ap
	next.block = block
	next.intel = intel
	next.noise = noise
	next.light_active = light_active
	next.deck = deck.copy()
	for enemy: EntityInstance in enemies: next.enemies.append(enemy.copy())
	for status: StatusInstance in statuses: next.statuses.append(status.copy())
	return next
