class_name EventActionResult
extends RefCounted

# 本次动作造成的 EventInstance 变化；只由 EventSystem.commit 提交。
var changes: Array[EventChange] = []
# 事件机会产生的卡牌奖励定义，由 CardRewardSystem 统一转成待领取机会。
var reward_definitions: Array[CardRewardData] = []