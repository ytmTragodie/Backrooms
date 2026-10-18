extends Control

const FAILURE_MESSAGES: Dictionary = {
	&"insufficient_ap": "行动点不足", &"event_resolved": "该局势已解决，请结束回合",
	&"invalid_event_target": "局势目标已经变化，请重新选择", &"card_not_in_hand": "这张牌已不在手牌中",
	&"run_ended": "生命耗尽，本局结束", &"card_required": "调查必须通过手牌执行",
	&"invalid_card_definition": "卡牌数据异常", &"invalid_event_definition": "局势数据异常",
	&"invalid_event_state": "局势状态异常", &"invalid_insight_definition": "认知数据异常",
	&"invalid_floor_context": "楼层数据不匹配", &"invalid_event_context": "牌桌状态异常",
	&"unsupported_effect": "本轮探索不支持该牌效果", &"invalid_command": "操作无效",
	&"invalid_entity_target": "实体目标已经变化，请重新选择", &"invalid_target_kind": "这张牌不能作用于所选目标",
	&"no_active_entity": "该实体已不再活跃", &"analysis_complete": "该实体的规律已调查清楚",
	&"analysis_unavailable": "该实体暂无可调查规律", &"guard_unneeded": "当前没有需要防护的危险",
}
const TAG_NAMES: Dictionary = {&"OBSERVE": "观察", &"SEARCH": "搜索", &"NOISE": "噪音"}
const ENTITY_STATES: Dictionary = {&"WATCHING": "窥视", &"APPROACHING": "靠近", &"CHASING": "追逐", &"STAGGERED": "踉跄", &"DEFEATED": "击败", &"DISENGAGED": "已脱离"}
const ENTITY_INTENTS: Dictionary = {&"approach": "继续靠近（无伤害）", &"bite": "撕咬", &"lunge": "扑击", &"recover": "恢复警戒（无伤害）", &"none": "无"}
const MIXED_FLOOR: FloorData = preload("res://data/floors/floor_level_6.tres")
const MIXED_DECK: DeckData = preload("res://data/cards/mixed_deck.tres")
const EXPLORE_FLOOR: FloorData = preload("res://data/floors/floor_level_0.tres")
const EXPLORE_DECK: DeckData = preload("res://data/cards/exploration_deck.tres")

# 仅保存临时选择引用，不保存第二份 HP、调查、意图或费用。
var _selected_event: EventInstance
var _selected_entity: EntityInstance
var _selected_board: BoardState

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
@onready var _entity_card: Button = %EntityCard
@onready var _entity_information: Label = %EntityInformation


func _ready() -> void:
	_connect_manager()
	_world_card.pressed.connect(_select_world_card)
	_entity_card.pressed.connect(_select_entity)
	(%NewLevel0 as Button).pressed.connect(_start_run.bind(EXPLORE_FLOOR, EXPLORE_DECK))
	(%NewLevel6 as Button).pressed.connect(_start_run.bind(MIXED_FLOOR, MIXED_DECK))
	_refresh_state()
	print("[APP] Project initialized")


func _connect_manager() -> void:
	_manager.state_changed.connect(_refresh_state)
	_manager.action_resolved.connect(_show_result)
	_end_turn.pressed.connect(_manager.end_turn)


func _start_run(floor: FloorData, deck: DeckData) -> void:
	# 新局是系统控制：创建全新生命周期，而非进战斗时替换当前局的 AP／手牌。
	var equipment: Array[EquipmentData] = _manager.starting_equipment.duplicate()
	_manager.free()
	_manager = TurnManager.new()
	_manager.name = "TurnManager"
	_manager.floor_data = floor
	_manager.starter_deck = deck
	_manager.starting_equipment = equipment
	_selected_board = null
	_selected_event = null
	_selected_entity = null
	_connect_manager()
	add_child(_manager)
	_status.text = "新局：%s。先选择世界牌，再打出手牌；防御直接保护玩家。" % floor.display_name


func _select_world_card() -> void:
	# 选择只是表现层操作；不发玩法命令，不推进调查，也不揭示新线索。
	_selected_board = _manager.run_state.floor_state.board_state
	_selected_event = _selected_board.active_event
	_selected_entity = null
	_refresh_state()
	_status.text = "已选择当前局势。请打出手牌推进调查；查看牌面不消耗行动点。"


func _select_entity() -> void:
	_selected_board = _manager.run_state.floor_state.board_state
	_selected_event = null
	_selected_entity = _selected_board.entity
	_refresh_state()
	_status.text = "已选择实体。调查可揭示规律；攻击造成伤害；防御直接保护玩家。"


func _refresh_state() -> void:
	var run: RunState = _manager.run_state
	var floor: FloorState = run.floor_state
	var board: BoardState = floor.board_state
	var event: EventInstance = board.active_event
	var data: EventData = _manager.floor_data.find_event(event.event_id) if event != null else null
	var entity: EntityInstance = board.entity
	var entity_data: EntityData = _manager.floor_data.find_entity(entity.entity_id) if entity != null else null
	if _selected_board != board or (_selected_event != null and _selected_event != event) or (_selected_entity != null and _selected_entity != entity):
		_selected_board = board
		_selected_event = event
		_selected_entity = entity if event == null else null
	_entity_card.visible = entity != null
	if entity != null:
		var damage: int = entity_data.aggressive_damage if entity.intent == &"lunge" else (entity_data.normal_damage if entity.intent == &"bite" else 0)
		_entity_information.text = "实体牌　｜　%s%s\n生命：%d／%d\n状态：%s\n意图：%s%s\n调查规律：%d／%d\n已揭示规律：%s" % [entity_data.display_name, "（已选）" if _selected_entity == entity else "", entity.hp, entity.max_hp, ENTITY_STATES.get(entity.state, "未知"), ENTITY_INTENTS.get(entity.intent, "未知"), "（伤害 %d）" % damage if damage > 0 else "", entity.analysis_progress, entity_data.analysis_threshold, "；".join(entity.revealed_rules) if not entity.revealed_rules.is_empty() else "尚未调查清楚"]
	_stats.text = "生命：%d　｜　压力：%d　｜　威胁：%d　｜　认知：%d　｜　行动点：%d　｜　回合：%d　｜　防护：%d" % [run.player_hp, run.stress, run.threat, run.cognition, run.ap, run.turn_number, floor.player_block]
	_counts.text = "抽牌堆：%d｜弃牌堆：%d" % [run.deck_state.draw_pile.size(), run.deck_state.discard_pile.size()]
	_end_turn.disabled = run.player_hp <= 0
	_world_card.disabled = event == null
	if event == null:
		_name.text = "本轮局势已调查完毕" if floor.remaining_fresh_events.is_empty() else "暂无符合条件的局势"
		_description.text = "新鲜局势在本次访问中不会重复出现。"
		_objective.text = "调查目标：当前没有活动局势"
		_pressure.text = "局势后果：无；楼层滞留规则仍会继续结算。"
		_rule.text = ""
		_clues.text = "已确认认知：%d。" % floor.cognition
		_state.text = "本次调查已结束，可重新开始新局。" if floor.remaining_fresh_events.is_empty() else "当前没有符合条件的调查目标。"
		if entity != null and entity.active:
			_state.text = "局势调查结束；实体仍在场，请选择实体继续应对。"
	else:
		_name.text = "局势牌　｜　%s%s" % [data.display_name, "（已选）" if _selected_event == event else ""]
		_description.text = data.display_text
		_objective.text = "目标：%s　｜　调查进度：%d／%d" % [data.objective_text, event.explore_progress, data.explore_threshold]
		_rule.text = "规则：%s牌对本局势额外增加 %d 调查。" % [TAG_NAMES.get(data.bonus_tag, "相应标签"), data.explore_bonus] if data.explore_bonus > 0 else "规则：按玩家牌的基础调查值推进。"
		if event.resolved:
			_pressure.text = "局势后果：已解决，不再施加压力。"
		else:
			_pressure.text = "回合末后果：若本回合未推进，压力 +%d。
当前：%s" % [data.neglect_stress, "本回合已推进，免于该压力" if event.last_progress_turn == floor.turn_count else "尚未推进本局势"]
			if data.neglect_damage > 0:
				_pressure.text = "回合末后果：若未推进，环境伤害 %d（可格挡，先于实体）。\n当前：%s" % [data.neglect_damage, "本回合已推进，免于该伤害" if event.last_progress_turn == floor.turn_count else "尚未推进本局势"]
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
		var bonus: int = EventSystem.explore_bonus(definition, data) if data != null and _selected_event != null else 0
		var tags: PackedStringArray = []
		for tag: StringName in definition.tags:
			tags.append(TAG_NAMES.get(tag, "其他"))
		button.text = "%s
行动点：%d
调查 +%d%s
%s
%s" % [definition.display_name, final_cost, definition.explore_amount, "（当前 +%d）" % (definition.explore_amount + bonus) if bonus > 0 else "", "威胁 +%d" % definition.threat_cost if definition.threat_cost > 0 else "低风险调查", "、".join(tags)]
		var target_event: EventInstance = _selected_event
		var target_entity: EntityInstance = _selected_entity
		match definition.effect_type:
			CardData.EffectType.ATTACK:
				button.text = "%s\n行动点：%d\n伤害：%d\n目标：实体" % [definition.display_name, final_cost, definition.effect_value]
			CardData.EffectType.BLOCK:
				button.text = "%s\n行动点：%d\n防护：%d\n抵挡环境及实体\n回合末清除" % [definition.display_name, final_cost, definition.effect_value]
				target_event = null
				target_entity = null
			CardData.EffectType.RUN:
				button.text = "%s\n行动点：%d\n踉跄时脱离\n否则引发追逐\n威胁增加一" % [definition.display_name, final_cost]
		button.disabled = run.player_hp <= 0 or run.ap < final_cost or not RuleResolver.validate_card_target(PlayCardCommand.new(card, target_event, board, target_entity), floor, _manager.floor_data).is_empty()
		# 绑定刷新时的真实实例。旧按钮即便被重放，也必须由解析器拒绝过期目标。
		button.pressed.connect(_manager.request_play_card.bind(card, target_event, board, target_entity))
		_hand.add_child(button)


func _show_result(result: ActionResult) -> void:
	if not result.success:
		_status.text = "行动失败：%s。" % FAILURE_MESSAGES.get(result.failure_reason, "操作未完成")
		return
	if result.card_played != null:
		_status.text = "已打出%s；消耗行动点：%d。" % [result.card_played.definition.display_name, result.ap_spent]
		if result.explore_applied > 0:
			_status.text += "调查：+%d。" % result.explore_applied
		if result.threat_delta > 0:
			_status.text += "威胁：+%d。" % result.threat_delta
		if result.clue_revealed:
			_status.text += "已揭示线索。"
		if result.event_resolved:
			_status.text += "局势已解决，认知：+%d。" % result.cognition_delta
		if result.analysis_applied > 0:
			_status.text += "实体调查：+%d。" % result.analysis_applied
		if not result.entity_rule_revealed.is_empty():
			_status.text += "已揭示实体规律。"
		if result.entity_damage > 0:
			_status.text += "造成伤害：%d。" % result.entity_damage
		if result.block_gained > 0:
			_status.text += "防护：+%d。" % result.block_gained
	else:
		_status.text = "回合已推进；局势压力：+%d；环境伤害：%d；实体伤害：%d；抵挡：%d；滞留威胁：+%d。" % [result.pressure_stress, result.pressure_damage, result.player_damage, result.pressure_blocked + result.damage_blocked, result.threat_delta]
		if _manager.run_state.player_hp <= 0:
			_status.text = "生命耗尽，本局结束。局势伤害：%d；实体伤害：%d。" % [result.pressure_damage, result.player_damage]
