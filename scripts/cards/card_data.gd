class_name CardData
extends Resource

# 保留旧战斗效果枚举以兼容 Phase 1–8；REWORK A 的 Explore 由下方数值字段规划，
# 在解析结果中是实际的 explore 效果，不会作为成功 no-op 提交。
enum EffectType { NO_OP, PLACEHOLDER_DAMAGE, ATTACK, BLOCK, RUN, LIGHT, EXTINGUISH, CUTOUT_RUSHED, CUTOUT_SAFE, RECOVER }
enum Source { NORMAL, EQUIPMENT, FLOOR_TEMPORARY }
enum TargetKind { NONE = 0, OBJECTIVE = 1, ENTITY = 2 }
enum BonusCondition { NONE, GUARDED, HIGH_THREAT, ANALYZED_TARGET }

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
# 目标类别与生命周期是领域合同；UI 只查询同一校验，不替玩家换目标。
@export_flags("Situation", "Entity") var target_kinds: int = 0
@export var requires_active_target: bool = true
@export var target_entity_states: Array[StringName] = []
@export var bonus_condition: BonusCondition = BonusCondition.NONE
@export var conditional_bonus: int = 0
@export var condition_threshold: int = 4
@export var upgrade_to: CardData


func contextual_bonus(block: int, threat: int, analyzed: bool = false) -> int:
	match bonus_condition:
		BonusCondition.GUARDED:
			return conditional_bonus if block > 0 else 0
		BonusCondition.HIGH_THREAT:
			return conditional_bonus if threat >= condition_threshold else 0
		BonusCondition.ANALYZED_TARGET:
			return conditional_bonus if analyzed else 0
	return 0


func is_deckbuilding_definition_valid() -> bool:
	# 奖励／升级只能引入有真实基线的普通牌；旧无楼层测试占位牌不进入构筑池。
	if source != Source.NORMAL or id.is_empty() or display_name.is_empty() or ap_cost < 0 or explore_amount < 0 or threat_cost < 0 or conditional_bonus < 0 or condition_threshold < 0:
		return false
	if bonus_condition not in [BonusCondition.NONE, BonusCondition.GUARDED, BonusCondition.HIGH_THREAT, BonusCondition.ANALYZED_TARGET]:
		return false
	if not requires_active_target or target_kinds < 0 or target_kinds > 3:
		return false
	match effect_type:
		EffectType.NO_OP:
			return explore_amount > 0 and effect_value == 0 and placeholder_damage == 0 and target_kinds != 0 and ((target_kinds & TargetKind.ENTITY) == 0 or analyzes_entities)
		EffectType.ATTACK:
			return effect_value > 0 and explore_amount == 0 and target_kinds == TargetKind.ENTITY
		EffectType.BLOCK:
			return effect_value > 0 and explore_amount == 0 and target_kinds == TargetKind.NONE
		EffectType.RUN:
			return effect_value == 0 and explore_amount == 0 and target_kinds == TargetKind.ENTITY
	return false
