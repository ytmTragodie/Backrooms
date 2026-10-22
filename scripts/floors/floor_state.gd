class_name FloorState
extends RefCounted
var definition: FloorData
var map: FloorMapState
var floor_id: StringName:
	get: return definition.id
