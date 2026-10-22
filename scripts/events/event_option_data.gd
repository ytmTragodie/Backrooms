class_name EventOptionData
extends Resource
## 节点文本选项，可交换资源/知识/卡/装备，也可接入一次战斗或后续分支。
@export var id: StringName
@export var display_name: String
@export var supply_cost: int = 0
@export var hp_cost: int = 0
@export var stress_cost: int = 0
@export var required_knowledge: StringName
@export var rewards: RewardTableData
@export var knowledge: Array[StringName] = []
# 分类解锁，不把地点身份、实体身份和特殊规律混成可消费点数。
@export var known_floors: Array[StringName] = []
@export var known_entities: Array[StringName] = []
@export var known_exits: Array[StringName] = []
@export var reveal_nodes: int = 0
@export var encounter: EntityData
@export var next_event: EventData
