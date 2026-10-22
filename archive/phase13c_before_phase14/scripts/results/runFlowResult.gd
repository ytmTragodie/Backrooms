class_name RunFlowResult
extends RefCounted

# 跨领域的运行流程事实：待领取奖励、安全点、地图/结局，以及需要随动作提交的 RNG 草案。
var reward_created: Array[CardReward] = []
var reward_claimed: CardReward

var safe_point_used: SafePointState
var safe_point_discovered: bool = false

var open_map_selection: bool = false
var run_ended: bool = false

# 本次计划是否推进 RNG，以及提交后的 state；RuleResolver 只提交这一份。
var rng_state_after: int = 0
var commit_rng: bool = false