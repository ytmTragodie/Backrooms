class_name EquipmentState
extends RefCounted

# 装备槽与装备牌生成调度的唯一权威状态。跨楼层保留，不随 FloorState 重建。
# 槽位中保存的是 EquipmentInstance 引用；耐久/电量/次数只存在于实例，
# 这里绝不复制这些数值。
const SLOT_COUNT: int = 3

# 固定三个槽位，null 表示空槽。数组长度始终为 SLOT_COUNT。
var slots: Array[EquipmentInstance] = []
# 上一次生成装备行动牌的整局回合号；-1 表示本局尚未生成过。
# 同一回合最多生成一张装备牌，避免每个刷新入口重复消耗机会。
var generation_turn: int = -1
# 下一次生成从哪个槽位开始轮转；保证有多个可用装备时不会总取第一格。
var next_slot: int = 0


func _init(slot_count: int = SLOT_COUNT) -> void:
	slots.resize(slot_count)