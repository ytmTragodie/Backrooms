class_name MapRuleRecord
extends RefCounted
## 生成事实/诊断，不是第二份节点状态；用于验证和种子复现。
var rule_id: StringName
var anchor_id: StringName
var affected_id: StringName
var mandatory_path: bool = false
var applied: bool = false
var note: String
