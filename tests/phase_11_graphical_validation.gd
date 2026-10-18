extends "res://tests/phase_11_validation.gd"


func label() -> String:
	return "Phase 11 / actual Compatibility window, input and screenshots"


func tests() -> void:
	if DisplayServer.get_name() == "headless":
		check(false, "Windowed validation requires an actual renderer")
		return
	root.title = "后室：切出 Demo · 事件与素材走查"
	await production_run()
	for name_text: String in ["level0_events_objective", "level6_entry", "hound_mixed", "smiler", "summary"]:
		check(captures.has(name_text), "Rendered evidence exists: " + name_text)
	print("[GRAPHICAL] renderer=%s images=%d output=%s" % [RenderingServer.get_video_adapter_name(), captures.size(), OS.get_environment("BACKROOMS_PLAYTEST_OUTPUT")])
