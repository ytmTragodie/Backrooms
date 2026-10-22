class_name StatusInstance
extends RefCounted
## 单场战斗可变层数/剩余回合；Resource 不被修改。
var definition: StatusData
var stacks: int = 1
var remaining_turns: int = 1
func copy() -> StatusInstance:
	var next: StatusInstance = StatusInstance.new()
	next.definition = definition
	next.stacks = stacks
	next.remaining_turns = remaining_turns
	return next
