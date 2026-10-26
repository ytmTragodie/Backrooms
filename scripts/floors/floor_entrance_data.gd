class_name FloorEntranceData
extends Resource
## 当前所有入口均落原图 entry；命名入口用于识别实际连接，不创建第二份地图。
@export var id: StringName = &"entry"
@export var display_name: String = "入口"
@export var requirements: Array[TravelRequirementData] = []
