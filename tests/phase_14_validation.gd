extends SceneTree
## Phase 14 回归：历史玩法断言已退役，保留事务/所有权/有限收益等不变量。
const GAME: GameData = preload("res://data/game.tres")
const MAIN: PackedScene = preload("res://scenes/main/Main.tscn")
var checks: int = 0
var failures: Array[String] = []
var _graphical: bool = false
var _captures: Array[String] = []
var _capture_directory: String

func _initialize() -> void:
	_run.call_deferred()

func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)
		push_error("[TEST] FAIL " + label)

func _run() -> void:
	_content()
	_ownership()
	_combat()
	_equipment_and_behavior()
	_finite_equipment()
	_all_cards_and_entities()
	_escape()
	_maps()
	_nodes()
	_cutout_history()
	await _production_and_ui()
	if failures.is_empty(): print("[TEST] PASS Phase 14: %d checks; content, transactions, combat, DAG, rewards, history, UI" % checks)
	else: print("[TEST] FAIL Phase 14: %d failures / %d checks" % [failures.size(), checks])
	quit(0 if failures.is_empty() else 1)

func state(seed: int = 1, floor_id: StringName = &"floor_level_0") -> RunState:
	var owner: TurnManager = TurnManager.new()
	owner.game_data = GAME
	owner.start_run(seed)
	var result: RunState = owner.run_state
	owner.free()
	if floor_id != GAME.starting_floor:
		result.floor_state = MapSystem.generate(GAME.find_floor(floor_id), result.rng)
		result.history.floors[floor_id] = result.floor_state
	return result

func card(id: String) -> CardData:
	return load("res://data/cards/" + id + ".tres") as CardData

func enemy(id: String) -> EntityData:
	return load("res://data/entities/" + id + ".tres") as EntityData

func start_combat(run: RunState, data: EntityData) -> void:
	var result: ActionResult = ActionResult.new()
	result.expected_revision = run.revision
	result.expected_run = run
	result.success = true
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.state = run.rng.state
	CombatSystem.plan_start(data, result, run, rng)
	result.flow.rng_after = rng.state
	RuleResolver.commit(result, run)

func command(run: RunState, kind: GameCommand.Kind, choice: int = 0) -> GameCommand:
	var result: GameCommand = GameCommand.new(kind, run)
	result.choice = choice
	return result

func play_command(run: RunState, instance: CardInstance) -> GameCommand:
	var result: GameCommand = command(run, GameCommand.Kind.PLAY_CARD)
	result.card = instance
	result.definition = instance.definition
	if instance.definition.target_kind == CardData.TargetKind.ENTITY: result.target = run.combat.enemies[0]
	return result

func give(run: RunState, definition: CardData) -> CardInstance:
	var instance: CardInstance = CardInstance.new(definition)
	run.combat.deck.hand.append(instance)
	return instance

func play(run: RunState, definition: CardData) -> ActionResult:
	return RuleResolver.resolve(play_command(run, give(run, definition)), run, GAME)

func snapshot(run: RunState) -> String:
	var data: Array = [run.revision, run.player.hp, run.player.stress, run.player.supply, run.rng.state, run.flow.phase, run.floor_state.get_instance_id(), run.floor_state.map.current_node_id, run.flow.pending_rewards.size(), run.player.knowledge.rules.duplicate(), run.metrics.commands]
	for item: EquipmentInstance in run.player.equipment.slots: data.append(item.remaining_uses if item != null else -1)
	for owned: CardInstance in run.player.deck.cards: data.append([owned.get_instance_id(), owned.definition.id])
	for node: MapNodeState in run.floor_state.map.nodes: data.append([node.id, node.visibility, node.resolution, node.content_id])
	if run.combat != null:
		var battle: CombatState = run.combat
		data.append([battle.get_instance_id(),battle.turn_number,battle.ap,battle.block,battle.intel,battle.noise,battle.light_active])
		for zone: Array[CardInstance] in [battle.deck.hand,battle.deck.draw_pile,battle.deck.discard_pile,battle.deck.exhaust_pile]:
			data.append(zone.map(func(c: CardInstance) -> Array: return [c.get_instance_id(),c.definition.id]))
		for e: EntityInstance in battle.enemies: data.append([e.hp,e.block,e.state,e.current_intent.get_instance_id(),e.weakness_turns.duplicate(),e.statuses.map(func(s: StatusInstance) -> Array: return [s.definition.id,s.stacks,s.remaining_turns])])
	return str(data)

func reject_unchanged(run: RunState, request: GameCommand, label: String) -> void:
	var before: String = snapshot(run)
	var result: ActionResult = RuleResolver.resolve(request, run, GAME)
	check(not result.success and snapshot(run) == before, label)

func _content() -> void:
	check(ContentValidator.validate(GAME).is_empty(), "All connected content validates")
	var definitions: Array = JSON.parse_string(FileAccess.get_file_as_string("res://docs/PHASE_14_CONTENT_INDEX.json"))
	check(definitions.size() == 284, "284 declared Resource instances")
	for row: Dictionary in definitions: check(load(row.path) != null, "Resource loads: " + row.path)
	for row: Dictionary in definitions:
		if row.type in ["CardData","EventData","EntityData","FloorData"]: check(AssetCatalog.texture(StringName(row.id)) != null,"Current content has loaded art or deterministic default")
	check(AssetCatalog.audio(&"not_provided") == null,"Missing audio safely remains silent")
	check(GAME.card_pool.size() == 24 and GAME.starter_deck.cards.size() == 12, "24 ordinary cards and real 12-card starting deck")
	check(card("card_quick_draw").exhaust and card("card_quick_draw_plus").exhaust,"Quick Draw upgrade preserves exhaust lifecycle")
	var bad: GameData = GAME.duplicate(false) as GameData
	bad.revisit_weight_multiplier = 0
	check(not ContentValidator.validate(bad).is_empty(), "Cannot remove all revisit routes by zeroing multiplier")
	var option: EventOptionData = EventOptionData.new()
	option.id = &"locked"
	option.supply_cost = 99
	var event: EventData = EventData.new()
	event.id = &"bad"
	event.options = [option]
	var errors: Array[String] = []
	ContentValidator.validate_event(event, errors, [])
	check(not errors.is_empty(), "Events must retain a free option")

func _ownership() -> void:
	var a: RunState = state()
	var b: RunState = state()
	check(a.player != b.player and a.player.deck != b.player.deck and a.history != b.history, "Independent runs own distinct states")
	for property: Dictionary in a.player.get_property_list(): check(property.name not in ["ap","block","intel","noise"], "Player does not duplicate combat state")
	for property: Dictionary in a.player.deck.get_property_list(): check(property.name not in ["hand","draw_pile","discard_pile"], "Persistent deck has no combat zones")
	check(a.player.hp == 30 and a.player.knowledge.rules.is_empty(), "HP 30 and non-numeric Knowledge set")
	start_combat(a, enemy("entity_hound"))
	check(a.combat.ap == 3 and a.combat.deck.hand.size() == 6, "First combat: 3 AP, five base plus one equipment")
	for instance: CardInstance in a.combat.deck.hand: check(not a.player.deck.cards.has(instance), "Battle copies never alias owned card instances")
	var count: int = a.player.deck.cards.size()
	RuleResolver.resolve(command(a,GameCommand.Kind.END_TURN),a,GAME)
	check(a.player.deck.cards.size() == count and a.combat.ap == 3 and a.combat.turn_number == 2, "Turn resets AP and preserves persistent deck")
	var ordinary: Array[CardInstance] = []
	for zone: Array[CardInstance] in [a.combat.deck.hand,a.combat.deck.draw_pile,a.combat.deck.discard_pile,a.combat.deck.exhaust_pile]:
		for instance: CardInstance in zone:
			if instance.definition.source == CardData.Source.NORMAL: ordinary.append(instance)
	check(ordinary.size() == count, "Ordinary cards conserved across all four combat zones")
	reject_unchanged(b,command(b,GameCommand.Kind.END_TURN),"No exploration End Turn or second AP loop")

func simple_enemy() -> EntityData:
	var data: EntityData = enemy("entity_hound").duplicate(false) as EntityData
	data.behavior_data = EntityBehaviorData.new()
	data.behavior_data.actions = [load("res://data/entities/actions/bite.tres") as EntityActionData]
	data.weaknesses = []
	return data

func _combat() -> void:
	var run: RunState = state()
	start_combat(run,simple_enemy())
	var attack: CardInstance = give(run,card("card_attack"))
	var request: GameCommand = play_command(run,attack)
	var before: String = snapshot(run)
	var result: ActionResult = RuleResolver.plan(request,run,GAME)
	check(result.success and snapshot(run) == before, "Plan does not mutate AP/HP/cards/intent/RNG")
	var other: RunState = state()
	other.revision = run.revision
	check(not RuleResolver.commit(result,other), "Result cannot be applied to another Run with same revision")
	var target: EntityInstance = run.combat.enemies[0]
	check(RuleResolver.commit(result,run) and run.combat.enemies[0] == target and target.hp == 14 and run.combat.ap == 2, "Attack commits actual 4 damage once and preserves entity identity")
	check(not RuleResolver.commit(result,run), "Same ActionResult cannot be committed twice")
	reject_unchanged(run,request,"Old command cannot replay")
	var fake: GameCommand = play_command(run,give(run,card("card_attack")))
	fake.target = target.copy()
	reject_unchanged(run,fake,"Same data ID but different runtime instance rejected")
	var precise: GameCommand = play_command(run,give(run,card("card_precision")))
	reject_unchanged(run,precise,"Insufficient Intel spends nothing")
	play(run,card("card_recon"))
	check(run.combat.intel == 2 and run.combat.ap == 1, "Recon gains Intel and draws inside current deck")
	check(play(run,card("card_precision")).success and target.hp == 4 and run.combat.intel == 0, "Intel combo spends its own cost atomically")
	reject_unchanged(run,play_command(run,give(run,card("card_attack"))),"Zero AP spends nothing")
	RuleResolver.resolve(command(run,GameCommand.Kind.END_TURN),run,GAME)
	check(run.player.hp == 26, "Locked public bite deals exactly four unblocked damage")
	play(run,card("card_defend"))
	RuleResolver.resolve(command(run,GameCommand.Kind.END_TURN),run,GAME)
	check(run.player.hp == 26 and run.combat.block == 0, "Guard absorbs expected damage then expires")
	var final: GameCommand = play_command(run,give(run,card("card_attack")))
	check(RuleResolver.resolve(final,run,GAME).success and run.combat == null and run.metrics.victories == 1, "HP zero resolves one defeat and clears encounter")
	check(target.hp == 0 and not target.alive and not target.active,"Retired runtime instance itself is dead after final commit")
	var rewards: int = run.flow.pending_rewards.size()
	reject_unchanged(run,final,"Defeat cannot repeat")
	check(run.flow.pending_rewards.size() == rewards, "No duplicate victory rewards")
	run = state()
	start_combat(run,simple_enemy())
	run.combat.intel = 2
	play(run,card("card_disrupt"))
	RuleResolver.resolve(command(run,GameCommand.Kind.END_TURN),run,GAME)
	check(run.player.hp == 30 and run.combat.enemies[0].statuses.is_empty(), "Stun skips one locked intent and expires")
	var malformed: CardData = card("card_attack").duplicate(false) as CardData
	malformed.effects = [EffectData.new()]
	reject_unchanged(run,play_command(run,give(run,malformed)),"Malformed effects fail before any commit")

func _equipment_and_behavior() -> void:
	var run: RunState = state()
	start_combat(run,enemy("entity_smiler"))
	var flashlight: EquipmentInstance = run.player.equipment.slots[0]
	var light: CardInstance
	for instance: CardInstance in run.combat.deck.hand:
		if instance.source_equipment == flashlight: light = instance
	check(light != null and flashlight.remaining_uses == 3, "Equipment generates a real card without consuming battery")
	run.combat.ap = 0
	reject_unchanged(run,play_command(run,light),"Failed light use cannot consume battery")
	run.combat.ap = 3
	var old: GameCommand = play_command(run,light)
	check(RuleResolver.resolve(old,run,GAME).success and flashlight.remaining_uses == 2 and run.combat.light_active, "Successful strong light consumes one battery")
	check(run.combat.enemies[0].state == &"AGITATED" and run.combat.enemies[0].hp == 120, "Smiler uses common HP and actual strong light reaction")
	reject_unchanged(run,old,"Changed light definition invalidates old command")
	var off: CardInstance
	for instance: CardInstance in run.combat.deck.hand:
		if instance.source_equipment == flashlight: off = instance
	check(off != null and off.definition != light.definition, "Extinguish is a separate real definition in same opportunity")
	RuleResolver.resolve(play_command(run,off),run,GAME)
	check(flashlight.remaining_uses == 2 and not run.combat.light_active, "Extinguish does not consume charge")
	RuleResolver.resolve(command(run,GameCommand.Kind.END_TURN),run,GAME)
	RuleResolver.resolve(command(run,GameCommand.Kind.END_TURN),run,GAME)
	check(run.combat == null and run.metrics.resolved_alive == 1 and run.player.knowledge.rules.count(&"light_attracts") == 1, "Correct dark behavior resolves Smiler alive with unique Knowledge")
	start_combat(run,enemy("entity_smiler"))
	RuleResolver.resolve(command(run,GameCommand.Kind.END_TURN),run,GAME)
	RuleResolver.resolve(command(run,GameCommand.Kind.END_TURN),run,GAME)
	check(run.player.knowledge.rules.count(&"light_attracts") == 1, "Repeated behavior discovery does not duplicate Knowledge")
	run = state()
	start_combat(run,enemy("entity_hound"))
	var tagged: CardData = card("card_attack").duplicate(false) as CardData
	tagged.tags = [&"NOISE"]
	play(run,tagged)
	check(run.combat.noise == 0 and run.combat.enemies[0].state == &"WATCHING", "Unresolved display tag is not an actual Noise effect")
	var noisy: CardData = card("card_risky").duplicate(false) as CardData
	var actual_noise: EffectData = load("res://data/effects/noise1.tres").duplicate(true) as EffectData
	actual_noise.amount = 2
	noisy.effects = [actual_noise]
	play(run,noisy)
	check(run.combat.noise == 2 and run.combat.enemies[0].state == &"CHASING", "Actual Noise changes Hound behavior")
	var locked: EnemyIntent = run.combat.enemies[0].current_intent
	check(locked.display_name == "警戒靠近", "Noise cannot silently change already locked intent")
	RuleResolver.resolve(command(run,GameCommand.Kind.END_TURN),run,GAME)
	check(run.combat.enemies[0].current_intent.action_id == &"lunge", "Next intent reads combat-local Noise")
	var before: int = run.player.hp
	var expected: int = run.combat.enemies[0].current_intent.effects[0].amount
	RuleResolver.resolve(command(run,GameCommand.Kind.END_TURN),run,GAME)
	check(before - run.player.hp == expected, "Displayed locked damage equals actual resolution")
	for item: EquipmentInstance in run.player.equipment.slots: check(item.remaining_uses <= item.definition.capacity, "Shared EquipmentData capacity never mutated")

func _escape() -> void:
	var seen: Dictionary = {}
	for seed: int in range(100):
		var run: RunState = state(seed)
		start_combat(run,simple_enemy())
		var floor: FloorState = run.floor_state
		var rng_before: int = run.rng.state
		var preview: EscapePreview = EscapeSystem.preview(run)
		for index: int in range(5): EscapeSystem.preview(run)
		check(run.rng.state == rng_before and preview.allowed, "Escape preview is pure")
		var hp: int = run.player.hp
		var result: ActionResult = RuleResolver.resolve(command(run,GameCommand.Kind.ESCAPE),run,GAME)
		var actual: int = hp - run.player.hp
		seen[actual] = true
		check(result.success and actual >= preview.damage_min and actual <= preview.damage_max and result.combat.after.ap == 2, "Escape samples published inclusive range and costs one AP")
		check(run.combat == null and run.floor_state == floor and run.flow.pending_rewards.is_empty() and run.metrics.victories == 0 and run.metrics.escapes == 1, "Escape returns to node, no victory reward or floor change")
	check(seen.size() >= 3, "Escape uses a real random HP range")
	var run: RunState = state()
	start_combat(run,simple_enemy())
	run.combat.ap = 0
	check(not EscapeSystem.preview(run).allowed and EscapeSystem.preview(run).damage_max > 0, "Unavailable escape still shows meaningful risk range")
	reject_unchanged(run,command(run,GameCommand.Kind.ESCAPE),"No zero-AP escape")
	run.combat.ap = 1
	run.player.hp = 1
	var result: ActionResult = RuleResolver.resolve(command(run,GameCommand.Kind.ESCAPE),run,GAME)
	check(result.combat.after.outcome == CombatState.Outcome.DEFEAT and run.flow.phase == RunFlowState.Phase.RESULT and run.flow.pending_rewards.is_empty(), "Lethal escape becomes DEFEAT without rewards")

func _all_cards_and_entities() -> void:
	for definition: CardData in GAME.card_pool:
		var run: RunState = state()
		var durable: EntityData = simple_enemy()
		durable.max_hp = 999
		start_combat(run,durable)
		run.player.hp = 15
		run.player.stress = 5
		run.combat.intel = 10
		run.combat.noise = 3
		var result: ActionResult = play(run,definition)
		check(result.success and run.metrics.cards_played == 1, "Every normal content card resolves meaningful declared mechanics: " + String(definition.id))
		check(run.player.deck.cards.size() == 12, "Playing content card cannot alter ownership")
		if definition.upgrade_to != null:
			run.combat.ap = 3
			run.combat.intel = 10
			check(play(run,definition.upgrade_to).success,"Each upgrade is a usable definition")
	var index: Array = JSON.parse_string(FileAccess.get_file_as_string("res://docs/PHASE_14_CONTENT_INDEX.json"))
	for row: Dictionary in index:
		if row.type != "EntityData": continue
		var run: RunState = state()
		run.player.hp = 100
		run.player.max_hp = 100
		start_combat(run,load(row.path) as EntityData)
		for turn: int in range(3):
			if run.combat == null: break
			var intent: EnemyIntent = run.combat.enemies[0].current_intent
			check(intent != null and not intent.display_name.is_empty(),"Every entity exposes a locked readable intent")
			check(RuleResolver.resolve(command(run,GameCommand.Kind.END_TURN),run,GAME).success,"Every entity supports the shared turn lifecycle")

func equipment_card(run: RunState, item: EquipmentInstance) -> CardInstance:
	var instance: CardInstance = CardInstance.new(item.definition.action_card)
	instance.source_equipment = item
	run.combat.deck.hand.append(instance)
	return instance

func _finite_equipment() -> void:
	var run: RunState = state()
	start_combat(run,simple_enemy())
	var crowbar: EquipmentInstance = run.player.equipment.slots[1]
	var tool: CardInstance = equipment_card(run,crowbar)
	run.combat.ap = 0
	reject_unchanged(run,play_command(run,tool),"Failed Crowbar cannot consume durability")
	run.combat.ap = 3
	check(RuleResolver.resolve(play_command(run,tool),run,GAME).success and crowbar.remaining_uses == 2,"Successful Crowbar consumes one durability")
	crowbar.remaining_uses = 0
	reject_unchanged(run,play_command(run,equipment_card(run,crowbar)),"Broken tool cannot be used")
	var water: EquipmentInstance = run.player.equipment.slots[2]
	run.player.hp = 20
	run.player.stress = 3
	check(RuleResolver.resolve(play_command(run,equipment_card(run,water)),run,GAME).success and water.remaining_uses == 0 and run.player.hp == 25,"Almond Water applies healing and one finite use")
	reject_unchanged(run,play_command(run,equipment_card(run,water)),"Water cannot be consumed twice")
	check(run.player.deck.cards.all(func(c:CardInstance)->bool:return c.source_equipment==null and c.definition.source==CardData.Source.NORMAL),"Equipment never enters persistent deck")
	RuleResolver.resolve(command(run,GameCommand.Kind.ESCAPE),run,GAME)
	start_combat(run,simple_enemy())
	check(run.combat.noise == 0 and run.combat.statuses.is_empty() and run.player.equipment.slots[1] == crowbar and crowbar.remaining_uses == 0,"New combat resets temporary state and preserves physical equipment")
	run.combat = null
	run.flow.phase = RunFlowState.Phase.REWARD
	var reward: RewardOpportunity = RewardOpportunity.new()
	reward.equipment = load("res://data/equipment/equip_baton.tres") as EquipmentData
	run.flow.pending_rewards = [reward]
	reject_unchanged(run,command(run,GameCommand.Kind.REWARD,3),"Fourth equipment slot is rejected atomically")
	RuleResolver.resolve(command(run,GameCommand.Kind.REWARD,0),run,GAME)
	check(run.player.equipment.slots.size() == 3 and run.player.equipment.slots[0].definition == reward.equipment,"Equipment reward explicitly replaces selected carry slot")
	var count: int = run.player.deck.cards.size()
	run.flow.phase = RunFlowState.Phase.REST
	run.player.deck.cards.resize(5)
	var remove: GameCommand = command(run,GameCommand.Kind.REST,2)
	remove.card = run.player.deck.cards[0]
	reject_unchanged(run,remove,"Cannot remove below five owned cards")
	check(count == 12,"Equipment rewards never add normal cards")

func _maps() -> void:
	for seed: int in range(250):
		for data: FloorData in GAME.floors:
			var rng: RandomNumberGenerator = RandomNumberGenerator.new()
			rng.seed = seed
			var floor: FloorState = MapSystem.generate(data,rng)
			var map: FloorMapState = floor.map
			var incoming: Dictionary = {0:true}
			var to_exit: Dictionary = {map.nodes.size()-1:true}
			for edge: Vector2i in map.edges:
				check(map.nodes[edge.x].layer < map.nodes[edge.y].layer, "DAG edges strictly forward")
				if incoming.has(edge.x): incoming[edge.y] = true
			for index: int in range(map.nodes.size()-1,-1,-1):
				for edge: Vector2i in map.edges:
					if edge.x == index and to_exit.has(edge.y): to_exit[index] = true
			check(incoming.size() == map.nodes.size() and to_exit.size() == map.nodes.size(), "Every generated node is reachable and can reach EXIT")
			check(map.find(&"entry").resolution == MapNodeState.Resolution.RESOLVED and map.nodes[-1].kind == MapNodeState.Kind.EXIT, "Explicit entry and exit")
			check(map.nodes.any(func(n: MapNodeState) -> bool: return n.visibility == MapNodeState.Visibility.UNKNOWN), "Fog hides contents, not nodes/edges")
	var run: RunState = state()
	var illegal: GameCommand = command(run,GameCommand.Kind.MOVE)
	illegal.node_id = run.floor_state.map.nodes[-1].id
	reject_unchanged(run,illegal,"Cannot skip directly to EXIT")
	var first: MapNodeState = run.floor_state.map.find(run.floor_state.map.next_ids()[0])
	first.visibility = MapNodeState.Visibility.REVEALED
	check(first.resolution == MapNodeState.Resolution.UNVISITED, "Revealed and unvisited are independent")
	var twin: RunState = state()
	check(topology(run.floor_state.map) == topology(twin.floor_state.map), "Same seed yields same map and fixed contents")

func topology(map: FloorMapState) -> String:
	return str([map.edges,map.nodes.map(func(n: MapNodeState) -> Array: return [n.id,n.kind,n.content_id,n.position])])

func set_node(run: RunState, kind: MapNodeState.Kind) -> void:
	# 测试夹具仅复用既有生成节点；正式 UI 从合法连线进入。
	var node: MapNodeState = run.floor_state.map.nodes[1]
	node.kind = kind
	node.resolution = MapNodeState.Resolution.ACTIVE
	run.floor_state.map.current_node_id = node.id

func _nodes() -> void:
	var run: RunState = state()
	set_node(run,MapNodeState.Kind.EVENT)
	run.flow.phase = RunFlowState.Phase.EVENT
	run.flow.active_event = load("res://data/events/event_cache.tres") as EventData
	run.player.supply = 0
	reject_unchanged(run,command(run,GameCommand.Kind.EVENT_CHOICE,0),"Event payment failure is atomic")
	var take: GameCommand = command(run,GameCommand.Kind.EVENT_CHOICE,1)
	var hp: int = run.player.hp
	RuleResolver.resolve(take,run,GAME)
	check(run.player.hp == hp-3 and run.player.supply == 4 and run.floor_state.map.find(run.floor_state.map.current_node_id).resolution == MapNodeState.Resolution.RESOLVED, "Event exchange commits HP and finite reward together")
	reject_unchanged(run,take,"One-time event cannot be claimed twice")
	for data: FloorData in GAME.floors:
		for event: EventData in data.event_pool:
			var empty: RunState = state()
			empty.player.supply = 0
			empty.player.hp = 1
			check(event.options.any(func(o: EventOptionData) -> bool: return EventSystem.option_error(o,empty).is_empty()), "Every event has resource-independent escape option")
	run = state()
	set_node(run,MapNodeState.Kind.REWARD)
	var draft: ActionResult = ActionResult.new()
	RewardSystem.plan(load("res://data/rewards/combat.tres") as RewardTableData,draft,run,run.rng)
	run.flow.pending_rewards = draft.flow.rewards
	run.flow.phase = RunFlowState.Phase.REWARD
	var forged: GameCommand = command(run,GameCommand.Kind.REWARD)
	forged.reward = RewardOpportunity.new()
	reject_unchanged(run,forged,"Forged reward cannot edit deck")
	var count: int = run.player.deck.cards.size()
	var claim: GameCommand = command(run,GameCommand.Kind.REWARD)
	RuleResolver.resolve(claim,run,GAME)
	check(run.player.deck.cards.size() == count+1 and run.flow.pending_rewards.is_empty(), "Claim adds one offered permanent card")
	reject_unchanged(run,claim,"Reward identity cannot replay")
	run.flow.phase = RunFlowState.Phase.REST
	var upgrade: GameCommand = command(run,GameCommand.Kind.REST,1)
	upgrade.card = run.player.deck.cards[0]
	var before: CardData = upgrade.card.definition
	RuleResolver.resolve(upgrade,run,GAME)
	check(upgrade.card.definition == before.upgrade_to and before.upgrade_to != null, "REST upgrades only actual owned instance")
	reject_unchanged(run,upgrade,"REST consumed once")
	run.flow.phase = RunFlowState.Phase.SHOP
	run.flow.active_shop = GAME.floors[0].shops[0]
	run.player.supply = 0
	reject_unchanged(run,command(run,GameCommand.Kind.SHOP,0),"Shop rejects insufficient Supply")
	RuleResolver.resolve(command(run,GameCommand.Kind.SHOP,-1),run,GAME)
	check(run.flow.phase == RunFlowState.Phase.MAP, "Shop can always be left for free")
	run = state()
	set_node(run,MapNodeState.Kind.EVENT)
	run.flow.phase = RunFlowState.Phase.EVENT
	run.flow.active_event = load("res://data/events/event_meg.tres") as EventData
	RuleResolver.resolve(command(run,GameCommand.Kind.EVENT_CHOICE,0),run,GAME)
	check(run.player.knowledge.floors.has(&"floor_level_6") and run.player.knowledge.exits.has(&"level0_service") and run.player.knowledge.rules.has(&"map_survey"),"Event unlocks typed floor/exit/rule knowledge, not points")
	place_exit(run)
	check(not CutOutSystem.preview(run,GAME).labels.has("未知目的地"),"Known floor identity reveals destination in pure preview")
	# 撤离只能放弃本场胜利奖励，不能撤销进战斗前已合法取得的收益。
	run = state()
	run.player.supply = 9
	var prior: RewardOpportunity = RewardOpportunity.new()
	prior.cards = [card("card_defend")]
	run.flow.pending_rewards.append(prior)
	start_combat(run,simple_enemy())
	RuleResolver.resolve(command(run,GameCommand.Kind.ESCAPE),run,GAME)
	check(run.player.supply == 9 and run.flow.pending_rewards == [prior] and run.flow.phase == RunFlowState.Phase.REWARD,"Escape preserves pre-encounter rewards and resources")

func place_exit(run: RunState, route_index: int = 0) -> void:
	var node: MapNodeState = run.floor_state.map.nodes[-1]
	node.content_id = run.floor_state.definition.cutout_route_pool[route_index].id
	run.floor_state.map.current_node_id = node.id
	node.resolution = MapNodeState.Resolution.ACTIVE
	run.flow.phase = RunFlowState.Phase.CUTOUT

func _cutout_history() -> void:
	var run: RunState = state()
	place_exit(run)
	var rng_before: int = run.rng.state
	var preview: CutOutPreview = CutOutSystem.preview(run,GAME)
	for index: int in range(50): CutOutSystem.preview(run,GAME)
	check(preview.allowed and run.rng.state == rng_before and preview.labels.has("未知目的地"), "CutOut hides unknown identity and never consumes preview RNG")
	var total: float = 0
	for probability: float in preview.probabilities: total += probability
	check(is_equal_approx(total,1.0), "Normalized published probabilities sum to one")
	var old: FloorState = run.floor_state
	var old_map: FloorMapState = old.map
	old.map.nodes[1].resolution = MapNodeState.Resolution.RESOLVED
	var deck: DeckState = run.player.deck
	var equipment: EquipmentState = run.player.equipment
	var request: GameCommand = command(run,GameCommand.Kind.CUTOUT)
	var before: String = snapshot(run)
	var draft: ActionResult = RuleResolver.plan(request,run,GAME)
	check(draft.success and run.floor_state == old and snapshot(run) == before, "Planned transition changes no current floor")
	RuleResolver.commit(draft,run)
	check(run.player.deck == deck and run.player.equipment == equipment and run.history.floors[old.floor_id] == old, "Floor transition preserves owned deck, gear and historical state")
	reject_unchanged(run,request,"Same CutOut cannot submit twice")
	# 确保测试一次返回真实旧楼层的切出，再核对入口和历史身份。
	if run.floor_state.floor_id == &"floor_level_6":
		place_exit(run)
		for seed: int in range(1000):
			run.rng.seed = seed
			var back: ActionResult = RuleResolver.plan(command(run,GameCommand.Kind.CUTOUT),run,GAME)
			if back.flow.destination == &"floor_level_0":
				RuleResolver.commit(back,run)
				break
	check(run.floor_state == old and run.floor_state.map == old_map and old.map.current_node_id == &"entry", "Reentry restores same floor/map at entry")
	check(old.map.nodes[1].resolution == MapNodeState.Resolution.RESOLVED, "Already claimed content remains resolved")
	var destination: StringName = old.map.nodes[1].id
	var move: GameCommand = command(run,GameCommand.Kind.MOVE)
	move.node_id = destination
	var supply: int = run.player.supply
	var reward_count: int = run.metrics.rewards_claimed
	RuleResolver.resolve(move,run,GAME)
	check(run.flow.phase == RunFlowState.Phase.MAP and run.player.supply == supply and run.metrics.rewards_claimed == reward_count, "Resolved node is traversable without repeated rewards or encounter")
	# 即使原图全部结算且没有任何资源，重返仍可通行到 EXIT。
	for node: MapNodeState in old.map.nodes: node.resolution = MapNodeState.Resolution.RESOLVED
	run.player.supply = 0
	run.player.knowledge.rules.clear()
	for item: EquipmentInstance in run.player.equipment.slots: item.remaining_uses = 0
	while run.flow.phase == RunFlowState.Phase.MAP:
		var forward: GameCommand = command(run,GameCommand.Kind.MOVE)
		forward.node_id = old.map.next_ids()[0]
		check(RuleResolver.resolve(forward,run,GAME).success,"Exhausted historical floor still has forward traversal")
	check(CutOutSystem.preview(run,GAME).allowed,"No resources or missed Knowledge can permanently block historical exit")
	var samples: int = 0
	run = state(1,&"floor_level_6")
	place_exit(run,0)
	for seed: int in range(3000):
		var rng: RandomNumberGenerator = RandomNumberGenerator.new()
		rng.seed = seed
		var sample: ActionResult = ActionResult.new()
		CutOutSystem.plan(sample,run,GAME,rng)
		if sample.flow.destination == &"run_end": samples += 1
	# floor0 已访问降权：8 : (2*0.15)，不能仍按原始 80% 宣称。
	check(absf(float(samples)/3000 - 8.0/8.3) < 0.025, "3000 destination samples match effective weights")

func _production_and_ui() -> void:
	var main: MainGameView = MAIN.instantiate() as MainGameView
	root.size = Vector2i(1152,648)
	root.add_child(main)
	await process_frame
	check(main.manager.run_state.flow.phase == RunFlowState.Phase.MAP, "Normal entry opens production map")
	await capture(main,"map_level0")
	var completed: bool = false
	for seed: int in range(1,16):
		main.manager.start_run(seed)
		for step: int in range(180):
			var run: RunState = main.manager.run_state
			if run.flow.phase == RunFlowState.Phase.RESULT:
				if run.player.hp > 0:
					completed = true
					await capture(main,"summary")
					print("[RUN] seed=%d hp=%d victories=%d escapes=%d transitions=%d cards=%d" % [seed,run.player.hp,run.metrics.victories,run.metrics.escapes,run.metrics.floor_transitions,run.player.deck.cards.size()])
				break
			await capture(main,phase_name(run))
			var next: GameCommand = auto_command(run)
			var result: ActionResult = main.manager.submit(next)
			check(result.success,"Production UI command path accepts current legal action: " + str(next.kind))
			if not result.success: break
		if completed: break
	check(completed,"At least one actual production seed completes Level0 -> Level6 -> extraction alive")
	await _ui_fixtures(main)
	for dimensions: Vector2i in [Vector2i(1152,648),Vector2i(1280,720),Vector2i(1920,1080)]:
		root.size = dimensions
		main.manager.start_run(7)
		await process_frame
		await process_frame
		check(root.get_visible_rect().encloses(main._status.get_global_rect()),"Status fits supported resolution")
		check(main.find_children("*","OptionButton",true,false).is_empty(),"No debug/mode selectors in production UI")
		await capture(main,"map_%dx%d" % [dimensions.x,dimensions.y])
	main.free()

func _fixture_game(kind: MapNodeState.Kind, enemy_id: String = "entity_hound") -> GameData:
	# 明确标记的内容夹具：同样经节点命令进入，不在正式 UI 添加强制遭遇按钮。
	var game: GameData = GAME.duplicate(false) as GameData
	var floor: FloorData = GAME.floors[0].duplicate(false) as FloorData
	floor.map_config = floor.map_config.duplicate(true) as MapGenerationData
	var weights: PackedInt32Array = PackedInt32Array([0,0,0,0,0,0])
	weights[kind] = 100
	floor.map_config.node_weights = weights
	floor.encounter_pool = [enemy(enemy_id)]
	floor.event_pool = [load("res://data/events/event_lights.tres") as EventData]
	floor.reward_pool = load("res://data/rewards/combat.tres") as RewardTableData
	game.floors = [floor,GAME.floors[1]]
	return game

func _mouse_click(control: Control) -> void:
	await process_frame
	await process_frame
	var point: Vector2 = control.get_global_rect().get_center()
	var motion: InputEventMouseMotion = InputEventMouseMotion.new()
	motion.position = point
	root.push_input(motion,true)
	var hit: Control = root.gui_get_hovered_control()
	check(hit == control or (hit != null and control.is_ancestor_of(hit)),"Actual GUI hit reaches intended control")
	var press: InputEventMouseButton = InputEventMouseButton.new()
	press.position = point
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.button_mask = MOUSE_BUTTON_MASK_LEFT
	root.push_input(press,true)
	var release: InputEventMouseButton = press.duplicate() as InputEventMouseButton
	release.pressed = false
	release.button_mask = 0
	root.push_input(release,true)
	await process_frame

func _ui_fixtures(main: MainGameView) -> void:
	for dimensions: Vector2i in [Vector2i(1152,648),Vector2i(1280,720),Vector2i(1920,1080)]:
		root.size = dimensions
		for kind: MapNodeState.Kind in [MapNodeState.Kind.COMBAT,MapNodeState.Kind.EVENT,MapNodeState.Kind.REST,MapNodeState.Kind.REWARD,MapNodeState.Kind.SHOP]:
			main.manager.game_data = _fixture_game(kind)
			main.manager.start_run(42)
			await process_frame
			var map: MapView = main._content.get_child(2) as MapView
			var next: Button
			for button: Node in map.get_children():
				if button is Button and not (button as Button).disabled: next = button as Button; break
			await _mouse_click(next)
			check(main.manager.run_state.flow.phase != RunFlowState.Phase.MAP,"Actual map click enters requested node")
			await process_frame
			await process_frame
			check(root.get_visible_rect().encloses(main._content.get_global_rect()),"Whole node screen fits resolution: kind=%d dims=%s content=%s viewport=%s" % [kind,dimensions,main._content.get_global_rect(),root.get_visible_rect()])
			await capture(main,"fixture_%s_%dx%d" % [phase_name(main.manager.run_state),dimensions.x,dimensions.y])
			if kind == MapNodeState.Kind.COMBAT:
				var instance: PlayerCardView
				for button: Node in main._content.find_children("*","Button",true,false):
					if button is PlayerCardView and not (button as Button).disabled: instance = button as PlayerCardView; break
				var revision: int = main.manager.run_state.revision
				await _mouse_click(instance)
				check(main.manager.run_state.revision == revision+1,"Actual hand click commits one card transaction")
		main.manager.game_data = _fixture_game(MapNodeState.Kind.COMBAT,"entity_smiler")
		main.manager.start_run(42)
		var move: GameCommand = command(main.manager.run_state,GameCommand.Kind.MOVE)
		move.node_id = main.manager.run_state.floor_state.map.next_ids()[0]
		main.manager.submit(move)
		await capture(main,"fixture_smiler_%dx%d" % [dimensions.x,dimensions.y])
	main.manager.game_data = GAME

func phase_name(run: RunState) -> String:
	match run.flow.phase:
		RunFlowState.Phase.COMBAT: return "combat_" + String(run.combat.enemies[0].definition.id)
		RunFlowState.Phase.MAP: return "map_" + String(run.floor_state.floor_id)
		RunFlowState.Phase.EVENT: return "event"
		RunFlowState.Phase.REWARD: return "reward"
		RunFlowState.Phase.REST: return "rest"
		RunFlowState.Phase.SHOP: return "shop"
		RunFlowState.Phase.CUTOUT: return "cutout"
	return "other"

func auto_command(run: RunState) -> GameCommand:
	match run.flow.phase:
		RunFlowState.Phase.MAP:
			var ids: Array[StringName] = run.floor_state.map.next_ids()
			# 明确读取已固定内容仅用于自动测试；玩家 UI 不泄露未知节点。
			var best: StringName = ids[0]
			var score: int = -100
			for id: StringName in ids:
				var node: MapNodeState = run.floor_state.map.find(id)
				var value: int = [0,-3,3,2,4,1,5,0][node.kind]
				if value > score: score = value; best = id
			var next: GameCommand = command(run,GameCommand.Kind.MOVE)
			next.node_id = best
			return next
		RunFlowState.Phase.COMBAT:
			var best: GameCommand
			var score: int = -1
			for instance: CardInstance in run.combat.deck.hand:
				var next: GameCommand = play_command(run,instance)
				if not CombatSystem.card_error(next,run).is_empty(): continue
				var value: int = 0
				for effect: EffectData in instance.definition.effects:
					match effect.effect_type:
						EffectData.EffectType.DAMAGE: value += effect.amount * 2
						EffectData.EffectType.DRAW,EffectData.EffectType.GAIN_INTEL: value += 4
						EffectData.EffectType.BLOCK: value += 3 if run.combat.block < 4 else 0
						EffectData.EffectType.HEAL: value += 6 if run.player.hp < 23 else 0
						EffectData.EffectType.LIGHT: value += -50 if effect.amount > 0 else 20
				if value > score: score = value; best = next
			if best != null: return best
			if run.player.hp < 9 and EscapeSystem.preview(run).allowed: return command(run,GameCommand.Kind.ESCAPE)
			return command(run,GameCommand.Kind.END_TURN)
		RunFlowState.Phase.EVENT:
			var event: EventData = run.flow.active_event
			for index: int in range(event.options.size()):
				var option: EventOptionData = event.options[index]
				if option.encounter == null and EventSystem.option_error(option,run).is_empty(): return command(run,GameCommand.Kind.EVENT_CHOICE,index)
		RunFlowState.Phase.REWARD: return command(run,GameCommand.Kind.REWARD,-1 if run.flow.pending_rewards[0].equipment != null else 0)
		RunFlowState.Phase.REST: return command(run,GameCommand.Kind.REST,0 if run.player.hp < run.player.max_hp or run.player.stress > 0 else 4)
		RunFlowState.Phase.SHOP: return command(run,GameCommand.Kind.SHOP,-1)
		RunFlowState.Phase.CUTOUT: return command(run,GameCommand.Kind.CUTOUT)
	return command(run,GameCommand.Kind.EVENT_CHOICE,run.flow.active_event.options.size()-1)

func capture(_main: MainGameView, label: String) -> void:
	if not _graphical or _captures.has(label): return
	await process_frame
	await process_frame
	await create_timer(0.16).timeout
	await RenderingServer.frame_post_draw
	if _capture_directory.is_empty(): _capture_directory = OS.get_environment("BACKROOMS_PLAYTEST_OUTPUT")
	if _capture_directory.is_empty(): _capture_directory = OS.get_user_data_dir().path_join("phase14")
	DirAccess.make_dir_recursive_absolute(_capture_directory)
	check(root.get_texture().get_image().save_png(_capture_directory.path_join(label+".png")) == OK,"Actual rendered screenshot saved")
	_captures.append(label)
