class_name RewardEntryData
extends Resource
enum Kind { CARD_CHOICE, SUPPLY, EQUIPMENT, HEAL, CALM }
@export var kind: Kind = Kind.SUPPLY
@export var amount: int = 1
@export var weight: int = 1
@export var cards: Array[CardData] = []
@export var equipment: EquipmentData
