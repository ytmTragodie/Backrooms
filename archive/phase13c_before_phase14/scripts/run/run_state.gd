class_name RunState
extends RefCounted

# 整局状态聚合根。这里只持有各领域状态对象和整局元数据；
# 不保存 HP/AP/牌区/装备槽/奖励队列等具体业务字段。
# 新开一局应创建新的 RunState，领域对象随之获得独立身份。

# 玩家状态，跨楼层保留。HP/Stress/Supply/AP/Block 及其 Deck/Equipment 组合都在这里。
var player: PlayerState = PlayerState.new()
# 当前楼层驻留状态；切出时由 CutOutSystem 整体替换，不重建 RunState。
var floor_state: FloorState
# 整局流程状态：回合号、待领取奖励和最近一次切出记录。
var flow: RunFlowState = RunFlowState.new()
# 本局统计事实，只由已提交结果写入。
var metrics: RunMetrics = RunMetrics.new()
# 本局随机种子与 RNG；牌堆/奖励/切出共享这一份随机源。
var rng_seed: int = 1
var rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _init(seed_value: int = 1) -> void:
	# 每局持有独立 RNG，禁止系统调用全局随机源。
	rng_seed = seed_value
	rng.seed = rng_seed
