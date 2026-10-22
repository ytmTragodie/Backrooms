class_name CombatActionResult
extends RefCounted
## 短生命周期战斗草案，只有验证完整后由 CombatSystem.commit 合并。
var after: CombatState
var clear: bool = false
var cards_played: int = 0
var victory: bool = false
var escape: bool = false
var resolved_alive: int = 0
