class_name PlayerSystem
extends RefCounted
## 跨战斗资源和知识的唯一提交入口，战斗 AP 不归玩家域。
static func commit(result: ActionResult, state: RunState) -> void:
	var player: PlayerState = state.player
	player.hp = clampi(player.hp + result.player.hp_delta, 0, player.max_hp)
	player.stress = maxi(0, player.stress + result.player.stress_delta)
	player.supply += result.player.supply_delta
	for id: StringName in result.player.knowledge_rules:
		if not player.knowledge.rules.has(id): player.knowledge.rules.append(id)
	for id: StringName in result.player.knowledge_entities:
		if not player.knowledge.entities.has(id): player.knowledge.entities.append(id)
	for id: StringName in result.player.knowledge_floors:
		if not player.knowledge.floors.has(id): player.knowledge.floors.append(id)
	for id: StringName in result.player.knowledge_exits:
		if not player.knowledge.exits.has(id): player.knowledge.exits.append(id)
	for connection: KnownConnection in result.player.connections:
		var existing: KnownConnection
		for known: KnownConnection in player.knowledge.connections:
			if known.key() == connection.key(): existing = known
		if existing == null: player.knowledge.connections.append(connection)
		elif connection.traversed: existing.traversed = true
