class_name AssetAudio
extends Node
## 复用原声音服务为唯一应用级实例；音乐/音效只响应展示，不结算玩法。
signal cue_played(id: StringName)
var current_context: StringName
var _music: Array[AudioStreamPlayer] = []
var _effects: Array[AudioStreamPlayer] = []
var _active: int = 0
var _next_effect: int = 0
var _fade: Tween
var _last_hover: int = -1000

func _ready() -> void:
	for bus: StringName in [&"Music",&"SFX"]:
		if AudioServer.get_bus_index(bus) < 0:
			AudioServer.add_bus()
			AudioServer.set_bus_name(AudioServer.bus_count-1,bus)
			AudioServer.set_bus_send(AudioServer.bus_count-1,&"Master")
	for index: int in range(2):
		var player: AudioStreamPlayer = AudioStreamPlayer.new()
		player.bus = &"Music"
		player.volume_db = -70
		add_child(player)
		_music.append(player)
		player.finished.connect(func() -> void:
			if index == _active and player.stream != null: player.play())
	for index: int in range(6):
		var player: AudioStreamPlayer = AudioStreamPlayer.new()
		player.bus = &"SFX"
		player.volume_db = -20
		add_child(player)
		_effects.append(player)
	get_tree().node_added.connect(_bind_button)

func _exit_tree() -> void:
	stop_all()
	GameUITheme.release_fonts()

func stop_all() -> void:
	if _fade != null: _fade.kill()
	_fade = null
	for player: AudioStreamPlayer in _music + _effects:
		player.stop()
		player.stream = null
	current_context = &""

func _bind_button(node: Node) -> void:
	if not node is BaseButton: return
	var button: BaseButton = node as BaseButton
	if button.has_meta(&"audio_bound"): return
	button.set_meta(&"audio_bound",true)
	var reference: WeakRef = weakref(button)
	button.mouse_entered.connect(func() -> void:
		var live: BaseButton = reference.get_ref() as BaseButton
		if live == null or live.disabled or Time.get_ticks_msec()-_last_hover < 90: return
		_last_hover = Time.get_ticks_msec()
		cue(&"audio_button_hover"))
	button.pressed.connect(cue.bind(&"audio_button_click"))

func play_context(id: StringName) -> void:
	if id == current_context: return
	current_context = id
	if _music[_active].stream != null and _music[_active].stream.resource_path == AssetCatalog.path_for(id): return
	if _fade != null: _fade.kill()
	var outgoing: AudioStreamPlayer = _music[_active]
	_active = 1-_active
	var incoming: AudioStreamPlayer = _music[_active]
	incoming.stop()
	incoming.stream = AssetCatalog.audio(id)
	incoming.volume_db = -70
	# 无窗口验证不启动混音；真实窗口验证声音。Dummy 驱动在快速退树时可能尚未释放播放缓冲。
	if incoming.stream != null and DisplayServer.get_name() != "headless": incoming.play()
	_fade = create_tween().set_parallel(true)
	_fade.tween_property(outgoing,"volume_db",-70.0,0.45)
	_fade.tween_property(incoming,"volume_db",-26.0,0.65)
	_fade.chain().tween_callback(outgoing.stop)

func cue(id: StringName) -> void:
	var stream: AudioStream = AssetCatalog.audio(id)
	if stream == null or _effects.is_empty(): return
	var player: AudioStreamPlayer = _effects[_next_effect]
	_next_effect = (_next_effect+1)%_effects.size()
	player.stop()
	player.stream = stream
	if DisplayServer.get_name() != "headless": player.play()
	cue_played.emit(id)

func set_volume(bus: StringName, linear: float) -> void:
	# 设置页后续可直接使用此入口；不创建第二份音量状态。
	var index: int = AudioServer.get_bus_index(bus)
	if index < 0: return
	AudioServer.set_bus_volume_db(index,linear_to_db(clampf(linear,0.001,1.0)))
	AudioServer.set_bus_mute(index,linear <= 0)
