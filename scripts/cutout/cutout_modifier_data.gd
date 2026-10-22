class_name CutOutModifierData
extends Resource
## 明确声明的知识/物品分布修正；无条件默认为不生效，避免隐藏万能情报点。
@export var display_name: String
@export var knowledge_id: StringName
@export var equipment_id: StringName
@export var destination_id: StringName
@export var multiplier: float = 1.0
