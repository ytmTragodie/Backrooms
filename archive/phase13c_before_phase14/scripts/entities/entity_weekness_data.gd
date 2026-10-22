class_name EntityWeeknessData
extends Resource

@export var weekness_id: StringName
# 弱点效果的触发条件，包含触发类型和触发标签
@export var trigger : TriggerData
# 弱点的额外判定条件，虽然满足了触发标签，但是还需要满足额外的判定条件才能触发弱点行为
@export var condition : ConditionData

# 弱点行为触发效果
@export var effects : Array[EffectData]