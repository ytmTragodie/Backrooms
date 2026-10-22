class_name CutOutActionResult
extends RefCounted

# 切出尝试结果；失败时保留当前楼层。
var attempt: CutOutAttemptResult
# 本次线索/洞察带来的切出准备增量。
var stability_delta: int = 0
var knowledge_delta: int = 0
var preparation_reason: StringName

# 成功时的新楼层定义与已初始化的新楼层状态。
var destination: FloorData
var next_floor: FloorState