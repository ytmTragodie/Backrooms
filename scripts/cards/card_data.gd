class_name CardData
extends Resource

# 保留旧战斗效果枚举以兼容 Phase 1–8；REWORK A 的 Explore 由下方数值字段规划，
# 在解析结果中是实际的 explore 效果，不会作为成功 no-op 提交。
enum EffectType { NO_OP, PLACEHOLDER_DAMAGE, ATTACK, BLOCK, RUN, LIGHT, EXTINGUISH, CUTOUT_RUSHED, CUTOUT_SAFE, RECOVER }
enum Source { NORMAL, EQUIPMENT, FLOOR_TEMPORARY }

# 多张运行时卡牌共享这份定义；可变的局内状态不能写入 Resource。
@export var id: StringName
@export var display_name: String
@export_range(0, 3, 1, "or_greater") var ap_cost: int = 0
@export var effect_type: EffectType = EffectType.NO_OP
@export var exploration_action: StringName
# 当前仅作为请求伤害写入 ActionResult，不应用到真实目标。
@export var placeholder_damage: int = 0
@export var effect_value: int = 0
# Explore 是可复用玩法输出；exploration_action 只供尚未迁移的旧楼层使用。
@export var explore_amount: int = 0
@export var threat_cost: int = 0
@export var tags: Array[StringName] = []
@export var collects_resources: bool = false
@export var search_hidden_first: bool = false
@export var analyzes_entities: bool = false
# 来源决定牌区生命周期；具体电量／准备值仍只保存在原领域实例中。
@export var source: Source = Source.NORMAL
@export var retain: bool = false
