class_name ConditionData
extends Resource





# 定义几种条件类型，用于触发特定的行为
# 例如：当实体的HP低于某个阈值时，触发逃跑行为；当AP高于某个阈值时，触发攻击行为等, 楼层危险度高于某个值时，回合数,玩家位于特殊状态时，NOISE 达到阈值时，前回合行为符合条件时，冷却已经结束时
enum ConditionType { HP_RATIO,  THREAT_ABOVE, TURNS, STATUS_STACK, NOISE, PREV_ACTION, COOLDOWN_END }
# 比较方式
enum CompareOp {
    EQ,
    NE,
    GT,
    GTE,
    LT,
    LTE
}
@export  var type : ConditionType = ConditionType.HP_RATIO
@export var operator : CompareOp = CompareOp.GTE
# 数值型条件：HP比例、威胁、回合数、Noise、状态层数
@export var numeric_value: float = 0.0

# 引用型条件：状态ID、上一回合行为ID
@export var reference_id: StringName = &""


