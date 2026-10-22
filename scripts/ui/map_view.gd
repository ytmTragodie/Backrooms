class_name MapView
extends Control
## 拓扑/迷雾只读渲染；节点选择提交捕获上下文的 Command。
signal command_requested(command: GameCommand)
var _state: RunState
var _map: FloorMapState
var _points: Array[Vector2] = []
const NAMES: Array[String] = ["战斗", "精英", "事件", "休息", "补给", "交易", "出口", "入口"]

func present(state: RunState) -> void:
	_state = state
	_map = state.floor_state.map
	custom_minimum_size = Vector2(0, 300)
	size_flags_vertical = SIZE_EXPAND_FILL
	resized.connect(_layout)
	for node: MapNodeState in state.floor_state.map.nodes:
		var button: Button = Button.new()
		button.name = String(node.id)
		var known: bool = node.visibility == MapNodeState.Visibility.REVEALED
		button.text = NAMES[node.kind] if known else "？"
		if node.resolution == MapNodeState.Resolution.RESOLVED: button.text += " · 已过"
		if node.id == state.floor_state.map.current_node_id: button.text += "\n当前位置"
		button.custom_minimum_size = Vector2(90, 44)
		button.disabled = not state.floor_state.map.next_ids().has(node.id)
		button.tooltip_text = "已结算，仅通行" if node.resolution == MapNodeState.Resolution.RESOLVED else ("可前进：" + NAMES[node.kind] if known else "位置与连线已知，具体内容未知")
		if node.kind == MapNodeState.Kind.EXIT and state.player.knowledge.exits.has(node.content_id):
			for route: CutOutRouteData in state.floor_state.definition.cutout_route_pool:
				if route.id == node.content_id: button.tooltip_text = "已知出口：" + route.display_name
		if not button.disabled: button.add_theme_stylebox_override("normal", GameUITheme.panel(Color("27352f"), GameUITheme.GREEN, 2))
		var command: GameCommand = GameCommand.new(GameCommand.Kind.MOVE, state)
		command.node_id = node.id
		button.pressed.connect(func() -> void: command_requested.emit(command))
		add_child(button)
	_layout.call_deferred()

func _layout() -> void:
	# 旧视图可能排队销毁；不能沿 RunState 读到已经切换的新地图拓扑。
	if not is_inside_tree() or is_queued_for_deletion() or _map == null: return
	_points.clear()
	for index: int in range(_map.nodes.size()):
		var node: MapNodeState = _map.nodes[index]
		var point: Vector2 = Vector2(50, 32) + node.position * Vector2(maxf(1, size.x - 100), maxf(1, size.y - 64))
		_points.append(point)
		(get_child(index) as Control).position = point - Vector2(45, 22)
	queue_redraw()

func _draw() -> void:
	if _map == null or _points.size() != _map.nodes.size(): return
	for edge: Vector2i in _map.edges:
		var active: bool = _map.nodes[edge.x].id == _map.current_node_id
		draw_line(_points[edge.x], _points[edge.y], GameUITheme.GREEN if active else Color("4a514c"), 3 if active else 1, true)
		var direction: Vector2 = (_points[edge.y] - _points[edge.x]).normalized()
		var tip: Vector2 = _points[edge.y] - direction * 49
		draw_line(tip, tip - direction.rotated(0.55) * 9, GameUITheme.GOLD, 1, true)
		draw_line(tip, tip - direction.rotated(-0.55) * 9, GameUITheme.GOLD, 1, true)
