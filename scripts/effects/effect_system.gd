class_name EffectSystem
extends RefCounted
## 对私有战斗草案应用有限效果；不写 RunState 或共享 Resource。
static func status_bonus(statuses: Array[StatusInstance], field: StringName) -> int:
	var total: int = 0
	for status: StatusInstance in statuses: total += int(status.definition.get(field)) * status.stacks
	return total

static func apply(effects: Array[EffectData], result: ActionResult, state: RunState, enemy: EntityInstance, from_enemy: bool, rng: RandomNumberGenerator, reactions: bool = true) -> void:
	var combat: CombatState = result.combat.after
	for effect: EffectData in effects:
		var on_enemy: bool = effect.target == EffectData.TargetType.ENEMY or (effect.target == EffectData.TargetType.SELF and from_enemy)
		var statuses: Array[StatusInstance] = enemy.statuses if on_enemy else combat.statuses
		var dealt: int = 0
		match effect.effect_type:
			EffectData.EffectType.DAMAGE:
				var amount: int = effect.amount
				if not from_enemy: amount += status_bonus(combat.statuses, &"outgoing_damage_bonus")
				amount += status_bonus(statuses, &"incoming_damage_bonus")
				if on_enemy:
					amount = maxi(0, amount - enemy.definition.damage_reduction)
					var blocked: int = mini(enemy.block, amount)
					enemy.block -= blocked
					dealt = mini(enemy.hp, amount - blocked)
					enemy.hp -= dealt
					if enemy.hp == 0: enemy.state = &"DEFEATED"
				else:
					amount = maxi(0, amount)
					var blocked: int = mini(combat.block, amount)
					combat.block -= blocked
					dealt = mini(maxi(0, state.player.hp + result.player.hp_delta), amount - blocked)
					result.player.hp_delta -= dealt
			EffectData.EffectType.BLOCK:
				var amount: int = maxi(0, effect.amount + status_bonus(statuses, &"block_bonus"))
				if on_enemy: enemy.block += amount
				else: combat.block += amount
			EffectData.EffectType.HEAL:
				if on_enemy: enemy.hp = mini(enemy.definition.max_hp, enemy.hp + effect.amount)
				else: result.player.hp_delta += mini(effect.amount, state.player.max_hp - state.player.hp - result.player.hp_delta)
			EffectData.EffectType.DRAW: CardSystem.draw(combat.deck, effect.amount, rng)
			EffectData.EffectType.GAIN_AP: combat.ap += effect.amount
			EffectData.EffectType.GAIN_INTEL: combat.intel += effect.amount
			EffectData.EffectType.APPLY_STATUS: add_status(statuses, effect)
			EffectData.EffectType.CHANGE_STRESS: result.player.stress_delta += effect.amount
			EffectData.EffectType.CHANGE_NOISE: combat.noise = maxi(0, combat.noise + effect.amount)
			EffectData.EffectType.LIGHT: combat.light_active = effect.amount > 0
			EffectData.EffectType.WITHDRAW:
				if on_enemy: enemy.state = &"WITHDRAWN"
		if reactions and enemy.active:
			EntitySystem.react(TriggerData.TriggerType.ON_EFFECT_RECEIVED, effect.tags, enemy, result, state, rng)
			if on_enemy and dealt > 0: EntitySystem.react(TriggerData.TriggerType.ON_DAMAGE_TAKEN, effect.tags, enemy, result, state, rng)

static func add_status(statuses: Array[StatusInstance], effect: EffectData) -> void:
	for status: StatusInstance in statuses:
		if status.definition.id == effect.status.id:
			status.stacks = mini(status.definition.max_stacks, status.stacks + effect.amount)
			status.remaining_turns = maxi(status.remaining_turns, effect.duration if effect.duration > 0 else effect.status.default_duration)
			return
	var status: StatusInstance = StatusInstance.new()
	status.definition = effect.status
	status.stacks = mini(effect.amount, effect.status.max_stacks)
	status.remaining_turns = effect.duration if effect.duration > 0 else effect.status.default_duration
	statuses.append(status)

static func expire(statuses: Array[StatusInstance]) -> void:
	for status: StatusInstance in statuses.duplicate():
		status.remaining_turns -= 1
		if status.remaining_turns <= 0: statuses.erase(status)
