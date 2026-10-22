class_name MapGenerationData
extends Resource
## 分层 DAG 配置；同一节点层只向下一层连接，保证没有回退/环。
@export_range(3, 12) var depth: int = 5
@export_range(2, 4) var lanes: int = 3
# COMBAT/ELITE/EVENT/REST/REWARD/SHOP 的整数权重，EXIT 固定在终点。
@export var node_weights: PackedInt32Array = PackedInt32Array([35, 8, 30, 12, 10, 5])
@export_range(0, 3) var reveal_depth: int = 1
