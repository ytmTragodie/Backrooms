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
@export var shops: Array[ShopData] = []
@export var cutout_route_pool: Array[CutOutRouteData] = []
# 楼层战斗规则是数据，不保存 Noise；0 表示不用此规则。
@export var noise_damage_threshold: int = 0
@export var noise_damage_bonus: int = 0
