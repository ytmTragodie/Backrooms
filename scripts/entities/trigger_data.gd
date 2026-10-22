class_name TriggerData
extends Resource
enum TriggerType { ON_DAMAGE_TAKEN, ON_EFFECT_RECEIVED, ON_TURN_START, ON_TURN_END }
@export var trigger_type: TriggerType = TriggerType.ON_EFFECT_RECEIVED
# 匹配真正执行的 EffectData.tags，不匹配卡名或未结算的卡牌标签。
@export var effect_tag: StringName
