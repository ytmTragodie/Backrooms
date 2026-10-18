class_name PlayCardCommand
extends RefCounted

# 命令只标识请求使用的运行时卡牌，不携带 UI 节点，也不复制费用或状态。
var card: CardInstance
var target_event: EventInstance
var target_board: BoardState
var target_entity: EntityInstance
var definition: CardData


func _init(requested_card: CardInstance = null, event: EventInstance = null, board: BoardState = null, entity: EntityInstance = null) -> void:
	card = requested_card
	target_event = event
	target_board = board
	target_entity = entity
	# 保存出牌时的静态定义身份，照明替换／切出升级后的旧请求不能改变语义重放。
	definition = requested_card.definition if requested_card != null else null
