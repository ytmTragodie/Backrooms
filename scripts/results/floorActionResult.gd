class_name FloorActionResult
extends RefCounted

# 楼层域的计划变化。commit 只写 FloorState；资源节点和 Insight 仍由各自系统提交。
var threat_delta: int = 0
var threat_reason: StringName
# 本次实际应用的目标探索量，供 total_explore 统计。
var total_explore_delta: int = 0
# 本次新完成的目标数（0/1），用于安全点里程碑。
var completed_objectives_delta: int = 0

var floor_flags_added: Array[StringName] = []
var insight_ids: Array[StringName] = []
var cognition_delta: int = 0

var resource_discovered_id: StringName
var resource_looted_id: StringName

# 黑暗首次观察附加费、临时照明开关。
var dark_observation: bool = false
var light_activated: bool = false
var light_extinguished: bool = false