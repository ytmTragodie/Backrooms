class_name RewardSystem
extends RefCounted
## 奖励先规划具体选项，领取只消费 RunFlowState 中的真实机会。
static func plan(table: RewardTableData, result: ActionResult, state: RunState, rng: RandomNumberGenerator) -> void:
	if table == null: return
	for entry: RewardEntryData in table.guaranteed_rewards: plan_entry(entry, result, state, rng)
	var pool: Array[RewardEntryData] = table.random_rewards.duplicate()
	for index: int in range(mini(table.random_count, pool.size())):
		var weights: PackedInt32Array = []
		for entry: RewardEntryData in pool: weights.append(entry.weight)
		var chosen: int = MapSystem.weighted_index(weights, rng)
		plan_entry(pool[chosen], result, state, rng)
		pool.remove_at(chosen)

static func plan_entry(entry: RewardEntryData, result: ActionResult, state: RunState, rng: RandomNumberGenerator) -> void:
	match entry.kind:
		RewardEntryData.Kind.SUPPLY: result.player.supply_delta += entry.amount
		RewardEntryData.Kind.HEAL: result.player.hp_delta += mini(entry.amount, state.player.max_hp - state.player.hp - result.player.hp_delta)
		RewardEntryData.Kind.CALM: result.player.stress_delta -= entry.amount
		RewardEntryData.Kind.CARD_CHOICE:
			var opportunity: RewardOpportunity = RewardOpportunity.new()
			var pool: Array[CardData] = entry.cards.duplicate()
			for index: int in range(mini(3, pool.size())):
				var choice: int = rng.randi_range(0, pool.size() - 1)
				opportunity.cards.append(pool[choice])
				pool.remove_at(choice)
			result.flow.rewards.append(opportunity)
		RewardEntryData.Kind.EQUIPMENT:
			var opportunity: RewardOpportunity = RewardOpportunity.new()
			opportunity.equipment = entry.equipment
			result.flow.rewards.append(opportunity)

static func next_phase(result: ActionResult, state: RunState) -> void:
	result.flow.phase_after = RunFlowState.Phase.REWARD if state.flow.pending_rewards.size() + result.flow.rewards.size() > 0 else RunFlowState.Phase.MAP

static func plan_claim(command: GameCommand, result: ActionResult, state: RunState) -> StringName:
	if state.flow.pending_rewards.is_empty() or command.reward != state.flow.pending_rewards[0]: return &"stale_reward"
	var reward: RewardOpportunity = command.reward
	if command.choice != -1:
		if reward.equipment != null:
			if command.choice < 0 or command.choice >= EquipmentState.SLOT_COUNT: return &"invalid_choice"
			result.equipment.replacement = reward.equipment
			result.equipment.slot = command.choice
		else:
			if command.choice < 0 or command.choice >= reward.cards.size(): return &"invalid_choice"
			result.deck.add.append(reward.cards[command.choice])
	result.flow.claim_reward = reward
	result.flow.phase_after = RunFlowState.Phase.REWARD if state.flow.pending_rewards.size() > 1 else RunFlowState.Phase.MAP
	return &""
