class_name OpeningStoryData
extends Resource
## 开场演出静态配置，不持有 RunState，也不驱动地图/战斗规则。
@export var background_id: StringName = &"intro_background"
@export var audio_id: StringName = &"music_intro"
@export var lines: PackedStringArray = []
@export var characters_per_second: float = 18
@export var hold_seconds: float = 1.6
