class_name PlayerActionResult
extends RefCounted

# 玩家域的净变化。提交只读取 hp_delta/stress_delta/supply_delta/block_delta；
# 其余字段是计划分解，供日志、UI 与测试说明伤害来源，不是第二份可写状态。
var hp_delta: int = 0
var stress_delta: int = 0
var supply_delta: int = 0
var block_delta: int = 0

# 实体/意图造成的实际生命损失与被格挡量。
var damage_taken: int = 0
var damage_blocked: int = 0
# 环境压力造成的实际生命损失与被格挡量；stress 分量见 pressure_stress。
var pressure_stress: int = 0
var pressure_damage: int = 0
var pressure_blocked: int = 0

# 回合末清空临时防护；提交时先应用 block_delta，再按此标记归零。
var expire_block: bool = false