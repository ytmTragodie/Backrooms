class_name CardData
extends Resource

enum EffectType { NO_OP, PLACEHOLDER_DAMAGE }

# 多张运行时卡牌共享这份定义；可变的局内状态不能写入 Resource。
@export var id: StringName
@export var display_name: String
@export_range(0, 3, 1, "or_greater") var ap_cost: int = 0
@export var effect_type: EffectType = EffectType.NO_OP
# 当前仅作为请求伤害写入 ActionResult，不应用到真实目标。
@export var placeholder_damage: int = 0
