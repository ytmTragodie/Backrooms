extends Control

const FAILURE_MESSAGES: Dictionary = {
	&"insufficient_ap": "行动点不足", &"event_resolved": "该局势已解决，请结束回合",
	&"invalid_event_target": "局势目标已经变化，请重新选择", &"card_not_in_hand": "这张牌已不在手牌中",
	&"run_ended": "生命耗尽，本局结束", &"card_required": "调查必须通过手牌执行",
	&"invalid_card_definition": "卡牌数据异常", &"invalid_event_definition": "局势数据异常",
	&"invalid_event_state": "局势状态异常", &"invalid_insight_definition": "认知数据异常",
	&"invalid_floor_context": "楼层数据不匹配", &"invalid_event_context": "牌桌状态异常",
	&"unsupported_effect": "本轮探索不支持该牌效果", &"invalid_command": "操作无效",
}
const TAG_NAMES: Dictionary = {&"OBSERVE": "观察", &"SEARCH": "搜索", &"NOISE": "噪音"}

@onready var _manager: TurnManager = $TurnManager
@onready var _stats: Label = %RunStats
@onready var _status: Label = %Status
@onready var _hand: HBoxContainer = %Hand
@onready var _counts: Label = %PileCounts
@onready var _end_turn: Button = %EndTurn
@onready var _world_card: Button = %WorldCard
@onready var _name: Label = %SituationName
@onready var _description: Label = %Description
@onready var _objective: Label = %Objective
@onready var _pressure: Label = %Pressure
@onready var _rule: Label = %SituationRule
@onready var _clues: Label = %Clues
@onready var _state: Label = %SituationState


func _ready() -> void:
	_manager.state_changed.connect(_refresh_state)
	_manager.action_resolved.connect(_show_result)
	_end_turn.pressed.connect(_manager.end_turn)
	_world_card.pressed.connect(_select_world_card)
	_refresh_state()
	print("[APP] Project initialized")


func _select_world_card() -> void:
	# 选择只是表现层操作；不发玩法命令，不推进调查，也不揭示新线索。
	_status.text = "已选择当前局势。请打出手牌推进调查；查看牌面不消耗行动点。"


func _refresh_state() -> void:
	var run: RunState = _manager.run_state
	var floor: FloorState = run.floor_state
	var board: BoardState = floor.board_state
	var event: EventInstance = board.active_event
	var data: EventData = _manager.floor_data.find_event(event.event_id) if event != null else null
	_stats.text = "生命：%d　｜　压力：%d　｜　威胁：%d　｜　认知：%d　｜　行动点：%d　｜　回合：%d" % [run.player_hp, run.stress, run.threat, run.cognition, run.ap, run.turn_number]
	_counts.text = "抽牌堆：%d｜弃牌堆：%d" % [run.deck_state.draw_pile.size(), run.deck_state.discard_pile.size()]
	_end_turn.disabled = run.player_hp <= 0
	_world_card.disabled = event == null
	if event == null:
		_name.text = "零层：本轮局势已调查完毕" if floor.remaining_fresh_events.is_empty() else "零层：暂无符合条件的局势"
		_description.text = "新鲜局势在本次访问中不会重复出现。"
		_objective.text = "调查目标：当前没有活动局势"
		_pressure.text = "局势后果：无；楼层滞留规则仍会继续结算。"
		_rule.text = ""
		_clues.text = "已确认认知：%d。" % floor.cognition
		_state.text = "本次调查已结束，可重新开始新局。" if floor.remaining_fresh_events.is_empty() else "当前没有符合条件的调查目标。"
	else:
		_name.text = "局势牌　｜　%s" % data.display_name
		_description.text = data.display_text
		_objective.text = "目标：%s　｜　调查进度：%d／%d" % [data.objective_text, event.explore_progress, data.explore_threshold]
		_rule.text = "规则：%s牌对本局势额外增加 %d 调查。" % [TAG_NAMES.get(data.bonus_tag, "相应标签"), data.explore_bonus] if data.explore_bonus > 0 else "规则：按玩家牌的基础调查值推进。"
		if event.resolved:
			_pressure.text = "局势后果：已解决，不再施加压力。"
		else:
			_pressure.text = "回合末后果：若本回合未推进，压力 +%d。
当前：%s" % [data.neglect_stress, "本回合已推进，免于该压力" if event.last_progress_turn == floor.turn_count else "尚未推进本局势"]
		_clues.text = "已揭示线索：%s" % ("；".join(event.known_information) if not event.known_information.is_empty() else "尚无（调查达到 %d 时揭示）" % data.clue_threshold)
		_state.text = "已解决：结束回合后补入下一张符合条件的局势。" if event.resolved else "调查中：未完成的进度会保留至下一回合。"
	for child: Node in _hand.get_children():
		_hand.remove_child(child)
		child.queue_free()
	for card: CardInstance in run.deck_state.hand:
		var definition: CardData = card.definition
		var final_cost: int = RuleResolver.card_ap_cost(definition, run, _manager.floor_data)
		var button: Button = Button.new()
		button.custom_minimum_size = Vector2(0, 116)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var bonus: int = EventSystem.explore_bonus(definition, data) if data != null else 0
		var tags: PackedStringArray = []
		for tag: StringName in definition.tags:
			tags.append(TAG_NAMES.get(tag, "其他"))
		button.text = "%s
行动点：%d
调查 +%d%s
%s
%s" % [definition.display_name, final_cost, definition.explore_amount, "（当前 +%d）" % (definition.explore_amount + bonus) if bonus > 0 else "", "威胁 +%d" % definition.threat_cost if definition.threat_cost > 0 else "低风险调查", "、".join(tags)]
		button.disabled = run.player_hp <= 0 or event == null or event.resolved or run.ap < final_cost
		# 绑定刷新时的真实实例。旧按钮即便被重放，也必须由解析器拒绝过期目标。
		button.pressed.connect(_manager.request_play_card.bind(card, event, board))
		_hand.add_child(button)


func _show_result(result: ActionResult) -> void:
	if not result.success:
		_status.text = "行动失败：%s。" % FAILURE_MESSAGES.get(result.failure_reason, "操作未完成")
		return
	if result.card_played != null:
		_status.text = "已打出%s；消耗行动点：%d；调查：+%d；威胁：+%d。" % [result.card_played.definition.display_name, result.ap_spent, result.explore_applied, result.threat_delta]
		if result.clue_revealed:
			_status.text += "已揭示线索。"
		if result.event_resolved:
			_status.text += "局势已解决，认知：+%d。" % result.cognition_delta
	else:
		_status.text = "回合已推进；局势压力：+%d；滞留威胁：+%d。" % [result.pressure_stress, result.threat_delta]
