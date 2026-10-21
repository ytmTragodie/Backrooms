extends Control

const FAILURE_MESSAGES: Dictionary = {
	&"insufficient_ap": "行动点不足", &"objective_resolved": "该目标已解决，请结束回合",
	&"invalid_objective_target": "调查目标已经变化，请重新选择", &"card_not_in_hand": "这张牌已不在手牌中",
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

# UI 只保存选择/预览引用。所有合法性和费用仍查询同一个 RuleResolver。
var _selected_objective: ObjectiveInstance
var _selected_entity: EntityInstance
var _selected_board: BoardState
var _preview_card: CardInstance
var _audio: AssetAudio
var _event_views: Dictionary = {}
var _shown_entity: EntityInstance
var _flash_tween: Tween

@onready var _manager: TurnManager = $TurnManager
@onready var _hand: HandView = %Hand
@onready var _world_card: ObjectiveCardView = %WorldCard
@onready var _entity_card: EntityCardView = %EntityCard
@onready var _status: Label = %Status
@onready var _end_turn: Button = %EndTurn
@onready var _debug_panel: PanelContainer = %DebugPanel
@onready var _reward_panel: CardRewardPanel = %RewardPanel
@onready var _safe_panel: SafePointPanel = %SafePointPanel
@onready var _safe_button: Button = %OpenSafePoint
@onready var _summary: RunSummaryPanel = %RunSummary


func _ready() -> void:
	theme = GameUITheme.build()
	_audio = AssetAudio.new()
	add_child(_audio)
	if AssetCatalog.is_provided(&"button_primary"):
		_end_turn.add_theme_stylebox_override("normal", AssetCatalog.frame(&"button_primary"))
	_connect_manager()
	_world_card.pressed.connect(_select_world_card)
	_entity_card.pressed.connect(_select_entity)
	_debug_panel.test_run_requested.connect(_start_debug_run)
	_reward_panel.command_submitted.connect(func(command: CardRewardCommand) -> void: _manager.submit_reward_command(command))
	_safe_panel.command_submitted.connect(func(command: SafePointCommand) -> void: _manager.submit_safe_point_command(command))
	_safe_button.pressed.connect(func() -> void: _safe_panel.open(_manager.run_state))
	_summary.new_run_requested.connect(_start_new_run)
	resized.connect(_resize_layout)
	$Margin/Layout/Board.resized.connect(_resize_layout)
	_refresh_state()
	print("[APP] Project initialized")


func _connect_manager() -> void:
	_manager.state_changed.connect(_refresh_state)
	_manager.action_resolved.connect(_show_result)
	_end_turn.pressed.connect(_manager.end_turn)


func _start_debug_run(floor: FloorData, deck: DeckData) -> void:
	if OS.is_debug_build(): _replace_run(floor, deck)


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
	_preview_card = null
	_connect_manager()
	add_child(_manager)
	_status.text = "选择世界目标，单击手牌出牌。"


func _select_world_card() -> void:
	_selected_board = _manager.run_state.floor_state.board_state
	_selected_objective = _selected_board.active_objective
	_selected_entity = null
	_refresh_state()


func _select_entity() -> void:
	_selected_board = _manager.run_state.floor_state.board_state
	_selected_objective = null
	_selected_entity = _selected_board.entity
	_refresh_state()


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
	_safe_button.tooltip_text = "先应对实体／处理奖励" if _safe_button.disabled else "可选整备；查看与返回不消费机会"
	if _selected_board != board or (_selected_objective != null and _selected_objective != board.active_objective) or (_selected_entity != null and _selected_entity != board.entity) or (_selected_objective == null and _selected_entity == null and board.active_objective != null):
		_selected_board = board
		_selected_objective = board.active_objective
		_selected_entity = board.entity if board.active_objective == null else null
	if not run.player.deck.hand.has(_preview_card): _preview_card = null
	_world_card.present(floor, _manager.floor_data, ResourceNodeSystem.find_search_reward(floor, _manager.floor_data, true, run) != null, _selected_objective != null)
	var entity: EntityInstance = board.entity
	_entity_card.present(entity, _manager.floor_data.find_entity(entity.entity_id) if entity != null else null, floor, _manager.floor_data, _selected_entity != null)
	(%RunStats as Label).text = "生命：%d 压力：%d 威胁：%d 认知：%d 行动点：%d 回合：%d 防护：%d" % [run.player.hp, run.player.stress, run.floor_state.threat, run.floor_state.cognition, run.player.ap, run.flow.turn_number, run.player.block]
	(%StatusIcons as TopStatusBar).present(run)
	(%PileCounts as Label).text = "抽牌堆：%d｜弃牌堆：%d" % [run.player.deck.draw_pile.size(), run.player.deck.discard_pile.size()]
	_end_turn.disabled = run.player.hp <= 0 or _manager.floor_data.is_placeholder or not run.flow.pending_rewards.is_empty()
	_refresh_equipment_status(run)
	_refresh_environment(floor, _manager.floor_data)
	_refresh_hand(run)
	_refresh_target_feedback()
	_resize_layout()


func _command_for(card: CardInstance) -> PlayCardCommand:
	var targeted: bool = card.definition.target_kinds != CardData.TargetKind.NONE
	return PlayCardCommand.new(card, _selected_objective if targeted else null, _manager.run_state.floor_state.board_state, _selected_entity if targeted else null)


func _refresh_hand(run: RunState) -> void:
	for child: Node in _hand.get_children():
		_hand.remove_child(child)
		child.queue_free()
	for card: CardInstance in run.player.deck.hand:
		var command: PlayCardCommand = _command_for(card)
		var error: StringName = RuleResolver.validate_card_target(command, run.floor_state, _manager.floor_data, run)
		var cost: int = RuleResolver.card_ap_cost(card.definition, run, _manager.floor_data)
		var bonus: int = 0
		if card.definition.explore_amount > 0 and _selected_objective != null:
			bonus = ObjectiveSystem.explore_bonus(card.definition, _manager.floor_data.find_objective(_selected_objective.objective_id)) + card.definition.contextual_bonus(run.player.block, run.floor_state.threat)
		elif card.definition.effect_type == CardData.EffectType.ATTACK:
			bonus = card.definition.contextual_bonus(run.player.block, run.floor_state.threat, _selected_entity != null and not _selected_entity.revealed_rules.is_empty())
		var unavailable: bool = run.player.hp <= 0 or _manager.floor_data.is_placeholder or run.player.ap < cost or not error.is_empty() or not run.flow.pending_rewards.is_empty()
		var detail: String = CardText.description(card.definition) + "\n" + CardText.primary(card.definition, bonus)
		var reason: String = FAILURE_MESSAGES.get(error, "所选目标不适用")
		if error == &"invalid_target_kind":
			reason = "不能以实体为搜索目标" if card.definition.collects_resources and _selected_entity != null else "需要实体目标" if card.definition.target_kinds == CardData.TargetKind.ENTITY else "不能作用于所选目标"
		if not error.is_empty(): detail += "\n暂不可用：" + reason
		elif run.player.ap < cost: detail += "\n行动点不足"
		var view: PlayerCardView = PlayerCardView.new()
		_hand.add_child(view)
		view.present(card, cost, CardText.primary(card.definition, bonus), detail, error.is_empty(), unavailable)
		view.set_selected(card == _preview_card)
		view.preview_requested.connect(_preview)
		view.preview_ended.connect(_end_preview)
		# 保留已捕获的实际实例命令；过期按钮也必须由领域拒绝，不能在点击时重定向。
		view.pressed.connect(_submit_card_command.bind(command))
	_hand.update_dimensions()


func _preview(card: CardInstance) -> void:
	_preview_card = card
	_refresh_target_feedback()


func _end_preview(card: CardInstance) -> void:
	if _preview_card == card: _preview_card = null
	_refresh_target_feedback()


func _refresh_target_feedback() -> void:
	var run: RunState = _manager.run_state
	var floor: FloorState = run.floor_state
	var targeted: bool = _preview_card != null and _preview_card.definition.target_kinds != 0
	var valid_objective: bool = false
	var valid_entity: bool = false
	if targeted:
		valid_objective = RuleResolver.validate_card_target(PlayCardCommand.new(_preview_card, floor.current_objective, floor.board_state), floor, _manager.floor_data, run).is_empty()
		valid_entity = floor.entity != null and RuleResolver.validate_card_target(PlayCardCommand.new(_preview_card, null, floor.board_state, floor.entity), floor, _manager.floor_data, run).is_empty()
	_world_card.set_target_presentation(_selected_objective != null, valid_objective, targeted)
	_entity_card.set_target_presentation(_selected_entity != null, valid_entity, targeted)
	for child: Node in _hand.get_children():
		(child as PlayerCardView).set_selected((child as PlayerCardView).card == _preview_card)


func _submit_card_command(command: PlayCardCommand) -> void:
	_manager.submit_card_command(command)


func _refresh_equipment_status(run: RunState) -> void:
	var equipment: PackedStringArray = []
	var counters: Dictionary = {&"battery": "电量", &"durability": "耐久", &"charges": "次数"}
	for item: EquipmentInstance in run.player.equipment.slots:
		equipment.append("%s %s%d" % [item.definition.display_name, counters.get(item.definition.counter_kind, "次数"), item.remaining_uses] if item != null else "空携带槽")
	(%EquipmentStatus as Label).text = "携带装备　" + "　｜　".join(equipment)
	_debug_panel.update_context("%s\n补给 %d　稳定 %d　目的地认知 %d\n已出牌 %d　无效整手 %d／%d" % [_manager.floor_data.display_name, run.player.supply, run.floor_state.cutout_state.stability, run.floor_state.cutout_state.destination_knowledge, run.metrics.cards_played, run.metrics.dead_hands, run.metrics.hands_checked])


func _refresh_environment(floor: FloorState, data: FloorData) -> void:
	(%LevelArt as TextureRect).texture = AssetCatalog.texture(data.id, &"background")
	var names: PackedStringArray = []
	var details: PackedStringArray = []
	for rule: SceneRuleData in data.scene_rules:
		names.append(rule.display_name)
		details.append(rule.description)
	(%SceneRules as Label).text = "%s　｜　%s" % [data.display_name, " · ".join(names)]
	(%SceneRules as Label).tooltip_text = "；".join(details)
	var row: HBoxContainer = %EventRow
	row.visible = not floor.board_state.active_events.is_empty()
	for old: EventInstance in _event_views.keys():
		if not floor.board_state.active_events.has(old):
			var view: EventCardView = _event_views[old]
			row.remove_child(view)
			view.queue_free()
			_event_views.erase(old)
	for event: EventInstance in floor.board_state.active_events:
		if not _event_views.has(event):
			var view: EventCardView = EventCardView.new()
			row.add_child(view)
			_event_views[event] = view
			view.modulate.a = 0.4
			view.create_tween().tween_property(view, "modulate:a", 1.0, 0.12)
			_audio.cue(&"audio_omen" if event.definition.category == EventData.Category.OMEN else &"audio_event")
		(_event_views[event] as EventCardView).present(event)
	_audio.floor_changed(data.id)
	if floor.entity != null and floor.entity != _shown_entity:
		_audio.cue(&"audio_smiler" if data.find_entity(floor.entity.entity_id).behavior_type == EntityData.BehaviorType.LIGHT_REACTIVE else &"audio_hound")
	_shown_entity = floor.entity
	(%NoiseOverlay as TextureRect).visible = AssetCatalog.is_provided(&"fx_vhs_noise")
	if (%NoiseOverlay as TextureRect).visible: (%NoiseOverlay as TextureRect).texture = AssetCatalog.texture(&"fx_vhs_noise")


func _resize_layout() -> void:
	if not is_node_ready(): return
	var board: HBoxContainer = $Margin/Layout/Board
	var width: float = minf(800, board.size.x * 0.78) if not _entity_card.visible else (board.size.x - 16) * 0.5
	_world_card.custom_minimum_size.x = maxf(360, width)
	_entity_card.custom_minimum_size.x = maxf(360, width)
	_hand.update_dimensions()


func _show_result(result: ActionResult) -> void:
	if not result.success:
		_status.text = "行动失败：%s。" % FAILURE_MESSAGES.get(result.failure_reason, "请重新选择")
		return
	_audio.cue(&"audio_cutout" if result.cutout.destination != null else &"audio_card_play" if result.card.card_played != null else &"audio_button_click")
	if result.player.pressure_damage + result.player.damage_taken > 0 and AssetCatalog.is_provided(&"fx_damage_flash"):
		var flash: TextureRect = %DamageFlash
		flash.texture = AssetCatalog.texture(&"fx_damage_flash")
		flash.modulate.a = 0.2
		flash.show()
		if _flash_tween != null: _flash_tween.kill()
		_flash_tween = create_tween()
		_flash_tween.tween_property(flash, "modulate:a", 0.0, 0.16)
		_flash_tween.tween_callback(flash.hide)
	if result.run.reward_claimed != null: _status.text = "新牌已加入原有牌组。"
	elif result.run.safe_point_used != null: _status.text = "整备完成，继续探索。"
	elif result.card.card_played != null: _status.text = "已打出%s · 消耗%d行动点" % [result.card.card_definition.display_name, result.card.ap_spent]
	else: _status.text = "新回合 · 观察意图，再分配行动点。"
	if result.objective.progress_applied > 0: _status.text += " · 调查：+%d" % result.objective.progress_applied
	if result.floor.cognition_delta > 0: _status.text += " · 认知：+%d" % result.floor.cognition_delta
	if result.cutout.attempt != null: _status.text = "切出成功。" if result.cutout.attempt.succeeded else "仓促切出失败，此牌已保留。"
	if result.cutout.destination != null and result.cutout.destination.is_placeholder: _status.text = "已成功离层，本局完成。"
	var feedback: PackedStringArray = []
	if result.player.pressure_damage + result.player.damage_taken > 0: feedback.append("生命 −%d" % (result.player.pressure_damage + result.player.damage_taken))
	if result.entity.damage > 0: feedback.append("伤害 %d" % result.entity.damage)
	if result.player.block_delta > 0: feedback.append("防护 +%d" % result.player.block_delta)
	if result.floor.threat_delta > 0: feedback.append("威胁 +%d" % result.floor.threat_delta)
	if not feedback.is_empty(): _feedback("　".join(feedback))


func _feedback(value: String) -> void:
	var label: Label = GameUITheme.label(self, value, 21)
	label.z_index = 30
	label.position = Vector2(size.x * 0.36, size.y * 0.32)
	var animation: Tween = create_tween().set_parallel(true)
	animation.tween_property(label, "position:y", label.position.y - 18, 0.25)
	animation.tween_property(label, "modulate:a", 0.0, 0.25)
	animation.chain().tween_callback(label.queue_free)
