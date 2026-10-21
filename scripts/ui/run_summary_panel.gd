class_name RunSummaryPanel
extends PanelContainer

signal new_run_requested

@onready var _title: Label = $Margin/Layout/Title
@onready var _information: Label = $Margin/Layout/Information


func _ready() -> void:
	GameUITheme.style_modal(self)
	$Margin/Layout/NewRun.pressed.connect(func() -> void: new_run_requested.emit())


func refresh(state: RunState, complete: bool) -> void:
	visible = complete or state.player.hp <= 0
	if not visible:
		return
	var metrics: RunMetrics = state.metrics
	var floors: PackedStringArray = []
	for record: Dictionary in metrics.floor_exits:
		floors.append(record.name)
	var names: PackedStringArray = []
	for value: String in metrics.insights.values():
		names.append(value)
	var final_threat: int = metrics.floor_exits.back().threat if complete and not metrics.floor_exits.is_empty() else state.floor_state.threat
	_title.text = "探索完成" if complete else "本局结束"
	_information.text = "总回合数：%d\n完成楼层：%s\n获得新牌：%d　升级牌：%d　移除牌：%d\n已发现认知：%d\n%s\n击败实体：%s\n驱离／非击杀解决：%s\n最终生命：%d　最终压力：%d　最终威胁：%d\n种子：%d" % [state.flow.turn_number, " → ".join(floors) if not floors.is_empty() else "无", metrics.cards_rewarded, metrics.cards_upgraded, metrics.cards_removed, names.size(), "、".join(names) if not names.is_empty() else "尚未确认规律", "、".join(metrics.defeated) if not metrics.defeated.is_empty() else "无", "、".join(metrics.resolved_alive) if not metrics.resolved_alive.is_empty() else "无", state.player.hp, state.player.stress, final_threat, state.rng_seed]
