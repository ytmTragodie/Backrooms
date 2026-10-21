class_name PlayerSystem
extends RefCounted

# 玩家数值的唯一提交入口。当前 RunState 仍是权威容器；本阶段不创建并行的
# PlayerState，避免出现两份可写 HP/Stress/Supply。
static func commit(result: ActionResult, state: RunState) -> void:
	if result == null or state == null:
		return
	var player: PlayerActionResult = result.player
	var floor: FloorState = state.floor_state
	var changed: bool = player.hp_delta != 0 or player.stress_delta != 0 or player.supply_delta != 0 or player.block_delta != 0 or player.expire_block

	state.player_hp = clampi(state.player_hp + player.hp_delta, 0, RunState.MAX_PLAYER_HP)
	state.stress = maxi(0, state.stress + player.stress_delta)
	state.supply = maxi(0, state.supply + player.supply_delta)
	if floor != null:
		floor.player_block = maxi(0, floor.player_block + player.block_delta)
		if player.expire_block:
			# 回合末的临时防护必须在所有伤害结算后清空。
			floor.player_block = 0

	if changed:
		result.debug_lines.append("[PLAYER] hp %+d stress %+d supply %+d block %+d" % [player.hp_delta, player.stress_delta, player.supply_delta, player.block_delta])
		if player.pressure_stress != 0 or player.pressure_damage != 0:
			result.debug_lines.append("[PRESSURE] stress +%d damage %d blocked %d" % [player.pressure_stress, player.pressure_damage, player.pressure_blocked])
		if player.damage_taken != 0 or player.damage_blocked != 0:
			result.debug_lines.append("[INTENT] damage %d blocked %d" % [player.damage_taken, player.damage_blocked])