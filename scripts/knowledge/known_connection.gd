class_name KnownConnection
extends RefCounted
## 只记录已公开的联系身份与实际穿越事实，概率实时从出口配置推导。
var source_floor: StringName
var route_id: StringName
var destination_id: StringName
var traversed: bool = false

func key() -> String:
	return "%s/%s/%s" % [source_floor,route_id,destination_id]
