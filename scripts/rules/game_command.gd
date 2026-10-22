class_name GameCommand
extends RefCounted
## UI 只描述意图及捕获的上下文，数值与费用不由 UI 决定。
enum Kind { MOVE, PLAY_CARD, END_TURN, ESCAPE, EVENT_CHOICE, REWARD, REST, SHOP, CUTOUT, FINISH }
var kind: Kind
var revision: int
var floor: FloorState
var combat: CombatState
var node_id: StringName
var choice: int = 0
var card: CardInstance
var definition: CardData
var target: EntityInstance
var reward: RewardOpportunity
func _init(type: Kind = Kind.MOVE, state: RunState = null) -> void:
	kind = type
	if state != null:
		revision = state.revision
		floor = state.floor_state
		combat = state.combat
		if not state.flow.pending_rewards.is_empty(): reward = state.flow.pending_rewards[0]
