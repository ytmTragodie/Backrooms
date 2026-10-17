extends Control

const ACTION_NAMES: Dictionary = {
	&"inspect": "检查环境", &"search_nearby": "搜索附近", &"end_turn": "结束回合",
	&"loot": "搜刮物资", &"prepare_cutout": "准备切出",
	&"encounter": "进入后续遭遇", &"study_landmark": "查阅地标记录", &"extinguish_light": "关闭光源",
}
const ENTITY_STATES: Dictionary = {
	&"WATCHING": "凝视", &"APPROACHING": "靠近", &"CHASING": "追击",
	&"STAGGERED": "踉跄", &"DEFEATED": "已击败", &"DISENGAGED": "已脱离",
	&"HIDDEN": "潜藏", &"OBSERVING": "观察", &"AGITATED": "躁动",
	&"ATTACKING": "进攻", &"WITHDRAWN": "已退去",
}
const EQUIPMENT_COUNTERS: Dictionary = {
	&"battery": "电量", &"durability": "耐久", &"charges": "次数",
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
	&"floor_inactive": "已抵达占位楼层，本阶段探索已结束",
	&"invalid_resource_context": "资源状态异常", &"invalid_resource_definition": "资源数据异常",
	&"resource_not_found": "未找到这处物资", &"resource_undiscovered": "尚未定位这处物资",
	&"resource_depleted": "这处物资已经搜刮完毕", &"insufficient_supply": "补给不足",
	&"preparation_complete": "切出准备已充分", &"invalid_cutout_state": "切出状态异常",
	&"destination_unavailable": "暂无可用目的地", &"invalid_destination": "目的地数据异常",
	&"cutout_unprepared": "空间或目的地准备不足，可继续准备或选择冒险切出",
	&"invalid_entity_definition": "实体数据异常", &"invalid_entity_state": "实体状态异常",
	&"invalid_entity_context": "实体与楼层数据不匹配", &"no_active_entity": "当前没有可攻击的实体",
	&"run_ended": "生命耗尽，本局已结束",
	&"invalid_equipment_definition": "装备数据异常", &"invalid_equipment_state": "携带装备状态异常",
	&"invalid_equipment_slot": "携带槽位置无效", &"equipment_unavailable": "该携带槽为空",
	&"equipment_depleted": "装备已耗尽或损坏", &"light_not_needed": "这里不需要额外照明",
	&"light_already_active": "本回合照明已开启", &"nothing_to_restore": "当前没有可恢复的状态",
	&"encounter_unavailable": "当前不能进入后续遭遇", &"light_not_active": "当前没有开启的光源",
	&"landmark_unavailable": "这里没有可查阅的地标记录", &"insight_known": "这条规律已经确认",
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
@onready var _floor_tabs: TabContainer = %FloorTabs
@onready var _resource_list: VBoxContainer = %ResourceList
@onready var _cutout_info: Label = %CutOutInfo
@onready var _prepare_cutout: Button = %PrepareCutOut
@onready var _safe_cutout: Button = %SafeCutOut
@onready var _rushed_cutout: Button = %RushedCutOut
@onready var _forced_cutout: Button = %ForcedCutOut
@onready var _supply: Label = %Supply
@onready var _entity_info: Label = %EntityInfo
@onready var _block_info: Label = %BlockInfo
@onready var _equipment_slots: VBoxContainer = %EquipmentSlots
@onready var _encounter_action: Button = %EncounterAction
@onready var _landmark_action: Button = %LandmarkAction
@onready var _extinguish_light: Button = %ExtinguishLight


func _ready() -> void:
	_turn_manager.state_changed.connect(_refresh_state)
	_turn_manager.action_resolved.connect(_on_action_resolved)
	_end_turn_button.pressed.connect(_turn_manager.end_turn)
	_inspect_action.pressed.connect(_turn_manager.request_exploration.bind(&"inspect"))
	_search_action.pressed.connect(_turn_manager.request_exploration.bind(&"search_nearby"))
	_encounter_action.pressed.connect(_turn_manager.request_exploration.bind(&"encounter"))
	_landmark_action.pressed.connect(_turn_manager.request_exploration.bind(&"study_landmark"))
	_extinguish_light.pressed.connect(_turn_manager.request_exploration.bind(&"extinguish_light"))
	_floor_tabs.set_tab_title(0, "探索现场")
	_floor_tabs.set_tab_title(1, "资源与切出")
	_floor_tabs.set_tab_title(2, "实体意图")
	_floor_tabs.set_tab_title(3, "携带装备")
	_prepare_cutout.pressed.connect(_turn_manager.request_exploration.bind(&"prepare_cutout"))
	_safe_cutout.pressed.connect(_turn_manager.request_exploration.bind(&"cutout_safe"))
	_rushed_cutout.pressed.connect(_turn_manager.request_exploration.bind(&"cutout_rushed"))
	_forced_cutout.pressed.connect(_turn_manager.request_exploration.bind(&"cutout_forced"))
	_refresh_state()
	if _turn_manager.run_state.floor_state != null and _turn_manager.run_state.floor_state.entity != null:
		_floor_tabs.current_tab = 2
	print("[APP] Project initialized")


func _on_action_resolved(result: ActionResult) -> void:
	if result.success and result.cutout_attempt != null:
		_status_label.text = "切出成功，抵达%s。压力：+%d。" % [result.destination.display_name, result.stress_delta] if result.cutout_attempt.succeeded else "仓促切出未成功，仍在当前楼层。压力：+%d；威胁：+%d。可继续准备或强行切出。" % [result.stress_delta, result.threat_delta]
		if result.cutout_attempt.succeeded and _turn_manager.run_state.floor_state.entity != null:
			_floor_tabs.current_tab = 2
	elif result.success and result.equipment_used != null:
		var item: EquipmentInstance = result.equipment_used
		_status_label.text = "已使用%s；消耗行动点：%d；剩余%s：%d。" % [item.definition.display_name, result.ap_spent, EQUIPMENT_COUNTERS.get(item.definition.counter_kind, "次数"), item.remaining_uses]
		if result.entity_damage > 0:
			_status_label.text += "造成伤害：%d。" % result.entity_damage
		if result.light_activated:
			_status_label.text += "照明持续至回合结束。"
		if result.stress_restored > 0:
			_status_label.text += "压力降低：%d。" % result.stress_restored
		if result.hp_restored > 0:
			_status_label.text += "生命恢复：%d。" % result.hp_restored
	elif result.success and result.card_played != null:
		_status_label.text = "已打出%s；消耗行动点：%d；认知：+%d；威胁：+%d。" % [result.card_played.definition.display_name, result.ap_spent, result.cognition_delta, result.threat_delta]
		if result.effect == &"damage":
			_status_label.text += "造成伤害：%d。" % result.entity_damage
		elif result.damage_requested > 0:
			_status_label.text += "预期伤害：%d（尚未结算）。" % result.damage_requested
		if result.block_gained > 0:
			_status_label.text += "获得格挡：%d。" % result.block_gained
	elif result.success:
		_status_label.text = "%s；消耗行动点：%d；认知：+%d；威胁：+%d。" % [ACTION_NAMES.get(result.action_id, "行动完成"), result.ap_spent, result.cognition_delta, result.threat_delta]
	else:
		_status_label.text = "行动失败：%s。" % FAILURE_MESSAGES.get(result.failure_reason, "操作未完成")
	if result.success and result.supply_delta > 0:
		_status_label.text += "补给：+%d。" % result.supply_delta
	elif result.success and not result.resource_discovered_id.is_empty():
		_status_label.text += "已定位一处物资。"
	if result.player_damage > 0:
		_status_label.text += "受到伤害：%d。" % result.player_damage
	if result.damage_blocked > 0:
		_status_label.text += "格挡吸收伤害：%d。" % result.damage_blocked
	if _turn_manager.run_state.player_hp <= 0:
		_status_label.text = "生命耗尽，本局结束。"


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
		play_button.text = "%s｜行动点：%d｜打出" % [card.definition.display_name, RuleResolver.card_ap_cost(card.definition, state, _turn_manager.floor_data)]
		# UI 只转发请求；规则验证、AP 扣除和牌区移动全部留在领域层。
		play_button.pressed.connect(_turn_manager.request_play_card.bind(card))
		_hand.add_child(play_button)
	_refresh_floor(state.floor_state)
	_refresh_resources_and_cutout(state)
	_refresh_entity(state.floor_state)
	_refresh_equipment(state)
	if state.player_hp <= 0:
		_inspect_action.disabled = true
		_search_action.disabled = true


func _refresh_floor(floor: FloorState) -> void:
	if floor == null:
		_floor_info.text = "尚未进入楼层"
		_event_info.text = ""
		_insights.text = ""
		_inspect_action.disabled = true
		_search_action.disabled = true
		return
	var data: FloorData = _turn_manager.floor_data
	if data.is_placeholder:
		_floor_info.text = "当前楼层：%s" % data.display_name
		_event_info.text = data.placeholder_description
		_insights.text = "本次楼层过渡已完成。"
		_inspect_action.disabled = true
		_search_action.disabled = true
		return
	_floor_info.text = "当前楼层：%s\n楼层回合：%d\n威胁：%d／%d｜认知：%d／%d\n剩余新鲜事件：%d" % [data.display_name, floor.turn_count, floor.threat, FloorState.MAX_THREAT, floor.cognition, FloorState.MAX_COGNITION, floor.remaining_fresh_events.size()]
	if floor.floor_flags.has(&"darkness"):
		if floor.light_active:
			_floor_info.text += "\n黑暗中照明已开启（本回合）：观察按普通费用，可直接验证事件线索。"
		else:
			_floor_info.text += "\n黑暗：每回合首次观察额外消耗 %d 行动点%s。" % [data.dark_observe_surcharge, "（本回合已支付）" if floor.dark_observation_used else ""]
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


func _refresh_resources_and_cutout(state: RunState) -> void:
	_supply.text = "补给：%d" % state.supply
	var floor: FloorState = state.floor_state
	var data: FloorData = _turn_manager.floor_data
	var active: bool = floor != null and data != null and not data.is_placeholder and state.player_hp > 0
	_end_turn_button.disabled = not active
	for child: Node in _hand.get_children():
		(child as Button).disabled = not active
	for child: Node in _resource_list.get_children():
		_resource_list.remove_child(child)
		child.queue_free()
	_prepare_cutout.disabled = not active
	_safe_cutout.disabled = not active or not CutOutSystem.is_prepared(floor.cutout_state)
	_rushed_cutout.disabled = not active
	_forced_cutout.disabled = not active
	if not active:
		_cutout_info.text = "生命耗尽，本局结束。" if state.player_hp <= 0 else (data.placeholder_description if data != null and data.is_placeholder else "尚未进入楼层")
		if data != null and data.is_placeholder:
			_floor_tabs.current_tab = 1
		return
	var hidden_count: int = 0
	for node: ResourceNode in floor.resource_nodes:
		if node.status == ResourceNode.Status.UNDISCOVERED:
			hidden_count += 1
			continue
		var definition: ResourceNodeData = data.find_resource(node.node_id)
		if node.status == ResourceNode.Status.DISCOVERED:
			var button: Button = Button.new()
			button.text = "%s：搜刮（1 行动点）" % definition.display_name
			button.pressed.connect(_turn_manager.request_exploration.bind(&"loot", node.node_id))
			_resource_list.add_child(button)
		else:
			var label: Label = Label.new()
			label.text = "%s：%s" % [definition.display_name, "已搜刮" if node.status == ResourceNode.Status.LOOTED else "已枯竭"]
			_resource_list.add_child(label)
	var hint: Label = Label.new()
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.text = "搜索附近可定位表层物资；深入搜索可直接搜刮隐藏物资。" if hidden_count > 0 else "这里看起来越来越空，物资不会自然补充。"
	if floor.cognition >= 4:
		hint.text += "未定位节点：%d。" % hidden_count
	_resource_list.add_child(hint)
	var cutout: CutOutState = floor.cutout_state
	var stability: String = "空间没有响应" if cutout.stability == 0 else ("空间接缝仍不稳定" if cutout.stability < CutOutSystem.SAFE_STABILITY else "空间接缝已稳定")
	var destination: String = "目的地方向未知" if cutout.destination_knowledge == 0 else "目的地方向部分辨明"
	if cutout.destination_knowledge >= CutOutState.MAX_KNOWLEDGE:
		var names: PackedStringArray = []
		for destination_id: StringName in cutout.destination_candidates:
			names.append(data.find_destination(destination_id).display_name)
		destination = "目的地已辨明：%s" % "、".join(names)
	_cutout_info.text = "%s。\n%s。\n确认新的认知线索或消耗补给，可改善切出准备。\n强行切出始终可用，但会增加压力。" % [stability, destination]


func _refresh_entity(floor: FloorState) -> void:
	_block_info.text = "本回合格挡：%d" % (floor.player_block if floor != null else 0)
	var floor_data: FloorData = _turn_manager.floor_data
	var active: bool = floor != null and floor_data != null and not floor_data.is_placeholder and _turn_manager.run_state.player_hp > 0
	_encounter_action.visible = floor_data != null and floor_data.followup_entity != null
	_encounter_action.disabled = not active or not EntitySystem.can_enter_followup(floor, floor_data)
	if _encounter_action.visible:
		_encounter_action.text = "追查远处异常：%s（1 行动点）" % floor_data.followup_entity.display_name
	_landmark_action.visible = floor_data != null and floor_data.landmark_insight != null
	_landmark_action.disabled = not active or (floor_data.landmark_insight != null and floor.discovered_insight_ids.has(floor_data.landmark_insight.id))
	_extinguish_light.disabled = not active or not floor.light_active
	if floor == null or floor.entity == null:
		_entity_info.text = "当前没有实体。探索、回合和切出使用同一套行动点。"
		return
	var entity: EntityInstance = floor.entity
	var data: EntityData = floor_data.find_entity(entity.entity_id)
	var intent: String = "无后续行动"
	match entity.intent:
		&"approach":
			intent = "回合末靠近，暂不造成伤害"
		&"bite":
			intent = "回合末撕咬，造成 %d 伤害" % data.normal_damage
		&"lunge":
			intent = "回合末扑咬，造成 %d 伤害" % data.aggressive_damage
		&"recover":
			intent = "回合末重新观察，暂不攻击"
		&"remain_hidden":
			intent = "保持黑暗则在回合末退去；强光会引来注视"
		&"watch_light":
			intent = "暂不攻击；再次开灯会升级，无光回合末将退去"
		&"warn_light":
			intent = "回合末若仍有光则准备进攻；熄灯可使其退去"
		&"light_strike":
			intent = "回合末若仍有光则攻击 %d；熄灯可避免攻击并使其退去" % data.aggressive_damage
	_entity_info.text = "%s\n生命：%d／%d\n状态：%s\n意图：%s\n当前格挡：%d" % [data.display_name, entity.hp, entity.max_hp, ENTITY_STATES.get(entity.state, "未知"), intent, floor.player_block]


func _refresh_equipment(state: RunState) -> void:
	for child: Node in _equipment_slots.get_children():
		_equipment_slots.remove_child(child)
		child.queue_free()
	var active: bool = state.player_hp > 0 and state.floor_state != null and _turn_manager.floor_data != null and not _turn_manager.floor_data.is_placeholder
	# 固定展示三格；只读取实例计数，按钮只转发槽位命令。
	for index: int in range(RunState.CARRY_SLOT_COUNT):
		var row: VBoxContainer = VBoxContainer.new()
		row.name = "EquipmentSlot%d" % index
		var label: Label = Label.new()
		label.name = "Info"
		var button: Button = Button.new()
		button.name = "UseEquipment"
		var item: EquipmentInstance = state.equipment_slots[index]
		if item == null:
			label.text = "携带槽 %d：空" % (index + 1)
			button.text = "暂无装备"
			button.disabled = true
		else:
			var data: EquipmentData = item.definition
			label.text = "携带槽 %d：%s\n%s：%d／%d" % [index + 1, data.display_name, EQUIPMENT_COUNTERS.get(data.counter_kind, "次数"), item.remaining_uses, data.capacity]
			button.text = "%s（%d 行动点）" % [data.action_name, data.ap_cost] if item.remaining_uses > 0 else ("已损坏" if data.counter_kind == &"durability" else "已耗尽")
			button.disabled = not active or item.remaining_uses <= 0
			button.pressed.connect(_turn_manager.request_use_equipment.bind(index))
		row.add_child(label)
		row.add_child(button)
		_equipment_slots.add_child(row)
