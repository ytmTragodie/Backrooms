class_name PlayerState
extends RefCounted

# 玩家在本局中的唯一权威状态。跨楼层保留，只有新开一局才整体替换。
# HP/Stress/Supply/AP/Block 的提交入口是 PlayerSystem；Deck/Equipment 是组合对象，
# 分别由 CardSystem/EquipmentSystem 维护，本类只持有它们的引用。
const MAX_HP: int = 30
const AP_PER_TURN: int = 3

# 当前生命与生命上限。hp 始终在 [0, max_hp] 内；max_hp 默认 30，
# 为未来角色初始模板保留可配置入口，但本轮不引入角色数据。
var hp: int = MAX_HP
var max_hp: int = MAX_HP

# 压力与补给是玩家资源，跨楼层持续，不随 FloorState 重建。
var stress: int = 0
var supply: int = 0

# 回合内行动点。TurnManager 安排回合开始，PlayerSystem.begin_turn 恢复，
# RuleResolver 只规划 ap_delta，最终由 PlayerSystem.commit 写入。
var ap: int = AP_PER_TURN

# 临时防护。属于玩家而不是楼层，因此换层后仍然存在；
# 回合末由 PlayerSystem 在所有伤害结算完成后清空。
var block: int = 0

# 玩家拥有的牌区；DeckState 的身份在换层和新回合中保持不重建。
var deck: DeckState = DeckState.new()
# 三个装备槽及装备生成调度状态；EquipmentInstance 的耐久/电量/次数不复制到这里。
var equipment: EquipmentState = EquipmentState.new()