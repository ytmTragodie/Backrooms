class_name MapNodeState
extends RefCounted
## 生成节点实例。content_id 在生成时固定，迷雾不重新抽内容。
enum Kind { COMBAT, ELITE, EVENT, REST, REWARD, SHOP, EXIT, ENTRY }
enum Visibility { UNKNOWN, REVEALED,INVISIBLE } # unknown 是未探索，revealed 是已探索，invisible 是未显现，不在地图上显示有这个节点，但是仍然存在，玩家通过特定事件可以发现它。
enum Resolution { UNVISITED, ACTIVE, RESOLVED }
var id: StringName
var kind: Kind = Kind.ENTRY
var content_id: StringName
var layer: int = 0
var position: Vector2
# position 是归一化地图坐标 [0,1]，不是本机像素布局。
var visibility: Visibility = Visibility.UNKNOWN
# 揭示与结算状态正交，重返已结算节点只通行。
var resolution: Resolution = Resolution.UNVISITED
# 主题分区只是生成元数据；未来动态实体占用不得覆盖 content_id/一次性结算。
var region_id: StringName
