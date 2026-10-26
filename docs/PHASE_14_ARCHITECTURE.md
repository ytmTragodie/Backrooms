# Phase 14：实际运行架构与迁移契约

> Phase 15 增量见 [PHASE_15_ARCHITECTURE.md](PHASE_15_ARCHITECTURE.md)：当前已有第三个 Level、多出口/代价出口、地图生成规则和只读楼层网络。以下保留 Phase 14 基础契约；数量与新增字段以增量文档为准。

以 [Phase14_GAMEPLAY _Redesign.md](<Phase14_GAMEPLAY _Redesign.md>) 为设计源。以下描述当前实现，不把旧探索原型或未来建议当作完成项。

## 状态与唯一所有者

```text
RunState
├─ player: PlayerState                 PlayerSystem 提交 HP/Stress/Supply/Knowledge
│  ├─ deck: DeckState.cards             CardSystem 提交永久牌组
│  ├─ equipment: EquipmentState.slots   EquipmentSystem 提交携带物/次数
│  └─ knowledge: KnowledgeState         四类已知 ID 集合，非通用点数
├─ floor_state: FloorState             当前 Level 的实际引用
│  └─ map: FloorMapState                节点、连接、当前节点、揭示/结算
├─ history: FloorHistoryState           保存实际 FloorState，重返不重新生成
├─ flow: RunFlowState                   阶段、当前文本事件/商店、奖励队列、结果
├─ combat: CombatState 或 null          CombatSystem 提交本场 AP/Block/Intel/Noise
│  ├─ deck: CombatDeckState             抽/手/弃/消耗，永久牌实例不进入这里
│  ├─ enemies: EntityInstance[]         当前只实际生成一名敌人
│  └─ statuses                         只属于本场战斗
└─ RNG / revision / metrics            统一随机序列、事务版本与已提交事实
```

长期牌和战斗牌共享只读 CardData，但为不同 CardInstance。升级/删牌作用于实际持有实例；战斗抽弃不改变永久集合。物品只保存在三个携带槽，动作牌进入战斗手牌。

## 命令与事务

`MainGameView → GameCommand → TurnManager.submit → RuleResolver.plan → 各领域计划 → ActionResult → commit → Signal/UI`。

- Command 捕获 Run revision、FloorState、CombatState、卡/定义/实体或奖励机会引用。目标验证依赖运行实例，不依赖定义 ID。陈旧输入拒绝，不能自动改选。
- 规划使用复制的 RNG 状态；战斗使用短生命周期私有草案，卡定义、持有物、活动实例和地图均不被规划修改。
- ActionResult 按 Player/Combat/Deck/Equipment/Floor/Flow 分组；Combat 草案不是第二个持久状态。
- 提交顺序：Player → 永久 Deck → Equipment → Map/历史激活 → Combat → Flow/奖励 → RNG/统计/revision。每个所有者只落地自己的状态。
- 同一结果只能应用到原 Run 的原 revision，不能双提交或应用到同 revision 的另一局。
- 提交通知不会再触发伤害/奖励；失败返回空草案，不推进 RNG、不扣 AP/Intel/耐久、不移动牌、不发奖。
- `commit` 是同步落地已验证计划，**没有数据库回滚**；坏配置在开局 ContentValidator、失败路径测试和严格错误日志中发现。

## 战斗：单场、公开意图

开始战斗：复制持有牌 → 洗牌 → 生成实体 → 锁定意图 → 抽五张 → 最多一张装备机会。基础 AP 3。M.E.G. 侦察生成 Intel，精确打击/预判/打断等牌消费 Intel；Knowledge 不参与数值付费。

回合末固定顺序：

1. 实体 ON_TURN_END 条件反应；因此满足避光条件可以在攻击前退去。
2. 依次执行已锁定意图（失衡可跳过）；死亡时停止后续敌人动作。
3. 状态持续伤害；判定 DEFEAT / VICTORY。
4. 状态到期、回合 +1、AP 回复 3、清空本回合 Block。
5. ON_TURN_START 反应；再次检查结局；锁定下次意图。
6. 清理旧手牌、保留 NORMAL Retain、抽至五张、轮转生成至多一张装备机会。

EnemyIntent 保存确定效果副本；UI 读取它，结算也读取它。Noise/增益只改变下一次锁定；防护、失衡、受伤修正仍可以影响实际生命损失。意图中没有由 UI 另抽的随机伤害。

条件采用有限枚举：生命比例、回合、Noise、状态层、前次行为、行为状态、实际光源。行为先筛最高 priority，再按正权重选择，冷却在真正行动后登记。所有选择使用同一个 Run RNG。

弱点以 TriggerData + 条件 + EffectData + 冷却声明。不匹配卡名/实体名；只有实际执行的效果标签触发反应。弱点不递归触发自己，避免反应链无限循环。

状态首版支持平坦输出/受伤/防护修正、持续伤害、跳过意图；层数和持续时间只保存在 StatusInstance。不建立通用 DSL。

## 撤离与 CutOut

- EscapeSystem：仅战斗、1 AP、不判成功率；实体基础 HP 区间加当前锁定意图修正，归零并保证 min≤max。预览不抽 RNG。正式计划采样一次，伤害可能致死；忽略 Block 的直接损失是本原型明确代价。存活为 ESCAPE，致死为 DEFEAT。
- ESCAPE 结算当前节点，不发战斗胜利奖励；进战斗前已合法取得的资源/待领奖励保留。不会切换 Level。
- CutOutSystem：仅当前 EXIT；必定成功，按有效正权重抽一个目的地。预览按 Knowledge 合并未知目的地概率，与正式采样使用同一权重函数。
- 已访问楼层权重乘 0.15；永远不乘零。知识和携带路线信标使用声明式修正。信标首版为被动携带修正，不自动消耗次数。
- 重入从**同一张地图入口**开始，已结算节点只经过；奖励/事件/休息/商店/已结束战斗不重开。出口可再次使用，但本身不产出奖励。
- 每个节点都可达出口，每个配置楼层都必须有通往 run_end 的正权重路径。概率切出不保证固定次数内抵达终局，但不存在零概率出口/消耗钥匙软锁。

## 节点与内容边界

MapSystem 只管拓扑/实例/结算与揭示。EventSystem 只管文本选项条件及跨域规划；中立/友善身份在 EventData，转入战斗时才使用 EntityData 的敌对能力。

RewardSystem 创建真实 RewardOpportunity，UI 只能领取队列中的当前实例。REST 一次选择：回复、强化、删除、补满装备或放弃；查看候选不消耗。SHOP 首版一次交易或离开，不引入货币以外的新库存系统，使用已有 Supply。

当前两层各五层深度、每层 2–3 个不规则节点，终点 EXIT；所有边严格向后继层，不允许回退。节点位置和连接公开，内容揭示独立于 UNVISITED/ACTIVE/RESOLVED。

## 旧实现处理

`archive/phase13c_before_phase14/` 保存迁移前 scripts/data/scenes/tests（包含开发者未完成的 Phase 14 字段修改），根 `.gdignore` 排除 Godot 导入。不提供可启动的旧游戏模式，旧 res:// 引用也不代表归档可独立运行。

正式 scripts/data/scenes 不再引用 Objective、旧探索回合、Threat/Cognition、临时 CutOut 牌和旧准备/资源搜刮命令。旧测试没有伪装成继续通过；Phase 14 测试重建仍适用的不变量，旧玩法断言留作历史。

## 有意未扩展

只实现单敌人、两个 Level 和 M.E.G. 原型，不实现职业选择、多敌人、Boss、遗物、制作、元进度、通用脚本规则解释器。楼层历史是同一局内存持久化；**没有新增磁盘存档或旧存档迁移器**。新内容数字属于原型，仍需真人平衡与体验测试。
