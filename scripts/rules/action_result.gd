class_name ActionResult
extends RefCounted

# 记录本次动作的事实；ap_spent 是消耗量，权威 AP 仍只存于 RunState。
var success: bool = false
var failure_reason: StringName
var ap_spent: int = 0
var card_played: CardInstance
var card_definition: CardData
var effect: StringName
var damage_requested: int = 0
var action_id: StringName
var objective_id: StringName
var floor_flags_added: Array[StringName] = []
var insight_ids: Array[StringName] = []
var cognition_delta: int = 0
var threat_delta: int = 0
var threat_reason: StringName
# 事件变更计划与 AP、牌区变更一并提交，失败不留下半次交互。
var objective_interaction: StringName
var objective_information: Array[String] = []
var objective_resolved: bool = false
var objective_target: ObjectiveInstance
var explore_base: int = 0
var explore_bonus: int = 0
var explore_applied: int = 0
var explore_after: int = -1
var clue_revealed: bool = false
var pressure_checked: bool = false
var pressure_stress: int = 0
var pressure_damage: int = 0
var pressure_blocked: int = 0
var resource_discovered_id: StringName
var resource_looted_id: StringName
var supply_delta: int = 0
var stability_delta: int = 0
var knowledge_delta: int = 0
var preparation_reason: StringName
var stress_delta: int = 0
var cutout_attempt: CutOutAttemptResult
var destination: FloorData
var next_floor: FloorState
var rng_state_after: int = 0
var commit_rng: bool = false
var entity_hp_after: int = -1
var entity_target: EntityInstance
var analysis_after: int = -1
var analysis_applied: int = 0
var entity_rule_revealed: String
var entity_state_after: StringName
var entity_intent_after: StringName
var entity_damage: int = 0
var entity_defeated: bool = false
var entity_spawned: EntityInstance
var entity_state_reason: StringName
var entity_light_exposed: bool = false
var block_gained: int = 0
var expire_block: bool = false
var intent_resolved: StringName
var player_damage: int = 0
var damage_blocked: int = 0
var dark_observation: bool = false
var equipment_used: EquipmentInstance
var equipment_slot: int = -1
var equipment_uses_spent: int = 0
var light_activated: bool = false
var light_extinguished: bool = false
var stress_restored: int = 0
var hp_restored: int = 0
var debug_lines: Array[String] = []
var rewards_created: Array[CardReward] = []
var reward_claimed: CardReward
var deck_card_changed: CardInstance
var deck_change_kind: StringName
var safe_point_used: SafePointState
var resource_equipment: EquipmentInstance
var resource_uses_gained: int = 0
var event_changes: Array[EventChange] = []
var event_reward_definitions: Array[CardRewardData] = []
