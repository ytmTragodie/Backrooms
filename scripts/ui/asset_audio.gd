class_name AssetAudio
extends Node

var _ambience: AudioStreamPlayer
var _effect: AudioStreamPlayer
var _floor_id: StringName


func _ready() -> void:
	_ambience = AudioStreamPlayer.new()
	_ambience.volume_db = -20
	add_child(_ambience)
	_ambience.finished.connect(func() -> void: _ambience.play())
	_effect = AudioStreamPlayer.new()
	_effect.volume_db = -12
	add_child(_effect)


func floor_changed(id: StringName) -> void:
	if id == _floor_id: return
	_floor_id = id
	_ambience.stop()
	_ambience.stream = AssetCatalog.audio(StringName(String(id).replace("floor_", "ambience_")))
	if _ambience.stream != null: _ambience.play()


func cue(id: StringName) -> void:
	var stream: AudioStream = AssetCatalog.audio(id)
	if stream == null: return
	_effect.stream = stream
	_effect.play()
