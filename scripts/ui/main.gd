class_name MainGameView
extends Control
## 展示地图/节点/战斗阶段。只持有 UI 选择，所有收益都提交给 TurnManager。
@onready var manager: TurnManager = $TurnManager
var _layout: VBoxContainer
var _content: VBoxContainer
var _status: Label
var _feedback: Label
var _background: TextureRect
var _rest_mode: int = 0
var _audio: AssetAudio

func _ready() -> void:
	theme = GameUITheme.build()
	_audio = AssetAudio.new()
	add_child(_audio)
	_background = TextureRect.new()
	_background.mouse_filter = MOUSE_FILTER_IGNORE
	_background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	add_child(_background)
	_background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shade: ColorRect = ColorRect.new()
	shade.mouse_filter = MOUSE_FILTER_IGNORE
	shade.color = Color(0.025, 0.035, 0.04, 0.83)
	add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var margin: MarginContainer = MarginContainer.new()
	add_child(margin)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side: String in ["left", "right", "top", "bottom"]: margin.add_theme_constant_override("margin_" + side, 18)
	_layout = VBoxContainer.new()
	_layout.add_theme_constant_override("separation", 10)
	margin.add_child(_layout)
	_status = GameUITheme.label(_layout, "", 18)
	_content = VBoxContainer.new()
	_content.size_flags_vertical = SIZE_EXPAND_FILL
	_layout.add_child(_content)
	_feedback = GameUITheme.label(_layout, "地图决定路线；战斗中使用手牌，保留 1 行动点即可撤离。", 13)
	manager.state_changed.connect(refresh)
	manager.action_resolved.connect(_show_result)
	refresh()

static func error_text(reason: StringName) -> String:
	return {&"insufficient_ap":"行动点不足", &"insufficient_intel":"情报不足", &"insufficient_supply":"补给不足", &"insufficient_hp":"生命不足", &"knowledge_required":"尚未掌握所需知识", &"card_not_in_hand":"此牌已不在手中", &"stale_command":"画面已变化，请重新选择", &"stale_target":"实体目标已失效", &"equipment_depleted":"装备次数耗尽", &"stale_equipment_action":"光源状态已经变化", &"nothing_to_restore":"当前无需恢复", &"invalid_choice":"此选择不可用", &"invalid_phase":"当前阶段不可执行", &"run_ended":"本局已经结束", &"illegal_route":"只能沿高亮连线前进", &"exit_required":"必须位于出口"}.get(reason, "条件不满足")

func _show_result(result: ActionResult) -> void:
	_feedback.text = result.message if result.success and not result.message.is_empty() else "操作完成" if result.success else "无法执行：" + error_text(result.failure_reason)
	if result.success: _audio.cue(&"audio_cutout" if not result.flow.destination.is_empty() else &"audio_card_play" if result.combat.cards_played > 0 else &"audio_button_click")

func _button(parent: Node, text_value: String, command: GameCommand, error: StringName = &"") -> Button:
	var button: Button = Button.new()
	button.text = text_value
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	button.custom_minimum_size = Vector2(160,42)
	# HBox 中换行按钮必须参与剩余宽度分配，否则会缩成一字宽并把整屏撑高。
	button.size_flags_horizontal = SIZE_EXPAND_FILL
	button.disabled = not error.is_empty()
	if button.disabled: button.tooltip_text = error_text(error)
	parent.add_child(button)
	button.pressed.connect(manager.submit.bind(command))
	return button

func _command(kind: GameCommand.Kind, choice: int = 0) -> GameCommand:
	var command: GameCommand = GameCommand.new(kind, manager.run_state)
	command.choice = choice
	return command

func refresh() -> void:
	if manager.run_state == null: return
	var state: RunState = manager.run_state
	for child: Node in _content.get_children():
		_content.remove_child(child)
		child.queue_free()
	_background.texture = AssetCatalog.texture(state.floor_state.definition.asset_id, &"background")
	_audio.floor_changed(state.floor_state.floor_id)
	_status.text = "%s　｜　生命 %d/%d　压力 %d　补给 %d　已知规律 %d" % [state.floor_state.definition.display_name, state.player.hp, state.player.max_hp, state.player.stress, state.player.supply, state.player.knowledge.rules.size()]
	match state.flow.phase:
		RunFlowState.Phase.MAP: _map(state)
		RunFlowState.Phase.COMBAT: _combat(state)
		RunFlowState.Phase.EVENT: _event(state)
		RunFlowState.Phase.REWARD: _reward(state)
		RunFlowState.Phase.REST: _rest(state)
		RunFlowState.Phase.SHOP: _shop(state)
		RunFlowState.Phase.CUTOUT: _cutout(state)
		RunFlowState.Phase.RESULT: _summary(state)
	if state.flow.phase != RunFlowState.Phase.REST: _rest_mode = 0

func _heading(title: String, subtitle: String = "") -> void:
	GameUITheme.label(_content, title, 25)
	if not subtitle.is_empty(): GameUITheme.label(_content, subtitle, 14, GameUITheme.GREEN)

func _map(state: RunState) -> void:
	_heading("选择路线", state.floor_state.definition.description)
	var map: MapView = MapView.new()
	_content.add_child(map)
	map.present(state)
	map.command_requested.connect(manager.submit)
	GameUITheme.label(_content, "连接始终可见 · 问号隐藏内容 · 绿色为可前进节点 · 已访问节点不会重复提供收益", 13)
	_equipment(state)

func _equipment(state: RunState) -> void:
	var names: PackedStringArray = []
	for item: EquipmentInstance in state.player.equipment.slots:
		names.append("空槽" if item == null else "%s %d/%d" % [item.definition.display_name, item.remaining_uses, item.definition.capacity])
	GameUITheme.label(_content, "携带装备　" + "　｜　".join(names), 13, GameUITheme.GOLD)

func _combat(state: RunState) -> void:
	var combat: CombatState = state.combat
	_heading("遭遇战斗", "行动点 %d/%d　防护 %d　情报 %d　噪音 %d　战斗回合 %d　%s" % [combat.ap, combat.max_ap, combat.block, combat.intel, combat.noise, combat.turn_number, "光源已开启" if combat.light_active else "光源关闭"])
	var row: HBoxContainer = HBoxContainer.new()
	row.size_flags_vertical = SIZE_EXPAND_FILL
	_content.add_child(row)
	var enemy: EntityInstance = combat.enemies[0]
	var art: TextureRect = GameUITheme.texture(row, enemy.definition.asset_id)
	art.custom_minimum_size = Vector2(180, 120)
	var information: VBoxContainer = VBoxContainer.new()
	information.size_flags_horizontal = SIZE_EXPAND_FILL
	row.add_child(information)
	GameUITheme.label(information, "%s　生命 %d/%d　防护 %d" % [enemy.definition.display_name, enemy.hp, enemy.definition.max_hp, enemy.block], 22)
	GameUITheme.label(information, "意图：%s　%s" % [enemy.current_intent.display_name, CardText.effects_text(enemy.current_intent.effects, " / ")], 19, GameUITheme.RED)
	var details: Label = GameUITheme.label(information, enemy.definition.description, 13)
	details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	# VBox 首帧尚未分配宽度时，自动换行可能暂算为数十行；限制两行并保留实际阅读高度。
	details.clip_text = true
	details.max_lines_visible = 2
	details.custom_minimum_size.y = 36
	details.tooltip_text = enemy.definition.description
	var statuses: PackedStringArray = []
	for status: StatusInstance in enemy.statuses: statuses.append("%s%d（%d回合）" % [status.definition.display_name, status.stacks, status.remaining_turns])
	var state_name: String = {&"WATCHING":"警戒",&"APPROACHING":"靠近",&"CHASING":"追逐",&"HIDDEN":"隐藏",&"AGITATED":"躁动",&"STAGGERED":"失衡",&"WITHDRAWN":"退去",&"DEFEATED":"击败"}.get(enemy.state,"活动")
	GameUITheme.label(information, "实体状态：" + state_name + "　" + " / ".join(statuses), 13)
	var player_statuses: PackedStringArray = []
	for status: StatusInstance in combat.statuses: player_statuses.append("%s%d（%d回合）" % [status.definition.display_name,status.stacks,status.remaining_turns])
	GameUITheme.label(information,"自身状态：" + (" / ".join(player_statuses) if not player_statuses.is_empty() else "无"),13,GameUITheme.GREEN)
	_equipment(state)
	var hand_scroll: ScrollContainer = ScrollContainer.new()
	hand_scroll.custom_minimum_size.y = 238
	_content.add_child(hand_scroll)
	var hand: HBoxContainer = HBoxContainer.new()
	hand.add_theme_constant_override("separation", 12)
	hand_scroll.add_child(hand)
	for card: CardInstance in combat.deck.hand:
		var command: GameCommand = _command(GameCommand.Kind.PLAY_CARD)
		command.card = card
		command.definition = card.definition
		command.target = enemy if card.definition.target_kind == CardData.TargetKind.ENTITY else null
		var view: PlayerCardView = PlayerCardView.new()
		hand.add_child(view)
		view.present(card, CombatSystem.card_error(command, state))
		view.pressed.connect(manager.submit.bind(command))
	var controls: HBoxContainer = HBoxContainer.new()
	_content.add_child(controls)
	GameUITheme.label(controls, "抽牌 %d　弃牌 %d　消耗 %d　" % [combat.deck.draw_pile.size(), combat.deck.discard_pile.size(), combat.deck.exhaust_pile.size()], 14)
	_button(controls, "结束回合", _command(GameCommand.Kind.END_TURN))
	var preview: EscapePreview = EscapeSystem.preview(state)
	_button(controls, "撤离 · 1行动点 · 生命损失 %d–%d / 压力+%d" % [preview.damage_min, preview.damage_max, preview.stress_gain], _command(GameCommand.Kind.ESCAPE), &"" if preview.allowed else preview.reason)

func _event(state: RunState) -> void:
	var event: EventData = state.flow.active_event
	_heading(event.display_name, "事件 · 选项结算，不使用战斗手牌")
	if not event.actor_name.is_empty(): GameUITheme.label(_content,"%s · %s" % [event.actor_name,["未知关系","中立","友善","敌对"][event.relation]],14,GameUITheme.GREEN)
	var story: Label = GameUITheme.label(_content, event.description, 19)
	story.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	for index: int in range(event.options.size()):
		var option: EventOptionData = event.options[index]
		_button(_content, option.display_name, _command(GameCommand.Kind.EVENT_CHOICE, index), EventSystem.option_error(option, state))

func _reward(state: RunState) -> void:
	_heading("获得物资", "只领取本次实际提供的选项；也可以放弃。")
	var reward: RewardOpportunity = state.flow.pending_rewards[0]
	if reward.equipment != null:
		GameUITheme.label(_content, "获得装备：%s；选择携带槽（会替换原物品）" % reward.equipment.display_name, 19)
		for index: int in range(EquipmentState.SLOT_COUNT):
			var item: EquipmentInstance = state.player.equipment.slots[index]
			_button(_content, "槽位 %d：%s" % [index + 1, item.definition.display_name if item != null else "空"], _command(GameCommand.Kind.REWARD, index))
	else:
		for index: int in range(reward.cards.size()): _button(_content, CardText.description(reward.cards[index]), _command(GameCommand.Kind.REWARD, index))
	_button(_content, "放弃本次奖励", _command(GameCommand.Kind.REWARD, -1))

func _rest(state: RunState) -> void:
	_heading("临时休息点", "本节点只能完成一项整备；查看候选不会消耗机会。")
	if _rest_mode in [1, 2]:
		var scroll: ScrollContainer = ScrollContainer.new()
		scroll.size_flags_vertical = SIZE_EXPAND_FILL
		_content.add_child(scroll)
		var options: VBoxContainer = VBoxContainer.new()
		options.size_flags_horizontal = SIZE_EXPAND_FILL
		scroll.add_child(options)
		for card: CardInstance in state.player.deck.cards:
			if _rest_mode == 1 and card.definition.upgrade_to == null: continue
			var command: GameCommand = _command(GameCommand.Kind.REST, _rest_mode)
			command.card = card
			_button(options, card.definition.display_name + (" → " + card.definition.upgrade_to.display_name if _rest_mode == 1 else " · 移除"), command)
		var back: Button = Button.new()
		back.text = "返回整备选项"
		_content.add_child(back)
		back.pressed.connect(func() -> void: _rest_mode = 0; refresh())
	else:
		_button(_content, "休息：恢复 7 生命，压力 -3", _command(GameCommand.Kind.REST, 0))
		for choice: int in [1, 2]:
			var button: Button = Button.new()
			button.text = "选择一张牌升级" if choice == 1 else "移除一张牌（至少保留五张）"
			button.custom_minimum_size.y = 42
			_content.add_child(button)
			button.pressed.connect(func() -> void: _rest_mode = choice; refresh())
		_button(_content, "补满携带装备次数", _command(GameCommand.Kind.REST, 3))
		_button(_content, "不整备，继续前进", _command(GameCommand.Kind.REST, 4))

func _shop(state: RunState) -> void:
	_heading(state.flow.active_shop.display_name, "以补给交换一次物资，或直接离开。")
	for index: int in range(state.flow.active_shop.offers.size()):
		var offer: ShopOfferData = state.flow.active_shop.offers[index]
		_button(_content, "%s · %d 补给" % [offer.display_name, offer.price], _command(GameCommand.Kind.SHOP, index), &"insufficient_supply" if state.player.supply < offer.price else &"")
	_button(_content, "离开交易点", _command(GameCommand.Kind.SHOP, -1))

func _cutout(state: RunState) -> void:
	var preview: CutOutPreview = CutOutSystem.preview(state, manager.game_data)
	_heading("出口 · " + CutOutSystem.route(state).display_name, "普通切出必定成功；目的地依以下概率确定。")
	for index: int in range(preview.labels.size()): GameUITheme.label(_content, "%s　%.1f%%" % [preview.labels[index], preview.probabilities[index] * 100], 24)
	GameUITheme.label(_content, "已生效：" + (" / ".join(preview.modifiers) if not preview.modifiers.is_empty() else "基础分布"), 15)
	_button(_content, "确认切出", _command(GameCommand.Kind.CUTOUT))

func _summary(state: RunState) -> void:
	_heading(state.flow.result_text)
	GameUITheme.label(_content, "胜利 %d　撤离 %d　存活解决 %d\n出牌 %d　领取奖励 %d　切出 %d\n最终牌组 %d 张　随机种子 %d" % [state.metrics.victories, state.metrics.escapes, state.metrics.resolved_alive, state.metrics.cards_played, state.metrics.rewards_claimed, state.metrics.floor_transitions, state.player.deck.cards.size(), state.rng_seed], 20)
	var button: Button = Button.new()
	button.text = "开始新局"
	button.custom_minimum_size.y = 48
	_content.add_child(button)
	button.pressed.connect(func() -> void: manager.start_run(state.rng_seed + 1))
