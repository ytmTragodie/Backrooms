extends "res://tests/phase_10_validation.gd"

var _saved: PackedStringArray = []
var _output: String


func label() -> String:
	return "Phase 10 / windowed render and input walkthrough"


func tests() -> void:
	graphical = true
	if DisplayServer.get_name() == "headless":
		check(false, "Graphical validation requires an actual window/rendering driver")
		return
	_output = OS.get_environment("BACKROOMS_PLAYTEST_OUTPUT")
	if _output.is_empty():
		_output = OS.get_user_data_dir().path_join("phase10-playtest")
	check(DirAccess.make_dir_recursive_absolute(_output) == OK, "Can save rendered playtest evidence")
	root.title = "后室：切出 Demo · 窗口化走查"
	await full_run(1)
	for name_text: String in ["level0_targeting", "rushed_cutout", "prepared_cutout", "card_reward", "safe_point", "safe_point_candidates", "hound_targeting", "hound_removed", "smiler", "transition", "summary"]:
		check(_saved.has(name_text), "Rendered evidence exists: " + name_text)
	print("[GRAPHICAL] renderer=%s output=%s images=%d" % [RenderingServer.get_video_adapter_name(), _output, _saved.size()])


func checkpoint(main: Control, name_text: String) -> void:
	await super.checkpoint(main, name_text)
	if _saved.has(name_text):
		return
	await RenderingServer.frame_post_draw
	for node_name: String in ["%WorldCard", "%EntityCard", "%Hand", "%EndTurn"]:
		var node: Control = main.get_node(node_name) as Control
		if node.is_visible_in_tree():
			check(main.get_viewport_rect().encloses(node.get_global_rect()), "Rendered frame contains " + node_name)
	print("[GRAPHICAL] capture=%s viewport=%s entity=%s" % [name_text, main.get_viewport_rect(), (main.get_node("%EntityCard") as Control).get_global_rect()])
	var rendered: Image = root.get_texture().get_image()
	check(rendered != null and rendered.get_width() >= 1152 and rendered.get_height() >= 648, "Capture uses actual window viewport texture")
	if rendered != null:
		check(rendered.save_png(_output.path_join(name_text + ".png")) == OK, "Save graphical checkpoint")
		_saved.append(name_text)
