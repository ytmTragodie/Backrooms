class_name PlayerSystem
extends RefCounted

# 玩家状态的唯一提交入口。RunState 只聚合 PlayerState，不保留第二份 HP/AP/Block。
# 本系统提交玩家域的全部净变化：AP、HP、Stress、Supply、Block，以及回合末清空。
static func validate(state: RunState) -> StringName:
	if state == null or state.player == null:
		return &"invalid_player_state"
	var player: PlayerState = state.player
	if player.max_hp <= 0 or player.hp < 0 or player.hp > player.max_hp:
		return &"invalid_player_state"
	if player.stress < 0 or player.supply < 0 or player.ap < 0 or player.block < 0:
		return &"invalid_player_state"
	return &""


# 回合生命周期由 TurnManager 安排；这里只负责把 AP 写回权威状态。
static func begin_turn(state: RunState) -> void:
	if state == null or state.player == null:
		return
	state.player.ap = PlayerState.AP_PER_TURN


static func commit(result: ActionResult, state: RunState) -> void:
	if result == null or state == null or state.player == null:
		return
	var player: PlayerState = state.player
	var delta: PlayerActionResult = result.player
	var changed: bool = delta.ap_delta != 0 or delta.hp_delta != 0 or delta.stress_delta != 0 or delta.supply_delta != 0 or delta.block_delta != 0 or delta.expire_block
	if not changed:
		return

	player.ap = maxi(0, player.ap + delta.ap_delta)
	player.hp = clampi(player.hp + delta.hp_delta, 0, player.max_hp)
	player.stress = maxi(0, player.stress + delta.stress_delta)
	player.supply = maxi(0, player.supply + delta.supply_delta)
	player.block = maxi(0, player.block + delta.block_delta)
	if delta.expire_block:
		# 回合末的临时防护必须在所有伤害结算后清空。
		player.block = 0

	# AP 已由 RuleResolver 记录 [AP]；这里只在不涉及 AP 的玩家数值变化时补充来源日志。
	if delta.hp_delta != 0 or delta.stress_delta != 0 or delta.supply_delta != 0 or delta.block_delta != 0 or delta.expire_block:
		result.debug_lines.append("[PLAYER] hp %+d stress %+d supply %+d block %+d" % [delta.hp_delta, delta.stress_delta, delta.supply_delta, delta.block_delta])
	if delta.pressure_stress != 0 or delta.pressure_damage != 0:
		result.debug_lines.append("[PRESSURE] stress +%d damage %d blocked %d" % [delta.pressure_stress, delta.pressure_damage, delta.pressure_blocked])
	if delta.damage_taken != 0 or delta.damage_blocked != 0:
		result.debug_lines.append("[INTENT] damage %d blocked %d" % [delta.damage_taken, delta.damage_blocked])
