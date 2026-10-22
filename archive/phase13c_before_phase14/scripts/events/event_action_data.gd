class_name EventActionData
extends Resource

# 基础交互与卡牌可共用数据条件，但只由解析器提交实例进度。
@export var action_id: StringName
@export var required_flags: Array[StringName] = []
@export var granted_flags: Array[StringName] = []
@export var insight: InsightData
@export_multiline var revealed_text: String
@export var resolves_event: bool = false
@export var requires_light: bool = false
