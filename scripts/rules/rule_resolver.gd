class_name RuleResolver
extends RefCounted
## 唯一事务入口。Validate/Plan 完整成功后才提交，提交不重新抽随机数。
static func resolve(command: GameCommand, state: RunState, game: GameData) -> ActionResult:
	var result: ActionResult = plan(command, state, game)
	if result.success: commit(result, state)
	return result

static func plan(command: GameCommand, state: RunState, game: GameData) -> ActionResult:
	var result: ActionResult = ActionResult.new()
	if command == null or state == null or state.floor_state == null: return _fail(result, &"invalid_command")
	if command.revision != state.revision or command.floor != state.floor_state or command.combat != state.combat: return _fail(result, &"stale_command")
	if state.player.hp <= 0 or state.flow.phase == RunFlowState.Phase.RESULT: return _fail(result, &"run_ended")
	var required: Dictionary = {GameCommand.Kind.MOVE: RunFlowState.Phase.MAP, GameCommand.Kind.PLAY_CARD: RunFlowState.Phase.COMBAT, GameCommand.Kind.END_TURN: RunFlowState.Phase.COMBAT, GameCommand.Kind.ESCAPE: RunFlowState.Phase.COMBAT, GameCommand.Kind.EVENT_CHOICE: RunFlowState.Phase.EVENT, GameCommand.Kind.REWARD: RunFlowState.Phase.REWARD, GameCommand.Kind.REST: RunFlowState.Phase.REST, GameCommand.Kind.SHOP: RunFlowState.Phase.SHOP, GameCommand.Kind.CUTOUT: RunFlowState.Phase.CUTOUT}
	if not required.has(command.kind) or state.flow.phase != required[command.kind]: return _fail(result, &"invalid_phase")
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.state = state.rng.state
	var error: StringName
	match command.kind:
		GameCommand.Kind.MOVE: error = _plan_move(command, result, state, rng)
		GameCommand.Kind.PLAY_CARD: error = CombatSystem.plan_card(command, result, state, rng)
		GameCommand.Kind.END_TURN: error = CombatSystem.plan_end_turn(result, state, rng)
		GameCommand.Kind.ESCAPE: error = EscapeSystem.plan(result, state, rng)
		GameCommand.Kind.EVENT_CHOICE: error = EventSystem.plan(command, result, state, rng)
		GameCommand.Kind.REWARD: error = RewardSystem.plan_claim(command, result, state)
		GameCommand.Kind.REST: error = _plan_rest(command, result, state)
		GameCommand.Kind.SHOP: error = _plan_shop(command, result, state, rng)
		GameCommand.Kind.CUTOUT: error = CutOutSystem.plan(result, state, game, rng)
	if not error.is_empty(): return _fail(ActionResult.new(), error)
	result.success = true
	result.expected_revision = state.revision
	result.expected_run = state
	result.flow.rng_after = rng.state
	return result

static func _plan_move(command: GameCommand, result: ActionResult, state: RunState, rng: RandomNumberGenerator) -> StringName:
	var map: FloorMapState = state.floor_state.map
	if not map.next_ids().has(command.node_id): return &"illegal_route"
	var node: MapNodeState = map.find(command.node_id)
	result.floor.move_to = node.id
	MapSystem.plan_reveal(result, state, 0, node.layer)
	result.flow.phase_after = RunFlowState.Phase.MAP
	# 已结算节点仅通行，不能重新触发事件/收益/商店。出口不产收益，可再次离开。
	if node.resolution == MapNodeState.Resolution.RESOLVED and node.kind != MapNodeState.Kind.EXIT: return &""
	var floor: FloorData = state.floor_state.definition
	match node.kind:
		MapNodeState.Kind.COMBAT, MapNodeState.Kind.ELITE:
			var pool: Array[EntityData] = floor.encounter_pool if node.kind == MapNodeState.Kind.COMBAT else floor.elite_pool
			for data: EntityData in pool:
				if data.id == node.content_id: CombatSystem.plan_start(data, result, state, rng)
		MapNodeState.Kind.EVENT:
			for data: EventData in floor.event_pool:
				if data.id == node.content_id: result.flow.event_after = data
			result.flow.phase_after = RunFlowState.Phase.EVENT
		MapNodeState.Kind.REST: result.flow.phase_after = RunFlowState.Phase.REST
		MapNodeState.Kind.REWARD:
			RewardSystem.plan(floor.reward_pool, result, state, rng)
			result.floor.resolve_current = true
			RewardSystem.next_phase(result, state)
		MapNodeState.Kind.SHOP:
			for data: ShopData in floor.shops:
				if data.id == node.content_id: result.flow.shop_after = data
			result.flow.phase_after = RunFlowState.Phase.SHOP
		MapNodeState.Kind.EXIT: result.flow.phase_after = RunFlowState.Phase.CUTOUT
	return &""

static func _plan_rest(command: GameCommand, result: ActionResult, state: RunState) -> StringName:
	match command.choice:
		0:
			if state.player.hp == state.player.max_hp and state.player.stress == 0: return &"nothing_to_restore"
			result.player.hp_delta = mini(7, state.player.max_hp - state.player.hp)
			result.player.stress_delta = -3
		1:
			if not state.player.deck.cards.has(command.card) or command.card.definition.upgrade_to == null: return &"invalid_choice"
			result.deck.upgrade = command.card
		2:
			if not state.player.deck.cards.has(command.card) or state.player.deck.cards.size() <= 5: return &"invalid_choice"
			result.deck.remove = command.card
		3:
			var needed: bool = false
			for item: EquipmentInstance in state.player.equipment.slots:
				if item != null and item.remaining_uses < item.definition.capacity: needed = true
			if not needed: return &"nothing_to_restore"
			result.equipment.refill = true
		4: pass
		_: return &"invalid_choice"
	result.floor.resolve_current = true
	result.flow.phase_after = RunFlowState.Phase.MAP
	return &""

static func _plan_shop(command: GameCommand, result: ActionResult, state: RunState, rng: RandomNumberGenerator) -> StringName:
	if command.choice != -1:
		if state.flow.active_shop == null or command.choice < 0 or command.choice >= state.flow.active_shop.offers.size(): return &"invalid_choice"
		var offer: ShopOfferData = state.flow.active_shop.offers[command.choice]
		if state.player.supply < offer.price: return &"insufficient_supply"
		result.player.supply_delta -= offer.price
		RewardSystem.plan_entry(offer.reward, result, state, rng)
	result.floor.resolve_current = true
	RewardSystem.next_phase(result, state)
	return &""

static func commit(result: ActionResult, state: RunState) -> bool:
	if not result.success or result.expected_run != state or result.expected_revision != state.revision: return false
	# 固定提交顺序。每个数值只由状态所有者落地一次，通知不参与规则。
	PlayerSystem.commit(result, state)
	CardSystem.commit(result, state)
	EquipmentSystem.commit(result, state)
	MapSystem.commit(result, state)
	CombatSystem.commit(result, state)
	if result.flow.claim_reward != null:
		state.flow.pending_rewards.pop_front()
		state.metrics.rewards_claimed += 1
	state.flow.pending_rewards.append_array(result.flow.rewards)
	if result.flow.phase_after >= 0: state.flow.phase = result.flow.phase_after as RunFlowState.Phase
	state.flow.active_event = result.flow.event_after
	state.flow.active_shop = result.flow.shop_after
	if not result.flow.result_text.is_empty(): state.flow.result_text = result.flow.result_text
	if not result.flow.destination.is_empty():
		state.flow.last_destination = result.flow.destination
		state.metrics.floor_transitions += 1
	state.rng.state = result.flow.rng_after
	state.metrics.commands += 1
	state.metrics.cards_played += result.combat.cards_played
	if result.combat.victory: state.metrics.victories += 1
	if result.combat.escape: state.metrics.escapes += 1
	state.metrics.resolved_alive += result.combat.resolved_alive
	state.revision += 1
	return true

static func _fail(result: ActionResult, reason: StringName) -> ActionResult:
	result.failure_reason = reason
	return result
