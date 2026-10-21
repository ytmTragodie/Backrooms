class_name RunMetrics
extends RefCounted

# 仅记录已提交事实，绝不从 UI 回调推断奖励或战斗结果。
var cards_rewarded: int = 0
var cards_upgraded: int = 0
var cards_removed: int = 0
var cards_played: int = 0
var objectives: Array[Dictionary] = []
var insights: Dictionary = {}
var defeated: Array[String] = []
var resolved_alive: Array[String] = []
var floor_exits: Array[Dictionary] = []
var dead_hands: int = 0
var hands_checked: int = 0
var multiple_option_hands: int = 0
var entity_encounters: Array[Dictionary] = []


func record_deck_change(result: ActionResult) -> void:
	match result.deck.change_kind:
		&"added": cards_rewarded += 1
		&"upgraded": cards_upgraded += 1
		&"removed": cards_removed += 1


func record_action(result: ActionResult, state: RunState, data: FloorData) -> void:
	var floor: FloorState = state.floor_state
	if result.card.card_played != null:
		cards_played += 1
	if result.objective.newly_resolved and result.objective.target != null:
		var turns: int = floor.turn_count - result.objective.target.activated_turn + 1
		objectives.append({"id": result.objective.id, "turns": turns})
		result.debug_lines.append("[BALANCE] situation=%s turns=%d" % [result.objective.id, turns])
	for id: StringName in result.floor.insight_ids:
		var insight: InsightData = data.find_insight(id)
		if insight != null:
			insights[String(floor.floor_id) + "/" + String(id)] = insight.display_name
	var entity: EntityInstance = result.entity.target
	if entity != null and not entity.active and result.entity.state_after in [&"DEFEATED", &"WITHDRAWN", &"DISENGAGED"]:
		var entity_data: EntityData = data.find_entity(entity.entity_id)
		var name_text: String = entity_data.display_name if entity_data != null else String(entity.entity_id)
		if entity.alive:
			resolved_alive.append(name_text)
		else:
			defeated.append(name_text)
		result.debug_lines.append("[BALANCE] entity=%s turns=%d alive=%s" % [entity.entity_id, floor.turn_count - entity.spawned_turn + 1, entity.alive])
		entity_encounters.append({"id": entity.entity_id, "turns": floor.turn_count - entity.spawned_turn + 1, "alive": entity.alive})
	if result.cutout.attempt != null and result.cutout.attempt.succeeded:
		floor_exits.append({"id": floor.floor_id, "name": data.display_name, "turns": floor.turn_count, "threat": floor.threat, "deck_size": state.deck_state.get_card_count()})
		result.debug_lines.append("[BALANCE] exit=%s turns=%d threat=%d deck=%d rewarded=%d avg_cards=%.2f" % [floor.floor_id, floor.turn_count, floor.threat, state.deck_state.get_card_count(), cards_rewarded, float(cards_played) / state.turn_number])
