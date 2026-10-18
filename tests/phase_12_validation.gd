extends "res://tests/phase_11_validation.gd"

var resolution: Vector2i = Vector2i(1152, 648)
var _saved: PackedStringArray = []
var _screenshots: bool = false


func label() -> String:
	return "Phase 12 / provided assets, reusable views, targeting, responsive UI and full route"


func tests() -> void:
	_test_asset_contract()
	await _test_all_art_missing()
	for dimensions: Vector2i in [Vector2i(1152, 648), Vector2i(1280, 720), Vector2i(1920, 1080)]:
		resolution = dimensions
		root.size = dimensions
		await _test_views_and_states()
		await production_run()


func _test_asset_contract() -> void:
	var entries: Dictionary = AssetCatalog.entries()
	for id: String in entries:
		var entry: Dictionary = entries[id]
		check(String(entry.path).begins_with("res://assets/"), "Manifest uses project asset paths")
		if entry.status == "PROVIDED":
			check(AssetCatalog.is_provided(StringName(id)), "Provided resource exists: " + id)
			if entry.category != "音频" and entry.category != "字体":
				check(load(AssetCatalog.path_for(StringName(id))) is Texture2D, "Provided image really loads: " + id)
		elif entry.category == "音频":
			check(AssetCatalog.audio(StringName(id)) == null, "Missing audio remains silent")
		elif entry.category == "字体":
			check(AssetCatalog.font(StringName(id)) == null, "Missing Chinese font uses engine/system fallback")
		else:
			check(AssetCatalog.texture(StringName(id)) != null, "Missing dedicated art has default")
	check(AssetCatalog.is_provided(&"entity_hound") and AssetCatalog.is_provided(&"entity_smiler") and AssetCatalog.is_provided(&"floor_level_6"), "Dedicated existing entity/floor art is integrated")
	check(AssetCatalog.texture(&"card_search") == AssetCatalog.texture(&"ui_default_art"), "Absent Search art uses explicit neutral default cover")
	check(AssetCatalog.audio(&"does_not_exist") == null and AssetCatalog.texture(&"does_not_exist") != null, "Optional unknown assets do not block UI")
	# Simulate a missing final asset without changing developer files.
	var old: Dictionary = AssetCatalog._entries["entity_hound"].duplicate(true)
	AssetCatalog._entries["entity_hound"] = {"path": "res://assets/missing/hound.png", "fallback_path": "res://assets/cards/default-cardcover.png"}
	check(AssetCatalog.texture(&"entity_hound") == AssetCatalog.texture(&"ui_default_art"), "Required image missing at runtime follows explicit fallback")
	AssetCatalog._entries["entity_hound"] = old


func _test_all_art_missing() -> void:
	var backup: Dictionary = AssetCatalog.entries()
	for id: String in backup:
		AssetCatalog._entries[id] = {"path": "res://assets/not_provided/" + id + ".png"}
	var main: Control = make_view(CURRENT_0)
	await process_frame
	var owner: TurnManager = main.get_node("TurnManager") as TurnManager
	check(owner.run_state.deck_state.hand.size() == 5 and (main.get_node("%WorldCard") as Control).visible, "Whole gameplay UI constructs with every final asset missing")
	for child: Node in main.get_node("%Hand").get_children():
		check((child as PlayerCardView)._art.texture != null, "Missing final art never leaves a broken PlayerCardView")
	main.free()
	AssetCatalog._entries = backup


func make_view(data: FloorData, cards: Array[CardData] = []) -> Control:
	var main: Control = MAIN.instantiate() as Control
	var owner: TurnManager = main.get_node("TurnManager") as TurnManager
	owner.floor_data = data
	if not cards.is_empty():
		owner.starter_deck = DeckData.new()
		owner.starter_deck.cards = cards
	root.add_child(main)
	return main


func _test_views_and_states() -> void:
	var data: FloorData = clean_floor(CURRENT_0)
	var main: Control = make_view(data)
	await record(main, "level0_normal_objective")
	var owner: TurnManager = main.get_node("TurnManager") as TurnManager
	var before: Dictionary = extended_snapshot(owner)
	var observe: CardInstance = hand_card(owner, OBSERVE)
	var view: PlayerCardView = ui_button(main, observe) as PlayerCardView
	check(view != null and view.card == observe and view._art.texture != null and view._name_label.text == observe.definition.display_name, "PlayerCardView shows actual definition/art with dynamic Chinese name")
	for key: String in ["%Objective", "%Clues", "%SituationState"]:
		var text_node: Label = main.get_node(key) as Label
		check(text_node.is_visible_in_tree() and text_node.size.y >= 18, "Visible Objective text retains readable height: " + key)
	var search_view: PlayerCardView = ui_button(main, hand_card(owner, SEARCH)) as PlayerCardView
	check(search_view._keywords.text.contains("威胁+1"), "Threat cost is visible outside clipped long description")
	view.mouse_entered.emit()
	await process_frame
	check(view.selected and (main.get_node("%WorldCard") as BoardCardView).is_target_valid and extended_snapshot(owner) == before, "Hover/select only previews authoritative Objective legality")
	view.mouse_exited.emit()
	await _mouse_click(view)
	check(owner.run_state.floor_state.total_explore > 0 and owner.run_state.ap == 2, "One actual mouse click still plays once")
	check((main.get_node("%WorldCard") as ObjectiveCardView)._bar.value == owner.run_state.floor_state.current_objective.explore_progress, "Objective progress reads domain instance")
	main.free()

	data = clean_floor(CURRENT_6)
	data.entry_entity_automatic = true
	main = make_view(data)
	owner = main.get_node("TurnManager") as TurnManager
	await record(main, "level6_hound")
	await record(main, "equipment_generated")
	var attack: CardInstance = hand_card(owner, ATTACK)
	view = ui_button(main, attack) as PlayerCardView
	before = extended_snapshot(owner)
	view.mouse_entered.emit()
	check((main.get_node("%EntityCard") as BoardCardView).is_target_valid and not (main.get_node("%WorldCard") as BoardCardView).is_target_valid and (main.get_node("%WorldCard") as Control).modulate.r < 1, "Attack preview highlights Entity and dims incompatible Objective")
	check(extended_snapshot(owner) == before and view.disabled, "Preview changes no state; incompatible selected target still disables card")
	view.mouse_exited.emit()
	(main.get_node("%EntityCard") as Button).pressed.emit()
	check(not ui_button(main, attack).disabled, "Explicit legal target enables Attack")
	await _mouse_click(ui_button(main, attack))
	check((main.get_node("%EntityCard") as EntityCardView)._hp.text.contains("14／18") and (main.get_node("%EntityCard") as EntityCardView)._intent.text.contains("撕咬"), "Entity view updates HP and readable actual intent after card")
	check(owner.run_state.ap == 2, "No separate combat AP")
	main.free()

	data = clean_floor(CURRENT_6)
	data.entry_entity_automatic = true
	var heavy: CardData = preload("res://data/cards/rewards/card_heavy_strike.tres")
	main = make_view(data, [heavy, heavy, heavy, heavy, heavy])
	owner = main.get_node("TurnManager") as TurnManager
	for index: int in range(3):
		var board: BoardState = owner.run_state.floor_state.board_state
		owner.request_play_card(hand_card(owner, heavy), null, board, board.entity)
	check(owner.run_state.floor_state.entity == null and not (main.get_node("%EntityCard") as Control).visible, "Resolved entity leaves active view according to lifecycle")
	main.free()

	data = clean_floor(CURRENT_0)
	data.fresh_objectives = []
	data.intro_objective = null
	data.resource_nodes = []
	main = make_view(data)
	owner = main.get_node("TurnManager") as TurnManager
	for index: int in range(5): owner.end_turn()
	var exit_card: CardInstance = generated(owner, &"rushed")
	check(exit_card != null, "Actual fallback produces retained exit without content")
	view = ui_button(main, exit_card) as PlayerCardView
	check(view.card.source == CardData.Source.FLOOR_TEMPORARY and view._keywords.text == "保留" and view._source_label.text.contains("楼层临时牌"), "Retain/source are explicit within same HandView")
	await record(main, "rushed_cutout")
	main.free()

	for definition: EventData in [CURRENT_0.events[0], CURRENT_6.events[1], CURRENT_0.events[1]]:
		var event_view: EventCardView = EventCardView.new()
		root.add_child(event_view)
		event_view.present(EventInstance.new(definition))
		check(event_view._title.text.contains(["负面", "前兆", "机会"][definition.category]) and event_view.find_children("*", "ProgressBar", true, false).is_empty(), "Every Event category is compact modifier UI with no Explore HP")
		check(event_view._effect.custom_minimum_size.y >= 26 and not event_view._effect.text.is_empty(), "Event effect is visibly allocated, not a one-pixel clipped label")
		event_view.free()


func record(main: Control, name_text: String) -> void:
	await process_frame
	await process_frame
	for node_name: String in ["%StatusIcons", "%SceneRules", "%EventRow", "%WorldCard", "%EntityCard", "%Hand", "%EquipmentStatus", "%EndTurn", "%RewardPanel", "%SafePointPanel", "%RunSummary"]:
		var node: Control = main.get_node(node_name) as Control
		if node.is_visible_in_tree(): check(root.get_visible_rect().encloses(node.get_global_rect()), "Responsive layout contains %s at %s (%s)" % [node_name, resolution, node.get_global_rect()])
	for child: Node in main.get_node("%Hand").get_children():
		check(child is PlayerCardView, "Only actual player card views in unified hand")
		if (child as Control).is_visible_in_tree(): check(root.get_visible_rect().encloses((child as Control).get_global_rect()), "Every hand hitbox fits viewport")
	var key: String = "%dx%d/%s" % [resolution.x, resolution.y, name_text]
	if not _screenshots or _saved.has(key): return
	# 等待短反馈结束后取真实渲染帧；不把无窗口几何检查当作截图。
	await create_timer(0.30).timeout
	await RenderingServer.frame_post_draw
	var directory: String = OS.get_environment("BACKROOMS_PLAYTEST_OUTPUT")
	if directory.is_empty(): directory = OS.get_user_data_dir().path_join("phase12")
	directory = directory.path_join("%dx%d" % [resolution.x, resolution.y])
	check(DirAccess.make_dir_recursive_absolute(directory) == OK, "Screenshot directory available")
	check(root.get_texture().get_image().save_png(directory.path_join(name_text + ".png")) == OK, "Actual rendered screenshot saved")
	_saved.append(key)


func checkpoint(main: Control, name_text: String) -> void:
	await record(main, name_text)


func _mouse_click(control: Control, mouse_button: MouseButton = MOUSE_BUTTON_LEFT) -> void:
	# 切换目标会重建手牌，先完成排序。手势在同一帧按顺序送入视口，避免
	# Windows 原生指针/窗口缩放事件插进模拟按下与抬起之间；仍经过真实 GUI 命中。
	await process_frame
	await process_frame
	var point: Vector2 = control.get_global_rect().get_center()
	var motion: InputEventMouseMotion = InputEventMouseMotion.new()
	motion.position = point
	motion.global_position = point
	root.push_input(motion, true)
	var hit: Control = root.gui_get_hovered_control()
	check(hit == control or (hit != null and control.is_ancestor_of(hit)), "Pointer reaches intended actual UI hitbox")
	var press: InputEventMouseButton = InputEventMouseButton.new()
	press.position = point
	press.global_position = point
	press.button_index = mouse_button
	press.button_mask = MOUSE_BUTTON_MASK_LEFT if mouse_button == MOUSE_BUTTON_LEFT else MOUSE_BUTTON_MASK_RIGHT
	press.pressed = true
	root.push_input(press, true)
	var release: InputEventMouseButton = press.duplicate() as InputEventMouseButton
	release.pressed = false
	release.button_mask = 0
	root.push_input(release, true)
	await process_frame


func _claim(main: Control) -> void:
	var owner: TurnManager = main.get_node("TurnManager") as TurnManager
	while not owner.run_state.pending_rewards.is_empty():
		await record(main, "card_reward")
		var options: VBoxContainer = main.get_node("%RewardPanel/Margin/Layout/Scroll/Options") as VBoxContainer
		check(options.get_child_count() == 3, "Reward preserves three earned card choices")
		await _mouse_click(options.get_child(0) as Control)


func production_run() -> void:
	root.size = resolution
	var main: Control = make_view(CURRENT_0)
	var owner: TurnManager = main.get_node("TurnManager") as TurnManager
	var state: RunState = owner.run_state
	var deck: DeckState = state.deck_state
	await record(main, "level0_event")
	for turn: int in range(65):
		if owner.floor_data.is_placeholder or state.player_hp <= 0: break
		await _claim(main)
		await _use_safe(main, SafePointCommand.Choice.UPGRADE if owner.floor_data.id == CURRENT_0.id else SafePointCommand.Choice.REMOVE)
		for action: int in range(5):
			if state.ap == 0: break
			var floor: FloorState = state.floor_state
			var entity: EntityInstance = floor.entity
			var chosen: CardInstance
			if entity != null:
				await record(main, "smiler" if entity.entity_id == CURRENT_6.followup_entity.id else "event_hound")
				if entity.entity_id == CURRENT_6.followup_entity.id:
					var off: Array[CardInstance] = candidates(owner, CardData.EffectType.EXTINGUISH)
					if not off.is_empty(): chosen = off[0]
					if chosen == null and not entity.light_exposed and state.ap >= 2:
						var lights: Array[CardInstance] = candidates(owner, CardData.EffectType.LIGHT)
						if not lights.is_empty(): chosen = lights[0]
				else:
					var attacks: Array[CardInstance] = candidates(owner, CardData.EffectType.ATTACK)
					var guards: Array[CardInstance] = candidates(owner, CardData.EffectType.BLOCK)
					if not attacks.is_empty() and attacks[0].definition.effect_value >= entity.hp: chosen = attacks[0]
					elif floor.player_block < EntitySystem.intent_damage(entity, owner.floor_data.find_entity(entity.entity_id), floor, owner.floor_data) and not guards.is_empty(): chosen = guards[0]
					elif not attacks.is_empty(): chosen = attacks[0]
			if chosen == null:
				var explores: Array[CardInstance] = candidates(owner, -1, true)
				if not explores.is_empty(): chosen = explores[0]
			if chosen == null: break
			if chosen.definition.target_kinds != 0:
				(main.get_node("%EntityCard" if chosen.definition.effect_type == CardData.EffectType.ATTACK else "%WorldCard") as Button).pressed.emit()
			var button: Button = ui_button(main, chosen)
			check(not button.disabled, "Production route uses real enabled hand card")
			button.pressed.emit()
			await _claim(main)
		if generated(owner, &"safe") != null:
			var view: PlayerCardView = ui_button(main, generated(owner, &"safe")) as PlayerCardView
			check(view._keywords.text == "保留" and view._frame.modulate != Color.WHITE, "Safe exit has upgraded visual and retain marker")
			await record(main, "safe_cutout")
		var floor: FloorState = state.floor_state
		if floor.current_objective == null and floor.remaining_fresh_objectives.is_empty() and floor.entity == null and (owner.floor_data.id == CURRENT_0.id or floor.resolved_entity_ids.has(CURRENT_6.followup_entity.id)):
			await _use_safe(main, SafePointCommand.Choice.UPGRADE if owner.floor_data.id == CURRENT_0.id else SafePointCommand.Choice.REMOVE)
			var exits: Array[CardInstance] = candidates(owner, CardData.EffectType.CUTOUT_SAFE)
			if exits.is_empty(): exits = candidates(owner, CardData.EffectType.CUTOUT_RUSHED)
			if not exits.is_empty():
				ui_button(main, exits[0]).pressed.emit()
				await record(main, "level6_entry" if not owner.floor_data.is_placeholder else "summary")
		if not owner.floor_data.is_placeholder: (main.get_node("%EndTurn") as Button).pressed.emit()
	check(owner.floor_data.is_placeholder and state.player_hp > 0 and state.deck_state == deck and state.metrics.floor_exits.size() == 2, "Responsive current-data full run completes alive without gameplay redesign")
	check(state.metrics.defeated.has("猎犬") and state.metrics.resolved_alive.has("笑魇") and state.metrics.cards_rewarded == 3, "Encounter/reward invariants preserved through visual UI")
	check(not (main.get_node("%DebugPanel") as Control).visible, "Developer tools remain hidden")
	await record(main, "summary")
	print("[PHASE12] resolution=%s turns=%d hp=%d rewards=%d upgrades=%d removed=%d" % [resolution, state.turn_number, state.player_hp, state.metrics.cards_rewarded, state.metrics.cards_upgraded, state.metrics.cards_removed])
	main.free()
