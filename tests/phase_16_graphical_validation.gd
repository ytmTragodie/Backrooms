extends "res://tests/phase_16_validation.gd"
func _initialize() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Phase 16 graphical verification requires actual window")
		quit(1)
		return
	_graphical = true
	root.title = "后室：Phase 16 主菜单与资源验收"
	super._initialize()

func _entry_flow() -> void:
	for dimensions: Vector2i in [Vector2i(1152,648),Vector2i(1280,720),Vector2i(1920,1080)]:
		root.size = dimensions
		app = START.instantiate() as StartScreen
		root.add_child(app)
		await process_frame
		await process_frame
		for node: Node in app.find_children("*","Button",true,false): check(root.get_visible_rect().encloses((node as Control).get_global_rect()),"Menu fits desktop resolution")
		await capture(null,"phase16_menu_%dx%d" % [dimensions.x,dimensions.y])
		await _mouse_click(app.start_button)
		check(app.page == StartScreen.Page.INTRO,"Actual start click enters intro")
		await create_timer(1.8).timeout
		await capture(null,"phase16_intro_%dx%d" % [dimensions.x,dimensions.y])
		await _mouse_click(app.story_view.skip_button)
		await process_frame
		check(app.game_view != null and app.game_view.manager.run_state.player.hp == 30,"Actual skip click enters original run")
		await capture(app.game_view,"phase16_map_%dx%d" % [dimensions.x,dimensions.y])
		app.free()
		app = null
		await process_frame
	root.size = Vector2i(1152,648)
	await super._entry_flow()
