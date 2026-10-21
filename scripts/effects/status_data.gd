class_name StatusData
extends Resource
# 定义状态数据结构，包含状态ID、名称、描述,和效果等信息

# 定义不同状态类型，如虚弱，易伤，灼烧，眩晕,流血等负面状态，以及 强化，敏捷，亢奋 等正面状态
enum StatusType {
    WEAKNESS,
    VULNERABILITY,
    BURN,
    STUN,
    BLEEDING,
    BUFF,
    AGILITY,
    FRENZY
}

enum DURATION_TYPE {
    TURN_END,
    TURN_START
}

@export var id: StringName
@export var name: String
@export var description: String
@export var type: StatusType = StatusType.WEAKNESS
@export var max_stacks: int = 100
# 定义状态的持续时间类型，TURN_END 表示在回合结束时消失，TURN_START 表示在回合开始时消失
@export var duration_type: DURATION_TYPE = DURATION_TYPE.TURN_END
# 定义一个状态的效果数据，包含状态的具体效果，如增加伤害，减少防御，造成持续伤害等
# AI 帮助实现,please continue