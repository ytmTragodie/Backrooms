class_name OpeningStoryView
extends Control
## 所有 Tween 只改画面；结束信号唯一发出，跳过不会多次初始化新局。
signal completed
@export var story: OpeningStoryData
var _finished: bool = false
var _animation: Tween
var _text: Label
var _flash: ColorRect
var skip_button: Button

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = GameUITheme.build()
	var background: TextureRect = GameUITheme.texture(self,story.background_id)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.modulate = Color(0.24,0.22,0.16)
	_flash = ColorRect.new()
	_flash.mouse_filter = MOUSE_FILTER_IGNORE
	_flash.color = Color(0,0,0,0.35)
	add_child(_flash)
	_flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center: CenterContainer = CenterContainer.new()
	add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_text = GameUITheme.label(center,"",30)
	_text.custom_minimum_size = Vector2(640,150)
	_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	GameUITheme.apply_role(_text,&"display")
	skip_button = Button.new()
	skip_button.text = "跳过开场 · Esc"
	add_child(skip_button)
	skip_button.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	skip_button.position -= Vector2(225,65)
	skip_button.size = Vector2(200,44)
	skip_button.pressed.connect(finish)
	(get_node("/root/GameAudio") as AssetAudio).play_context(story.audio_id)
	_animate.call_deferred()

func _animate() -> void:
	if _finished: return
	_animation = create_tween()
	_animation.tween_property(_flash,"color:a",0.9,0.45)
	_animation.tween_property(_flash,"color:a",0.55,0.18)
	_animation.tween_property(_flash,"color:a",0.8,0.16)
	for line: String in story.lines:
		_animation.tween_callback(func() -> void:
			_text.text = line
			_text.visible_ratio = 0
			_text.modulate.a = 0)
		_animation.tween_property(_text,"modulate:a",1.0,0.35)
		_animation.tween_property(_text,"visible_ratio",1.0,maxf(0.05,line.length()/maxf(1,story.characters_per_second)))
		_animation.tween_interval(maxf(0,story.hold_seconds))
		_animation.tween_property(_text,"modulate:a",0.0,0.35)
	_animation.tween_property(_flash,"color:a",1.0,0.6)
	_animation.tween_callback(finish)

func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		finish()

func finish() -> void:
	if _finished: return
	_finished = true
	if _animation != null: _animation.kill()
	completed.emit()
