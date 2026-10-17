class_name EntitySystem
extends RefCounted

const INTENTS: Dictionary = {
	&"WATCHING": &"approach", &"APPROACHING": &"bite", &"CHASING": &"lunge",
	&"STAGGERED": &"recover", &"DEFEATED": &"none", &"DISENGAGED": &"none",
}


static func validate_definition(data: EntityData) -> StringName:
	if data == null or data.id.is_empty() or data.max_hp <= 0 or data.normal_damage < 0 or data.aggressive_damage < 0 or data.initial_state not in [&"WATCHING", &"APPROACHING"]:
		return &"invalid_entity_definition"
	return &""


static func spawn(data: EntityData) -> EntityInstance:
	assert(validate_definition(data).is_empty(), "Invalid entity definition")
	var entity: EntityInstance = EntityInstance.new()
	entity.entity_id = data.id
	entity.max_hp = data.max_hp
	entity.hp = data.max_hp
	entity.state = data.initial_state
	entity.intent = INTENTS[entity.state]
	return entity


static func validate(floor: FloorState, data: FloorData) -> StringName:
	if floor.player_block < 0:
		return &"invalid_entity_state"
	var entity: EntityInstance = floor.entity
	if data.entry_entity == null:
		return &"" if entity == null else &"invalid_entity_context"
	var error: StringName = validate_definition(data.entry_entity)
	if not error.is_empty():
		return error
	if entity == null or entity.entity_id != data.entry_entity.id or entity.max_hp != data.entry_entity.max_hp:
		return &"invalid_entity_context"
	if entity.hp < 0 or entity.hp > entity.max_hp or not INTENTS.has(entity.state) or entity.intent != INTENTS.get(entity.state):
		return &"invalid_entity_state"
	if (entity.hp == 0) != (entity.state == &"DEFEATED"):
		return &"invalid_entity_state"
	return &""


static func plan_card(result: ActionResult, definition: CardData, state: RunState) -> StringName:
	var entity: EntityInstance = state.floor_state.entity
	match definition.effect_type:
		CardData.EffectType.BLOCK:
			result.block_gained = definition.effect_value
		CardData.EffectType.RUN:
			result.threat_delta = mini(1, FloorState.MAX_THREAT - state.floor_state.threat)
			result.threat_reason = &"player_ran"
			if entity != null and entity.active:
				_set_next_state(result, &"DISENGAGED" if entity.state == &"STAGGERED" else &"CHASING")
		CardData.EffectType.ATTACK, CardData.EffectType.PLACEHOLDER_DAMAGE:
			if entity == null or not entity.active:
				return &"no_active_entity"
			var damage: int = definition.effect_value if definition.effect_type == CardData.EffectType.ATTACK else definition.placeholder_damage
			result.damage_requested = damage
			result.entity_damage = mini(damage, entity.hp)
			result.entity_hp_after = entity.hp - result.entity_damage
			result.entity_defeated = result.entity_hp_after == 0
			_set_next_state(result, &"DEFEATED" if result.entity_defeated else (&"APPROACHING" if entity.state == &"WATCHING" else entity.state))
	return &""


static func plan_end_turn(result: ActionResult, state: RunState, data: FloorData) -> void:
	var entity: EntityInstance = state.floor_state.entity
	result.expire_block = true
	if entity == null or not entity.active:
		return
	# 只执行界面已经公示的意图，每次 End Turn 一次；不用随机 AI 或第二套时钟。
	result.intent_resolved = entity.intent
	var damage: int = 0
	var next_state: StringName = entity.state
	match entity.intent:
		&"approach":
			next_state = &"APPROACHING"
		&"bite":
			damage = data.entry_entity.normal_damage
			next_state = &"CHASING"
		&"lunge":
			damage = data.entry_entity.aggressive_damage
		&"recover":
			next_state = &"WATCHING"
	result.damage_blocked = mini(state.floor_state.player_block, damage)
	result.player_damage = mini(state.player_hp, maxi(0, damage - result.damage_blocked))
	if damage > 0 and result.damage_blocked == damage:
		next_state = &"STAGGERED"
	_set_next_state(result, next_state)


static func _set_next_state(result: ActionResult, next_state: StringName) -> void:
	result.entity_state_after = next_state
	result.entity_intent_after = INTENTS[next_state]


static func commit(result: ActionResult, state: RunState) -> void:
	var floor: FloorState = state.floor_state
	var entity: EntityInstance = floor.entity
	if result.block_gained > 0:
		floor.player_block += result.block_gained
		result.debug_lines.append("[BLOCK] +%d total=%d" % [result.block_gained, floor.player_block])
	if not result.intent_resolved.is_empty():
		result.debug_lines.append("[ENTITY] intent=%s damage=%d blocked=%d" % [result.intent_resolved, result.player_damage, result.damage_blocked])
	if result.player_damage > 0:
		state.player_hp -= result.player_damage
		result.debug_lines.append("[HP] player -%d remaining=%d" % [result.player_damage, state.player_hp])
	if result.expire_block:
		floor.player_block = 0
	if entity == null:
		return
	if result.entity_hp_after >= 0:
		entity.hp = result.entity_hp_after
		result.debug_lines.append("[DAMAGE] %s -%d hp=%d" % [entity.entity_id, result.entity_damage, entity.hp])
	if not result.entity_state_after.is_empty():
		if entity.state != result.entity_state_after:
			result.debug_lines.append("[ENTITY] %s state %s -> %s" % [entity.entity_id, entity.state, result.entity_state_after])
		entity.state = result.entity_state_after
		entity.intent = result.entity_intent_after
	if result.entity_defeated:
		result.debug_lines.append("[ENTITY] defeated %s" % entity.entity_id)
