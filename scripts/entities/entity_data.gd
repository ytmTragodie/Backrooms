class_name EntityData
extends Resource

enum BehaviorType { PURSUIT, LIGHT_REACTIVE }

@export var id: StringName
@export var display_name: String
@export var max_hp: int = 18
@export var initial_state: StringName = &"WATCHING"
@export var normal_damage: int = 4
@export var aggressive_damage: int = 5
@export var behavior_type: BehaviorType = BehaviorType.PURSUIT
@export var rule_insight: InsightData
