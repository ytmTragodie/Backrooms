class_name EffectData
extends Resource
## 有限效果目录，卡牌/意图/弱点共用。没有脚本表达式解释器。
enum EffectType { DAMAGE, BLOCK, HEAL, DRAW, GAIN_AP, GAIN_INTEL, APPLY_STATUS, CHANGE_STRESS, CHANGE_NOISE, LIGHT, WITHDRAW }
enum TargetType { SELF, PLAYER, ENEMY }
@export var effect_type: EffectType = EffectType.DAMAGE
@export var target: TargetType = TargetType.SELF
@export var amount: int = 0
@export var status: StatusData
# 持续若干完整战斗回合；0 使用 StatusData.default_duration。
@export var duration: int = 0
@export var tags: Array[StringName] = []
