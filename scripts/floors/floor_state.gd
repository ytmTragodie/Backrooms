class_name FloorState
extends RefCounted
var definition: FloorData
var map: FloorMapState
# 成功提交的事件选项身份；地图重返不重置，未选择/失败选项不写入。
var event_outcomes: Array[StringName] = []
var floor_id: StringName:
	get: return definition.id
