class_name EntitySystem
extends RefCounted
## 数据条件、行为选取和意图锁定。没有按 entity_id 区分规则。
static func spawn(data: EntityData, instance_id: int) -> EntityInstance:
	var enemy: EntityInstance = EntityInstance.new()
	enemy.instance_id = instance_id
	enemy.definition = data
	enemy.hp = data.max_hp
	enemy.state = data.initial_state
	return enemy

static func conditions_match(conditions: Array[ConditionData], enemy: EntityInstance, combat: CombatState) -> bool:
	for condition: ConditionData in conditions:
		if not condition_matches(condition, enemy, combat): return false
	return true

static func condition_matches(condition: ConditionData, enemy: EntityInstance, combat: CombatState) -> bool:
	var value: float = 0
	match condition.type:
		ConditionData.ConditionType.HP_RATIO: value = float(enemy.hp) / enemy.definition.max_hp
		ConditionData.ConditionType.TURN: value = combat.turn_number
		ConditionData.ConditionType.NOISE: value = combat.noise
		ConditionData.ConditionType.LIGHT_ACTIVE: value = 1 if combat.light_active else 0
		ConditionData.ConditionType.PREV_ACTION: value = 1 if enemy.previous_action == condition.reference_id else 0
		ConditionData.ConditionType.STATE: value = 1 if enemy.state == condition.reference_id else 0
		ConditionData.ConditionType.STATUS_STACK:
			for status: StatusInstance in enemy.statuses:
				if status.definition.id == condition.reference_id: value = status.stacks
	match condition.operator:
		ConditionData.CompareOp.EQ: return is_equal_approx(value, condition.numeric_value)
		ConditionData.CompareOp.NE: return not is_equal_approx(value, condition.numeric_value)
		ConditionData.CompareOp.GT: return value > condition.numeric_value
		ConditionData.CompareOp.GTE: return value >= condition.numeric_value
		ConditionData.CompareOp.LT: return value < condition.numeric_value
		ConditionData.CompareOp.LTE: return value <= condition.numeric_value
	return false

static func lock_intent(enemy: EntityInstance, combat: CombatState, floor: FloorData, rng: RandomNumberGenerator) -> void:
	var candidates: Array[EntityActionData] = []
	var priority: int = -2147483648
	for action: EntityActionData in enemy.definition.behavior_data.actions:
		if not conditions_match(action.conditions, enemy, combat): continue
		if enemy.last_actions.has(action.id) and combat.turn_number - int(enemy.last_actions[action.id]) <= action.cooldown: continue
		if action.priority > priority:
			priority = action.priority
			candidates.clear()
		if action.priority == priority: candidates.append(action)
	var intent: EnemyIntent = EnemyIntent.new()
	intent.display_name = "观察动静"
	if not candidates.is_empty():
		var total: int = 0
		for action: EntityActionData in candidates: total += action.weight
		var roll: int = rng.randi_range(1, total)
		var chosen: EntityActionData = candidates[0]
		for action: EntityActionData in candidates:
			roll -= action.weight
			if roll <= 0:
				chosen = action
				break
		intent.action_id = chosen.id
		intent.display_name = chosen.display_name
		intent.escape_damage_modifier = chosen.escape_damage_modifier
		intent.state_after = chosen.state_after
		for effect: EffectData in chosen.effects:
			# 锁定数值副本；Noise/状态的改变只影响下次意图，不能悄改已公开伤害。
			var locked: EffectData = effect.duplicate(true) as EffectData
			if locked.effect_type == EffectData.EffectType.DAMAGE:
				locked.amount = maxi(0, locked.amount + EffectSystem.status_bonus(enemy.statuses, &"outgoing_damage_bonus"))
				if floor.noise_damage_threshold > 0 and combat.noise >= floor.noise_damage_threshold: locked.amount += floor.noise_damage_bonus
			intent.effects.append(locked)
	enemy.current_intent = intent

static func react(trigger: TriggerData.TriggerType, tags: Array[StringName], enemy: EntityInstance, result: ActionResult, state: RunState, rng: RandomNumberGenerator) -> void:
	if not enemy.active: return
	var combat: CombatState = result.combat.after
	for weakness: WeaknessData in enemy.definition.weaknesses:
		if weakness.trigger.trigger_type != trigger: continue
		if not weakness.trigger.effect_tag.is_empty() and not tags.has(weakness.trigger.effect_tag): continue
		if enemy.weakness_turns.has(weakness.id) and combat.turn_number - int(enemy.weakness_turns[weakness.id]) < maxi(1, weakness.cooldown): continue
		if not conditions_match(weakness.conditions, enemy, combat): continue
		enemy.weakness_turns[weakness.id] = combat.turn_number
		if not weakness.state_after.is_empty(): enemy.state = weakness.state_after
		EffectSystem.apply(weakness.effects, result, state, enemy, true, rng, false)
