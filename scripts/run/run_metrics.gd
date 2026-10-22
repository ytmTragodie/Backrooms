class_name RunMetrics
extends RefCounted
## 只记录已提交事实，不持有活动状态的副本。
var commands: int = 0
var cards_played: int = 0
var victories: int = 0
var escapes: int = 0
var resolved_alive: int = 0
var rewards_claimed: int = 0
var floor_transitions: int = 0
