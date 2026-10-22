class_name EventData
extends Resource

enum Category { DEBUFF, OMEN, OPPORTUNITY }

@export var id: StringName
@export var display_name: String
@export_multiline var display_text: String
@export var category: Category = Category.DEBUFF
@export_range(1, 20) var duration: int = 3
@export var stress_per_turn: int = 0
@export var damage_per_turn: int = 0
@export var modifier_tag: StringName
@export var ap_modifier: int = 0
@export var accelerate_tags: Array[StringName] = []
@export var spawn_entity: EntityData
@export var requires_resolved_entity: EntityData
@export var condition_tag: StringName
@export var required_actions: int = 1
@export var supply_reward: int = 0
@export var insight: InsightData
@export var card_reward: CardRewardData
