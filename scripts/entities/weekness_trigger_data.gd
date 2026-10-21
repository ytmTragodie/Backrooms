class_name TriggerData
extends Resource

# 定义几种触发类型，用于触发实体的弱点行为
# 当实体受到伤害时触发，当实体受到特定效果时触发，当回合开始时触发，当回合结束时触发
enum TriggerType {
    ON_DAMAGE_TAKEN,
    ON_EFFECT_RECEIVED,
    ON_TURN_START,
    ON_TURN_END
}

@export var trigger_type: TriggerType
# 用来识别卡牌标签（强光，噪声，钝击等），当实体受到带有特定标签的卡牌效果时触发弱点行为 
@export var efftect_tag :StringName = &""