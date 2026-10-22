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


static func primary(card: CardData, bonus: int = 0) -> String:
	var output: String
	if card.explore_amount > 0:
		output = "调查 +%d" % (card.explore_amount + bonus)
		if card.collects_resources: output += "\n领取一份有限资源"
	else:
		match card.effect_type:
			CardData.EffectType.ATTACK: output = "伤害 %d" % (card.effect_value + bonus)
			CardData.EffectType.BLOCK: output = "防护 +%d\n抵挡环境与实体" % card.effect_value
			CardData.EffectType.RUN: output = "踉跄时脱离\n否则引发追逐"
			CardData.EffectType.LIGHT: output = "本回合照明\n电量 −1"
			CardData.EffectType.EXTINGUISH: output = "关闭光照\n不消耗电量"
			CardData.EffectType.RECOVER: output = "压力 −2\n高压力时生命 +1"
			CardData.EffectType.CUTOUT_RUSHED: output = "风险离层 · 压力+1\n失败仍保留此牌"
			CardData.EffectType.CUTOUT_SAFE: output = "准备充分\n安全离层"
			_: output = "查看详情"
	if card.threat_cost > 0: output += "\n威胁 +%d" % card.threat_cost
	return output
