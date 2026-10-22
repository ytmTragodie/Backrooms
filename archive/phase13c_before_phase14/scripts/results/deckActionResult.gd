class_name DeckActionResult
extends RefCounted

# 奖励/整备对牌组的影响。删除和升级直接引用原实例；新增牌在 commit 时才创建实例。
var card_added: CardInstance
var card_removed: CardInstance
var card_upgraded: CardInstance
var added_definition: CardData
# 提交后的统一事实，供指标和 UI 读取。
var card_changed: CardInstance
var change_kind: StringName