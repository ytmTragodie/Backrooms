class_name StatusData
extends Resource
## 状态的数值规则。首版只用平坦修正/回合末伤害/跳过意图。
@export var id: StringName
@export var display_name: String
@export_multiline var description: String
# 层数上限与持续完整战斗回合；实例可用 EffectData.duration 覆盖默认时长。
@export var max_stacks: int = 10
@export var default_duration: int = 2
# 以下是每层的平坦点数修正，不是百分比，也不跨战斗保存。
@export var outgoing_damage_bonus: int = 0
@export var incoming_damage_bonus: int = 0
@export var block_bonus: int = 0
# 回合末每层直接生命损失（不耗防护）；skip_intent 在本回合意图阶段读取。
@export var turn_end_damage: int = 0
@export var skip_intent: bool = false
