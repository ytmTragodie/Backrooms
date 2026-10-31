extends "res://tests/phase_14_validation.gd"
## Phase 15：固定种子图约束、已知网络、入口筛选、代价及重返事务。
var verified_seed: int = 1
func _run() -> void:
	check(ContentValidator.validate(GAME).is_empty(),"Phase 15 content validates")
	_generated_maps()
	_network()
	_travel()
	_conditions_and_failure()
	_level7_behavior()
	_full_run()
	await _new_ui()
	if failures.is_empty(): print("[TEST] PASS Phase 15: %d checks; seeded maps, mixed intel, network, paid exits, Level 7, atomic failure, UI" % checks)
	else: print("[TEST] FAIL Phase 15: %d failures / %d checks" % [failures.size(),checks])
	quit(0 if failures.is_empty() else 1)

func _fingerprint(floor: FloorState) -> String:
	var nodes: Array = []
	for node: MapNodeState in floor.map.nodes: nodes.append([node.id,node.kind,node.content_id,node.region_id])
	return str([nodes,floor.map.edges])

func _generated_maps() -> void:
	var optional: int = 0
	var generated: int = 0
	for floor: FloorData in GAME.floors:
		for seed: int in range(400):
			var rng: RandomNumberGenerator = RandomNumberGenerator.new()
			rng.seed = seed
			var created: FloorState = MapSystem.generate(floor,rng)
			check(created.map.validation_errors.is_empty(),"Seeded legal map %s seed=%d: %s" % [floor.id,seed,created.map.validation_errors])
			rng.seed = seed
			check(_fingerprint(created) == _fingerprint(MapSystem.generate(floor,rng)),"Seed determinism")
			var exit_routes: Array[StringName] = []
			for node: MapNodeState in created.map.nodes:
				if node.kind == MapNodeState.Kind.EXIT: exit_routes.append(node.content_id)
			check(exit_routes.size() == floor.map_config.exit_count,"Configured real exits exist")
			if floor.id != &"floor_level_7": continue
			generated += 1
			for record: MapRuleRecord in created.map.rule_records:
				if record.rule_id == &"abyss_intel":
					check(record.applied and MapGraph.dominates(created.map,record.affected_id,record.anchor_id),"Mandatory intel dominates only its actual encounter")
					check(MapGraph.distance(created.map,record.affected_id,record.anchor_id) in [2,3],"Intel is 2–3 real forward steps before encounter")
				if record.rule_id == &"abyss_salvage":
					var support: MapNodeState = created.map.find(record.affected_id)
					check(record.applied and support.kind == MapNodeState.Kind.REWARD and support.content_id == &"salvage_supplies" and MapGraph.distance(created.map,record.anchor_id,support.id) == 1,"Risk route has actual adjacent high-value supply")
				if record.rule_id == &"occasional_bones" and record.applied: optional += 1
	check(optional > 0 and optional < generated,"Optional intel is not mandatory or absent across seeds")

func _network() -> void:
	var run: RunState = state(15)
	var before: String = snapshot(run)
	check(LevelNetworkSystem.rows(run,GAME).is_empty(),"Unexplored connections do not leak")
	place_exit(run)
	var result: ActionResult = ActionResult.new()
	CutOutSystem.observe(result,run.floor_state.definition,CutOutSystem.route(run),run)
	PlayerSystem.commit(result,run)
	before = snapshot(run)
	var connection_count: int = run.player.knowledge.connections.size()
	for index: int in range(30):
		var rows: Array[Dictionary] = LevelNetworkSystem.rows(run,GAME)
		check(not rows.is_empty() and rows[0].targets.size() > 0,"Known route projects actual candidates")
		CutOutSystem.preview(run,GAME)
	check(snapshot(run) == before and connection_count == run.player.knowledge.connections.size(),"Network and preview do not consume RNG/revision or write Knowledge")
	check(not run.player.knowledge.floors.has(&"floor_level_7"),"Network does not discover unknown floor by itself")
	var stale: GameCommand = command(run,GameCommand.Kind.CUTOUT)
	check(RuleResolver.resolve(stale,run,GAME).success,"Real exit resolves")
	check(run.player.knowledge.connections.any(func(c: KnownConnection) -> bool: return c.traversed),"Actual traversal records stable connection")
	reject_unchanged(run,stale,"Duplicate exit request commits nothing")

func _travel() -> void:
	var run: RunState = state(7,&"floor_level_7")
	place_exit(run)
	run.floor_state.map.find(run.floor_state.map.current_node_id).content_id = &"level7_cave"
	var old: FloorState = run.floor_state
	var hp: int = run.player.hp
	var stress: int = run.player.stress
	var before: String = snapshot(run)
	var request: GameCommand = command(run,GameCommand.Kind.CUTOUT)
	var draft: ActionResult = RuleResolver.plan(request,run,GAME)
	check(draft.success and snapshot(run) == before,"Paid travel plans full outcome without mutation")
	check(CutOutSystem.preview(run,GAME).allowed,"Poor preparation still allows paid exit")
	check(RuleResolver.commit(draft,run),"Paid exit commits")
	check(run.player.hp == hp-3 and run.player.stress == stress+2,"Exit costs commit once with transition")
	check(old.map.find(request.floor.map.current_node_id).resolution == MapNodeState.Resolution.RESOLVED,"Old exit resolved before floor activation")
	reject_unchanged(run,request,"Repeated paid exit does not charge twice")
	var dying: RunState = state(9,&"floor_level_7")
	place_exit(dying)
	dying.floor_state.map.find(dying.floor_state.map.current_node_id).content_id = &"level7_cave"
	dying.player.hp = 2
	var rng_before: int = dying.rng.state
	check(RuleResolver.resolve(command(dying,GameCommand.Kind.CUTOUT),dying,GAME).success,"Lethal paid exit remains executable")
	check(dying.flow.phase == RunFlowState.Phase.RESULT and dying.player.hp == 0 and dying.rng.state == rng_before,"Lethal cost produces explicit result without destination draw/soft-lock")

func _conditions_and_failure() -> void:
	var run: RunState = state(13,&"floor_level_7")
	var route: CutOutRouteData = run.floor_state.definition.cutout_route_pool[1]
	var weights: Dictionary = CutOutSystem.distribution(route,run,GAME)
	check(weights.weights[0] > 0 and weights.weights[1] == 0,"Missing clue filters optional destination, never all routes")
	run.player.knowledge.rules.append(&"lore_level_8")
	check(CutOutSystem.distribution(route,run,GAME).weights[1] > 0,"Knowledge activates candidate without being spent")
	var requirement: TravelRequirementData = TravelRequirementData.new()
	requirement.kind = TravelRequirementData.Kind.EVENT_OUTCOME
	requirement.id = &"event_bathroom_read"
	check(not requirement.satisfied(run),"Unchosen event is not completed outcome")
	var event_result: ActionResult = ActionResult.new()
	run.flow.phase = RunFlowState.Phase.EVENT
	run.flow.active_event = load("res://data/events/event_bathroom.tres") as EventData
	var request: GameCommand = command(run,GameCommand.Kind.EVENT_CHOICE)
	var planned: ActionResult = RuleResolver.plan(request,run,GAME)
	check(planned.success and not requirement.satisfied(run),"Event outcome waits for commit")
	RuleResolver.commit(planned,run)
	check(requirement.satisfied(run),"Chosen event outcome persists on owning floor")
	var bad: GameData = GAME.duplicate(false) as GameData
	bad.floors = GAME.floors.duplicate()
	var target: FloorData = GAME.find_floor(&"floor_level_7").duplicate(false) as FloorData
	target.map_config = target.map_config.duplicate(false) as MapGenerationData
	target.map_config.rules = target.map_config.rules.duplicate()
	target.map_config.rules[0] = target.map_config.rules[0].duplicate(false) as MapRuleData
	target.map_config.rules[0].min_layer = 99
	target.map_config.rules[0].max_layer = 99
	bad.floors[2] = target
	var source: RunState = state(17,&"floor_level_6")
	source.floor_state.definition = source.floor_state.definition.duplicate(false) as FloorData
	source.floor_state.definition.cutout_route_pool = source.floor_state.definition.cutout_route_pool.duplicate()
	for index: int in range(source.floor_state.definition.cutout_route_pool.size()):
		if source.floor_state.definition.cutout_route_pool[index].id == &"level6_waves":
			var paid: CutOutRouteData = source.floor_state.definition.cutout_route_pool[index].duplicate(false) as CutOutRouteData
			paid.hp_cost = 3
			paid.stress_cost = 2
			source.floor_state.definition.cutout_route_pool[index] = paid
	place_exit(source)
	source.floor_state.map.find(source.floor_state.map.current_node_id).content_id = &"level6_waves"
	var before: String = snapshot(source)
	var failed: ActionResult = RuleResolver.resolve(command(source,GameCommand.Kind.CUTOUT),source,bad)
	check(not failed.success and failed.failure_reason == &"invalid_map" and snapshot(source) == before and source.player.knowledge.connections.is_empty(),"Invalid generated destination rolls back cost, map, Knowledge and RNG")
	var conditional: CutOutDestinationData = route.destinations[1].duplicate(true) as CutOutDestinationData
	conditional.requirements.clear()
	var gated: FloorData = GAME.find_floor(&"floor_level_6").duplicate(false) as FloorData
	gated.entrances = gated.entrances.duplicate()
	gated.entrances[0] = gated.entrances[0].duplicate(false) as FloorEntranceData
	var entry_req: TravelRequirementData = TravelRequirementData.new()
	entry_req.id = &"unknown_entry_pass"
	gated.entrances[0].requirements = [entry_req]
	bad.floors[1] = gated
	check(not CutOutSystem.destination_allowed(conditional,run,bad),"Target entrance independently validates conditions")
	var locked_game: GameData = GAME.duplicate(false) as GameData
	locked_game.floors = GAME.floors.duplicate()
	var locked_floor: FloorData = GAME.floors[0].duplicate(false) as FloorData
	locked_floor.cutout_route_pool = locked_floor.cutout_route_pool.duplicate()
	var locked_route: CutOutRouteData = locked_floor.cutout_route_pool[0].duplicate(false) as CutOutRouteData
	locked_route.destinations = locked_route.destinations.duplicate()
	for index: int in range(locked_route.destinations.size()):
		locked_route.destinations[index] = locked_route.destinations[index].duplicate(false) as CutOutDestinationData
		locked_route.destinations[index].requirements = [entry_req]
	locked_floor.cutout_route_pool[0] = locked_route
	locked_game.floors[0] = locked_floor
	check(not ContentValidator.validate(locked_game).is_empty(),"All-conditional terminal exit is rejected as invalid content")
	_revisit_level7()

func _revisit_level7() -> void:
	var run: RunState = state(21,&"floor_level_6")
	var six: FloorState = run.floor_state
	place_exit(run)
	six.map.find(six.map.current_node_id).content_id = &"level6_waves"
	check(RuleResolver.resolve(command(run,GameCommand.Kind.CUTOUT),run,GAME).success,"Six-to-seven transition")
	var seven: FloorState = run.floor_state
	var map: FloorMapState = seven.map
	seven.map.nodes[1].resolution = MapNodeState.Resolution.RESOLVED
	seven.event_outcomes.append(&"event_cave_chart_read")
	run.player.knowledge.rules.append(&"lore_level_8")
	place_exit(run)
	seven.map.find(seven.map.current_node_id).content_id = &"level7_cave"
	var returned: bool = false
	for seed: int in range(1000):
		run.rng.seed = seed
		var draft: ActionResult = RuleResolver.plan(command(run,GameCommand.Kind.CUTOUT),run,GAME)
		if draft.success and draft.flow.destination == &"floor_level_6":
			RuleResolver.commit(draft,run)
			returned = true
			break
	check(returned and run.floor_state == six and six.map.current_node_id == &"entry","Revisit six restores exact historical map")
	place_exit(run)
	six.map.find(six.map.current_node_id).content_id = &"level6_waves"
	check(RuleResolver.resolve(command(run,GameCommand.Kind.CUTOUT),run,GAME).success,"Return to visited seven")
	check(run.floor_state == seven and seven.map == map and map.current_node_id == &"entry" and map.nodes[1].resolution == MapNodeState.Resolution.RESOLVED and seven.event_outcomes.has(&"event_cave_chart_read"),"Seven reentry keeps map, finite node state and event outcomes")

func _level7_behavior() -> void:
	var run: RunState = state(27,&"floor_level_7")
	var definition: EntityData = load("res://data/entities/entity_thing7.tres") as EntityData
	start_combat(run,definition)
	check(run.combat.enemies[0].hp == 90 and run.combat.ap == 3,"Thing uses common HP and AP system")
	var light: CardData = load("res://data/cards/card_light_bomb.tres") as CardData
	var entity: EntityInstance = run.combat.enemies[0]
	run.combat.intel = 1
	check(play(run,light).success,"Existing strong-light effect activates data-defined weakness")
	check(entity.hp > 0 and not entity.active and run.player.knowledge.rules.has(&"abyss_light"),"Thing withdraws alive and confirms same clue")

func _toward(run: RunState, exit_id: StringName) -> GameCommand:
	if run.flow.phase == RunFlowState.Phase.MAP:
		var best: StringName
		var score: int = -999
		for id: StringName in run.floor_state.map.next_ids():
			if MapGraph.distance(run.floor_state.map,id,exit_id) < 0: continue
			var node: MapNodeState = run.floor_state.map.find(id)
			var value: int = [0,-4,3,4,5,1,6,0][node.kind]
			if value > score: best = id; score = value
		var move: GameCommand = command(run,GameCommand.Kind.MOVE)
		move.node_id = best
		return move
	if run.flow.phase == RunFlowState.Phase.COMBAT and run.floor_state.floor_id == &"floor_level_7":
		for instance: CardInstance in run.combat.deck.hand:
			if instance.definition.effects.any(func(e: EffectData) -> bool: return e.effect_type == EffectData.EffectType.LIGHT and e.amount > 0):
				var play_light: GameCommand = play_command(run,instance)
				if CombatSystem.card_error(play_light,run).is_empty(): return play_light
	return auto_command(run)

func _full_run() -> void:
	var completed: bool = false
	for seed: int in range(1,41):
		var run: RunState = state(seed)
		for wanted: StringName in [&"level0_service",&"level6_waves",&"level7_fire_door"]:
			var target: MapNodeState
			for node: MapNodeState in run.floor_state.map.nodes:
				if node.kind == MapNodeState.Kind.EXIT and node.content_id == wanted: target = node
			if target == null: break
			for step: int in range(220):
				if run.flow.phase in [RunFlowState.Phase.CUTOUT,RunFlowState.Phase.RESULT]: break
				var result: ActionResult = RuleResolver.resolve(_toward(run,target.id),run,GAME)
				check(result.success,"Full route uses real legal commands")
				if not result.success: break
			if run.flow.phase != RunFlowState.Phase.CUTOUT: break
			check(RuleResolver.resolve(command(run,GameCommand.Kind.CUTOUT),run,GAME).success,"Full run exits through actual reached node")
		if run.player.hp > 0 and run.flow.phase == RunFlowState.Phase.RESULT and run.history.floors.has(&"floor_level_7"):
			completed = true
			verified_seed = seed
			print("[PHASE15 RUN] seed=%d hp=%d transitions=%d" % [seed,run.player.hp,run.metrics.floor_transitions])
			break
	check(completed,"Real commands complete Level0 -> Level6 -> Level7 -> extraction")

func _new_ui() -> void:
	var main: MainGameView = MAIN.instantiate() as MainGameView
	root.add_child(main)
	await process_frame
	main._show_network()
	await process_frame
	var view: LevelNetworkView = main.get_node("LevelNetwork") as LevelNetworkView
	check(view != null and view.find_children("*","Button",true,false).size() == 1,"Network has only close button, no teleport/gameplay bypass")
	view.free()
	main.free()
