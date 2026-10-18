class_name CardRewardPanel
extends PanelContainer

signal command_submitted(command: CardRewardCommand)

@onready var _title: Label = $Margin/Layout/Title
@onready var _options: VBoxContainer = $Margin/Layout/Scroll/Options


func refresh(state: RunState) -> void:
	visible = not state.pending_rewards.is_empty() and state.player_hp > 0
	for child: Node in _options.get_children():
		_options.remove_child(child)
		child.queue_free()
	if not visible:
		return
	var reward: CardReward = state.pending_rewards[0]
	var kind: CardRewardData.Kind = reward.definition.kind
	_title.text = {CardRewardData.Kind.ADD_CARD: "选择一张牌加入牌组", CardRewardData.Kind.UPGRADE_CARD: "选择一张牌升级", CardRewardData.Kind.REMOVE_CARD: "选择一张牌移出牌组"}[kind]
	if kind == CardRewardData.Kind.ADD_CARD:
		for definition: CardData in reward.choices:
			_add_option(CardText.description(definition), CardRewardCommand.new(reward, definition))
	else:
		var candidates: Array[CardInstance] = CardRewardSystem.eligible_cards(state, kind)
		for card: CardInstance in candidates:
			var text: String = CardText.description(card.definition)
			if kind == CardRewardData.Kind.UPGRADE_CARD:
				text += "\n升级为：" + CardText.description(card.definition.upgrade_to)
			_add_option(text, CardRewardCommand.new(reward, null, card))
		if candidates.is_empty():
			_add_option("当前没有可调整的牌，继续探索", CardRewardCommand.new(reward))


func _add_option(text: String, command: CardRewardCommand) -> void:
	var button: Button = Button.new()
	button.text = text
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	button.custom_minimum_size.y = 78
	button.pressed.connect(func() -> void: command_submitted.emit(command))
	_options.add_child(button)
