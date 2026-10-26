class_name LevelNetworkView
extends PanelContainer
## 本界面没有 GameCommand 或传送入口；关闭/滚动只改变 UI。
func present(state: RunState, game: GameData) -> void:
	name = "LevelNetwork"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	offset_left = 30
	offset_right = -30
	offset_top = 30
	offset_bottom = -30
	z_index = 90
	var box: VBoxContainer = VBoxContainer.new()
	add_child(box)
	var header: HBoxContainer = HBoxContainer.new()
	box.add_child(header)
	var title: Label = GameUITheme.label(header,"楼层网络 · 已知切出联系",25)
	title.size_flags_horizontal = SIZE_EXPAND_FILL
	var close: Button = Button.new()
	close.text = "返回当前遭遇"
	header.add_child(close)
	close.pressed.connect(queue_free)
	var note: Label = GameUITheme.label(box,"仅供规划，不能传送。概率按当前持有条件估计；到达出口时重新计算。",14)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var levels: PackedStringArray = []
	for floor: FloorData in game.floors:
		if state.player.knowledge.floors.has(floor.id) or state.history.floors.has(floor.id): levels.append("%s（%s）" % [floor.display_name,"已访问 %d 次" % int(state.history.visits.get(floor.id,0)) if state.history.floors.has(floor.id) else "已发现"])
	GameUITheme.label(box,"　｜　".join(levels),17,GameUITheme.GREEN)
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.size_flags_vertical = SIZE_EXPAND_FILL
	box.add_child(scroll)
	var list: VBoxContainer = VBoxContainer.new()
	list.size_flags_horizontal = SIZE_EXPAND_FILL
	scroll.add_child(list)
	var rows: Array[Dictionary] = LevelNetworkSystem.rows(state,game)
	if rows.is_empty(): GameUITheme.label(list,"尚未记录切出联系。沿当前地图探索，抵达出口或阅读路线记录。",18)
	for row: Dictionary in rows:
		var panel: PanelContainer = PanelContainer.new()
		list.add_child(panel)
		var group: VBoxContainer = VBoxContainer.new()
		panel.add_child(group)
		GameUITheme.label(group,"%s → %s　｜　代价：生命 %d / 压力 +%d" % [row.source,row.route,row.hp_cost,row.stress_cost],18,GameUITheme.GOLD)
		for target: Dictionary in row.targets:
			var text: String = "　↳ %s　%.1f%%　%s" % [target.label,target.probability*100,"已穿越" if target.traversed else "已知"]
			if not target.conditions.is_empty(): text += "　条件："+target.conditions
			var label: Label = GameUITheme.label(group,text,16)
			label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
