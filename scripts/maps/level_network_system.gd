class_name LevelNetworkSystem
extends RefCounted
## 只读投影：拓扑来自实际 Floor/Route；已知集合只控制公开范围，不复制出口配置。
static func rows(state: RunState, game: GameData) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for floor: FloorData in game.floors:
		if not state.player.knowledge.floors.has(floor.id) and not state.history.floors.has(floor.id): continue
		for route: CutOutRouteData in floor.cutout_route_pool:
			if not state.player.knowledge.exits.has(route.id): continue
			var weights: Dictionary = CutOutSystem.distribution(route,state,game)
			var total: float = 0
			for weight: float in weights.weights: total += weight
			var targets: Array[Dictionary] = []
			var unknown: float = 0
			for index: int in range(route.destinations.size()):
				var destination: CutOutDestinationData = route.destinations[index]
				var known: bool = CutOutSystem.destination_known(destination,state)
				var traversed: bool = false
				for connection: KnownConnection in state.player.knowledge.connections:
					if connection.source_floor == floor.id and connection.route_id == route.id and connection.destination_id == destination.id:
						known = true
						traversed = connection.traversed
				var probability: float = weights.weights[index]/total if total > 0 else 0.0
				if not known:
					unknown += probability
					continue
				var conditions: PackedStringArray = []
				for requirement: TravelRequirementData in destination.requirements: conditions.append(requirement.description)
				if destination.floor_id != &"run_end":
					for requirement: TravelRequirementData in game.find_floor(destination.floor_id).find_entrance(destination.entrance_id).requirements: conditions.append(requirement.description)
				targets.append({"label":CutOutSystem.destination_label(destination,game),"probability":probability,"traversed":traversed,"conditions":" / ".join(conditions)})
			if unknown > 0: targets.append({"label":"未知目的地","probability":unknown,"traversed":false,"conditions":""})
			rows.append({"source":floor.display_name,"route":route.display_name,"targets":targets,"hp_cost":route.hp_cost,"stress_cost":route.stress_cost})
	return rows
