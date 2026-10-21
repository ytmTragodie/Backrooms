# ARCHITECTURE｜后室卡牌游戏架构规范

> 版本：2026-10-20，精简重构版。**本文件是目标架构约束，不代表所有模块已实现。** 技术现状以仓库代码为准，玩法目标以 `GDD.md` 为准。修改前先检查 `AGENTS.md`、现有调用方、测试及 `.tres` 引用。
>
> 优先级：用户本次指令 → 仓库 `AGENTS.md` → 本文件 → `CODING_RULES.md` → `GDD.md`。旧 Phase 记录、迁移计划和审计文档只供追溯，不能恢复被废弃的玩法。

## 1. 技术边界与核心原则

- Godot 4.x / GDScript / Compatibility / Windows；2D 卡牌 UI。未经同意不引入 C#、ECS、外部框架或插件。
- **卡牌优先**：玩家主动游戏行为以统一手牌中的真实 CardInstance 发起，遵循“一牌一主语义”；普通牌、装备生成牌、楼层临时牌共用手牌与 AP，但生命周期不同。奖励领取、一次性安全点决策、地图目的地选择属于已获得机会的流程处理，不是第二套探索/战斗按钮。
- **单一权威状态**：UI 只读状态并提交 Command；不能保存可写的 HP、进度、牌堆、实体状态副本。
- **数据驱动、组合优先**：代码实现可复用规则，`.tres` 描述使用规则的具体内容。不要按怪物 ID、关卡名、卡牌名写不断增长的 `if/elif`。
- **小而完整的垂直切片**：先复用现有系统，待职责边界明确再拆类；不要为想象中的扩展预建通用 DSL、万能 Component、复杂继承树。

## 2. 数据模型：Data、Instance、State

| 类型                       | 回答的问题                       | 示例                                                         | 约束                                            |
| -------------------------- | -------------------------------- | ------------------------------------------------------------ | ----------------------------------------------- |
| `*Data` (`Resource`)       | 它被设计成什么？                 | `ObjectiveData.progress_threshold`、`EquipmentData.max_charges`、`PlayerData.starting_deck` | 静态、可共享；不得在运行中写入单局进度          |
| `*Instance` (`RefCounted`) | 这一个具体对象此刻怎样？         | `ObjectiveInstance.progress`、`EntityInstance.hp`、`EquipmentInstance.charges` | 每次出现独立实例；可随结算变化                  |
| `*State` (`RefCounted`)    | 这个作用域目前拥有什么？         | `RunState`、`PlayerState`、`DeckState`、`FloorState`、`BoardState` | 一个字段只有一个可写所有者，不维护平行副本      |
| `*ActionResult`            | 此次动作**计划**造成什么变化？   | `result.player.supply_delta`、`result.objective.resolved`    | 短生命周期事务草稿，绝不是第二份 State          |
| `*System`                  | 谁校验、规划、提交某类领域规则？ | `ObjectiveSystem`、`CardSystem`                              | 按真实职责创建，不强求每个 Data 都有同名 System |

判断字段归属的顺序：**静态配置还是本局变化 → 谁拥有最终状态 → 生命周期是单回合、单楼层还是跨楼层 → 是否已有唯一写入者**。例如 Objective 完成给 2 Supply：`ObjectiveData.completion_supply` 定义奖励，`ObjectiveInstance.resolved` 记录完成，`result.player.supply_delta += 2` 计划玩家资源增加，最终由玩家状态的提交入口写入。

### 2.1 状态树：RunState 是聚合根，不是巨型属性桶

目标组织方式（**渐进迁移，非立即重命名指令**）：

```text
RunState                       # 一局游戏的聚合根、跨层引用与运行流程
├── player: PlayerState        # HP/max_hp、Stress/Supply、AP/Block 等个人持有状态
│   ├── deck: DeckState        # NORMAL 牌组与手牌/牌区的唯一所有者
│   └── equipment: EquipmentState  # 携带槽、物品实例与装备牌生成调度
├── floor_state: FloorState    # 本次楼层访问的 Threat、Cognition、规则与资源
│   ├── board_state: BoardState # 最多 2 Event + 1 Objective + 当前 1 Entity
│   └── cutout_state: CutOutState
├── flow: RunFlowState         # 回合号、待领取奖励队列、最近切出记录
├── metrics                    # 已提交事实
└── rng / rng_seed             # 确定性随机源
```

- `RunState` 中不再保留 `player_hp / stress / supply / ap / deck_state / equipment_slots / pending_rewards / turn_number / last_cutout_attempt` 等平铺业务字段；`FloorState` 也不再保留 `player_block`。不要为了过渡重新添加同义可写字段。
- 玩家**持有** `DeckState / EquipmentState` 的引用，牌区与装备内部数据由各自 State 管；“玩家有牌组”不等于“玩家类里平铺 draw/hand/discard 每个数组”。`EquipmentState` 只保存槽位引用与生成调度，耐久/电量/次数只在 `EquipmentInstance` 上。
- 作用域要明确：Supply/HP/Stress/AP/Block 属于玩家，由 `PlayerSystem` 提交；Threat/Cognition/本层环境属于 Floor；`TurnManager` 只安排回合生命周期并调用 `PlayerSystem.begin_turn`，不直接写玩家字段。
- `FloorData` 是层型配置，`FloorState` 是本次访问；回到同一层一般创建新状态。BoardState 才是活动世界对象的唯一所有者；ID/历史记录不是活动实例的替代品。
- 跨层地图持久信息归 RunMapState，不归本层 FloorState；Reward Opportunity 归 `RunFlowState.pending_rewards`，真正加入/升级/移除的牌归 DeckState。

### 2.2 控制大型类的增长

- `RunState` 只**聚合状态引用、维护 Run 级不变量/初始化**，不加入卡牌、实体、环境、装备业务规则。
- 类变长时，先按**状态所有权和生命周期**拆出可命名子状态，例如 `PlayerState / DeckState / EquipmentState / RunMapState`；不要以“文件超过 N 行”为唯一依据。
- 一个 `System` 可拆成语义明确的私有函数（校验、各类型规划、提交），而非增加平行 Manager。不要拆成几十个只有转发语句的 System。
- 优先组合持有（has-a），避免把 Objective / Entity / Event 继承成共享业务状态的“万能世界卡”；只允许复用轻量显示组件。
- 所有 `.tres`、测试夹具和存档契约是迁移接口，改字段名要同步盘点，不可只改代码就宣称完成。

## 3. 动作事务：Validate → Plan → Commit → Notify

```text
UI 选择真实手牌 + 合法目标
  → PlayCardCommand
  → RuleResolver 验证身份/费用/条件
  → 领域系统共同构造一个 ActionResult（只规划，不写状态）
  → 全部成功：同步提交各领域变化与 RNG
  → 发信号、刷新 UI、记录已提交日志
  → 失败：卡牌/AP/装备/奖励/实体/随机状态均不改变
```

`ActionResult` 已在向分域结构迁移，**沿用仓库当前已完成的分组**，不要在顶层继续加大量平铺字段，也不要为架构整齐重新拆一遍。推荐边界：

```gdscript
# 示意字段名，实施时以仓库现有 Result API 为准。
result.objective.resolved = true       # Objective 的完成事实
result.player.supply_delta += 2       # 玩家获得资源（触发来源仍是 Objective）
result.entity.hp_after = 6            # 实体生命变化
result.floor.threat_delta += 1        # 楼层风险变化
result.flow.rewards_created.append(opportunity) # 将已规划的奖励机会提交到 Run 队列
```

**Result 按最终被改变的状态所有者分组，不按触发来源分组**。`FlowActionResult` 仅记录流程机会/阶段变化（奖励待选、地图选择、安全点/结局），不能作为 `WorldActionResult` 式兜底桶；实际牌组变化进入 Deck 领域。跨域变化很正常，但一个值只能提交一次。

### 3.1 System 的协作边界

- `ObjectiveSystem.plan_*()` 可写 `result.player.*`，也可调用 `InsightSystem.plan_*()`；这**不是**直接修改玩家/Insight 状态。
- `ObjectiveSystem.commit()` **只提交 ObjectiveInstance 自身的状态**；本层累计完成数等 FloorState 统计应通过 Floor 领域的结果与提交入口更新，不能顺手改其他领域，更不能直接 `state.player.supply += ...`。玩家资源由玩家领域统一提交，卡奖励机会由 CardRewardSystem/流程领域处理，牌组真正变化由 CardSystem 提交。
- `plan` 只读权威状态、填入 Result；`commit` 按计划写状态，**不重新抽随机数、不重新计算条件、不临时发奖励**。
- RuleResolver/TurnManager 负责编排全部 plan 和明确的 commit 顺序。跨域先后依赖必须写出并测试，不能靠 Signal/SceneTree 回调顺序完成玩法。
- 没有独立复杂规则时不强制新增 `PlayerSystem`；如果加入，应先做**薄提交层**，并确保既有写入路径迁走而不是双写。
- 所谓原子性指“提交前完整验证和规划、拒绝无部分变化”；不要声称 GDScript 自动提供数据库式回滚。提交中间失败属于开发缺陷，应通过不变量/测试规避。

## 4. 领域责任速查

| 领域                       | 拥有的规则/状态                                         | 不能越界负责                       |
| -------------------------- | ------------------------------------------------------- | ---------------------------------- |
| CardSystem / DeckState     | 发牌、抽弃洗、Retain、生成牌生命周期、真实牌组修改      | 怪物掉血、Objective 判定           |
| ObjectiveSystem            | PROGRESS / CONDITION / SEQUENCE，目标完成、目标实例状态 | 玩家资源最终写入、卡奖励生成 UI    |
| EventSystem                | DEBUFF / OMEN / OPPORTUNITY 的倒计时、条件、临时压力    | Objective 调查进度、第二套交互     |
| EntitySystem               | HP、State、Intent、条件反应、退场                       | 单独战斗模式、卡牌的发放/洗牌      |
| EquipmentSystem            | 持续装备、可用次数、专用行动卡来源                      | 把装备物品放入 NORMAL 牌组         |
| FloorSystem / BoardState   | 当前访问、Threat/Cognition、内容调度和活动目标          | 跨楼层地图历史与玩家持有的 Supply  |
| InsightSystem              | 唯一 Insight 的确认/去重，触发楼层认知结果              | 把每次观察直接等同 +1 Cognition    |
| CutOutSystem / Map         | 离层合法性/风险，路线候选、已访问记录                   | 另造离层按钮或即时跳层绕过地图选择 |
| CardRewardSystem           | 三选一机会的生成/校验/领取流程                          | 管理所有 Supply/HP/地图奖励        |
| RuleResolver / TurnManager | 一次动作的事务编排 / 回合生命期                         | 吞并每个领域的具体规则             |

### 4.1 Objective 与 Event 分离

- `SceneRule`：持续环境规则/呈现，不能选为目标。
- `Event`：短期局势影响（DEBUFF、OMEN、OPPORTUNITY），最多 2 张，**无 Explore HP、不可作为普通牌调查目标**。
- `Objective`：稀有的可选风险/收益对象，最多活动 1 个，支持 `PROGRESS`（短进度及阶段反馈）、`CONDITION`（无序条件）、`SEQUENCE`（有序步骤）。一般不作为离层前置。
- `Entity`：直接威胁，当前至多 1 个活动实例；普通伤害、行为规则、存活退去共用 EntitySystem。
- **调度与选择分离**：先由探索/遭遇调度决定本次是否出现 Objective，再由 ObjectiveSystem 在合格定义中选哪一个；**降低 weight 只改变对象比例，不降低 Objective 总出现频率**。

### 4.2 环境 → Entity 的可扩展反应

- 世界描述“当前实际生效的环境条件/效果”（如 LIGHT、DARK、NOISE、WET），EntityData 声明自身匹配条件与状态/Intent 反应。
- 由 EntitySystem 根据**真正结算的效果**规划反应；不能只凭未成功打出的卡面 LIGHT 标签判断暴露。
- 优先反应为警戒、追击、退去、意图改变，再考虑数值伤害；禁止无限增加 `entity_light_exposed / entity_noise_exposed / ...` 顶层布尔字段。
- 可引入小型 `EnvironmentReactionData` 或现有 Condition/Effect Resource；优先复用已有结构，不预建通用环境模拟器。

## 5. 关卡流程与内容生命周期（目标设计）

- **普通回合**：单一 3 AP 与手牌，Entity / Event / Objective 可共存；怪物意图、环境压力、滞留等由同一 TurnManager 按明确定序结算。新怪物不在生成的同一动作里立刻执行意图。
- **Objective**：低频可选；完成可触发 Player、Insight、CutOut、Reward、Entity/Omen 等跨域规划，但各领域分别 commit。
- **Safe Point**：是一次性获得的机会；符合触发与可用条件时立即呈现“进入/放弃”，放弃即消失；进入后可休整/构筑。不是长期保留的普通操作按钮。
- **CutOut**：成功先生成路线候选、打开 Map 目的地选择，选择后才真正切换 FloorState。RunMapState 保留已访问/已知路线；安全切出提供更明确情报，仓促切出信息更少。无论资源/Insight 如何，都必须存在风险可接受但非免费、不保证安全的离层途径。
- **切出牌失败处理的目标规则**：未打出可以 Retain；已打出但失败，应离开手牌进入**可再次抽取的楼层临时弃置/回收流程**，不得直接原位保牌。实现前须设计来源隔离及重抽保障，不能把它默默变成永久 NORMAL 牌；目前旧代码若仍为失败保牌，属**待迁移**而不是已实现。
- **奖励**：pending queue 是 Run 级唯一权威机会队列；领取消耗对应机会，实际新增/升级/移除 NORMAL 卡必须通过 Deck 领域。不能重复发奖。

## 6. UI、资源、随机、日志与验证

- 玩家牌、Event、Objective、Entity、装备在外观上可复用卡框组件，但**业务 Data/Instance 保持分离**；Event 卡正面精简，详情通过悬停/只读面板/日志提供。
- 素材通过稳定 `asset_id` → `assets/asset_manifest.json` 解析；UI 文本、数值动态绘制，缺图用回退，不让素材驱动玩法。
- 游戏 RNG 只有一个权威序列；规划用可复制/隔离的随机状态，提交成功才推进，种子应能复现问题。
- Signal 只通知已完成的结果，不触发隐含的另一条奖励/伤害规则链。
- 保存仅序列化可重建的稳定 ID、数值和状态，不保存 Scene Node 引用。运行指标只记录已提交事实，不复制活动状态。
- 必须验证：失败无副作用、卡牌来源与实例守恒、唯一奖励/Insight、目标访问身份校验、环境反应依据实际效果、无永久卡死离层、跨层携带状态、当前真实窗口显示。**Headless 通过不等于视觉验收。**

## 7. 架构决策与迁移准则

**先查现状 → 给出受影响文件/引用 → 说明状态唯一所有者 → 最小可测试修改 → 移除旧路径**。设计目标与当前代码冲突时，先报告差异，不得把整套目标架构当作单次任务自动重写。长文件优先从“职责混杂、状态双写、跨域 commit”下手，不因行数单独拆分。