class_name RuleResolver
extends RefCounted


static func resolve(command: PlayCardCommand, state: RunState, cards: CardSystem) -> ActionResult:
	# 解析器不持有 RunState；调用者必须显式提供同一局的状态与牌堆系统。
	var result: ActionResult = ActionResult.new()
	var card: CardInstance = command.card if command != null else null
	var card_id: StringName = &"<invalid>"
	if card != null and card.definition != null:
		card_id = card.definition.id
	result.debug_lines.append("[COMMAND] play_card %s" % card_id)
	# 所有失败分支都位于玩法写入之前，因此无需失败后的回滚。
	if command == null or card == null:
		return _fail(result, &"invalid_command", card_id)
	if state == null or state.deck_state == null or cards == null or not cards.is_bound_to(state):
		return _fail(result, &"invalid_state_context", card_id)
	if not state.deck_state.hand.has(card):
		return _fail(result, &"card_not_in_hand", card_id)
	var definition: CardData = card.definition
	if definition == null or definition.id.is_empty():
		return _fail(result, &"invalid_card_definition", card_id)
	if definition.ap_cost < 0 or definition.placeholder_damage < 0:
		return _fail(result, &"invalid_card_definition", card_id)
	if definition.effect_type != CardData.EffectType.NO_OP and definition.effect_type != CardData.EffectType.PLACEHOLDER_DAMAGE:
		return _fail(result, &"unsupported_effect", card_id)
	if definition.effect_type == CardData.EffectType.NO_OP and definition.placeholder_damage != 0:
		return _fail(result, &"invalid_card_definition", card_id)
	var final_cost: int = definition.ap_cost
	if state.ap < final_cost:
		return _fail(result, &"insufficient_ap", card_id)

	# 先计算并构建完整结果；占位伤害只进入结果，不修改任何目标的 HP。
	result.success = true
	result.ap_spent = final_cost
	result.card_played = card
	match definition.effect_type:
		CardData.EffectType.NO_OP:
			result.effect = &"no_op"
		CardData.EffectType.PLACEHOLDER_DAMAGE:
			result.effect = &"placeholder_damage"
			result.damage_requested = definition.placeholder_damage
	result.debug_lines.append("[RULE] validation success")
	result.debug_lines.append("[RULE] final_cost=%d" % final_cost)

	# 验证到提交保持同步，期间不发送信号，避免观察者读到只扣 AP、未移牌的中间状态。
	var previous_ap: int = state.ap
	state.ap -= result.ap_spent
	cards.move_hand_to_discard(card)
	result.debug_lines.append("[AP] %d -> %d" % [previous_ap, state.ap])
	result.debug_lines.append("[CARD] hand -> discard %s" % card_id)
	result.debug_lines.append("[RESULT] success %s effect=%s damage_requested=%d" % [card_id, result.effect, result.damage_requested])
	_write_log(result)
	return result


static func _fail(result: ActionResult, reason: StringName, card_id: StringName) -> ActionResult:
	result.failure_reason = reason
	result.debug_lines.append("[RULE] validation failed reason=%s" % reason)
	result.debug_lines.append("[RESULT] failed %s" % card_id)
	_write_log(result)
	return result


static func _write_log(result: ActionResult) -> void:
	if OS.is_debug_build():
		for line: String in result.debug_lines:
			print(line)
