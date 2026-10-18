class_name CardRewardData
extends Resource

enum Kind { ADD_CARD, UPGRADE_CARD, REMOVE_CARD }

@export var kind: Kind = Kind.ADD_CARD
@export var pool: Array[CardData] = []
