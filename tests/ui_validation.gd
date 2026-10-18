extends "res://tests/migration_test_base.gd"


func label() -> String:
	return "Player UI / hidden debug tools"


func tests() -> void:
	# 使用常见窗口比例检查主布局，避免默认无窗口测试尺寸掩盖裁切。
	root.size = Vector2i(1152, 648)
	await _test_default_entry()
	await _test_debug_panel()
	await _test_generated_hand()


func _test_default_entry() -> void:
	var main: Control = MAIN.instantiate() as Control
	(main.get_node("TurnManager") as TurnManager).floor_data = preload("res://tests/fixtures/phase9/floors/floor_level_0.tres")
	(main.get_node("TurnManager") as TurnManager).starter_deck = preload("res://tests/fixtures/phase9/cards/run_deck.tres")
	root.add_child(main)
	var owner: TurnManager = main.get_node("TurnManager") as TurnManager
	check(owner.floor_data.id == LEVEL_0.id and owner.run_state.player_hp == 30 and owner.run_state.ap == 3 and owner.run_state.deck_state.hand.size() == 5, "Normal Main entry starts Level 0 directly without a scenario selector")
	check(owner.run_state.deck_state.get_card_count() == DECK.cards.size(), "Normal entry keeps the production run deck")
	for removed: String in ["%CardMode", "%EquipmentPicker", "%ResourcePicker", "%NewLevel0", "%NewLevel6", "%FloorContext"]:
		check(main.get_node_or_null(removed) == null, "Removed global/developer control: %s" % removed)
	for value: String in ["生命", "压力", "威胁", "认知", "行动点", "回合", "防护"]:
		check((main.get_node("%RunStats") as Label).text.contains(value), "Top status retains %s" % value)
	for value: String in ["手电筒", "撬棍", "杏仁水"]:
		check((main.get_node("%EquipmentStatus") as Label).text.contains(value), "Compact equipment status retains %s" % value)
	check((main.get_node("%EquipmentStatus") as Label).mouse_filter == Control.MOUSE_FILTER_IGNORE, "Carried equipment status is display only")
	check((main.get_node("%SituationName") as Label).text.contains("目标牌") and not (main.get_node("%EntityCard") as Button).visible, "Default board renders real Situation and hides empty Entity slot")
	check(not (main.get_node("%DebugPanel") as Control).visible and (main.get_node("%DebugPanel") as Control).get_parent() == main, "Debug panel is hidden and outside the normal layout")
	_check_default_controls(main)
	var before: Dictionary = snapshot(owner)
	(main.get_node("%WorldCard") as Button).pressed.emit()
	check(snapshot(owner) == before, "World Card only selects, without revealing or granting effects")
	var hand: HBoxContainer = main.get_node("%Hand") as HBoxContainer
	await process_frame
	await _mouse_click(hand.get_child(0) as Control, MOUSE_BUTTON_RIGHT)
	check(snapshot(owner) == before and main.find_children("*", "PopupMenu", true, false).is_empty(), "Right-click shows no verb menu and changes no gameplay state")
	await _mouse_click(hand.get_child(0) as Control)
	check(owner.run_state.floor_state.current_objective.explore_progress == 3 and owner.run_state.ap == 2, "One real mouse click directly investigates without action selection")
	check(main.find_children("*", "PopupMenu", true, false).is_empty(), "Playing a card creates no gameplay-action list")
	await process_frame
	await process_frame
	for name: String in ["%WorldCard", "%Hand", "%EndTurn", "%EquipmentStatus"]:
		check(main.get_viewport_rect().encloses((main.get_node(name) as Control).get_global_rect()), "Normal layout contains %s" % name)
	main.free()


func _test_debug_panel() -> void:
	var main: Control = MAIN.instantiate() as Control
	(main.get_node("TurnManager") as TurnManager).floor_data = preload("res://tests/fixtures/phase9/floors/floor_level_0.tres")
	(main.get_node("TurnManager") as TurnManager).starter_deck = preload("res://tests/fixtures/phase9/cards/run_deck.tres")
	root.add_child(main)
	var owner: TurnManager = main.get_node("TurnManager") as TurnManager
	var panel: Control = main.get_node("%DebugPanel") as Control
	var before: Dictionary = snapshot(owner)
	await _press_f8()
	check(panel.visible == OS.is_debug_build(), "F8 opens developer tools only in a debug build")
	check(snapshot(owner) == before, "Debug visibility does not mutate gameplay")
	if OS.is_debug_build():
		await _press_f8(true)
		check(panel.visible, "Key-repeat does not repeatedly toggle developer panel")
		await _press_f8()
		check(not panel.visible and snapshot(owner) == before, "F8 closes debug panel without changing state")
		await _press_f8()
		(panel.get_node("Padding/Layout/StartLevel6") as Button).pressed.emit()
		var mixed: TurnManager = main.get_node("TurnManager") as TurnManager
		check(mixed != owner and mixed.floor_data.id == LEVEL_6.id and not panel.visible, "Explicit debug test-run request closes panel and creates a separate new run")
		check(not (main.get_node("%EntityCard") as Button).visible and mixed.run_state.floor_state.board_state.active_events.size() == 2, "Production Level 6 foreshadows Hound through an Omen")
		for turn: int in range(3):
			mixed.end_turn()
		check((main.get_node("%EntityCard") as Button).visible and (main.get_node("%EntityInformation") as Label).text.contains("猎犬"), "Normal board renders Situation + Hound with no testing action bar")
		await process_frame
		await process_frame
		for name: String in ["%WorldCard", "%EntityCard", "%Hand", "%EndTurn"]:
			check(main.get_viewport_rect().encloses((main.get_node(name) as Control).get_global_rect()), "Mixed board layout contains %s" % name)
		_check_default_controls(main)
		await _press_f8()
		(panel.get_node("Padding/Layout/StartLevel0") as Button).pressed.emit()
		check((main.get_node("TurnManager") as TurnManager).floor_data.id == LEVEL_0.id and not panel.visible, "Retained Level 0 fixture also remains confined to hidden debug panel")
	main.free()


func _test_generated_hand() -> void:
	var main: Control = MAIN.instantiate() as Control
	(main.get_node("TurnManager") as TurnManager).floor_data = preload("res://tests/fixtures/phase9/floors/floor_level_0.tres")
	(main.get_node("TurnManager") as TurnManager).starter_deck = preload("res://tests/fixtures/phase9/cards/run_deck.tres")
	(main.get_node("TurnManager") as TurnManager).floor_data = LEVEL_6
	root.add_child(main)
	var owner: TurnManager = main.get_node("TurnManager") as TurnManager
	var run: RunState = owner.run_state
	var hand: HBoxContainer = main.get_node("%Hand") as HBoxContainer
	var light: CardInstance = generated(owner, &"light")
	check(light != null and hand.get_child_count() == 6, "Five normal cards and one equipment card share the same visible hand")
	var index: int = run.deck_state.hand.find(light)
	var button: Button = hand.get_child(index) as Button
	check(button.text.contains("照明") and button.text.contains("装备牌") and button.get_node_or_null("CardActions") == null, "Generated equipment card has a readable primary action and no generic mode selector")
	await process_frame
	await process_frame
	for node: Control in [hand, button, main.get_node("%EndTurn") as Control]:
		check(main.get_viewport_rect().encloses(node.get_global_rect()), "Six-card layout is contained at the normal window aspect ratio")
	var battery: EquipmentInstance = run.equipment_slots[0]
	await _mouse_click(button)
	check(run.ap == 2 and battery.remaining_uses == 2 and run.floor_state.light_active and generated(owner, &"extinguish") == light, "Actual click lights and exposes separate Extinguish definition in the same hand position")
	check(run.deck_state.discard_pile.is_empty(), "Equipment click does not pollute normal discard")
	var before: Dictionary = snapshot(owner)
	check(main.find_children("*", "PopupMenu", true, false).is_empty(), "Unified hand has no mode menus")
	index = run.deck_state.hand.find(light)
	button = hand.get_child(index) as Button
	check(button.text.contains("熄灯"), "LIGHT on exposes Extinguish as its own explicit card")
	await _mouse_click(button)
	check(not run.floor_state.light_active and battery.remaining_uses == 2 and generated(owner, &"light") == light, "Explicit Extinguish click costs AP without consuming battery")
	(main.get_node("%EndTurn") as Button).pressed.emit()
	var exit_card: CardInstance = generated(owner, &"rushed")
	check(exit_card != null, "Minimum floor stay generates an explicit exit hand card")
	index = run.deck_state.hand.find(exit_card)
	button = hand.get_child(index) as Button
	check(button.text.contains("仓促切出") and button.text.contains("保留") and button.text.contains("楼层临时牌"), "Exit card displays source and intentional hand-slot cost")
	(main.get_node("%EndTurn") as Button).pressed.emit()
	check(generated(owner, &"rushed") == exit_card and run.deck_state.hand.size() == 6, "UI End Turn retains the floor card while normal refill and one equipment generation share the hand")
	run.ap = 0
	main._refresh_state()
	index = run.deck_state.hand.find(exit_card)
	button = hand.get_child(index) as Button
	check(button.disabled and button.get_node_or_null("CardActions") == null, "Zero AP disables the paid exit card; old free forced branches are absent")
	before = snapshot(owner)
	await _mouse_click(button)
	check(snapshot(owner) == before, "Disabled generated card mouse click changes nothing")
	check(not (main.get_node("%DebugPanel") as Control).visible, "All generated-card gameplay stays independent of developer panel")
	_check_default_controls(main)
	main.free()


func _mouse_click(control: Control, mouse_button: MouseButton = MOUSE_BUTTON_LEFT) -> void:
	# push_input 使用视口坐标，显式标记本地坐标以覆盖实际鼠标命中路径。
	var motion: InputEventMouseMotion = InputEventMouseMotion.new()
	motion.position = control.get_global_rect().get_center()
	motion.global_position = motion.position
	root.push_input(motion, true)
	await process_frame
	var press: InputEventMouseButton = InputEventMouseButton.new()
	press.button_index = mouse_button
	press.pressed = true
	press.position = control.get_global_rect().get_center()
	press.global_position = press.position
	press.button_mask = MOUSE_BUTTON_MASK_LEFT if mouse_button == MOUSE_BUTTON_LEFT else MOUSE_BUTTON_MASK_RIGHT
	root.push_input(press, true)
	await process_frame
	var release: InputEventMouseButton = press.duplicate() as InputEventMouseButton
	release.pressed = false
	release.button_mask = 0
	root.push_input(release, true)
	await process_frame


func _press_f8(echo: bool = false) -> void:
	var event: InputEventKey = InputEventKey.new()
	event.keycode = KEY_F8
	event.pressed = true
	event.echo = echo
	root.push_input(event)
	await process_frame


func _check_default_controls(main: Control) -> void:
	var hand: HBoxContainer = main.get_node("%Hand") as HBoxContainer
	for control: Node in main.find_children("*", "Control", true, false):
		check(not control is OptionButton, "No global mode/equipment/resource dropdown remains in the scene")
		if control is Button and (control as Button).is_visible_in_tree():
			check(control == main.get_node("%EndTurn") or control == main.get_node("%WorldCard") or control == main.get_node("%EntityCard") or hand.is_ancestor_of(control), "Visible main actions are only World Card selection, actual hand cards, and End Turn")
