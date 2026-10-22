class_name FloorHistoryState
extends RefCounted
## 保存实际 FloorState 引用；重返不会创建空白地图或重置一次性奖励。
var floors: Dictionary[StringName, FloorState] = {}
var visits: Dictionary[StringName, int] = {}
