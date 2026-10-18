extends "res://tests/phase_10_validation.gd"

const CURRENT_0: FloorData = preload("res://data/floors/floor_level_0.tres")
const CURRENT_6: FloorData = preload("res://data/floors/floor_level_6.tres")
const CURRENT_DECK: DeckData = preload("res://data/cards/run_deck.tres")
var captures: PackedStringArray = []


func label() -> String:
	return "Phase 11 / Event taxonomy, lifecycle, transactions, assets and production route"


func tests() -> void:
	_test_taxonomy()
	_test_capacity_and_modifiers()
	_test_omen()
	_test_opportunity()
	_test_current_exit_fallback()
	_test_assets()
	await production_run()


func clean_floor(source: FloorData = CURRENT_0) -> FloorData:
	var data: FloorData = source.duplicate(false) as FloorData
	data.events = []
	data.followup_on_light = false
	return data


func new_event(id: StringName, category: EventData.Category, duration: int) -> EventData:
	var data: EventData = EventData.new()
	data.id = id
	data.display_name = "测试事件"
	data.display_text = "测试声明"
	data.category = category
	data.duration = duration
	return data


func extended_snapshot(owner: TurnManager) -> Dictionary:
	var result: Dictionary = full_snapshot(owner)
	result["events"] = owner.run_state.floor_state.board_state.active_events.map(func(event: EventInstance) -> Array: return [event.get_instance_id(), event.remaining_turns, event.matching_actions, event.checked_turn, event.retired])
	result["seen_events"] = owner.run_state.floor_state.seen_event_ids.duplicate()
	return result


func _test_taxonomy() -> void:
	for data: FloorData in [CURRENT_0, CURRENT_6]:
		check(data.fresh_objectives.size() == 2 and not data.scene_rules.is_empty(), "Each floor separates two actual targets from persistent scene rules")
		check(EventSystem.validate_definitions(data).is_empty(), "Production Events validate")
		for event: EventData in data.events:
			check(not event.get_property_list().any(func(p: Dictionary) -> bool: return p.name in ["explore_threshold", "explore_progress"]), "Events have no Explore HP")
		var owner: TurnManager = manager(CURRENT_DECK.cards, data)
		check(owner.run_state.floor_state.board_state.active_events.size() <= 2 and owner.run_state.floor_state.current_objective != null, "Events and Objective coexist")
		for pile: Array[CardInstance] in [owner.run_state.deck_state.hand, owner.run_state.deck_state.draw_pile, owner.run_state.deck_state.discard_pile]:
			for card: CardInstance in pile: check(card is CardInstance, "Player piles contain only actual Player Cards")
		owner.free()


func _test_capacity_and_modifiers() -> void:
	var data: FloorData = clean_floor()
	var first: EventData = new_event(&"debuff_first", EventData.Category.DEBUFF, 1)
	first.stress_per_turn = 2
	first.modifier_tag = &"OBSERVE"
	first.ap_modifier = 1
	var second: EventData = new_event(&"debuff_second", EventData.Category.DEBUFF, 3)
	second.damage_per_turn = 2
	var third: EventData = new_event(&"overflow", EventData.Category.DEBUFF, 2)
	data.events = [first, second, third]
	var owner: TurnManager = manager([OBSERVE, OBSERVE, OBSERVE, OBSERVE, OBSERVE], data)
	var state: RunState = owner.run_state
	var old: EventInstance = state.floor_state.board_state.active_events[0]
	check(state.floor_state.seen_event_ids == [first.id, second.id] and state.floor_state.board_state.active_events.size() == 2, "Deterministic capacity defers third Event")
	check(RuleResolver.card_ap_cost(OBSERVE, state, data) == 2, "Active tag modifier applies to final AP")
	check(play(owner, OBSERVE).success and state.ap == 1, "Card commits modified AP and Objective together")
	var before: Dictionary = extended_snapshot(owner)
	var failed: ActionResult = play(owner, OBSERVE)
	check(not failed.success and extended_snapshot(owner) == before and failed.event_changes.is_empty(), "Failed AP changes no timers/conditions/charges/AP/RNG")
	owner.end_turn()
	check(state.stress == 2 and state.player_hp == 28 and old.retired, "Both active debuffs resolve in one lifecycle, then expire")
	check(state.floor_state.seen_event_ids == [first.id, second.id, third.id] and state.floor_state.board_state.active_events[1].definition == third, "Overflow fills first free slot without replacing survivor")
	check(RuleResolver.card_ap_cost(OBSERVE, state, data) == 1, "Retired Event no longer modifies cards")
	before = extended_snapshot(owner)
	var forged: ActionResult = ActionResult.new()
	var stale: EventChange = EventChange.new(old)
	stale.matching_actions = 99
	forged.event_changes.append(stale)
	EventSystem.commit(forged, state)
	check(extended_snapshot(owner) == before and old.matching_actions == 0, "Stale Event reference cannot re-enter or produce effects")
	owner.free()
	data.events = [second]
	owner = manager([GUARD, OBSERVE, OBSERVE, OBSERVE, OBSERVE], data)
	check(play(owner, GUARD).success, "Guard is useful against Event-only environmental damage")
	var result: ActionResult = owner.end_turn()
	check(result.pressure_blocked == 2 and result.pressure_damage == 0 and owner.run_state.player_hp == 30, "Environmental Event consumes same Guard before entities")
	owner.free()
	data = clean_floor(CURRENT_6)
	data.entry_entity_automatic = true
	second.duration = 3
	data.events = [second]
	owner = manager([GUARD, OBSERVE, OBSERVE, OBSERVE, OBSERVE], data)
	owner.end_turn()
	var same_board: BoardState = owner.run_state.floor_state.board_state
	check(play(owner, GUARD).success, "Mixed encounter defense uses normal card/AP")
	result = owner.end_turn()
	check(result.pressure_blocked == 2 and result.damage_blocked == 2 and result.player_damage == 2, "Event pressure consumes Guard before Hound intent; remainder is not counted twice")
	check(owner.run_state.floor_state.board_state == same_board and same_board.entity != null and owner.run_state.ap == 3, "Event and Entity keep one board/AP/turn lifecycle")
	owner.free()


func _test_omen() -> void:
	var data: FloorData = clean_floor(CURRENT_6)
	var omen: EventData = new_event(&"hound_warning", EventData.Category.OMEN, 1)
	omen.spawn_entity = data.entry_entity
	data.events = [omen]
	var owner: TurnManager = manager([OBSERVE, ATTACK, GUARD, DEEP, SEARCH], data)
	var state: RunState = owner.run_state
	state.ap = 1
	var unchanged: Dictionary = extended_snapshot(owner)
	var invalid_noise: ActionResult = play(owner, DEEP)
	check(not invalid_noise.success and extended_snapshot(owner) == unchanged, "Failed NOISE card cannot accelerate Omen")
	state.ap = 3
	check(state.floor_state.entity == null, "Hound has a readable warning before entry")
	owner.end_turn()
	var hound: EntityInstance = state.floor_state.entity
	check(hound != null and hound.hp == 18 and hound.entity_id == omen.spawn_entity.id and hound.state == &"WATCHING", "Countdown spawns intended common entity; new entity does not retroactively attack")
	check(state.floor_state.board_state.active_events.is_empty() and state.floor_state.current_objective != null, "Omen leaves board; entity and Objective coexist")
	owner.end_turn()
	check(state.floor_state.entity == hound and hound.state == &"APPROACHING", "Only one Hound instance, one existing intent lifecycle")
	owner.free()
	data = clean_floor(CURRENT_6)
	omen = new_event(&"noise_warning", EventData.Category.OMEN, 2)
	omen.spawn_entity = data.entry_entity
	omen.accelerate_tags = [&"NOISE"]
	data.events = [omen]
	owner = manager([DEEP, SEARCH, OBSERVE, ATTACK, GUARD], data)
	check(play(owner, DEEP).success and owner.run_state.floor_state.board_state.active_events[0].remaining_turns == 1, "Successful NOISE accelerates declared Omen")
	owner.free()
	data = clean_floor(CURRENT_6)
	omen = new_event(&"smiler_warning", EventData.Category.OMEN, 2)
	omen.spawn_entity = data.followup_entity
	omen.accelerate_tags = [&"LIGHT", &"NOISE"]
	data.events = [omen]
	owner = manager([OBSERVE, ATTACK, GUARD, SEARCH, DEEP], data)
	state = owner.run_state
	check(play_generated(owner, &"light").success and state.floor_state.board_state.active_events[0].remaining_turns == 1, "Actual LIGHT accelerates Omen once")
	owner.end_turn()
	var smiler: EntityInstance = state.floor_state.entity
	check(smiler != null and smiler.entity_id == data.followup_entity.id and smiler.light_exposed, "Omen spawns Smiler with actual light exposure")
	owner.end_turn()
	check(smiler.alive and smiler.state == &"WITHDRAWN" and state.floor_state.entity == null and state.cognition == 1, "Respect darkness resolves Smiler alive and confirms unique Insight")
	check(state.pending_rewards.size() == 1, "Meaningful behavior offers existing reward exactly once")
	owner.submit_reward_command(CardRewardCommand.new(state.pending_rewards[0], state.pending_rewards[0].choices[0]))
	owner.end_turn()
	check(state.floor_state.entity == null and state.pending_rewards.is_empty() and state.cognition == 1, "Expired Omen and Insight cannot trigger twice")
	owner.free()
	# A ready Omen waits rather than replacing an occupied entity slot.
	data = clean_floor(CURRENT_6)
	data.entry_entity_automatic = true
	omen = new_event(&"waiting", EventData.Category.OMEN, 1)
	omen.spawn_entity = data.followup_entity
	data.events = [omen]
	owner = manager([], data)
	owner.end_turn()
	check(owner.run_state.floor_state.entity.entity_id == data.entry_entity.id and owner.run_state.floor_state.board_state.active_events[0].remaining_turns == 0, "Occupied entity slot preserves ready Omen and existing entity")
	owner.free()


func _test_opportunity() -> void:
	var data: FloorData = clean_floor()
	data.events = [CURRENT_0.events[1]]
	var owner: TurnManager = manager([SEARCH, SEARCH, SEARCH, SEARCH, SEARCH], data)
	var state: RunState = owner.run_state
	var event: EventInstance = state.floor_state.board_state.active_events[0]
	check(play(owner, SEARCH).success and event.matching_actions == 1, "Opportunity listens to a real card targeting Objective, not Event")
	check(play(owner, SEARCH).success and event.retired and state.pending_rewards.size() == 1 and state.cognition == 1, "Second matching card commits reward/Insight/retirement once")
	owner.submit_reward_command(CardRewardCommand.new(state.pending_rewards[0], state.pending_rewards[0].choices[0]))
	check(play(owner, SEARCH).success and state.pending_rewards.is_empty() and event.matching_actions == 2 and state.cognition == 1, "Further cards do not re-award retired Opportunity")
	owner.free()
	var expired: EventData = CURRENT_0.events[1].duplicate(false) as EventData
	expired.duration = 1
	data.events = [expired]
	owner = manager([], data)
	owner.end_turn()
	check(owner.run_state.floor_state.board_state.active_events.is_empty() and owner.run_state.pending_rewards.is_empty(), "Missed Opportunity expires without reward or blocking exit")
	owner.free()


func _test_current_exit_fallback() -> void:
	for seed_value: int in [2, 7, 19]:
		var first: FloorData = clean_floor(CURRENT_0)
		var second: FloorData = clean_floor(CURRENT_6)
		for data: FloorData in [first, second]:
			data.fresh_objectives = []
			data.intro_objective = null
			data.resource_nodes = []
			data.safe_point = null
		first.cutout_destinations = [second]
		var owner: TurnManager = manager(CURRENT_DECK.cards, first, false, seed_value)
		for floor_index: int in range(2):
			for turn: int in range(5): owner.end_turn()
			check(generated(owner, &"rushed") != null and owner.run_state.cognition == 0, "Current floors retain exit without any Event/Objective/resource/Insight/equipment")
			for attempt: int in range(20):
				var result: ActionResult = play_generated(owner, &"rushed")
				if result.cutout_attempt != null and result.cutout_attempt.succeeded: break
				check(generated(owner, &"rushed") != null, "Rushed failure preserves exit")
				owner.end_turn()
		check(owner.floor_data.is_placeholder, "Missing all current content cannot permanently trap either floor")
		owner.free()


func _test_assets() -> void:
	var entries: Dictionary = AssetCatalog.entries()
	check(entries.size() >= 60, "Manifest covers current demo categories")
	for id: String in entries:
		var entry: Dictionary = entries[id]
		check(AssetCatalog.path_for(StringName(id)).begins_with("res://assets/") and not String(entry.path).contains(":" + "/Users"), "Runtime asset paths are project-relative")
		if entry.category == "音频":
			check(AssetCatalog.audio(StringName(id)) == null or AssetCatalog.is_provided(StringName(id)), "Missing audio is silent")
		else:
			check(AssetCatalog.texture(StringName(id)) != null, "Required/optional art resolves or has fallback")
	check(AssetCatalog.texture(&"unknown_optional") == AssetCatalog.CARD_PLACEHOLDER and AssetCatalog.audio(&"unknown_optional") == null, "Unknown optional entries safely fall back")
	# 用已导入占位文件模拟素材提供者填入正确路径，不写任何最终素材。
	AssetCatalog._entries["provided_probe"] = {"path": "res://assets/placeholders/card.svg"}
	check(AssetCatalog.is_provided(&"provided_probe") and AssetCatalog.texture(&"provided_probe") == AssetCatalog.CARD_PLACEHOLDER, "Manifest-specified existing file is actually loaded")
	AssetCatalog._entries["invalid_probe"] = {"path": "C:/outside/project.png"}
	check(AssetCatalog.path_for(&"invalid_probe").is_empty() and AssetCatalog.texture(&"invalid_probe") == AssetCatalog.CARD_PLACEHOLDER, "Absolute local file path is rejected before loading")
	AssetCatalog._entries.erase("provided_probe")
	AssetCatalog._entries.erase("invalid_probe")
	check(AssetCatalog.BACKGROUND_PLACEHOLDER.get_width() == 1152 and AssetCatalog.FRAME_PLACEHOLDER.get_height() == 192, "Imported placeholder textures work")
	for directory: String in ["res://data/cards", "res://data/cards/generated", "res://data/cards/rewards"]:
		for file: String in DirAccess.get_files_at(directory):
			if not file.begins_with("card_") or not file.ends_with(".tres") or file in ["card_wait.tres", "card_struggle.tres"]: continue
			var card: CardData = load(directory.path_join(file)) as CardData
			check(entries.has(String(card.id)), "Every active player definition maps by its actual stable ID")
	for data: FloorData in [CURRENT_0, CURRENT_6]:
		for objective: ObjectiveData in data.fresh_objectives:
			check(entries.has(String(objective.asset_id)), "Objective explicit illustration ID resolves")


func capture(main: Control, name_text: String) -> void:
	await checkpoint(main, name_text)
	for node_name: String in ["%EventRow", "%SceneRules", "%WorldCard", "%EntityCard", "%Hand", "%EndTurn"]:
		var node: Control = main.get_node(node_name) as Control
		if node.is_visible_in_tree(): check(root.get_visible_rect().encloses(node.get_global_rect()), "New UI fits viewport: " + node_name)
	if DisplayServer.get_name() == "headless" or captures.has(name_text): return
	await RenderingServer.frame_post_draw
	var directory: String = OS.get_environment("BACKROOMS_PLAYTEST_OUTPUT")
	if directory.is_empty(): directory = OS.get_user_data_dir().path_join("phase11")
	check(DirAccess.make_dir_recursive_absolute(directory) == OK, "Screenshot directory exists")
	check(root.get_texture().get_image().save_png(directory.path_join(name_text + ".png")) == OK, "Actual frame captured")
	captures.append(name_text)


func production_run() -> void:
	root.size = Vector2i(1152, 648)
	var main: Control = MAIN.instantiate() as Control
	root.add_child(main)
	var owner: TurnManager = main.get_node("TurnManager") as TurnManager
	var state: RunState = owner.run_state
	var deck: DeckState = state.deck_state
	var encountered_hound: bool = false
	var encountered_smiler: bool = false
	await capture(main, "level0_events_objective")
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
				encountered_hound = encountered_hound or entity.entity_id == CURRENT_6.entry_entity.id
				encountered_smiler = encountered_smiler or entity.entity_id == CURRENT_6.followup_entity.id
				await capture(main, "smiler" if entity.entity_id == CURRENT_6.followup_entity.id else "hound_mixed")
				if entity.entity_id == CURRENT_6.followup_entity.id:
					var extinguish: Array[CardInstance] = candidates(owner, CardData.EffectType.EXTINGUISH)
					if not extinguish.is_empty(): chosen = extinguish[0]
					# Expose once if possible, then extinguish using the same real equipment opportunity.
					if chosen == null and not entity.light_exposed and state.ap >= 2:
						var light: Array[CardInstance] = candidates(owner, CardData.EffectType.LIGHT)
						if not light.is_empty(): chosen = light[0]
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
			check(not button.disabled, "Production route uses enabled actual hand card")
			button.pressed.emit()
			await _claim(main)
		var floor: FloorState = state.floor_state
		if floor.current_objective == null and floor.remaining_fresh_objectives.is_empty() and floor.entity == null and (owner.floor_data.id == CURRENT_0.id or floor.resolved_entity_ids.has(CURRENT_6.followup_entity.id)):
			var exits: Array[CardInstance] = candidates(owner, CardData.EffectType.CUTOUT_SAFE)
			if exits.is_empty(): exits = candidates(owner, CardData.EffectType.CUTOUT_RUSHED)
			if not exits.is_empty():
				ui_button(main, exits[0]).pressed.emit()
				await capture(main, "level6_entry" if not owner.floor_data.is_placeholder else "summary")
		if not owner.floor_data.is_placeholder: (main.get_node("%EndTurn") as Button).pressed.emit()
	check(owner.floor_data.is_placeholder and state.player_hp > 0 and state.deck_state == deck and state.metrics.floor_exits.size() == 2, "Current production Level 0 → Level 6 → exit completes alive in one run/hand/AP loop")
	check(encountered_hound and encountered_smiler and state.metrics.resolved_alive.has("笑魇"), "Both Omen encounters occur and Smiler resolves alive")
	check(not (main.get_node("%DebugPanel") as Control).visible, "No developer controls in production UI")
	print("[PHASE11] turns=%d hp=%d rewards=%d dead=%d/%d entities=%s" % [state.turn_number, state.player_hp, state.metrics.cards_rewarded, state.metrics.dead_hands, state.metrics.hands_checked, state.metrics.entity_encounters])
	await capture(main, "summary")
	main.free()
