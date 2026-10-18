class_name BoardState
extends RefCounted

# 活动世界实例只有这一份所有权；牌区和 UI 都不复制调查进度或实体生命。
var active_event: EventInstance
# 仅兼容现有单实体结算，不在 REWORK A 扩展多实体玩法。
var entity: EntityInstance
