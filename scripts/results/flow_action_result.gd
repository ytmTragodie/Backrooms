class_name FlowActionResult
extends RefCounted
## 只记录流程机会/阶段/随机提交，不接管玩家资源或牌组。
# phase_after 为 -1 表示保留阶段；event/shop 仅在对应阶段持有定义。
var phase_after: int = -1
var event_after: EventData
var shop_after: ShopData
var rewards: Array[RewardOpportunity] = []
var claim_reward: RewardOpportunity
var result_text: String
var destination: StringName
var rng_after: int
# rng_after 是规划后精确状态，有效动作才提交；预览不产生结果。
