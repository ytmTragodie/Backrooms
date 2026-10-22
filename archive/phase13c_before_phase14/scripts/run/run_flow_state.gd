class_name RunFlowState
extends RefCounted

# 整局流程状态：只保存跨动作的流程性事实，不充当玩家/楼层的万能容器。
# 生命周期为整个 Run；重新开局时由新的 RunState 创建新实例。

# 待领取奖励按 FIFO 排队；只有 CardRewardSystem 可以创建、领取和弹出。
var pending_rewards: Array[CardReward] = []

# 当前整局回合号。牌组/装备生成调度和回合生命周期读取它，
# 但状态本身不等于某个楼层的 turn_count（后者是本次驻留计数）。
var turn_number: int = 1

# 最近一次切出尝试的整局记录；跨楼层保留，供调试/统计读取。
# 它只记录结果，不参与下一层的结算。
var last_cutout_attempt: CutOutAttemptResult