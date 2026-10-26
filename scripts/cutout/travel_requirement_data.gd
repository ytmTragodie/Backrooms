class_name TravelRequirementData
extends Resource
## 候选目的地/入口的筛选条件；出口本身必须始终保留无条件候选。
enum Kind { KNOWLEDGE, EQUIPMENT, EVENT_OUTCOME }
@export var kind: Kind = Kind.KNOWLEDGE
@export var id: StringName
@export var source_floor: StringName
@export var description: String

func satisfied(state: RunState) -> bool:
	match kind:
		Kind.KNOWLEDGE: return state.player.knowledge.has(id)
		Kind.EQUIPMENT:
			for item: EquipmentInstance in state.player.equipment.slots:
				if item != null and item.definition.id == id and item.remaining_uses > 0: return true
		Kind.EVENT_OUTCOME:
			var floor: FloorState = state.history.floors.get(source_floor, state.floor_state if source_floor.is_empty() else null)
			return floor != null and floor.event_outcomes.has(id)
	return false

static func all_satisfied(requirements: Array[TravelRequirementData], state: RunState) -> bool:
	for requirement: TravelRequirementData in requirements:
		if not requirement.satisfied(state): return false
	return true
