class_name PlayerActionResult
extends RefCounted
## 单动作净差量，PlayerSystem 是唯一提交者；不包含战斗 AP/Block。
var hp_delta: int = 0
var stress_delta: int = 0
var supply_delta: int = 0
# 本次新增稳定 ID，提交时按所属集合去重，不能累加成通用知识点。
var knowledge_rules: Array[StringName] = []
var knowledge_entities: Array[StringName] = []
var knowledge_floors: Array[StringName] = []
var knowledge_exits: Array[StringName] = []
var connections: Array[KnownConnection] = []
