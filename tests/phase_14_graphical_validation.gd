extends "res://tests/phase_14_validation.gd"
func _initialize() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Graphical validation requires an actual window")
		quit(1)
		return
	_graphical = true
	root.title = "后室：Phase 14 地图与战斗验收"
	super._initialize()
