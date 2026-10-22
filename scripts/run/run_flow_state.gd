class_name RunFlowState
extends RefCounted
enum Phase { MAP, COMBAT, EVENT, REST, REWARD, SHOP, CUTOUT, RESULT }
## 当前流程及真实待领奖励。不是任意领域变化的兜底桶。
var phase: Phase = Phase.MAP
var pending_rewards: Array[RewardOpportunity] = []
var active_event: EventData
var active_shop: ShopData
var result_text: String = ""
var last_destination: StringName
