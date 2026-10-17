class_name EntitySystem
extends RefCounted

const INTENTS: Dictionary = {
	&"WATCHING": &"approach", &"APPROACHING": &"bite", &"CHASING": &"lunge",
	&"STAGGERED": &"recover", &"DEFEATED": &"none", &"DISENGAGED": &"none",
	&"HIDDEN": &"remain_hidden", &"OBSERVING": &"watch_light", &"AGITATED": &"warn_light",
	&"ATTACKING": &"light_strike", &"WITHDRAWN": &"none",
}
const PURSUIT_STATES: Array[StringName] = [&"WATCHING", &"APPROACHING", &"CHASING", &"STAGGERED", &"DEFEATED", &"DISENGAGED"]
const LIGHT_STATES: Array[StringName] = [&"HIDDEN", &"OBSERVING", &"AGITATED", &"ATTACKING", &"WITHDRAWN", &"DEFEATED"]


static func validate_definition(data: EntityData) -> StringName:
	if data == null or data.id.is_empty() or data.max_hp <= 0 or data.normal_damage < 0 or data.aggressive_damage < 0:
		return &"invalid_entity_definition"
	if data.behavior_type not in [EntityData.BehaviorType.PURSUIT, EntityData.BehaviorType.LIGHT_REACTIVE]:
		return &"invalid_entity_definition"
	if data.behavior_type == EntityData.BehaviorType.PURSUIT and data.initial_state not in [&"WATCHING", &"APPROACHING"]:
		return &"invalid_entity_definition"
	if data.behavior_type == EntityData.BehaviorType.LIGHT_REACTIVE and data.initial_state != &"HIDDEN":
		return &"invalid_entity_definition"
	if data.behavior_type == EntityData.BehaviorType.LIGHT_REACTIVE:
		return InsightSystem.validate_definition(data.rule_insight)
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
	# 两种遭遇共用当前实例槽；不允许用后续定义覆盖仍活跃的前一个实体。
	for definition: EntityData in [data.entry_entity, data.followup_entity]:
		if definition != null:
			var error: StringName = validate_definition(definition)
			if not error.is_empty():
				return error
	if data.entry_entity != null and data.followup_entity != null and data.entry_entity.id == data.followup_entity.id:
		return &"invalid_entity_definition"
	if data.entry_entity == null:
		return &"" if entity == null else &"invalid_entity_context"
	if entity == null:
		return &"invalid_entity_context"
	var definition: EntityData = data.find_entity(entity.entity_id)
	if definition == null or entity.max_hp != definition.max_hp:
		return &"invalid_entity_context"
	if entity.hp < 0 or entity.hp > entity.max_hp or not INTENTS.has(entity.state) or entity.intent != INTENTS.get(entity.state):
		return &"invalid_entity_state"
	var states: Array[StringName] = PURSUIT_STATES if definition.behavior_type == EntityData.BehaviorType.PURSUIT else LIGHT_STATES
	if not states.has(entity.state):
		return &"invalid_entity_state"
	if (definition.behavior_type == EntityData.BehaviorType.PURSUIT and entity.light_exposed) or (entity.state in [&"OBSERVING", &"AGITATED"] and not entity.light_exposed):
		return &"invalid_entity_state"
	if definition.behavior_type == EntityData.BehaviorType.LIGHT_REACTIVE and not floor.floor_flags.has(&"darkness"):
		return &"invalid_entity_context"
	if (entity.hp == 0) != (entity.state == &"DEFEATED"):
		return &"invalid_entity_state"
	return &""


static func plan_card(result: ActionResult, definition: CardData, state: RunState, data: FloorData) -> StringName:
	var entity: EntityInstance = state.floor_state.entity
	var entity_data: EntityData = data.find_entity(entity.entity_id) if entity != null else null
	match definition.effect_type:
		CardData.EffectType.BLOCK:
			result.block_gained = definition.effect_value
		CardData.EffectType.RUN:
			result.threat_delta = mini(1, FloorState.MAX_THREAT - state.floor_state.threat)
			result.threat_reason = &"player_ran"
			if entity != null and entity.active and entity_data.behavior_type == EntityData.BehaviorType.PURSUIT:
				_set_next_state(result, &"DISENGAGED" if entity.state == &"STAGGERED" else &"CHASING")
		CardData.EffectType.ATTACK, CardData.EffectType.PLACEHOLDER_DAMAGE:
			var damage: int = definition.effect_value if definition.effect_type == CardData.EffectType.ATTACK else definition.placeholder_damage
			return plan_attack(result, damage, state, entity_data)
	return &""


static func plan_attack(result: ActionResult, damage: int, state: RunState, data: EntityData) -> StringName:
	var entity: EntityInstance = state.floor_state.entity
	if entity == null or not entity.active:
		return &"no_active_entity"
	result.damage_requested = damage
	result.entity_damage = mini(damage, entity.hp)
	result.entity_hp_after = entity.hp - result.entity_damage
	result.entity_defeated = result.entity_hp_after == 0
	var reaction: StringName = &"ATTACKING" if data.behavior_type == EntityData.BehaviorType.LIGHT_REACTIVE else (&"APPROACHING" if entity.state == &"WATCHING" else entity.state)
	_set_next_state(result, &"DEFEATED" if result.entity_defeated else reaction)
	result.entity_state_reason = &"player_attack"
	return &""


static func can_enter_followup(floor: FloorState, data: FloorData) -> bool:
	return floor != null and data != null and data.entry_entity != null and data.followup_entity != null and floor.entity != null and floor.entity.entity_id == data.entry_entity.id and not floor.entity.active


static func plan_followup(result: ActionResult, state: RunState, data: FloorData) -> StringName:
	if not can_enter_followup(state.floor_state, data):
		return &"encounter_unavailable"
	if data.followup_entity.behavior_type == EntityData.BehaviorType.LIGHT_REACTIVE and not state.floor_state.floor_flags.has(&"darkness"):
		return &"invalid_entity_context"
	result.entity_spawned = spawn(data.followup_entity)
	# 已经开启的光源也算一次暴露；只规划新实例，不修改原有实体。
	if state.floor_state.light_active and data.followup_entity.behavior_type == EntityData.BehaviorType.LIGHT_REACTIVE:
		result.entity_spawned.state = &"OBSERVING"
		result.entity_spawned.intent = INTENTS[&"OBSERVING"]
		result.entity_spawned.light_exposed = true
	return &""


static func plan_light_reaction(result: ActionResult, state: RunState, data: FloorData) -> void:
	var entity: EntityInstance = state.floor_state.entity
	if entity == null or not entity.active or data.find_entity(entity.entity_id).behavior_type != EntityData.BehaviorType.LIGHT_REACTIVE:
		return
	# 普通原型手电即强光；同一回合反复开关也会升级，失败开灯不会到达此入口。
	var next_state: StringName = &"OBSERVING" if entity.state == &"HIDDEN" else (&"AGITATED" if entity.state == &"OBSERVING" else &"ATTACKING")
	_set_next_state(result, next_state)
	result.entity_state_reason = &"strong_light"
	result.entity_light_exposed = true
	if next_state in [&"AGITATED", &"ATTACKING"]:
		result.threat_delta = mini(1, FloorState.MAX_THREAT - state.floor_state.threat)
		result.threat_reason = &"repeated_strong_light"


static func plan_end_turn(result: ActionResult, state: RunState, data: FloorData) -> void:
	var entity: EntityInstance = state.floor_state.entity
	result.expire_block = true
	if entity == null or not entity.active:
		return
	# 只执行界面已经公示的意图，每次 End Turn 一次；不用随机 AI 或第二套时钟。
	result.intent_resolved = entity.intent
	var definition: EntityData = data.find_entity(entity.entity_id)
	if definition.behavior_type == EntityData.BehaviorType.LIGHT_REACTIVE:
		_plan_light_end_turn(result, state, definition)
		return
	var damage: int = 0
	var next_state: StringName = entity.state
	match entity.intent:
		&"approach":
			next_state = &"APPROACHING"
		&"bite":
			damage = definition.normal_damage
			next_state = &"CHASING"
		&"lunge":
			damage = definition.aggressive_damage
		&"recover":
			next_state = &"WATCHING"
	result.damage_blocked = mini(state.floor_state.player_block, damage)
	result.player_damage = mini(state.player_hp, maxi(0, damage - result.damage_blocked))
	if damage > 0 and result.damage_blocked == damage:
		next_state = &"STAGGERED"
	_set_next_state(result, next_state)


static func _plan_light_end_turn(result: ActionResult, state: RunState, data: EntityData) -> void:
	var entity: EntityInstance = state.floor_state.entity
	# 先读取本回合实际照明，再由统一提交清除临时光源；不会在熄灯后执行过期攻击。
	if not state.floor_state.light_active:
		_set_next_state(result, &"WITHDRAWN")
		result.entity_state_reason = &"darkness_respected"
		if entity.light_exposed:
			InsightSystem.plan_confirmation(result, data.rule_insight, state.floor_state)
		return
	if entity.state == &"AGITATED":
		_set_next_state(result, &"ATTACKING")
		result.entity_state_reason = &"light_warning_ignored"
	elif entity.state == &"ATTACKING":
		result.damage_blocked = mini(state.floor_state.player_block, data.aggressive_damage)
		result.player_damage = mini(state.player_hp, maxi(0, data.aggressive_damage - result.damage_blocked))
		# 格挡仍然有效，但规则型实体不会套用猎犬的踉跄状态机。
		_set_next_state(result, &"ATTACKING")
		result.entity_state_reason = &"light_strike"


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
	if result.entity_spawned != null:
		floor.entity = result.entity_spawned
		entity = floor.entity
		result.debug_lines.append("[ENTITY] spawn %s hp=%d state=%s" % [entity.entity_id, entity.hp, entity.state])
	if entity == null:
		return
	if result.entity_light_exposed:
		entity.light_exposed = true
	if result.entity_hp_after >= 0:
		entity.hp = result.entity_hp_after
		result.debug_lines.append("[DAMAGE] %s -%d hp=%d" % [entity.entity_id, result.entity_damage, entity.hp])
	if not result.entity_state_after.is_empty():
		if entity.state != result.entity_state_after:
			result.debug_lines.append("[ENTITY] %s state %s -> %s reason=%s" % [entity.entity_id, entity.state, result.entity_state_after, result.entity_state_reason])
		entity.state = result.entity_state_after
		entity.intent = result.entity_intent_after
	if result.entity_defeated:
		result.debug_lines.append("[ENTITY] defeated %s" % entity.entity_id)
