class_name CutOutRouteData
extends Resource
@export var id: StringName
@export var display_name: String
@export var destinations: Array[CutOutDestinationData] = []
@export var modifiers: Array[CutOutModifierData] = []
# 末端是零代价/代价出口，不是条件门；生命不足时仍能选择并明确结算本局。
@export var hp_cost: int = 0
@export var stress_cost: int = 0
