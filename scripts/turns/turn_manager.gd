class_name TurnManager
extends Node
## 薄应用入口：创建 Run、接收命令、完整提交后通知。没有第二套回合算法。
signal state_changed
signal action_resolved(result: ActionResult)
@export var game_data: GameData
@export var seed_value: int = 1
var run_state: RunState

func _ready() -> void:
	start_run(seed_value)

func start_run(seed: int) -> void:
	var errors: Array[String] = ContentValidator.validate(game_data)
	if not errors.is_empty():
		push_error("Content invalid: " + "; ".join(errors))
		return
	# 新局也先验证私有地图，失败不能替换当前正在玩的 RunState。
	var next: RunState = RunState.new(seed)
	next.player.supply = game_data.starting_supply
	CardSystem.initialize(next.player.deck, game_data.starter_deck)
	EquipmentSystem.initialize(next.player.equipment, game_data.starting_equipment)
	next.floor_state = MapSystem.generate(game_data.find_floor(game_data.starting_floor), next.rng)
	if not next.floor_state.map.validation_errors.is_empty():
		push_error("Map invalid: "+"; ".join(next.floor_state.map.validation_errors))
		return
	next.history.floors[next.floor_state.floor_id] = next.floor_state
	next.history.visits[next.floor_state.floor_id] = 1
	next.player.knowledge.floors.append(next.floor_state.floor_id)
	run_state = next
	state_changed.emit()

func submit(command: GameCommand) -> ActionResult:
	var result: ActionResult = RuleResolver.resolve(command, run_state, game_data)
	if result.success: state_changed.emit()
	action_resolved.emit(result)
	return result

func end_turn() -> ActionResult:
	return submit(GameCommand.new(GameCommand.Kind.END_TURN, run_state))
