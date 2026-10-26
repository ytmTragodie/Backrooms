class_name KnowledgeState
extends RefCounted
## 长期知识集合，既不是 Intel，也没有可消费的通用点数。
var floors: Array[StringName] = []
var entities: Array[StringName] = []
var exits: Array[StringName] = []
var rules: Array[StringName] = []
var connections: Array[KnownConnection] = []

func has(id: StringName) -> bool:
	return floors.has(id) or entities.has(id) or exits.has(id) or rules.has(id)
