class_name EquipmentActionResult
extends RefCounted
## 单动作物品计划；失败时次数/轮转/替换均不落地。
var item: EquipmentInstance
var uses_delta: int = 0
var next_slot: int = -1
# -1 表示不调整槽位；replacement 非空时 slot 必须已验证。
var replacement: EquipmentData
var slot: int = -1
var refill: bool = false
