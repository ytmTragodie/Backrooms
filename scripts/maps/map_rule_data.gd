class_name MapRuleData
extends Resource
## 有限生成规则目录；只在新地图草案上执行，不解释表达式、不参与回合规则。
enum Kind { PLACE_CONTENT, INTEL_BEFORE, SUPPORT_AFTER, LIMIT_DANGER }
@export var id: StringName
@export var kind: Kind = Kind.INTEL_BEFORE
@export var required: bool = false
@export_range(0, 1) var probability: float = 1.0
@export var max_applications: int = 1
# 锚点筛选；空 content_id 表示匹配此类型的任意内容。
@export var target_kind: MapNodeState.Kind = MapNodeState.Kind.ELITE
@export var target_content_id: StringName
# 可指定同次生成中 PLACE_CONTENT 的锚点，避免同定义的随机副本抢占关联规则。
@export var anchor_rule_id: StringName
@export var min_layer: int = 1
@export var max_layer: int = 99
# 情报路径距离为有向最短距离；必经表示线索支配目标，不是视觉上位于左边。
@export var min_distance: int = 2
@export var max_distance: int = 3
@export var mandatory_path: bool = false
@export var clue_event: EventData
# 支援只能放在目标的真实后继；奖励仍由 RewardSystem 处理。
@export var support_kind: MapNodeState.Kind = MapNodeState.Kind.REST
@export var reward: RewardTableData
@export var max_consecutive: int = 2
