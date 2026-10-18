extends Control

const FAILURE_MESSAGES: Dictionary = {
	&"insufficient_ap": "行动点不足", &"objective_resolved": "该目标已解决，请结束回合",
	&"invalid_objective_target": "目标目标已经变化，请重新选择", &"card_not_in_hand": "这张牌已不在手牌中",
	&"run_ended": "生命耗尽，本局结束", &"card_required": "调查必须通过手牌执行",
	&"invalid_card_definition": "卡牌数据异常", &"invalid_objective_definition": "目标数据异常",
	&"invalid_objective_state": "目标状态异常", &"invalid_insight_definition": "认知数据异常",
	&"invalid_floor_context": "楼层数据不匹配", &"invalid_objective_context": "牌桌状态异常",
	&"unsupported_effect": "本轮探索不支持该牌效果", &"invalid_command": "操作无效",
	&"invalid_entity_target": "实体目标已经变化，请重新选择", &"invalid_target_kind": "这张牌不能作用于所选目标",
	&"no_active_entity": "该实体已不再活跃", &"analysis_complete": "该实体的规律已调查清楚",
	&"analysis_unavailable": "该实体暂无可调查规律", &"guard_unneeded": "当前没有需要防护的危险",
	&"invalid_equipment_target": "携带物已变化，请重新选择",
	&"invalid_resource_target": "资源目标已变化，请重新选择", &"resources_exhausted": "没有可发现的资源",
	&"resource_undiscovered": "尚未发现该资源", &"resource_depleted": "资源已取走，不能再次领取",
	&"equipment_depleted": "装备次数已耗尽", &"equipment_incompatible": "此模式与所选装备不兼容",
	&"light_not_needed": "当前不需要照明", &"light_already_active": "照明已经开启", &"light_not_active": "照明尚未开启",
	&"encounter_unavailable": "当前不能追查后续遭遇", &"landmark_unavailable": "此处没有可调查的地标",
	&"insight_known": "该规律已经确认", &"nothing_to_restore": "当前没有可恢复的状态",
	&"insufficient_supply": "补给不足", &"preparation_complete": "切出准备已达上限", &"cutout_unprepared": "尚不满足安全切出条件",
	&"floor_inactive": "本次探索已结束", &"invalid_equipment_state": "装备状态异常",
	&"invalid_card_source": "这张牌的来源已失效，请重新选择", &"cutout_unavailable": "尚未出现切出机会",
	&"invalid_cutout_card": "切出牌定义异常",
	&"reward_pending": "请先完成当前奖励选择", &"invalid_reward": "这次奖励已经处理",
	&"invalid_reward_choice": "请选择本次提供的卡牌", &"invalid_reward_card": "这张牌不符合本次调整条件",
	&"entity_state_incompatible": "该实体状态不适用此牌",
	&"safe_point_unavailable": "安全点已使用或当前仍有危险", &"invalid_safe_point": "安全点已失效",
}
const TAG_NAMES: Dictionary = {&"OBSERVE": "观察", &"SEARCH": "搜索", &"NOISE": "噪音"}
const ENTITY_STATES: Dictionary = {&"WATCHING": "窥视", &"APPROACHING": "靠近", &"CHASING": "追逐", &"STAGGERED": "踉跄", &"DEFEATED": "击败", &"DISENGAGED": "已脱离", &"HIDDEN": "隐藏", &"OBSERVING": "注视", &"AGITATED": "躁动", &"ATTACKING": "攻击", &"WITHDRAWN": "退去（仍存活）"}
const ENTITY_INTENTS: Dictionary = {&"approach": "继续靠近（无伤害）", &"bite": "撕咬", &"lunge": "扑击", &"recover": "恢复警戒（无伤害）", &"none": "无", &"remain_hidden": "保持隐藏", &"watch_light": "注视光源", &"warn_light": "警告：继续照明将发动攻击", &"light_strike": "袭击光源"}
# 仅保存临时选择引用，不保存第二份 HP、调查、意图或费用。
var _selected_objective: ObjectiveInstance
var _selected_entity: EntityInstance
var _selected_board: BoardState
var _audio: AssetAudio
var _shown_events: Array[EventInstance] = []
var _shown_entity: EntityInstance

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
@onready var _equipment_status: Label = %EquipmentStatus
@onready var _debug_panel: PanelContainer = %DebugPanel
@onready var _reward_panel: CardRewardPanel = %RewardPanel
@onready var _safe_panel: SafePointPanel = %SafePointPanel
@onready var _safe_button: Button = %OpenSafePoint
@onready var _summary: RunSummaryPanel = %RunSummary


func _ready() -> void:
	_audio = AssetAudio.new()
	add_child(_audio)
	if AssetCatalog.is_provided(&"button_primary"):
		_end_turn.add_theme_stylebox_override("normal", AssetCatalog.frame(&"button_primary"))
	_connect_manager()
	_world_card.pressed.connect(_select_world_card)
	_entity_card.pressed.connect(_select_entity)
	_debug_panel.test_run_requested.connect(_start_debug_run)
	_reward_panel.command_submitted.connect(_submit_reward_command)
	_safe_panel.command_submitted.connect(_submit_safe_point_command)
	_safe_button.pressed.connect(func() -> void: _safe_panel.open(_manager.run_state))
	_summary.new_run_requested.connect(_start_new_run)
	_refresh_state()
	print("[APP] Project initialized")


func _connect_manager() -> void:
	_manager.state_changed.connect(_refresh_state)
	_manager.action_resolved.connect(_show_result)
	_end_turn.pressed.connect(_manager.end_turn)


func _start_debug_run(floor: FloorData, deck: DeckData) -> void:
	# 只接受隐藏开发面板的测试请求，正常入口仍由 Main 自动开局。
	if not OS.is_debug_build():
		return
	_replace_run(floor, deck)


func _start_new_run() -> void:
	_replace_run(preload("res://data/floors/floor_level_0.tres"), preload("res://data/cards/run_deck.tres"))


func _replace_run(floor: FloorData, deck: DeckData) -> void:
	_safe_panel.hide()
	var equipment: Array[EquipmentData] = _manager.starting_equipment.duplicate()
	_manager.free()
	_manager = TurnManager.new()
	_manager.name = "TurnManager"
	_manager.floor_data = floor
	_manager.starter_deck = deck
	_manager.starting_equipment = equipment
	_selected_board = null
	_selected_objective = null
	_selected_entity = null
	_connect_manager()
	add_child(_manager)
	_status.text = "请选择世界牌目标，再打出手牌。"


func _select_world_card() -> void:
	# 选择只是表现层操作；不发玩法命令，不推进调查，也不揭示新线索。
	_selected_board = _manager.run_state.floor_state.board_state
	_selected_objective = _selected_board.active_objective
	_selected_entity = null
	_refresh_state()
	_status.text = "已选择当前目标。请打出手牌推进调查。" if _selected_objective != null else "已选择周围环境；搜索可领取仍可用的有限补给。"


func _select_entity() -> void:
	_selected_board = _manager.run_state.floor_state.board_state
	_selected_objective = null
	_selected_entity = _selected_board.entity
	_refresh_state()
	_status.text = "已选择实体。调查可揭示规律；攻击造成伤害；防御直接保护玩家。"


func _refresh_state() -> void:
	var run: RunState = _manager.run_state
	var floor: FloorState = run.floor_state
	var board: BoardState = floor.board_state
	_reward_panel.refresh(run)
	_safe_panel.refresh(run)
	_summary.refresh(run, _manager.floor_data.is_placeholder)
	$Margin.visible = not _summary.visible
	_safe_button.visible = floor.safe_point != null and floor.safe_point.reached and not floor.safe_point.consumed and not _manager.floor_data.is_placeholder
	_safe_button.disabled = not SafePointSystem.available(run)
	_safe_button.tooltip_text = "先应对当前实体或处理奖励" if _safe_button.disabled else "可选：本层只有一次整备，也可以直接离开"
	_refresh_equipment_status(run)
	var event: ObjectiveInstance = board.active_objective
	var data: ObjectiveData = _manager.floor_data.find_objective(event.objective_id) if event != null else null
	var entity: EntityInstance = board.entity
	var environment_reward: bool = ResourceNodeSystem.find_search_reward(floor, _manager.floor_data, true, run) != null
	var entity_data: EntityData = _manager.floor_data.find_entity(entity.entity_id) if entity != null else null
	if _selected_board != board or (_selected_objective != null and _selected_objective != event) or (_selected_entity != null and _selected_entity != entity) or (_selected_objective == null and _selected_entity == null and event != null):
		_selected_board = board
		_selected_objective = event
		_selected_entity = entity if event == null else null
	_refresh_environment(floor, _manager.floor_data)
	_entity_card.visible = entity != null
	if entity != null:
		var damage: int = EntitySystem.intent_damage(entity, entity_data, floor, _manager.floor_data)
		_entity_information.text = "实体牌　｜　%s%s\n生命：%d／%d\n状态：%s\n意图：%s%s\n调查规律：%d／%d\n已揭示规律：%s" % [entity_data.display_name, "（已选）" if _selected_entity == entity else "", entity.hp, entity.max_hp, ENTITY_STATES.get(entity.state, "未知"), ENTITY_INTENTS.get(entity.intent, "未知"), "（伤害 %d）" % damage if damage > 0 else "", entity.analysis_progress, entity_data.analysis_threshold, "；".join(entity.revealed_rules) if not entity.revealed_rules.is_empty() else "尚未调查清楚"]
		if entity_data.behavior_type == EntityData.BehaviorType.LIGHT_REACTIVE:
			_entity_information.text = "实体牌　｜　%s\n生命：%d／%d\n状态：%s\n意图：%s\n公开警示：反复强光会激怒注视；无光时退去。\n已知规律：%s" % [entity_data.display_name, entity.hp, entity.max_hp, ENTITY_STATES.get(entity.state, "未知"), ENTITY_INTENTS.get(entity.intent, "未知") if floor.light_active else "若保持黑暗，回合末退去", "避光可令其存活退去" if floor.discovered_insight_ids.has(entity_data.rule_insight.id) else "可以通过实际行为或调查目标线索确认"]
	_stats.text = "生命：%d　｜　压力：%d　｜　威胁：%d　｜　认知：%d　｜　行动点：%d　｜　回合：%d　｜　防护：%d" % [run.player_hp, run.stress, run.threat, run.cognition, run.ap, run.turn_number, floor.player_block]
	_refresh_status_icons(run)
	_counts.text = "抽牌堆：%d｜弃牌堆：%d" % [run.deck_state.draw_pile.size(), run.deck_state.discard_pile.size()]
	_end_turn.disabled = run.player_hp <= 0 or _manager.floor_data.is_placeholder or not run.pending_rewards.is_empty()
	_world_card.disabled = event == null and not environment_reward
	if event == null:
		_name.text = ("目标已调查完毕｜周围补给" if floor.remaining_fresh_objectives.is_empty() else "周围环境：仍有可用补给") if environment_reward else ("本轮目标已调查完毕" if floor.remaining_fresh_objectives.is_empty() else "暂无活动目标")
		_description.text = "选择这里后可用搜索领取有限补给。" if environment_reward else "新鲜目标不会重复；下一回合补入符合条件的新目标。"
		_objective.text = "调查目标：当前没有活动目标"
		_pressure.text = "目标后果：无；楼层滞留规则仍会继续结算。"
		_rule.text = ""
		_clues.text = "已确认认知：%d。" % floor.cognition
		_state.text = "目标已调查完毕，仍可通过手牌继续探索或离层。" if floor.remaining_fresh_objectives.is_empty() else "当前没有符合条件的调查目标。"
		if entity != null and entity.active:
			_state.text = "目标调查结束；实体仍在场，请选择实体继续应对。"
		if _manager.floor_data.is_placeholder:
			_name.text = "已离层：本次探索完成"
			_description.text = _manager.floor_data.placeholder_description
			_state.text = "本局结果：生命 %d，压力 %d，经历 %d 回合。本次探索已结束。" % [run.player_hp, run.stress, run.turn_number]
	else:
		_name.text = "目标牌　｜　%s%s" % [data.display_name, "（已选）" if _selected_objective == event else ""]
		AssetCatalog.world_art(_world_card, data.asset_id, &"frame_objective")
		_description.text = data.display_text
		_objective.text = "目标：%s　｜　调查进度：%d／%d" % [data.objective_text, event.explore_progress, data.explore_threshold]
		_rule.text = "规则：%s牌对本目标额外增加 %d 调查。" % [TAG_NAMES.get(data.bonus_tag, "相应标签"), data.explore_bonus] if data.explore_bonus > 0 else "规则：按玩家牌的基础调查值推进。"
		_pressure.visible = data.neglect_stress > 0 or data.neglect_damage > 0
		_state.visible = event.resolved
		if event.resolved:
			_pressure.text = "目标后果：已解决，不再施加压力。"
		else:
			_pressure.text = "回合末后果：若本回合未推进，压力 +%d。
当前：%s" % [data.neglect_stress, "本回合已推进，免于该压力" if event.last_progress_turn == floor.turn_count else "尚未推进本目标"]
			if data.neglect_damage > 0:
				_pressure.text = "回合末后果：若未推进，环境伤害 %d（可格挡，先于实体）。\n当前：%s" % [data.neglect_damage, "本回合已推进，免于该伤害" if event.last_progress_turn == floor.turn_count else "尚未推进本目标"]
		_clues.text = "已揭示线索：%s" % ("；".join(event.known_information) if not event.known_information.is_empty() else "尚无（调查达到 %d 时揭示）" % data.clue_threshold)
		_state.text = "已解决：结束回合后补入下一张符合条件的目标。" if event.resolved else "调查中：未完成的进度会保留至下一回合。"
	for child: Node in _hand.get_children():
		_hand.remove_child(child)
		child.queue_free()
	for card: CardInstance in run.deck_state.hand:
		var definition: CardData = card.definition
		var final_cost: int = RuleResolver.card_ap_cost(definition, run, _manager.floor_data)
		var button: Button = Button.new()
		button.icon = AssetCatalog.texture(definition.id)
		button.add_theme_constant_override("icon_max_width", 28)
		button.expand_icon = true
		button.add_theme_stylebox_override("normal", AssetCatalog.frame(&"frame_player"))
		button.add_theme_stylebox_override("focus", AssetCatalog.frame(&"fx_card_highlight") if AssetCatalog.is_provided(&"fx_card_highlight") else AssetCatalog.frame(&"frame_player"))
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.add_theme_font_size_override("font_size", 13)
		button.custom_minimum_size = Vector2(0, 96)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var bonus: int = ObjectiveSystem.explore_bonus(definition, data) if data != null and _selected_objective != null else 0
		var tags: PackedStringArray = []
		for tag: StringName in definition.tags:
			tags.append(TAG_NAMES.get(tag, "其他"))
		button.text = "%s\n行动点：%d · 调查 +%d%s\n%s" % [definition.display_name, final_cost, definition.explore_amount, "（当前 +%d）" % (definition.explore_amount + bonus) if bonus > 0 else "", "威胁 +%d" % definition.threat_cost if definition.threat_cost > 0 else "低风险调查"]
		var target_objective: ObjectiveInstance
		var target_entity: EntityInstance
		if definition.explore_amount > 0:
			button.text += "\n目标：目标或可分析实体" if definition.analyzes_entities else "\n目标：当前环境\n有限资源随搜索领取"
		match definition.effect_type:
			CardData.EffectType.ATTACK:
				button.text = "%s\n行动点：%d\n伤害：%d\n目标：实体" % [definition.display_name, final_cost, definition.effect_value]
			CardData.EffectType.BLOCK:
				button.text = "%s\n行动点：%d\n防护：%d\n抵挡环境及实体\n回合末清除" % [definition.display_name, final_cost, definition.effect_value]
			CardData.EffectType.RUN:
				button.text = "%s\n行动点：%d\n踉跄时脱离\n否则引发追逐\n威胁增加一" % [definition.display_name, final_cost]
			CardData.EffectType.LIGHT:
				button.text = "照明\n行动点：%d\n本回合产生光照\n成功消耗一电量" % final_cost
			CardData.EffectType.EXTINGUISH:
				button.text = "熄灯\n行动点：%d\n关闭当前光照\n不消耗电量" % final_cost
			CardData.EffectType.RECOVER:
				button.text = "饮用杏仁水\n行动点：%d\n压力减二\n高压力时恢复生命" % final_cost
			CardData.EffectType.CUTOUT_RUSHED:
				button.text = "仓促切出\n行动点：%d\n保留 · 占手牌位\n压力加一 · 有失败风险\n失败保留此牌" % final_cost
			CardData.EffectType.CUTOUT_SAFE:
				button.text = "安全切出\n行动点：%d\n保留 · 占手牌位\n准备充分 · 安全离层" % final_cost
		if card.source == CardData.Source.EQUIPMENT:
			button.text += "\n%s · 剩余%d" % [card.source_equipment.definition.display_name, card.source_equipment.remaining_uses]
		if definition.tags.has(&"NOISE"):
			button.text += " · 噪音"
		# 显式选择保留原样，即使种类不兼容；领域校验负责置灰，不能静默重定向。
		if definition.target_kinds != CardData.TargetKind.NONE:
			target_objective = _selected_objective
			target_entity = _selected_entity
		if definition.effect_type == CardData.EffectType.ATTACK and definition.threat_cost > 0:
			button.text += "\n威胁 +%d" % definition.threat_cost
		var condition: String = CardText.condition_description(definition)
		if not condition.is_empty():
			button.text += "\n" + condition
		button.text += "\n%s" % {CardData.Source.NORMAL: "普通牌", CardData.Source.EQUIPMENT: "装备牌", CardData.Source.FLOOR_TEMPORARY: "楼层临时牌"}.get(card.source, "")
		var command: PlayCardCommand = PlayCardCommand.new(card, target_objective, board, target_entity)
		var error: StringName = RuleResolver.validate_card_target(command, floor, _manager.floor_data, run)
		button.disabled = run.player_hp <= 0 or _manager.floor_data.is_placeholder or run.ap < final_cost or not error.is_empty() or not run.pending_rewards.is_empty()
		var reason: String = FAILURE_MESSAGES.get(error, "目标不适用")
		if error == &"invalid_target_kind":
			reason = "不能以实体为搜索目标" if definition.collects_resources and _selected_entity != null else "需要实体目标" if definition.target_kinds == CardData.TargetKind.ENTITY else "不能作用于所选目标"
		if error in [&"objective_resolved", &"no_active_entity"]:
			reason = "该目标已解决"
		# 详情仅为牌面文字和失败原因，不提供第二种动词或任何执行控件。
		button.tooltip_text = button.text + ("\n暂不可用：%s" % reason if not error.is_empty() else "\n行动点不足" if run.ap < final_cost else "\n点击打出，作用于已选目标。")
		button.pressed.connect(_submit_card_command.bind(command))
		_hand.add_child(button)
		_add_card_icons(button, definition)


func _submit_card_command(command: PlayCardCommand) -> void:
	_manager.submit_card_command(command)


func _submit_reward_command(command: CardRewardCommand) -> void:
	_manager.submit_reward_command(command)


func _submit_safe_point_command(command: SafePointCommand) -> void:
	_manager.submit_safe_point_command(command)


func _refresh_equipment_status(run: RunState) -> void:
	var equipment: PackedStringArray = []
	var counters: Dictionary = {&"battery": "电量", &"durability": "耐久", &"charges": "次数"}
	for item: EquipmentInstance in run.equipment_slots:
		equipment.append("%s（%s%d）" % [item.definition.display_name, counters.get(item.definition.counter_kind, "次数"), item.remaining_uses] if item != null else "空携带槽")
	_equipment_status.text = "　｜　".join(equipment)
	var floor: FloorState = run.floor_state
	_debug_panel.update_context("%s\n补给：%d　稳定：%d　目的地认知：%d　照明：%s\n新牌：%d　已解目标：%d　死手：%d／%d" % [_manager.floor_data.display_name, run.supply, floor.cutout_state.stability, floor.cutout_state.destination_knowledge, "开启" if floor.light_active else "关闭", run.metrics.cards_rewarded, run.metrics.objectives.size(), run.metrics.dead_hands, run.metrics.hands_checked])


func _show_result(result: ActionResult) -> void:
	if _audio != null and result.success:
		_audio.cue(&"audio_cutout" if result.destination != null else &"audio_card_play" if result.card_played != null else &"audio_button_click")
	if result.success and result.pressure_damage + result.player_damage > 0 and AssetCatalog.is_provided(&"fx_damage_flash"):
		(%DamageFlash as TextureRect).texture = AssetCatalog.texture(&"fx_damage_flash")
		(%DamageFlash as TextureRect).show()
		get_tree().create_timer(0.2).timeout.connect(func() -> void: (%DamageFlash as TextureRect).hide())
	if not result.success:
		_status.text = "行动失败：%s。" % FAILURE_MESSAGES.get(result.failure_reason, "操作未完成")
		return
	if result.reward_claimed != null:
		_status.text = "牌组已调整，继续本回合。"
		return
	if result.safe_point_used != null:
		_status.text = "整备完成；本层临时安全点已使用，继续探索。"
		return
	if result.card_played != null:
		_status.text = "已打出%s；消耗行动点：%d。" % [result.card_definition.display_name, result.ap_spent]
		if result.explore_applied > 0:
			_status.text += "调查：+%d。" % result.explore_applied
		if result.threat_delta > 0:
			_status.text += "威胁：+%d。" % result.threat_delta
		if result.clue_revealed:
			_status.text += "已揭示线索。"
		if result.objective_resolved:
			_status.text += "目标已解决，认知：+%d。" % result.cognition_delta
		if result.analysis_applied > 0:
			_status.text += "实体调查：+%d。" % result.analysis_applied
		if not result.entity_rule_revealed.is_empty():
			_status.text += "已揭示实体规律。"
		if result.entity_damage > 0:
			_status.text += "造成伤害：%d。" % result.entity_damage
		if result.block_gained > 0:
			_status.text += "防护：+%d。" % result.block_gained
		if not result.resource_looted_id.is_empty():
			_status.text += "已领取有限补给：%d。" % result.supply_delta
		if result.equipment_used != null:
			_status.text += "%s剩余次数：%d。" % [result.equipment_used.definition.display_name, result.equipment_used.remaining_uses]
		if result.resource_uses_gained > 0:
			_status.text += "%s补充 %d 次。" % [result.resource_equipment.definition.display_name, result.resource_uses_gained]
		if result.cutout_attempt != null:
			_status.text += "切出成功。" if result.cutout_attempt.succeeded else "仓促切出未成功；此牌已保留，可再次尝试或继续准备。"
		if result.destination != null and result.destination.is_placeholder:
			_status.text = "已成功离开六层，本局完成。"
	else:
		_status.text = "回合已推进；目标压力：+%d；环境伤害：%d；实体伤害：%d；抵挡：%d；滞留威胁：+%d。" % [result.pressure_stress, result.pressure_damage, result.player_damage, result.pressure_blocked + result.damage_blocked, result.threat_delta]
		if _manager.run_state.player_hp <= 0:
			_status.text = "生命耗尽，本局结束。目标伤害：%d；实体伤害：%d。" % [result.pressure_damage, result.player_damage]


func _refresh_environment(floor: FloorState, data: FloorData) -> void:
	(%LevelArt as TextureRect).texture = AssetCatalog.texture(data.id, &"background")
	var rules: PackedStringArray = []
	for rule: SceneRuleData in data.scene_rules:
		rules.append("%s：%s" % [rule.display_name, rule.description])
	(%SceneRules as Label).text = "%s　｜　%s" % [data.display_name, "；".join(rules)]
	var row: HBoxContainer = %EventRow
	for child: Node in row.get_children():
		row.remove_child(child)
		child.queue_free()
	for event: EventInstance in floor.board_state.active_events:
		var panel: PanelContainer = PanelContainer.new()
		panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		panel.add_theme_stylebox_override("panel", AssetCatalog.frame(&"frame_event"))
		var layout: HBoxContainer = HBoxContainer.new()
		panel.add_child(layout)
		var art: TextureRect = TextureRect.new()
		art.texture = AssetCatalog.texture(event.definition.id)
		art.custom_minimum_size = Vector2(36, 54)
		art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		layout.add_child(art)
		var text: Label = Label.new()
		text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		text.add_theme_font_size_override("font_size", 13)
		var category: String = ["负面", "前兆", "机会"][event.definition.category]
		text.text = "事件·%s｜%s　剩余%d回合\n%s" % [category, event.definition.display_name, event.remaining_turns, event.definition.display_text]
		if event.definition.category == EventData.Category.OPPORTUNITY:
			text.text += "（行动条件：%d／%d）" % [event.matching_actions, event.definition.required_actions]
		if event.definition.category == EventData.Category.OMEN and event.remaining_turns == 0:
			text.text += "（等待实体槽空出）"
		layout.add_child(text)
		row.add_child(panel)
		if not _shown_events.has(event) and _audio != null:
			_audio.cue(&"audio_omen" if event.definition.category == EventData.Category.OMEN else &"audio_event")
	_shown_events = floor.board_state.active_events.duplicate()
	if _audio != null: _audio.floor_changed(data.id)
	var entity: EntityInstance = floor.entity
	if entity != null:
		var definition: EntityData = data.find_entity(entity.entity_id)
		AssetCatalog.world_art(_entity_card, definition.id, &"frame_entity")
		if entity != _shown_entity and _audio != null:
			_audio.cue(&"audio_smiler" if definition.behavior_type == EntityData.BehaviorType.LIGHT_REACTIVE else &"audio_hound")
	_shown_entity = entity
	(%NoiseOverlay as TextureRect).visible = AssetCatalog.is_provided(&"fx_vhs_noise")
	if (%NoiseOverlay as TextureRect).visible:
		(%NoiseOverlay as TextureRect).texture = AssetCatalog.texture(&"fx_vhs_noise")
	if AssetCatalog.is_provided(&"fx_target_highlight"):
		_world_card.add_theme_stylebox_override("normal", AssetCatalog.frame(&"fx_target_highlight") if _selected_objective != null else AssetCatalog.frame(&"frame_objective"))
		_entity_card.add_theme_stylebox_override("normal", AssetCatalog.frame(&"fx_target_highlight") if _selected_entity != null else AssetCatalog.frame(&"frame_entity"))


func _refresh_status_icons(run: RunState) -> void:
	# 文本仍提供完整中文语义，图标只是可替换展示，缺图不影响读数。
	var row: HBoxContainer = %StatusIcons
	for child: Node in row.get_children():
		row.remove_child(child)
		child.queue_free()
	var ids: Array[StringName] = [&"hp", &"stress", &"threat", &"cognition", &"ap", &"", &"guard"]
	var names: Array[String] = ["生命", "压力", "威胁", "认知", "行动点", "回合", "防护"]
	var values: Array[int] = [run.player_hp, run.stress, run.threat, run.cognition, run.ap, run.turn_number, run.floor_state.player_block]
	for index: int in range(ids.size()):
		var group: HBoxContainer = HBoxContainer.new()
		group.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		group.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_child(group)
		if not ids[index].is_empty():
			var icon: TextureRect = TextureRect.new()
			icon.texture = AssetCatalog.texture(StringName("icon_" + String(ids[index])), &"icon")
			icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			icon.custom_minimum_size = Vector2(18, 18)
			group.add_child(icon)
		var label: Label = Label.new()
		label.text = "%s：%d" % [names[index], values[index]]
		group.add_child(label)


func _add_card_icons(button: Button, definition: CardData) -> void:
	var ids: Array[StringName] = []
	for tag: StringName in [&"LIGHT", &"NOISE", &"EXHAUST"]:
		if definition.tags.has(tag): ids.append(StringName("icon_" + String(tag).to_lower()))
	if definition.retain: ids.append(&"icon_retain")
	for index: int in range(ids.size()):
		var icon: TextureRect = TextureRect.new()
		icon.texture = AssetCatalog.texture(ids[index], &"icon")
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		button.add_child(icon)
		icon.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
		icon.position = Vector2(-18 * (index + 1), 4)
		icon.size = Vector2(14, 14)
