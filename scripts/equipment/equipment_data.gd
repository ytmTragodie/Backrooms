class_name EquipmentData
extends Resource
## 三格物品跨战斗保留，每战斗回合至多生成一张真实行动牌。
@export var id: StringName
@export var display_name: String
@export var counter_kind: StringName = &"charges"
@export var capacity: int = 3
@export var action_card: CardData
# 有此定义的物品按 CombatState.light_active 原位选择开/关灯动作。
@export var active_action_card: CardData
