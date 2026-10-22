class_name EventData
extends Resource
## 叙事节点内容，已取代旧 DEBUFF/OMEN 临时世界牌模型。
enum Relation { NONE, NEUTRAL, FRIENDLY, HOSTILE }
@export var id: StringName
@export var display_name: String
@export_multiline var description: String
@export var asset_id: StringName
# 叙事身份不等于敌对能力定义；同种实体可在事件中保持中立。
@export var actor_name: String
@export var relation: Relation = Relation.NONE
@export var options: Array[EventOptionData] = []
