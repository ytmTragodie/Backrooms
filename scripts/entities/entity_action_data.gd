class_name EntityActionData
extends Resource

# 定义几种基本的实体行为意图 
# 进攻，防御，逃跑，自我增益，敌方减益
enum IntentType { ATTACK, BLOCK, RUN, BUFF_SELF,DEBUFF_ENEMY }


# 定义实体的行动数据，包括行动名称、描述和效果等。
@export var action_id : StringName
@export var intent_type : IntentType
@export var action_name : String
# 定义动作的触发条件，某些动作本来是不会出现的，只有在特定条件下才会触发
@export var conditions : Array[ConditionData] = []
# 动作触发权重，权重越高，动作被选择的概率越大
@export var weight : int = 1
# 定义动作的冷却时间，单位为回合数，冷却时间为0表示该动作可以连续使用
@export var cooldown : int = 0
# 定义动作的效果
@export var effects : Array[EffectData] = []