class_name EscapeSystem
extends RefCounted
## 唯一撤离。预览不抽随机数，正式计划只采样一次，不改变 Level。
static func preview(state: RunState) -> EscapePreview:
	var result: EscapePreview = EscapePreview.new()
	if state.flow.phase != RunFlowState.Phase.COMBAT or state.combat == null or state.player.hp <= 0:
		result.reason = &"combat_required"
		return result
	var enemy: EntityInstance = state.combat.enemies[0]
	var modifier: int = enemy.current_intent.escape_damage_modifier
	result.damage_min = maxi(0, enemy.definition.escape_damage_min + modifier)
	result.damage_max = maxi(result.damage_min, enemy.definition.escape_damage_max + modifier)
	result.stress_gain = enemy.definition.escape_stress
	if state.combat.ap < result.ap_cost:
		result.reason = &"insufficient_ap"
		return result
	result.allowed = true
	return result

static func plan(result: ActionResult, state: RunState, rng: RandomNumberGenerator) -> StringName:
	var previewed: EscapePreview = preview(state)
	if not previewed.allowed: return previewed.reason
	result.combat.after = state.combat.copy()
	result.combat.after.ap -= previewed.ap_cost
	var damage: int = rng.randi_range(previewed.damage_min, previewed.damage_max)
	result.player.hp_delta -= mini(state.player.hp, damage)
	result.player.stress_delta += previewed.stress_gain
	result.combat.after.outcome = CombatState.Outcome.DEFEAT if state.player.hp <= damage else CombatState.Outcome.ESCAPE
	result.message = "撤离受到 %d 伤害，压力 +%d；放弃本场胜利奖励" % [damage, previewed.stress_gain]
	CombatSystem.plan_outcome(result, state, rng)
	return &""
