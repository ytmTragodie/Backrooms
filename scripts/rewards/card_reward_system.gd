class_name CardRewardSystem
extends RefCounted

const CHOICE_COUNT: int = 3
const MINIMUM_DECK_SIZE: int = 5


static func validate_definition(data: CardRewardData) -> StringName:
	if data == null:
		return &""
	if data.kind not in [CardRewardData.Kind.ADD_CARD, CardRewardData.Kind.UPGRADE_CARD, CardRewardData.Kind.REMOVE_CARD]:
		return &"invalid_reward_definition"
	if data.kind != CardRewardData.Kind.ADD_CARD:
		return &"" if data.pool.is_empty() else &"invalid_reward_definition"
	var ids: Array[StringName] = []
	for card: CardData in data.pool:
		if card == null or not card.is_deckbuilding_definition_valid() or ids.has(card.id):
			return &"invalid_reward_definition"
		ids.append(card.id)
	return &"" if ids.size() >= CHOICE_COUNT else &"invalid_reward_definition"


# 根据本次动作新完成的目标/实体，创建待领取机会；不直接改 pending_rewards。
static func plan(result: ActionResult, state: RunState, data: FloorData) -> void:
	var definitions: Array[CardRewardData] = result.event.reward_definitions.duplicate()
	if result.objective.newly_resolved and result.objective.target != null:
		var objective_definition: ObjectiveData = data.find_objective(result.objective.target.objective_id)
		if objective_definition != null:
			definitions.append(objective_definition.completion_reward)
	var entity: EntityInstance = state.floor_state.board_state.entity
	if entity != null and entity.active and (result.entity.defeated or result.entity.state_after in [&"DISENGAGED", &"WITHDRAWN"]):
		var definition: EntityData = data.find_entity(entity.entity_id)
		if definition != null and (not definition.reward_requires_light_exposure or entity.light_exposed or result.entity.light_exposed or result.entity.defeated):
			definitions.append(definition.resolution_reward)
	# 私有 RNG 草案串接其他计划；规划失败不推进本局 RNG。
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.state = result.run.rng_state_after if result.run.commit_rng else state.rng.state
	for definition: CardRewardData in definitions:
		if definition == null:
			continue
		var opportunity: CardReward = CardReward.new()
		opportunity.definition = definition
		if definition.kind == CardRewardData.Kind.ADD_CARD:
			var candidates: Array[CardData] = definition.pool.duplicate()
			for index: int in range(CHOICE_COUNT):
				var picked: int = rng.randi_range(0, candidates.size() - 1)
				opportunity.choices.append(candidates[picked])
				candidates.remove_at(picked)
			result.run.commit_rng = true
			result.run.rng_state_after = rng.state
		result.run.reward_created.append(opportunity)


# 只提交待领取队列；同一字段由 plan 写入、commit 读取。
static func commit(result: ActionResult, state: RunState) -> void:
	for opportunity: CardReward in result.run.reward_created:
		state.flow.pending_rewards.append(opportunity)
		result.debug_lines.append("[REWARD] offered kind=%d choices=%d" % [opportunity.definition.kind, opportunity.choices.size()])


static func eligible_cards(state: RunState, kind: CardRewardData.Kind) -> Array[CardInstance]:
	var eligible: Array[CardInstance] = []
	if kind == CardRewardData.Kind.REMOVE_CARD and state.player.deck.get_card_count() <= MINIMUM_DECK_SIZE:
		return eligible
	for pile: Array[CardInstance] in [state.player.deck.draw_pile, state.player.deck.hand, state.player.deck.discard_pile]:
		for card: CardInstance in pile:
			if card.source != CardData.Source.NORMAL:
				continue
			if kind == CardRewardData.Kind.UPGRADE_CARD:
				var upgraded: CardData = card.definition.upgrade_to
				if upgraded == null or upgraded == card.definition or not upgraded.is_deckbuilding_definition_valid():
					continue
			eligible.append(card)
	return eligible


# 校验并规划一次领取；不生成牌实例、不弹出奖励、不改牌区。
static func plan_claim(command: CardRewardCommand, state: RunState) -> ActionResult:
	var result: ActionResult = ActionResult.new()
	result.action_id = &"card_reward"
	result.debug_lines.append("[COMMAND] card_reward")
	if command == null or state == null or command.reward == null or state.flow.pending_rewards.is_empty() or state.flow.pending_rewards[0] != command.reward:
		return _fail(result, &"invalid_reward")
	if state.player.hp <= 0:
		return _fail(result, &"run_ended")
	var reward: CardReward = command.reward
	var error: StringName = validate_definition(reward.definition)
	if not error.is_empty():
		return _fail(result, error)
	var kind: CardRewardData.Kind = reward.definition.kind
	if kind == CardRewardData.Kind.ADD_CARD:
		if command.card != null or command.choice == null or command.choice.source != CardData.Source.NORMAL or not reward.choices.has(command.choice) or not reward.definition.pool.has(command.choice):
			return _fail(result, &"invalid_reward_choice")
		result.deck.change_kind = &"added"
		result.deck.added_definition = command.choice
		result.debug_lines.append("[DECK] plan add %s zone=discard" % command.choice.id)
	else:
		var candidates: Array[CardInstance] = eligible_cards(state, kind)
		if command.choice != null or (command.card == null and not candidates.is_empty()) or (command.card != null and (not candidates.has(command.card) or command.captured_definition != command.card.definition)):
			return _fail(result, &"invalid_reward_card")
		result.deck.card_changed = command.card
		result.deck.change_kind = &"upgraded" if kind == CardRewardData.Kind.UPGRADE_CARD else &"removed"
	result.run.reward_claimed = reward
	return result


# 领取的牌区操作由 CardSystem 执行；pending_rewards 仍只在本系统提交。
static func commit_claim(result: ActionResult, state: RunState) -> void:
	if result == null or state == null or result.run.reward_claimed == null:
		return
	if result.deck.change_kind == &"added" and result.deck.added_definition != null:
		var card: CardInstance = CardSystem.add_reward(state.player.deck, result.deck.added_definition)
		result.deck.card_added = card
		result.deck.card_changed = card
		result.debug_lines.append("[DECK] added %s zone=discard" % card.definition.id)
	elif result.deck.change_kind == &"upgraded" and result.deck.card_changed != null:
		var previous_id: StringName = result.deck.card_changed.definition.id
		CardSystem.upgrade_instance(result.deck.card_changed)
		result.deck.card_upgraded = result.deck.card_changed
		result.debug_lines.append("[DECK] upgraded %s -> %s" % [previous_id, result.deck.card_changed.definition.id])
	elif result.deck.change_kind == &"removed" and result.deck.card_changed != null:
		CardSystem.remove_instance(state.player.deck, result.deck.card_changed)
		result.deck.card_removed = result.deck.card_changed
		result.debug_lines.append("[DECK] removed %s" % result.deck.card_changed.definition.id)
	if not state.flow.pending_rewards.is_empty() and state.flow.pending_rewards[0] == result.run.reward_claimed:
		state.flow.pending_rewards.pop_front()
	result.debug_lines.append("[REWARD] claimed kind=%d" % result.run.reward_claimed.definition.kind)


static func _fail(result: ActionResult, reason: StringName) -> ActionResult:
	result.failure_reason = reason
	result.debug_lines.append("[REWARD] rejected reason=%s" % reason)
	return result