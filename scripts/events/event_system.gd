class_name EventSystem
extends RefCounted
static func option_error(option: EventOptionData, state: RunState) -> StringName:
	if option.supply_cost > state.player.supply: return &"insufficient_supply"
	if option.hp_cost >= state.player.hp: return &"insufficient_hp"
	if not option.required_knowledge.is_empty() and not state.player.knowledge.has(option.required_knowledge): return &"knowledge_required"
	return &""

static func plan(command: GameCommand, result: ActionResult, state: RunState, rng: RandomNumberGenerator) -> StringName:
	var event: EventData = state.flow.active_event
	if event == null or command.choice < 0 or command.choice >= event.options.size(): return &"invalid_choice"
	var option: EventOptionData = event.options[command.choice]
	var error: StringName = option_error(option, state)
	if not error.is_empty(): return error
	result.player.supply_delta -= option.supply_cost
	result.player.hp_delta -= option.hp_cost
	result.player.stress_delta += option.stress_cost
	result.player.knowledge_rules.append_array(option.knowledge)
	result.player.knowledge_floors.append_array(option.known_floors)
	result.player.knowledge_entities.append_array(option.known_entities)
	result.player.knowledge_exits.append_array(option.known_exits)
	MapSystem.plan_reveal(result, state, option.reveal_nodes)
	RewardSystem.plan(option.rewards, result, state, rng)
	if option.encounter != null:
		CombatSystem.plan_start(option.encounter, result, state, rng)
	elif option.next_event != null:
		result.flow.event_after = option.next_event
		result.flow.phase_after = RunFlowState.Phase.EVENT
	else:
		result.floor.resolve_current = true
		RewardSystem.next_phase(result, state)
	return &""
