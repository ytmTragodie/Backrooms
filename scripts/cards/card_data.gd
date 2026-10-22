class_name CardData
extends Resource
## 玩家卡的共享定义；不持有战斗牌区或运行消耗。
enum Source { NORMAL, EQUIPMENT }
enum TargetKind { NONE, ENTITY }
enum CardRarity { COMMON, UNCOMMON, RARE }
@export var id: StringName
@export var display_name: String
@export_multiline var description: String
@export var ap_cost: int = 1
@export var intel_cost: int = 0
@export var source: Source = Source.NORMAL
@export var target_kind: TargetKind = TargetKind.NONE
@export var rarity: CardRarity = CardRarity.COMMON
@export var effects: Array[EffectData] = []
@export var tags: Array[StringName] = []
@export var retain: bool = false
@export var exhaust: bool = false
# 装备牌成功结算才扣除；熄灯为零，仍要求真实物品存在。
@export var equipment_cost: int = 1
@export var upgrade_to: CardData

func is_valid() -> bool:
	return not id.is_empty() and not display_name.is_empty() and ap_cost >= 0 and intel_cost >= 0 and not effects.is_empty() and equipment_cost >= 0 and source in [Source.NORMAL,Source.EQUIPMENT] and target_kind in [TargetKind.NONE,TargetKind.ENTITY]
