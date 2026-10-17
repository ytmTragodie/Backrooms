class_name PlayCardCommand
extends RefCounted

# 命令只标识请求使用的运行时卡牌，不携带 UI 节点，也不复制费用或状态。
var card: CardInstance


func _init(requested_card: CardInstance = null) -> void:
	card = requested_card
