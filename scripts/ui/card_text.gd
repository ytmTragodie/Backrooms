class_name CardText
extends RefCounted


static func description(card: CardData) -> String:
	var text: String = "%s　｜　行动点 %d" % [card.display_name, card.ap_cost]
	if card.explore_amount > 0:
		text += "　调查 +%d" % card.explore_amount
	elif card.effect_type == CardData.EffectType.ATTACK:
		text += "　伤害 %d" % card.effect_value
	elif card.effect_type == CardData.EffectType.BLOCK:
		text += "　防护 +%d" % card.effect_value
	elif card.effect_type == CardData.EffectType.RUN:
		text += "　踉跄时脱离，否则引发追逐"
	if card.threat_cost > 0:
		text += "　威胁 +%d" % card.threat_cost
	if card.tags.has(&"NOISE"):
		text += "　噪音"
	if card.collects_resources:
		text += "　同时领取一份可用资源"
	var condition: String = condition_description(card)
	return text + ("\n" + condition if not condition.is_empty() else "")


static func condition_description(card: CardData) -> String:
	match card.bonus_condition:
		CardData.BonusCondition.GUARDED:
			return "已有防护时，伤害 +%d" % card.conditional_bonus
		CardData.BonusCondition.HIGH_THREAT:
			return "威胁至少 %d 时，调查 +%d" % [card.condition_threshold, card.conditional_bonus]
		CardData.BonusCondition.ANALYZED_TARGET:
			return "目标规律已揭示时，伤害 +%d" % card.conditional_bonus
	return ""
