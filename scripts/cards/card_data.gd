class_name CardData
extends Resource

@export var id: StringName
@export var display_name: String
@export_range(0, 3, 1, "or_greater") var ap_cost: int = 0
# Phase 2 reports this value only; effects and targets belong to later phases.
@export var placeholder_damage: int = 0
