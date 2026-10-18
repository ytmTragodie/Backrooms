extends "res://tests/phase_12_validation.gd"


func label() -> String:
	return "Phase 12 / actual window, 3 resolutions, 11 required visual states"


func tests() -> void:
	if DisplayServer.get_name() == "headless":
		check(false, "Actual window/render driver required")
		return
	_screenshots = true
	root.title = "后室档案 · Phase 12 视觉验收"
	await super.tests()
	for dimensions: Vector2i in [Vector2i(1152, 648), Vector2i(1280, 720), Vector2i(1920, 1080)]:
		for name_text: String in ["level0_normal_objective", "level0_event", "level6_hound", "event_hound", "smiler", "equipment_generated", "rushed_cutout", "safe_cutout", "card_reward", "safe_point", "summary"]:
			check(_saved.has("%dx%d/%s" % [dimensions.x, dimensions.y, name_text]), "Required rendered state exists at each resolution")
	print("[GRAPHICAL] adapter=%s screenshots=%d output=%s" % [RenderingServer.get_video_adapter_name(), _saved.size(), OS.get_environment("BACKROOMS_PLAYTEST_OUTPUT")])
