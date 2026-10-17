class_name RunState
extends RefCounted

const AP_PER_TURN: int = 3

var player_hp: int = 30
var stress: int = 0
# Phase 1 placeholders; these values belong to FloorState when floors are added.
var threat: int = 0
var cognition: int = 0
var turn_number: int = 1
var ap: int = AP_PER_TURN
var deck_state: DeckState = DeckState.new()
var rng_seed: int = 1
var rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _init(seed_value: int = 1) -> void:
	rng_seed = seed_value
	rng.seed = rng_seed
