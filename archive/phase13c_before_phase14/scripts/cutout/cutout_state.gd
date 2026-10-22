class_name CutOutState
extends RefCounted

const MAX_STABILITY: int = 3
const MAX_KNOWLEDGE: int = 2

var stability: int = 0
var destination_knowledge: int = 0
var destination_candidates: Array[StringName] = []
