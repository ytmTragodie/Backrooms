class_name MapGenerationData
extends Resource
## 分层 DAG 配置；同一节点层只向下一层连接，保证没有回退/环。
@export_range(3, 12) var depth: int = 5
@export_range(2, 4) var lanes: int = 3
# COMBAT/ELITE/EVENT/REST/REWARD/SHOP 的整数权重，EXIT 固定在终点。
@export var node_weights: PackedInt32Array = PackedInt32Array([35, 8, 30, 12, 10, 5])
@export_range(0, 3) var reveal_depth: int = 1
# 末层实际出口数量，不是只增加随机出口定义。
@export_range(1, 3) var exit_count: int = 1
@export var rules: Array[MapRuleData] = []
@export var regions: Array[MapRegionData] = []

func region_at(layer: int) -> MapRegionData:
	for region: MapRegionData in regions:
		if layer >= region.first_layer and layer <= region.last_layer: return region
	return null
