extends "res://tests/phase_15_validation.gd"
## 真窗口验收；游戏内没有场景选择或测试按钮。
func _initialize() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Phase 15 graphical validation requires an actual window")
		quit(1)
		return
	_graphical = true
	root.title = "后室：Phase 15 楼层网络与七层验收"
	root.size = Vector2i(1152,648)
	super._initialize()

func _new_ui() -> void:
	var main: MainGameView = MAIN.instantiate() as MainGameView
	root.add_child(main)
	await process_frame
	await capture(main,"phase15_level0")
	var network_button: Button
	for button: Node in main.find_children("*","Button",true,false):
		if (button as Button).text == "楼层网络": network_button = button as Button
	var before: String = snapshot(main.manager.run_state)
	await _mouse_click(network_button)
	await process_frame
	check(snapshot(main.manager.run_state) == before,"Clicking network leaves gameplay and RNG unchanged")
	await capture(main,"phase15_network_unknown")
	var overlay: LevelNetworkView = main.get_node("LevelNetwork") as LevelNetworkView
	check(overlay.find_children("*","Button",true,false).size() == 1,"Network has no teleport controls")
	await _mouse_click(overlay.find_children("*","Button",true,false)[0] as Button)
	await process_frame
	# 正式种子，以相同应用入口和命令走完整三层；测试策略可读取迷雾内容。
	main.manager.start_run(verified_seed)
	for wanted: StringName in [&"level0_service",&"level6_waves",&"level7_fire_door"]:
		var run: RunState = main.manager.run_state
		var target: MapNodeState
		for node: MapNodeState in run.floor_state.map.nodes:
			if node.kind == MapNodeState.Kind.EXIT and node.content_id == wanted: target = node
		check(target != null,"Production window route exists: "+String(wanted))
		if target == null: break
		for step: int in range(220):
			if run.flow.phase in [RunFlowState.Phase.CUTOUT,RunFlowState.Phase.RESULT]: break
			if run.floor_state.floor_id == &"floor_level_7": await capture(main,"phase15_level7_"+phase_name(run))
			check(main.manager.submit(_toward(run,target.id)).success,"Window legal command succeeds")
		await capture(main,"phase15_exit_"+String(run.floor_state.floor_id))
		check(main.manager.submit(command(run,GameCommand.Kind.CUTOUT)).success,"Window CutOut succeeds")
	check(main.manager.run_state.history.floors.has(&"floor_level_7") and main.manager.run_state.flow.phase == RunFlowState.Phase.RESULT,"Visible production run traverses Level7 and reaches result")
	await capture(main,"phase15_result")
	main._show_network()
	await capture(main,"phase15_network_known")
	main.get_node("LevelNetwork").free()
	var encounter: RunState = state(31,&"floor_level_7")
	start_combat(encounter,load("res://data/phase15/entity_thing7.tres") as EntityData)
	main.manager.run_state = encounter
	main.refresh()
	await capture(main,"phase15_thing7_combat")
	var light_card: CardInstance
	for card_instance: CardInstance in encounter.combat.deck.hand:
		if card_instance.definition.effects.any(func(e: EffectData) -> bool: return e.effect_type == EffectData.EffectType.LIGHT and e.amount > 0): light_card = card_instance
	check(light_card != null and main.manager.submit(play_command(encounter,light_card)).success,"Visible actual hand light resolves Thing alive")
	await capture(main,"phase15_thing7_withdrawn")
	# 明确的 UI 夹具：额外检查有代价出口和窄屏布局，不改正式数据资源。
	for dimensions: Vector2i in [Vector2i(1152,648),Vector2i(1280,720),Vector2i(1920,1080)]:
		root.size = dimensions
		var fixture: RunState = state(7,&"floor_level_7")
		place_exit(fixture)
		fixture.floor_state.map.find(fixture.floor_state.map.current_node_id).content_id = &"level7_cave"
		main.manager.run_state = fixture
		main.refresh()
		await process_frame
		await process_frame
		check(root.get_visible_rect().encloses(main._status.get_global_rect()),"Status fits Phase15 window")
		for button: Node in main.find_children("*","Button",true,false): check(root.get_visible_rect().encloses((button as Control).get_global_rect()),"Exit button fits supported window")
		await capture(main,"phase15_paid_exit_%dx%d" % [dimensions.x,dimensions.y])
	main.free()
