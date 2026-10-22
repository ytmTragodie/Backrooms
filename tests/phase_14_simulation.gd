extends "res://tests/phase_14_validation.gd"
## 结构性多种子模拟。策略读取完整节点内容，不代表迷雾下真人胜率。
func _run() -> void:
	var won: int = 0
	var lost: int = 0
	var stalled: int = 0
	var errors: int = 0
	var end_turns: int = 0
	var cards_played: int = 0
	var visits: int = 0
	var dead_hands: int = 0
	var hands: int = 0
	var hp_total: int = 0
	for seed: int in range(1,201):
		var run: RunState = state(seed)
		for step: int in range(400):
			if run.flow.phase == RunFlowState.Phase.RESULT: break
			if run.combat != null and run.combat.ap == 3:
				hands += 1
				var options: int = 0
				for instance: CardInstance in run.combat.deck.hand:
					if CombatSystem.card_error(play_command(run,instance),run).is_empty(): options += 1
				if options == 0: dead_hands += 1
			var next: GameCommand = auto_command(run)
			if next.kind == GameCommand.Kind.END_TURN: end_turns += 1
			var result: ActionResult = RuleResolver.resolve(next,run,GAME)
			if not result.success:
				errors += 1
				check(false,"Simulation rejected current legal policy action seed=%d reason=%s" % [seed,result.failure_reason])
				break
			check(run.player.hp >= 0 and run.player.supply >= 0 and run.player.stress >= 0,"Simulation long-term resource bounds")
			if run.combat != null: check(run.combat.ap >= 0 and run.combat.intel >= 0 and run.combat.enemies.size()==1,"Simulation shared combat invariants")
		if run.flow.phase != RunFlowState.Phase.RESULT: stalled += 1
		elif run.player.hp > 0: won += 1; hp_total += run.player.hp
		else: lost += 1
		cards_played += run.metrics.cards_played
		visits += run.metrics.floor_transitions
	check(errors==0 and stalled==0,"All 200 seeded runs reach a valid ending without rejected actions or soft-lock")
	var report: Dictionary = {"seeds":200,"wins":won,"deaths":lost,"unfinished_after_400_commands":stalled,"rejected_policy_actions":errors,"combat_end_turns":end_turns,"cards_played":cards_played,"floor_transitions":visits,"hand_samples_at_3_ap":hands,"samples_with_no_legal_card":dead_hands,"mean_survivor_hp":float(hp_total)/maxi(1,won),"policy":"Deterministic greedy cards; full hidden-node information for route selection. Structural smoke test, not human difficulty or final balance."}
	var output: FileAccess = FileAccess.open("res://docs/PHASE_14_SIMULATION.json",FileAccess.WRITE)
	output.store_string(JSON.stringify(report,"  ")+"\n")
	output.close()
	print("[SIMULATION] "+JSON.stringify(report))
	print("[TEST] %s Phase 14 simulation: %d checks" % ["PASS" if failures.is_empty() else "FAIL",checks])
	quit(0 if failures.is_empty() else 1)
