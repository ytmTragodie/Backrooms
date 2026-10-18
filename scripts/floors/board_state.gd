class_name BoardState
extends RefCounted

# 活动世界实例只有这一份所有权；牌区和 UI 都不复制调查进度或实体生命。
var active_objective: ObjectiveInstance
const EVENT_CAPACITY: int = 2
var active_events: Array[EventInstance] = []
# 继续复用单实体状态机；前兆等到此槽空闲，不扩展多实体战斗。
var entity: EntityInstance
