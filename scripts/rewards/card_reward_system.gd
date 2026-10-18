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


static func plan(result: ActionResult, state: RunState, data: FloorData) -> void:
	var definitions: Array[CardRewardData] = result.event_reward_definitions.duplicate()
	if result.objective_resolved and result.objective_target != null and not result.objective_target.resolved:
		definitions.append(data.find_objective(result.objective_target.objective_id).completion_reward)
	var entity: EntityInstance = state.floor_state.board_state.entity
	if entity != null and entity.active and (result.entity_defeated or result.entity_state_after in [&"DISENGAGED", &"WITHDRAWN"]):
		var definition: EntityData = data.find_entity(entity.entity_id)
		if not definition.reward_requires_light_exposure or entity.light_exposed or result.entity_light_exposed or result.entity_defeated:
			definitions.append(definition.resolution_reward)
	# 私有 RNG 草案串接其他计划；规划失败不推进本局 RNG。
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.state = result.rng_state_after if result.commit_rng else state.rng.state
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
			result.commit_rng = true
			result.rng_state_after = rng.state
		result.rewards_created.append(opportunity)


static func commit(result: ActionResult, state: RunState) -> void:
	state.pending_rewards.append_array(result.rewards_created)
	for opportunity: CardReward in result.rewards_created:
		result.debug_lines.append("[REWARD] offered kind=%d choices=%d" % [opportunity.definition.kind, opportunity.choices.size()])


static func eligible_cards(state: RunState, kind: CardRewardData.Kind) -> Array[CardInstance]:
	var eligible: Array[CardInstance] = []
	if kind == CardRewardData.Kind.REMOVE_CARD and state.deck_state.get_card_count() <= MINIMUM_DECK_SIZE:
		return eligible
	for pile: Array[CardInstance] in [state.deck_state.draw_pile, state.deck_state.hand, state.deck_state.discard_pile]:
		for card: CardInstance in pile:
			if card.source != CardData.Source.NORMAL:
				continue
			if kind == CardRewardData.Kind.UPGRADE_CARD:
				var upgraded: CardData = card.definition.upgrade_to
				if upgraded == null or upgraded == card.definition or not upgraded.is_deckbuilding_definition_valid():
					continue
			eligible.append(card)
	return eligible


static func resolve(command: CardRewardCommand, state: RunState) -> ActionResult:
	var result: ActionResult = ActionResult.new()
	result.action_id = &"card_reward"
	result.debug_lines.append("[COMMAND] card_reward")
	if command == null or state == null or command.reward == null or state.pending_rewards.is_empty() or state.pending_rewards[0] != command.reward:
		return _fail(result, &"invalid_reward")
	if state.player_hp <= 0:
		return _fail(result, &"run_ended")
	var reward: CardReward = command.reward
	var error: StringName = validate_definition(reward.definition)
	if not error.is_empty():
		return _fail(result, error)
	var kind: CardRewardData.Kind = reward.definition.kind
	if kind == CardRewardData.Kind.ADD_CARD:
		if command.card != null or command.choice == null or command.choice.source != CardData.Source.NORMAL or not reward.choices.has(command.choice) or not reward.definition.pool.has(command.choice):
			return _fail(result, &"invalid_reward_choice")
	else:
		var candidates: Array[CardInstance] = eligible_cards(state, kind)
		if command.choice != null or (command.card == null and not candidates.is_empty()) or (command.card != null and (not candidates.has(command.card) or command.captured_definition != command.card.definition)):
			return _fail(result, &"invalid_reward_card")
	# 从这里开始只有不会失败的牌区操作。奖励不恢复 AP、不推进回合、不另建牌组。
	if kind == CardRewardData.Kind.ADD_CARD:
		result.deck_change_kind = &"added"
		result.deck_card_changed = CardSystem.add_reward(state.deck_state, command.choice)
		result.debug_lines.append("[DECK] added %s zone=discard" % command.choice.id)
	elif command.card != null:
		result.deck_card_changed = command.card
		if kind == CardRewardData.Kind.UPGRADE_CARD:
			result.deck_change_kind = &"upgraded"
			var previous_id: StringName = command.card.definition.id
			CardSystem.upgrade_instance(command.card)
			result.debug_lines.append("[DECK] upgraded %s -> %s" % [previous_id, command.card.definition.id])
		else:
			result.deck_change_kind = &"removed"
			CardSystem.remove_instance(state.deck_state, command.card)
			result.debug_lines.append("[DECK] removed %s" % command.card.definition.id)
	state.pending_rewards.pop_front()
	result.reward_claimed = reward
	result.success = true
	result.effect = &"card_reward"
	result.debug_lines.append("[REWARD] claimed kind=%d" % kind)
	return result


static func _fail(result: ActionResult, reason: StringName) -> ActionResult:
	result.failure_reason = reason
	result.debug_lines.append("[REWARD] rejected reason=%s" % reason)
	return result
