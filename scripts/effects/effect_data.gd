class_name EffectData
extends Resource

# 定义几种基本的行为意图（兼容玩家的卡牌效果和实体的行为）
# 进攻，防御，治疗,抽卡，获得AP，获得APLIKE的点数（比如intel），施加正面/负面状态，改变压力，改变噪声
enum EffectType {
    DAMAGE,
    BLOCK,
    HEAL,
    DRAW,
    GAIN_AP,
    GAIN_APLIKE,
    APPLY_STATUS,
    CHANGE_STRESS,
    CHANGE_NOISE
}
# 对象类型
enum TargetType {
    SELF,
    PLAYER,
    ENEMY
}
@export var effect_type: EffectType
@export var target: TargetType
# 作用数值，具体含义根据effect_type而定
@export var amount: int = 0
# 施加状态的效果需要指定状态ID和持续时间
@export var status_id: StringName = &""
@export var duration: int = 0
