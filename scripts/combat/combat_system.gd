class_name CombatSystem
extends RefCounted
## 战斗生命周期与提交。效果/牌区/实体规则分别由各领域负责。
static func plan_start(enemy: EntityData, result: ActionResult, state: RunState, rng: RandomNumberGenerator) -> void:
	var combat: CombatState = CombatState.new()
	combat.deck = CardSystem.start_combat(state.player.deck, rng)
	combat.enemies.append(EntitySystem.spawn(enemy, state.revision + 1))
	result.combat.after = combat
	EntitySystem.lock_intent(combat.enemies[0], combat, state.floor_state.definition, rng)
	CardSystem.draw(combat.deck, 5, rng)
	EquipmentSystem.plan_generation(result, state)
	result.flow.phase_after = RunFlowState.Phase.COMBAT
	result.player.knowledge_entities.append(enemy.id)

static func card_error(command: GameCommand, state: RunState) -> StringName:
	if state.combat == null or state.combat.phase != CombatState.Phase.PLAYER: return &"combat_required"
	var card: CardInstance = command.card
	if card == null or not state.combat.deck.hand.has(card): return &"card_not_in_hand"
	if command.definition != card.definition: return &"stale_definition"
	var data: CardData = card.definition
	if not data.is_valid(): return &"invalid_card"
	for effect: EffectData in data.effects:
		if not ContentValidator.effect_valid(effect): return &"invalid_effect"
	# 纯恢复牌没有消费者时拒绝，防止成功空放并浪费有限装备次数。
	var useful: bool = false
	for effect: EffectData in data.effects:
		if effect.effect_type == EffectData.EffectType.HEAL:
			useful = useful or state.player.hp < state.player.max_hp
		elif effect.effect_type == EffectData.EffectType.CHANGE_STRESS and effect.amount < 0:
			useful = useful or state.player.stress > 0
		else: useful = true
	if not useful: return &"nothing_to_restore"
	if state.combat.ap < data.ap_cost: return &"insufficient_ap"
	if state.combat.intel < data.intel_cost: return &"insufficient_intel"
	if data.target_kind == CardData.TargetKind.ENTITY:
		if command.target == null or not state.combat.enemies.has(command.target) or not command.target.active: return &"stale_target"
	elif command.target != null: return &"invalid_target"
	if data.source == CardData.Source.EQUIPMENT: return EquipmentSystem.validate_card(card, state)
	return &""

static func plan_card(command: GameCommand, result: ActionResult, state: RunState, rng: RandomNumberGenerator) -> StringName:
	var error: StringName = card_error(command, state)
	if not error.is_empty(): return error
	var data: CardData = command.card.definition
	var combat: CombatState = state.combat.copy()
	result.combat.after = combat
	combat.ap -= data.ap_cost
	combat.intel -= data.intel_cost
	combat.deck.hand.erase(command.card)
	var index: int = state.combat.enemies.find(command.target) if command.target != null else 0
	EffectSystem.apply(data.effects, result, state, combat.enemies[index], false, rng)
	if data.source == CardData.Source.NORMAL:
		if data.exhaust: combat.deck.exhaust_pile.append(command.card)
		else: combat.deck.discard_pile.append(command.card)
	else:
		result.equipment.item = command.card.source_equipment
		result.equipment.uses_delta = -data.equipment_cost
		# 开/关灯是不同定义，复用同一机会；充能耗尽后仍允许熄灯。
		var item: EquipmentInstance = command.card.source_equipment
		if item.definition.active_action_card != null:
			var definition: CardData = item.definition.active_action_card if combat.light_active else item.definition.action_card
			if definition.equipment_cost == 0 or item.remaining_uses + result.equipment.uses_delta > 0:
				var replacement: CardInstance = CardInstance.new(definition)
				replacement.source_equipment = item
				combat.deck.hand.append(replacement)
	result.combat.cards_played = 1
	result.message = "已打出「%s」" % data.display_name
	plan_outcome(result, state, rng)
	return &""

static func plan_end_turn(result: ActionResult, state: RunState, rng: RandomNumberGenerator) -> StringName:
	var combat: CombatState = state.combat.copy()
	result.combat.after = combat
	# 固定顺序：回合末反应 → 锁定意图 → 持续伤害 → 到期清理 → 新回合/锁定/抽牌。
	for enemy: EntityInstance in combat.enemies:
		EntitySystem.react(TriggerData.TriggerType.ON_TURN_END, [], enemy, result, state, rng)
		if state.player.hp + result.player.hp_delta <= 0: break
		if not enemy.active: continue
		enemy.block = 0
		var stunned: bool = false
		for status: StatusInstance in enemy.statuses:
			if status.definition.skip_intent: stunned = true
		if not stunned:
			EffectSystem.apply(enemy.current_intent.effects, result, state, enemy, true, rng)
			if not enemy.current_intent.state_after.is_empty(): enemy.state = enemy.current_intent.state_after
			enemy.previous_action = enemy.current_intent.action_id
			enemy.last_actions[enemy.current_intent.action_id] = combat.turn_number
		if state.player.hp + result.player.hp_delta <= 0: break
	for status: StatusInstance in combat.statuses:
		result.player.hp_delta -= mini(maxi(0, state.player.hp + result.player.hp_delta), status.definition.turn_end_damage * status.stacks)
	for enemy: EntityInstance in combat.enemies:
		for status: StatusInstance in enemy.statuses:
			enemy.hp = maxi(0, enemy.hp - status.definition.turn_end_damage * status.stacks)
		if enemy.hp == 0: enemy.state = &"DEFEATED"
	plan_outcome(result, state, rng)
	if combat.outcome != CombatState.Outcome.NONE: return &""
	EffectSystem.expire(combat.statuses)
	for enemy: EntityInstance in combat.enemies: EffectSystem.expire(enemy.statuses)
	combat.turn_number += 1
	combat.ap = combat.max_ap
	combat.block = 0
	for enemy: EntityInstance in combat.enemies:
		EntitySystem.react(TriggerData.TriggerType.ON_TURN_START, [], enemy, result, state, rng)
		if state.player.hp + result.player.hp_delta <= 0: break
		if enemy.active: EntitySystem.lock_intent(enemy, combat, state.floor_state.definition, rng)
	plan_outcome(result, state, rng)
	if combat.outcome != CombatState.Outcome.NONE: return &""
	CardSystem.next_hand(combat.deck, rng)
	EquipmentSystem.plan_generation(result, state)
	result.message = "新战斗回合：意图已锁定"
	return &""

static func plan_outcome(result: ActionResult, state: RunState, rng: RandomNumberGenerator) -> void:
	var combat: CombatState = result.combat.after
	if state.player.hp + result.player.hp_delta <= 0: combat.outcome = CombatState.Outcome.DEFEAT
	if combat.outcome == CombatState.Outcome.NONE:
		var active: bool = false
		for enemy: EntityInstance in combat.enemies:
			if enemy.active: active = true
		if not active: combat.outcome = CombatState.Outcome.VICTORY
	if combat.outcome == CombatState.Outcome.NONE: return
	combat.phase = CombatState.Phase.FINISHED
	# 结束的遭遇不保留可影响下一节点的战斗资源；AP 保留用于结果审计扣费。
	combat.noise = 0
	combat.intel = 0
	combat.block = 0
	combat.light_active = false
	combat.statuses.clear()
	result.combat.clear = true
	result.floor.resolve_current = true
	if combat.outcome == CombatState.Outcome.DEFEAT:
		result.flow.phase_after = RunFlowState.Phase.RESULT
		result.flow.result_text = "探索失败：生命耗尽"
		return
	if combat.outcome == CombatState.Outcome.VICTORY:
		result.combat.victory = true
		for enemy: EntityInstance in combat.enemies:
			if enemy.alive:
				result.combat.resolved_alive += 1
				if not enemy.definition.behavior_knowledge.is_empty(): result.player.knowledge_rules.append(enemy.definition.behavior_knowledge)
			RewardSystem.plan(enemy.definition.reward_data, result, state, rng)
		result.message = "遭遇已解决：领取战斗奖励"
	else: result.combat.escape = true
	RewardSystem.next_phase(result, state)

static func commit(result: ActionResult, state: RunState) -> void:
	var next: CombatState = result.combat.after
	if next != null:
		if state.combat == null: state.combat = next
		else: _merge(next,state.combat)
	# 先合并最终 HP/结局，再释放活动引用。外部旧实例必须确实表现为死亡/退去。
	if result.combat.clear: state.combat = null

static func _merge(next: CombatState, current: CombatState) -> void:
	# 合并草案时保留活动实体实例身份，旧目标不能因为定义 ID 相同而命中新实例。
	for index: int in range(next.enemies.size()):
		var original: EntityInstance = current.enemies[index]
		var planned: EntityInstance = next.enemies[index]
		original.hp = planned.hp
		original.block = planned.block
		original.state = planned.state
		original.statuses = planned.statuses
		original.current_intent = planned.current_intent
		original.last_actions = planned.last_actions
		original.weakness_turns = planned.weakness_turns
		original.previous_action = planned.previous_action
		next.enemies[index] = original
	current.phase = next.phase
	current.outcome = next.outcome
	current.turn_number = next.turn_number
	current.ap = next.ap
	current.max_ap = next.max_ap
	current.block = next.block
	current.intel = next.intel
	current.noise = next.noise
	current.light_active = next.light_active
	current.deck = next.deck
	current.statuses = next.statuses
