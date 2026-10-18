class_name HandView
extends HBoxContainer


func _ready() -> void:
	alignment = BoxContainer.ALIGNMENT_CENTER
	add_theme_constant_override("separation", 12)
	resized.connect(update_dimensions)
	child_order_changed.connect(update_dimensions)
	update_dimensions()


func update_dimensions() -> void:
	if not is_inside_tree(): return
	var height: float = clampf(get_viewport_rect().size.y * 0.30, 190, 282)
	# 预留抬牌空间，悬停不覆盖装备状态或主牌桌。
	custom_minimum_size.y = height + 12
	var count: int = get_child_count()
	if count == 0: return
	var width: float = minf(height * 0.714, (size.x - maxi(0, count - 1) * 12) / count)
	for child: Node in get_children():
		if child is PlayerCardView:
			(child as Control).size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			(child as Control).size_flags_vertical = Control.SIZE_SHRINK_END
			(child as Control).custom_minimum_size = Vector2(width, height)

