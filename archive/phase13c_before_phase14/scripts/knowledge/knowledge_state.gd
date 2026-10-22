class_name KnowledgeState
extends RefCounted

# 知识状态聚合根。这里只持有各领域状态对象和知识元数据；不保存 HP/AP/牌区/装备槽/奖励队列等具体业务字段。
# 知识状态跨楼层保留，只有新开一局才整体替换。知识状态的身份在整局中保持不变，领域对象随之获得独立身份。
# 已知楼层
var known_floors : Dictionary[StringName, FloorData] = {}
# 已知实体
var known_entities : Dictionary[StringName, EntityData] = {}
# 已知出口
# var known_exits : Dictionary[StringName, ExitData] = {}
# 已知特殊规则（暂不实现）

