class_name EntityCardView
extends BoardCardView

const STATES: Dictionary = {&"WATCHING": "窥视", &"APPROACHING": "靠近", &"CHASING": "追逐", &"STAGGERED": "踉跄", &"DEFEATED": "击败", &"DISENGAGED": "脱离", &"HIDDEN": "隐藏", &"OBSERVING": "注视", &"AGITATED": "躁动", &"ATTACKING": "攻击", &"WITHDRAWN": "退去"}
const INTENTS: Dictionary = {&"approach": "继续靠近", &"bite": "撕咬", &"lunge": "扑击", &"recover": "恢复警戒", &"none": "无", &"remain_hidden": "保持隐藏", &"watch_light": "注视光源", &"warn_light": "继续照明将遭攻击", &"light_strike": "袭击光源"}
var _hp: Label
var _bar: ProgressBar
var _intent: Label
var _state: Label
var _rules: Label
var _legacy: Label
var _last_intent: StringName


func _ready() -> void:
	super._ready()
	_accent = GameUITheme.RED
	_hp = GameUITheme.label(information, "", 15)
	_bar = ProgressBar.new()
	_bar.show_percentage = false
	_bar.custom_minimum_size.y = 7
	_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bar.add_theme_stylebox_override("fill", GameUITheme.panel(GameUITheme.RED, GameUITheme.RED, 0))
	information.add_child(_bar)
	_intent = GameUITheme.label(information, "", 18, Color("f0ba9b"))
	_intent.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_state = GameUITheme.label(information, "", 14)
	_rules = GameUITheme.label(information, "", 13, GameUITheme.GREEN)
	_rules.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_rules.max_lines_visible = 2
	_legacy = legacy_label("EntityInformation")


func present(entity: EntityInstance, definition: EntityData, floor: FloorState, data: FloorData, selected_value: bool) -> void:
	visible = entity != null and entity.active
	if not visible: return
	heading.text = "实体牌 · %s%s" % [definition.display_name, "（已选）" if selected_value else ""]
	artwork.texture = AssetCatalog.texture(definition.id)
	_hp.text = "生命：%d／%d" % [entity.hp, entity.max_hp]
	_bar.max_value = entity.max_hp
	_bar.value = entity.hp
	var damage: int = EntitySystem.intent_damage(entity, definition, floor, data)
	_intent.text = "意图：%s%s" % [INTENTS.get(entity.intent, "未知"), " · 伤害%d" % damage if damage > 0 else " · 无伤害"]
	if definition.behavior_type == EntityData.BehaviorType.LIGHT_REACTIVE and not floor.light_active:
		_intent.text = "意图：保持黑暗则退去"
	_state.text = "状态：%s　调查规律：%d／%d" % [STATES.get(entity.state, "未知"), entity.analysis_progress, definition.analysis_threshold]
	_rules.text = "；".join(entity.revealed_rules) if not entity.revealed_rules.is_empty() else "可观察以揭示行为规律"
	if definition.behavior_type == EntityData.BehaviorType.LIGHT_REACTIVE:
		_rules.text = "公开警示：反复强光激怒注视；无光时可存活退去。"
	_legacy.text = "%s\n%s\n%s\n%s\n%s" % [heading.text, _hp.text, _state.text, _intent.text, _rules.text]
	tooltip_text = _legacy.text
	if not _last_intent.is_empty() and entity.intent != _last_intent:
		_intent.modulate = Color("ffc06b")
		create_tween().tween_property(_intent, "modulate", Color.WHITE, 0.18)
	_last_intent = entity.intent
	set_target_presentation(selected_value)

