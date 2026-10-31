extends "res://tests/phase_15_validation.gd"
## 对启动导航/迁移引用/字体与音频失败回退做集成验证，不修改玩法规则。
const START: PackedScene = preload("res://scenes/main/Start.tscn")
var app: StartScreen

func _run() -> void:
	_resource_migration()
	_assets()
	await _entry_flow()
	await _natural_story()
	await _audio_transitions()
	if failures.is_empty(): print("[TEST] PASS Phase 16: %d checks; resource migration, menu, story, duplicate input, fonts, audio ownership" % checks)
	else: print("[TEST] FAIL Phase 16: %d / %d" % [failures.size(),checks])
	quit(0 if failures.is_empty() else 1)

func _resource_migration() -> void:
	check(not DirAccess.dir_exists_absolute("res://data/phase15"),"Stage-named runtime data directory is removed")
	var report: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://docs/PHASE_16_RESOURCE_MIGRATION.json"))
	check(report.moves.size() == 65,"All 65 resources mapped")
	var audit: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://docs/PHASE_16_ASSET_AUDIT.json"))
	for row: Dictionary in audit.data_inventory: check(load("res://"+String(row.path)) != null,"All data resources load: "+String(row.path))
	for path: String in report.moves.values():
		check(ResourceLoader.exists("res://"+path) and load("res://"+path) != null,"Moved resource loads: "+path)
	check(ContentValidator.validate(GAME).is_empty(),"All current connected business data validates")
	check(ProjectSettings.get_setting("application/run/main_scene") == "res://scenes/main/Start.tscn","Project boots into actual main menu")
	check(FileAccess.file_exists("res://assets/ui_asset_pack/License.txt") and FileAccess.file_exists("res://assets/ref/backrooms_card_template_v1/README.md"),"Original pack and references retained for approval")

func _assets() -> void:
	for role: StringName in [&"body",&"display",&"numbers",&"archive"]:
		var font: Font = GameUITheme.font(role)
		for character: String in "生命压力补给行动点情报0123456789→？": check(font.has_char(character.unicode_at(0)),"Role has readable glyph or fallback: "+String(role)+character)
	var preview: bool = AssetCatalog.development_preview
	AssetCatalog.development_preview = false
	check(AssetCatalog.font(&"font_archive") == null and AssetCatalog.audio(&"music_menu") == null,"Unverified assets unavailable outside development preview")
	check(GameUITheme.font(&"display") != null and AssetCatalog.texture(&"ui_archive_normal") != null,"Release fallback remains usable")
	AssetCatalog.development_preview = preview
	check(AssetCatalog.audio(&"audio_button_click") != null,"Adopted CC0 feedback sound loads")
	check(AssetCatalog.audio(&"not_provided") == null,"Missing audio stays silent")

func _entry_flow() -> void:
	app = START.instantiate() as StartScreen
	root.add_child(app)
	await process_frame
	check(app.page == StartScreen.Page.MENU and app.game_view == null,"Menu does not initialize RunState")
	var placeholders: int = 0
	for button: Node in app.find_children("*","Button",true,false):
		if (button as Button).disabled:
			placeholders += 1
			check(not (button as Button).tooltip_text.is_empty(),"Unavailable entry has explanation")
	check(placeholders == 3,"Continue/settings/guide clearly disabled")
	app.request_section(&"settings")
	check(app.page == StartScreen.Page.MENU and app.game_view == null and app._menu_notice.text == StartScreen.RESERVED[&"settings"],"Reserved navigation interface gives feedback without starting a run")
	await capture(null,"phase16_menu")
	app.begin_run()
	app.begin_run()
	check(app.page == StartScreen.Page.INTRO and app.game_view == null,"Double start does not create runs behind intro")
	check(app.find_children("*","OpeningStoryView",true,false).size() == 1,"Only one intro exists")
	await process_frame
	await capture(null,"phase16_intro")
	var story: OpeningStoryView = app.story_view
	story.finish()
	story.finish()
	await process_frame
	check(app.page == StartScreen.Page.GAME and app.game_view != null,"Skip enters original game")
	var run: RunState = app.game_view.manager.run_state
	check(run != null and run.player.hp == 30 and run.revision == 0 and run.floor_state.map.current_node_id == &"entry","Original initialization starts once at real map entry")
	var expected: RunState = state(1)
	check(run.rng.state == expected.rng.state,"Intro/skip never consume gameplay RNG")
	app.begin_run()
	check(app.game_view.manager.run_state == run,"Late duplicate start cannot replace active run")
	await capture(app.game_view,"phase16_map")
	if _graphical:
		start_combat(run,enemy("entity_hound"))
		app.game_view.refresh()
		await capture(app.game_view,"phase16_combat")
		var playable: PlayerCardView
		for node: Node in app.game_view.find_children("*","PlayerCardView",true,false):
			if not (node as PlayerCardView).disabled: playable = node as PlayerCardView; break
		var revision: int = run.revision
		await _mouse_click(playable)
		check(run.revision == revision+1,"Real hand click still commits one transaction")
	app.game_view.return_to_menu_requested.emit()
	await process_frame
	check(app.page == StartScreen.Page.MENU and app.game_view == null,"Result navigation returns to menu without retained run")
	app.free()
	app = null
	await process_frame

func _natural_story() -> void:
	var source: OpeningStoryData = load("res://data/ui/opening_story.tres") as OpeningStoryData
	var fast: OpeningStoryData = source.duplicate(false) as OpeningStoryData
	fast.lines = PackedStringArray(["门", "光"])
	fast.characters_per_second = 10000
	fast.hold_seconds = 0
	app = START.instantiate() as StartScreen
	app.opening = fast
	root.add_child(app)
	app.begin_run()
	await create_timer(3.8).timeout
	check(app.page == StartScreen.Page.GAME and app.game_view.manager.run_state.revision == 0,"Natural story completion initializes only once")
	check(source.lines.size() == 5 and source.characters_per_second == 18,"Story fixture never mutates shared config")
	app.free()
	app = null
	await process_frame

func _audio_transitions() -> void:
	var audio: AssetAudio = root.get_node("GameAudio") as AssetAudio
	check(root.find_children("*","AssetAudio",true,false).size() == 1,"One application audio owner")
	for context: StringName in [&"music_menu",&"music_intro",&"ambience_level_0",&"music_combat",&"ambience_level_6"]:
		audio.play_context(context)
		audio.play_context(context)
	check(audio.current_context == &"ambience_level_6","Rapid context changes keep newest track")
	await create_timer(0.85).timeout
	var playing: int = 0
	for player: AudioStreamPlayer in audio._music:
		if player.playing: playing += 1
	check(playing <= 1,"Crossfade ends with at most one BGM")
	if _graphical and AssetCatalog.is_provided(&"ambience_level_6"): check(playing == 1,"Real window actually plays selected ambience")
	audio.play_context(&"missing_music")
	await create_timer(0.85).timeout
	check(not audio._music[0].playing and not audio._music[1].playing,"Missing music fades to silence")
	var volume: float = AudioServer.get_bus_volume_db(AudioServer.get_bus_index(&"SFX"))
	audio.set_volume(&"SFX",0)
	check(AudioServer.is_bus_mute(AudioServer.get_bus_index(&"SFX")),"Volume API affects real bus")
	audio.set_volume(&"SFX",db_to_linear(volume))
