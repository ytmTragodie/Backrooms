class_name CardText
extends RefCounted
static func effect_text(effect: EffectData) -> String:
	match effect.effect_type:
		EffectData.EffectType.DAMAGE: return "伤害 %d" % effect.amount
		EffectData.EffectType.BLOCK: return "防护 +%d" % effect.amount
		EffectData.EffectType.HEAL: return "恢复生命 %d" % effect.amount
		EffectData.EffectType.DRAW: return "抽 %d 张牌" % effect.amount
		EffectData.EffectType.GAIN_AP: return "行动点 +%d" % effect.amount
		EffectData.EffectType.GAIN_INTEL: return "情报 +%d" % effect.amount
		EffectData.EffectType.APPLY_STATUS: return "%s %d 层" % [effect.status.display_name, effect.amount]
		EffectData.EffectType.CHANGE_STRESS: return "压力 %+d" % effect.amount
		EffectData.EffectType.CHANGE_NOISE: return "噪音 %+d" % effect.amount
		EffectData.EffectType.LIGHT: return "开启强光" if effect.amount > 0 else "熄灭光源"
		EffectData.EffectType.WITHDRAW: return "存活退去"
	return ""

static func effects_text(effects: Array[EffectData], separator: String = "\n") -> String:
	var lines: PackedStringArray = []
	for effect: EffectData in effects: lines.append(effect_text(effect))
	return separator.join(lines)

static func description(card: CardData) -> String:
	return "%s　行动点 %d%s\n%s%s%s%s" % [card.display_name, card.ap_cost, " / 情报 %d" % card.intel_cost if card.intel_cost > 0 else "", effects_text(card.effects), "\n装备次数 -%d" % card.equipment_cost if card.source == CardData.Source.EQUIPMENT else "", "\n消耗：本场不再抽到" if card.exhaust else "", "\n保留" if card.retain else ""]
