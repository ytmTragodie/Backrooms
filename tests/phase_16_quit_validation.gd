extends "res://tests/phase_16_validation.gd"
## 专门验证真实退出入口，不能靠测试脚本自行 quit 冒充按钮工作。
func _run() -> void:
	app = START.instantiate() as StartScreen
	root.add_child(app)
	await create_timer(0.8).timeout
	var button: Button
	for node: Node in app.find_children("*","Button",true,false):
		if (node as Button).text == "退出游戏": button = node as Button
	if DisplayServer.get_name() == "headless": button.pressed.emit()
	else: await _mouse_click(button)
	check(app.page == StartScreen.Page.CLOSING,"Quit entry enters closing phase")
	check((root.get_node("GameAudio") as AssetAudio).current_context.is_empty(),"Quit releases playing audio")
	if failures.is_empty(): print("[TEST] PASS Phase 16 quit: button schedules clean desktop exit")
	else: quit(1); return
	await create_timer(0.5).timeout
	push_error("[TEST] FAIL Quit button did not exit application")
	quit(1)
