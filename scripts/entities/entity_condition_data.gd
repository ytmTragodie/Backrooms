class_name ConditionData
extends Resource
## 实体行为条件，只读取当前战斗；Noise 不跨节点。
enum ConditionType { HP_RATIO, TURN, NOISE, STATUS_STACK, PREV_ACTION, STATE, LIGHT_ACTIVE }
enum CompareOp { EQ, NE, GT, GTE, LT, LTE }
@export var type: ConditionType = ConditionType.TURN
@export var operator: CompareOp = CompareOp.GTE
@export var numeric_value: float = 0
@export var reference_id: StringName
