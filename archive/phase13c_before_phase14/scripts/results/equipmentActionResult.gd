class_name EquipmentActionResult
extends RefCounted

# 本次使用的装备实例及其槽位。
var used_equipment: EquipmentInstance
var slot: int = -1
# 已消耗的使用次数；commit 时从 remaining_uses 扣除。
var uses_spent: int = 0

# 资源搜索补给的装备与次数；由 EquipmentSystem.commit 写入。
var resource_equipment: EquipmentInstance
var resource_uses_gained: int = 0