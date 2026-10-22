class_name EnemyIntent
extends RefCounted
## 锁定的公开意图：UI 与结算读取同一份已经确定的效果，不再分别抽样。
var action_id: StringName
var display_name: String
var effects: Array[EffectData] = []
var escape_damage_modifier: int = 0
var state_after: StringName
