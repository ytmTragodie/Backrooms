class_name SafePointSystem
extends RefCounted


static func validate(data: SafePointData) -> StringName:
	if data != null and (data.id.is_empty() or data.required_situations < 1 or data.heal < 0 or data.stress_relief < 0 or data.heal + data.stress_relief == 0):
		return &"invalid_safe_point"
	return &""


static func available(state: RunState) -> bool:
	var floor: FloorState = state.floor_state
	return floor != null and floor.safe_point != null and floor.safe_point.reached and not floor.safe_point.consumed and floor.board_state.entity == null and state.pending_rewards.is_empty() and state.player_hp > 0


static func reach(state: RunState, result: ActionResult) -> void:
	var floor: FloorState = state.floor_state
	if floor.safe_point != null and not floor.safe_point.reached and floor.completed_objectives >= floor.safe_point.definition.required_situations:
		floor.safe_point.reached = true
		result.debug_lines.append("[SAFE_POINT] reached floor=%s" % floor.floor_id)


static func resolve(command: SafePointCommand, state: RunState) -> ActionResult:
	var result: ActionResult = ActionResult.new()
	result.action_id = &"safe_point"
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
		result.hp_restored = mini(command.point.definition.heal, RunState.MAX_PLAYER_HP - state.player_hp)
		result.stress_restored = mini(command.point.definition.stress_relief, state.stress)
		if result.hp_restored + result.stress_restored == 0:
			return _fail(ActionResult.new(), &"nothing_to_restore")
	else:
		var kind: CardRewardData.Kind = CardRewardData.Kind.REMOVE_CARD if command.choice == SafePointCommand.Choice.REMOVE else CardRewardData.Kind.UPGRADE_CARD
		if command.card == null or not CardRewardSystem.eligible_cards(state, kind).has(command.card) or command.captured_definition != command.card.definition:
			return _fail(result, &"invalid_reward_card")
	# 选类别／查看候选不消费机会；只有完整合法的最终选择才一起提交。
	if command.choice == SafePointCommand.Choice.REST:
		state.player_hp += result.hp_restored
		state.stress -= result.stress_restored
	else:
		result.deck_card_changed = command.card
		if command.choice == SafePointCommand.Choice.REMOVE:
			CardSystem.remove_instance(state.deck_state, command.card)
			result.deck_change_kind = &"removed"
		else:
			CardSystem.upgrade_instance(command.card)
			result.deck_change_kind = &"upgraded"
	command.point.consumed = true
	result.safe_point_used = command.point
	result.success = true
	result.effect = &"safe_point"
	result.debug_lines.append("[SAFE_POINT] consumed choice=%d hp=+%d stress=-%d" % [command.choice, result.hp_restored, result.stress_restored])
	return result


static func _fail(result: ActionResult, reason: StringName) -> ActionResult:
	result.failure_reason = reason
	return result
