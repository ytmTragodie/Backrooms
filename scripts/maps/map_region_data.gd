class_name MapRegionData
extends Resource
## 楼层内主题分区；内容 ID 必须属于 FloorData 的正式池，不另存内容定义。
@export var id: StringName
@export var display_name: String
@export var first_layer: int = 1
@export var last_layer: int = 99
@export var node_weights: PackedInt32Array = PackedInt32Array([35,8,30,12,10,5])
@export var event_ids: Array[StringName] = []
@export var encounter_ids: Array[StringName] = []
@export var elite_ids: Array[StringName] = []
