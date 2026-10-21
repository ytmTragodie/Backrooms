class_name SafePointSystem
extends RefCounted


static func validate(data: SafePointData) -> StringName:
	if data != null and (data.id.is_empty() or data.required_situations < 1 or data.heal < 0 or data.stress_relief < 0 or data.heal + data.stress_relief == 0):
		return &"invalid_safe_point"
	return &""


static func available(state: RunState) -> bool:
	var floor: FloorState = state.floor_state
	return floor != null and floor.safe_point != null and floor.safe_point.reached and not floor.safe_point.consumed and floor.board_state.entity == null and state.flow.pending_rewards.is_empty() and state.player.hp > 0


static func reach(state: RunState, result: ActionResult) -> void:
	var floor: FloorState = state.floor_state
	if floor.safe_point != null and not floor.safe_point.reached and floor.completed_objectives >= floor.safe_point.definition.required_situations:
		floor.safe_point.reached = true
		result.run.safe_point_discovered = true
		result.debug_lines.append("[SAFE_POINT] reached floor=%s" % floor.floor_id)


# 只规划；HP/Stress 交给 PlayerSystem，牌组交给本系统 commit。
static func plan(command: SafePointCommand, state: RunState) -> ActionResult:
	var result: ActionResult = ActionResult.new()
	result.action_id = &"safe_point"
	result.debug_lines.append("[COMMAND] safe_point")
	if state == null or command == null or state.floor_state == null or command.board != state.floor_state.board_state or command.point == null or command.point != state.floor_state.safe_point:
		return _fail(result, &"invalid_safe_point")
	var error: StringName = validate(command.point.definition)
	if not error.is_empty():
		return _fail(result, error)
	if not available(state):
		return _fail(result, &"safe_point_unavailable")
	if command.choice not in [SafePointCommand.Choice.REST, SafePointCommand.Choice.REMOVE, SafePointCommand.Choice.UPGRADE]:
		return _fail(result, &"invalid_command")
	if command.choice == SafePointCommand.Choice.REST:
		if command.card != null:
			return _fail(result, &"invalid_reward_card")
		var hp_restored: int = mini(command.point.definition.heal, state.player.max_hp - state.player.hp)
		var stress_restored: int = mini(command.point.definition.stress_relief, state.player.stress)
		if hp_restored + stress_restored == 0:
			return _fail(result, &"nothing_to_restore")
		result.player.hp_delta += hp_restored
		result.player.stress_delta -= stress_restored
		result.debug_lines.append("[SAFE_POINT] rest planned hp=+%d stress=-%d" % [hp_restored, stress_restored])
	else:
		var kind: CardRewardData.Kind = CardRewardData.Kind.REMOVE_CARD if command.choice == SafePointCommand.Choice.REMOVE else CardRewardData.Kind.UPGRADE_CARD
		if command.card == null or not CardRewardSystem.eligible_cards(state, kind).has(command.card) or command.captured_definition != command.card.definition:
			return _fail(result, &"invalid_reward_card")
		result.deck.card_changed = command.card
		if command.choice == SafePointCommand.Choice.REMOVE:
			result.deck.change_kind = &"removed"
		else:
			result.deck.change_kind = &"upgraded"
	result.run.safe_point_used = command.point
	return result


# 只提交 SafePointState 与牌组变化；玩家数值由 PlayerSystem 提交。
static func commit(result: ActionResult, state: RunState) -> void:
	if result == null or state == null or result.run.safe_point_used == null:
		return
	if result.deck.change_kind == &"removed" and result.deck.card_changed != null:
		CardSystem.remove_instance(state.player.deck, result.deck.card_changed)
		result.deck.card_removed = result.deck.card_changed
		result.debug_lines.append("[DECK] removed %s" % result.deck.card_changed.definition.id)
	elif result.deck.change_kind == &"upgraded" and result.deck.card_changed != null:
		var previous_id: StringName = result.deck.card_changed.definition.id
		CardSystem.upgrade_instance(result.deck.card_changed)
		result.deck.card_upgraded = result.deck.card_changed
		result.debug_lines.append("[DECK] upgraded %s -> %s" % [previous_id, result.deck.card_changed.definition.id])
	result.run.safe_point_used.consumed = true
	if result.deck.change_kind.is_empty():
		result.debug_lines.append("[SAFE_POINT] consumed rest")
	else:
		result.debug_lines.append("[SAFE_POINT] consumed choice=%s" % result.deck.change_kind)


static func _fail(result: ActionResult, reason: StringName) -> ActionResult:
	result.failure_reason = reason
	result.debug_lines.append("[SAFE_POINT] rejected reason=%s" % reason)
	return result
