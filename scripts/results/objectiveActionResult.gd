class_name ObjectiveActionResult
extends RefCounted

# 目标实例与本次交互事实。规划阶段只写这里，commit 才写 ObjectiveInstance。
var id: StringName
var target: ObjectiveInstance
# 本次命中的步骤标签（PROGRESS 为 explore，CONDITION/SEQUENCE 为卡片标签）。
var interaction: StringName

# PROGRESS：本次进度计算。
var progress_base: int = 0
var progress_bonus: int = 0
var progress_applied: int = 0
var progress_after: int = -1

# CONDITION：本次新完成的步骤，不包含实例中已完成的步骤。
var completed_conditions: Array[StringName] = []

# SEQUENCE：提交后的序列索引；-1 表示本次不改变序列。
var sequence_after: int = -1

# 线索文本与一次性揭示。
var information: Array[String] = []
var clue_revealed: bool = false

# 本次由未完成变为完成；CardRewardSystem 只据此发一次机会。
var resolved: bool = false
var newly_resolved: bool = false

# 回合末是否已对本次访问的目标做过压力检查。
var pressure_checked: bool = false