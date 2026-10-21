class_name CardActionResult
extends RefCounted

# 本次实际打出的牌及其静态定义；卡牌实例的牌区移动仍由 CardSystem 提交。
var card_played: CardInstance
var card_definition: CardData
# 本次动作消耗的行动点，权威 AP 只存于 RunState。
var ap_spent: int = 0
# 卡牌的主语义（explore/attack/block/run/装备牌 id 等），用于日志和结果展示。
var effect: StringName
# 仅记录本牌请求的伤害；实际扣血在 EntityActionResult/PlayerActionResult。
var damage_requested: int = 0