class_name CutOutAttemptResult
extends RefCounted

# “命令成功结算”与“穿越成功”不同，仓促失败仍是一次完整提交的合法尝试。
var attempt_type: StringName
var source_floor_id: StringName
var succeeded: bool = false
var destination_id: StringName
var roll: int = -1
