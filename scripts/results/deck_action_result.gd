class_name DeckActionResult
extends RefCounted
## 永久牌组修改计划；目标必须是玩家实际持有实例。
var add: Array[CardData] = []
var remove: CardInstance
var upgrade: CardInstance
# 升级只替换实例的 definition，不修改共享 CardData。
