class_name GameData
extends Resource
## 唯一内容组合入口，地图池/奖励池通过真实 Resource 引用接入。
@export var floors: Array[FloorData] = []
@export var starting_floor: StringName
@export var starter_deck: DeckData
@export var starting_equipment: Array[EquipmentData] = []
@export var statuses: Array[StatusData] = []
@export var card_pool: Array[CardData] = []
@export var starting_supply: int = 5
# 已访问目的地降权而非禁用；保证只有旧路线时仍然可以切出。
@export var revisit_weight_multiplier: float = 0.15
func find_floor(id: StringName) -> FloorData:
	for floor: FloorData in floors:
		if floor.id == id: return floor
	return null
