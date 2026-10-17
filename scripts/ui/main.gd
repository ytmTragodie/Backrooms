extends Control

const ACTION_NAMES: Dictionary = {
	&"inspect": "检查环境", &"search_nearby": "搜索附近", &"end_turn": "结束回合",
}
const FAILURE_MESSAGES: Dictionary = {
	&"insufficient_ap": "行动点不足", &"card_not_in_hand": "这张牌已不在手牌中",
	&"interaction_used": "本次事件中已完成此交互", &"event_resolved": "当前事件已解决",
	&"interaction_unavailable": "当前没有可进行的场景交互", &"floor_required": "尚未进入楼层",
	&"invalid_command": "操作无效", &"unknown_action": "此操作不可用",
	&"invalid_state_context": "当前状态异常", &"invalid_card_definition": "卡牌数据异常",
	&"unsupported_effect": "卡牌效果暂不可用", &"invalid_floor_context": "楼层数据不匹配",
	&"invalid_floor_state": "楼层状态异常", &"invalid_floor_definition": "楼层数据异常",
	&"invalid_event_context": "事件数据不匹配", &"invalid_event_definition": "事件数据异常",
	&"invalid_insight_definition": "认知线索数据异常",
}

@onready var _turn_manager: TurnManager = $TurnManager
@onready var _stats_label: Label = %RunStats
@onready var _end_turn_button: Button = %EndTurn
@onready var _pile_counts: Label = %PileCounts
@onready var _hand: VBoxContainer = %Hand
@onready var _status_label: Label = %Status
@onready var _floor_info: Label = %FloorInfo
@onready var _event_info: Label = %EventInfo
@onready var _insights: Label = %InsightList
@onready var _inspect_action: Button = %InspectAction
@onready var _search_action: Button = %SearchNearbyAction


func _ready() -> void:
	_turn_manager.state_changed.connect(_refresh_state)
	_turn_manager.action_resolved.connect(_on_action_resolved)
	_end_turn_button.pressed.connect(_turn_manager.end_turn)
	_inspect_action.pressed.connect(_turn_manager.request_exploration.bind(&"inspect"))
	_search_action.pressed.connect(_turn_manager.request_exploration.bind(&"search_nearby"))
	_refresh_state()
	print("[APP] Project initialized")


func _on_action_resolved(result: ActionResult) -> void:
	if result.success and result.card_played != null:
		_status_label.text = "已打出%s；消耗行动点：%d；认知：+%d；威胁：+%d。" % [result.card_played.definition.display_name, result.ap_spent, result.cognition_delta, result.threat_delta]
		if result.damage_requested > 0:
			_status_label.text += "预期伤害：%d（尚未结算）。" % result.damage_requested
	elif result.success:
		_status_label.text = "%s；消耗行动点：%d；认知：+%d；威胁：+%d。" % [ACTION_NAMES.get(result.action_id, "行动完成"), result.ap_spent, result.cognition_delta, result.threat_delta]
	else:
		_status_label.text = "行动失败：%s。" % FAILURE_MESSAGES.get(result.failure_reason, "操作未完成")


func _refresh_state() -> void:
	var state: RunState = _turn_manager.run_state
	_stats_label.text = "生命：%d\n压力：%d\n威胁：%d\n认知：%d\n回合：%d\n行动点：%d" % [
		state.player_hp,
		state.stress,
		state.threat,
		state.cognition,
		state.turn_number,
		state.ap,
	]
	var deck: DeckState = state.deck_state
	_pile_counts.text = "抽牌堆：%d｜弃牌堆：%d" % [deck.draw_pile.size(), deck.discard_pile.size()]
	for child: Node in _hand.get_children():
		_hand.remove_child(child)
		child.queue_free()
	for card: CardInstance in deck.hand:
		var play_button: Button = Button.new()
		play_button.text = "%s｜行动点：%d｜打出" % [card.definition.display_name, card.definition.ap_cost]
		# UI 只转发请求；规则验证、AP 扣除和牌区移动全部留在领域层。
		play_button.pressed.connect(_turn_manager.request_play_card.bind(card))
		_hand.add_child(play_button)
	_refresh_floor(state.floor_state)


func _refresh_floor(floor: FloorState) -> void:
	if floor == null:
		_floor_info.text = "尚未进入楼层"
		_event_info.text = ""
		_insights.text = ""
		_inspect_action.disabled = true
		_search_action.disabled = true
		return
	var data: FloorData = _turn_manager.floor_data
	_floor_info.text = "当前楼层：%s\n楼层回合：%d\n威胁：%d／%d｜认知：%d／%d\n剩余新鲜事件：%d" % [data.display_name, floor.turn_count, floor.threat, FloorState.MAX_THREAT, floor.cognition, FloorState.MAX_COGNITION, floor.remaining_fresh_events.size()]
	var event: EventData = data.find_event(floor.current_event_id)
	var instance: EventInstance = floor.current_event
	if event != null and instance != null:
		var phase_name: String = "已解决（结束回合后继续）" if instance.resolved else ("调查中" if instance.phase == &"partially_explored" else "未调查")
		_event_info.text = "当前事件：%s\n%s\n状态：%s\n已知信息：\n%s" % [event.display_name, event.display_text, phase_name, "\n".join(instance.known_information) if not instance.known_information.is_empty() else "尚无线索"]
	else:
		_event_info.text = "暂无可用新鲜事件。" if not floor.remaining_fresh_events.is_empty() else "新鲜事件已耗尽。滞留事件暂未开放。"
	# 按领域实例读取可用性；即使绕过禁用按钮发请求，解析器仍会独立验证。
	_inspect_action.disabled = instance == null or event == null or not event.has_action(&"inspect") or not instance.can_interact(&"inspect")
	_search_action.disabled = instance == null or event == null or not event.has_action(&"search_nearby") or not instance.can_interact(&"search_nearby")
	_inspect_action.text = "检查环境（1 行动点）" if instance == null or not instance.completed_interactions.has(&"inspect") else "检查环境（已完成）"
	_search_action.text = "搜索附近（1 行动点）" if instance == null or not instance.completed_interactions.has(&"search_nearby") else "搜索附近（已完成）"
	var insight_names: PackedStringArray = []
	for insight_id: StringName in floor.discovered_insight_ids:
		var insight: InsightData = data.find_insight(insight_id)
		insight_names.append(insight.display_name if insight != null else "未知认知线索")
	_insights.text = "已发现认知线索：\n%s" % ("\n".join(insight_names) if not insight_names.is_empty() else "暂无")
