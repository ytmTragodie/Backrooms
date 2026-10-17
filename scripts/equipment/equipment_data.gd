class_name EquipmentData
extends Resource

enum EffectType { LIGHT, ATTACK, RECOVER }

@export var id: StringName
@export var display_name: String
@export var action_name: String
@export var tags: Array[StringName] = []
@export var counter_kind: StringName = &"charges"
@export var capacity: int = 1
@export var ap_cost: int = 1
@export var effect_type: EffectType = EffectType.LIGHT
@export var effect_value: int = 0
@export var conditional_heal: int = 0
@export var heal_stress_threshold: int = 7
