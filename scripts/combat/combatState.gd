class_name CombatState
extends RefCounted
# 定义四种战斗结果：VICTORY=胜利，DEFEAT=失败，ESCAPE=逃跑
enum CombatResult {
    VICTORY,
    DEFEAT,
    ESCAPE
}

# 战斗期间存在combatState，战斗结束后由 CombatSystem 提交结果并销毁。
# 战斗状态聚合根。这里只持有各领域状态对象和战斗元数据；不保存 HP/AP/牌区/装备槽/奖励队列等具体业务字段。

# 战斗阶段，0=未开始，1=行动阶段，2=结算阶段，3=战斗结束。
var phase : int = 0
# 当前回合数
var turn : int = 0
# 行动点，由PlayerState 迁入，目前删除掉PlayerState 中的 AP/MaxAP/Block/Intel/Noise 等字段，战斗中使用 CombatState 中的字段。
var ap : int = 0
var max_ap : int = 0
# 防御
var block : int = 0
# 情报点，适配Meg 探索者
var intel : int = 0

# noise 噪声
var noise : int = 0
# 战斗时的卡组，考虑到战斗中可能会产生卡牌的临时变化，战斗中使用独立的 CombatDeckState。
var deck : CombatDeckState = CombatDeckState.new()
# 敌人&状态
var Enemies : Array[EntityInstance] = []


# 当前战斗的结果
var outcome : CombatResult = CombatResult.VICTORY