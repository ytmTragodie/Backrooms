class_name FloorData
extends Resource
## Level 静态配置。出口只存稳定 ID，避免 Resource 跨楼层循环引用。
@export var id: StringName
@export var display_name: String
@export_multiline var description: String
@export var asset_id: StringName
@export var map_config: MapGenerationData
@export var encounter_pool: Array[EntityData] = []
@export var elite_pool: Array[EntityData] = []
@export var event_pool: Array[EventData] = []
@export var reward_pool: RewardTableData
@export var additional_rewards: Array[RewardTableData] = []
@export var shops: Array[ShopData] = []
@export var cutout_route_pool: Array[CutOutRouteData] = []
@export var entrances: Array[FloorEntranceData] = []

func find_entrance(entrance_id: StringName) -> FloorEntranceData:
	for entrance: FloorEntranceData in entrances:
		if entrance.id == entrance_id: return entrance
	return null
# 楼层战斗规则是数据，不保存 Noise；0 表示不用此规则。
@export var noise_damage_threshold: int = 0
@export var noise_damage_bonus: int = 0

func find_reward(content_id: StringName) -> RewardTableData:
	if reward_pool != null and reward_pool.id == content_id: return reward_pool
	for data: RewardTableData in additional_rewards:
		if data.id == content_id: return data
	return null

func has_content(kind: MapNodeState.Kind, content_id: StringName) -> bool:
	var pool: Array = []
	match kind:
		MapNodeState.Kind.COMBAT: pool = encounter_pool
		MapNodeState.Kind.ELITE: pool = elite_pool
		MapNodeState.Kind.EVENT: pool = event_pool
		MapNodeState.Kind.SHOP: pool = shops
		MapNodeState.Kind.EXIT: pool = cutout_route_pool
		MapNodeState.Kind.REWARD: return find_reward(content_id) != null
		_: return content_id.is_empty()
	for data: Resource in pool:
		if data.id == content_id: return true
	return false
