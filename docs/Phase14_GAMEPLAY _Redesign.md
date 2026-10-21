# BACKROOMS: CUT OUT — Phase 14 数据结构与机制设计底稿

**版本：v0.3**  
**架构基础：Phase 13C**  

---

## 0. 总体定位与设计原则

### 0.1 核心玩法

游戏定位为以卡牌构筑和实体战斗为核心的后室 Roguelike。

主要由四个系统组成：

1. **Combat：** 卡牌构筑、攻击、防御、Intel、敌人意图、实体特殊机制与撤离。
2. **Map：** 非线性节点地图、迷雾信息、风险选择与空间探索。
3. **Event：** 文本交互、资源交换、友善或中立实体、特殊遭遇。
4. **CutOut：** 通过出口在多个目标 Level 之间进行概率切出。

不同 Level 通过地图配置、敌人、事件、资源分布和特殊规则塑造差异。

### 0.2 工程约束

- 继承 Phase 13C 已建立的状态组合根与单一写入者设计。
- 静态配置优先使用 Godot Resource（`.tres`）。
- 可变运行时状态使用 RefCounted。
- 状态修改遵循 Validate → Plan → ActionResult → Commit。
- 不允许业务系统绕过统一结算入口直接修改其他系统状态。
- 不保留正式玩法中新旧系统的双写兼容逻辑。
- 不因尚未实现的未来机制提前建立大量 Manager 或 State。
- 后续代码修改必须以实际仓库审查结果为准。

### 0.3 不再作为核心玩法的旧机制

- Observe / Search 驱动的探索出牌流程。
- Objective 进度条式楼层推进。
- 在普通环境节点使用整套战斗手牌。
- 通过旧版探索回合积累切出进度。

旧代码是否仍有可复用部分，需要在 14A 审查后决定。

---

## 1. 运行时状态架构

### 1.1 建议逻辑结构

```text
RunState
├── PlayerState
│   ├── HP / MaxHP
│   ├── Stress
│   ├── Supply
│   ├── DeckState
│   ├── EquipmentState
│   └── KnowledgeState                 [新增]
│
├── FloorState                        [当前激活 Level 的访问入口]
│   ├── floor_id
│   ├── FloorMapState
│   └── 当前 Level 的运行时数据
│
├── FloorHistoryState                 [新增，整局楼层状态存储]
│   └── 已生成 Level 的 FloorState / MapState
│
├── RunFlowState
│   ├── run_phase
│   ├── active_encounter
│   └── pending_rewards
│
└── RunMetrics / RNG
```

战斗期间存在：

```text
CombatState
├── phase / turn_number
├── ap / max_ap
├── block
├── intel
├── noise
├── CombatDeckState
├── EnemyState[]
├── 当前已锁定的敌人意图
└── outcome
```

**注意：上述为逻辑归属，不要求全部新建对应类。**

### 1.2 单一数据所有权

- PlayerState：负责跨战斗玩家数据。
- CombatState：负责单场战斗状态。
- FloorMapState：负责地图节点与连接的运行时状态。
- FloorHistoryState：负责已生成楼层的存储和重新激活。
- RunFlowState：负责当前流程阶段和待结算奖励。
- 静态 Resource：只提供内容配置，不存储可变运行时状态。



---

## 2. PlayerState 与 KnowledgeState(已添加)

### 2.1 PlayerState（已修改）

保留：

- HP / MaxHP
- Stress
- Supply
- DeckState
- EquipmentState

调整：

- AP、Block 从长期 PlayerState 迁移到 CombatState。
- 原探索专用临时状态按新职责删除或迁移。

### 2.2 KnowledgeState（已添加）

**已确认：使用已知信息集合，不设置通用情报点数。**

Knowledge 是长期知识，不等同于战斗 Intel。

建议按知识类型组织：

```text
KnowledgeState
├── 已知 Level 信息
├── 已知实体信息
├── 已知出口信息
└── 已知特殊规则
```

知识可以影响：

- 地图节点内容揭示。
- 实体弱点或行为信息。
- 事件特殊选项。
- 切出目的地身份的揭示。
- 某些预先定义的 CutOut 修正规则。

不必将 Knowledge 设计为可累积、可消费的统一数值。

---

## 3. CombatState：基础战斗（已添加）

### 3.1 已确认基础规则

- 每回合基础 AP：**3**。
- 每回合基础抽牌量：**5**。
- 使用抽牌堆、手牌、弃牌堆与消耗牌堆。
- 第一版仅需要实际支持单敌人。
- 目标选择与敌人容器保留后续多敌人扩展能力。
- 当前敌人行动意图对所有角色公开。
- M.E.G. 的战斗情报资源为 Intel。

### 3.2 建议字段

```text
CombatState
- phase
- turn_number
- ap
- max_ap
- block
- intel
- noise
- combat_deck_state
- enemies[]
- locked_intents[]
- outcome
```



### 3.4 战斗结局

```text
VICTORY
DEFEAT
ESCAPE
```

其中 ESCAPE 是独立结局，不提供战斗胜利奖励，也不会直接改变 Level。

---

## 4. DeckState、CombatDeckState 与 CardData

### 4.1 牌库生命周期

**DeckState：** 整局卡组，记录玩家拥有的卡牌。

**CombatDeckState：** 本场战斗的抽牌堆、手牌、弃牌堆和消耗牌堆。

战斗开始时从长期卡组创建战斗牌区。

战斗内的抽牌、弃牌、消耗不直接改变长期卡组，除非卡牌效果明确规定永久变化。

### 4.2 CardData 里面有关的定义可以复用effect_data的（已修改）

建议配置：

- card_id
- name
- description
- rarity
- cost
- card_type
- target_type
- effects[]
- upgrade_data
- lifecycle_flags

建议支持的效果：

- 攻击伤害
- 获得 Block
- 抽牌
- 获得 AP
- 获得 / 消耗 Intel
- 施加状态
- 恢复 HP
- 改变 Stress
- 改变 Noise

卡牌效果可通过统一效果列表配置，但是否采用通用效果解释器，须根据现有代码实际情况决定。

---

## 5. EntityData / EntityState / EntityIntent(已完成)

### 5.1 EntityData：静态配置

建议包含：

- id
- display_name
- description
- visual_data
- max_hp
- behavior_data
- weaknesses
- reward_data
- escape_damage_range
- escape_stress
- 其他专属规则

关于weakness

```
WeaknessData
├── weakness_id
├── trigger: TriggerData
├── conditions: Array[EntityConditionData]
├── effects: Array[EffectData]
└── cooldown

class_name TriggerData
extends Resource

enum TriggerType {
    ON_DAMAGE_TAKEN,
    ON_EFFECT_RECEIVED,
    ON_TURN_START,
    ON_TURN_END
}

@export var type: TriggerType
@export var effect_tag: StringName = &""
# effect_tag 用来识别强光、钝击等效果标签，而不是识别特定卡牌名称
```



### 5.2 EnemyState/Instance：战斗实例（half)

建议包含：

- instance_id
- enemy_data 引用
- current_hp
- block
- status_effects（这个是不是也要定义一个新的
- behavior_state
- current_intent
- alive

### 5.3 EnemyIntent

敌人意图必须具备两种用途：

1. 提供给战斗 UI 进行预览。
2. 提供给实际战斗结算。

同一已锁定意图的确定效果不得由 UI 与结算层分别随机生成。

---

## 6. EscapeSystem：统一战斗撤离

### 6.1 已确认规则

- **只有一种撤离**，不区分安全撤离与强行撤离。
- 撤离是战斗界面的常驻操作，不要求抽到撤离卡。
- 撤离消耗 **1 AP**。
- 玩家必须保留至少 1 AP 才能执行撤离。
- 撤离不进行成功率判定。
- 撤离受到实体决定的随机 HP 伤害。
- 撤离增加 Stress。
- 撤离伤害范围会受到当前敌人意图的小幅修正。
- 撤离不获得本场战斗的胜利奖励。
- 撤离结果为 ESCAPE。
- 撤离不是 CutOut，不改变当前 Level。

### 6.2 静态配置

EnemyData 至少应能够定义：

```text
escape_damage_min
escape_damage_max
escape_stress
```

当前意图可以携带撤离伤害修正数据，或者由独立规则根据意图类型计算。

修正后的伤害上下限必须满足：

- 最小值不大于最大值。
- 最终伤害不为负。
- 预览范围与真实抽样范围一致。

### 6.3 EscapePreview

用于 UI 展示：

- allowed
- reason（不可撤离时）
- ap_cost
- damage_min
- damage_max
- stress_gain
- reward_forfeit

预览阶段不得消耗 RNG。

### 6.4 EscapeResult

一次正式撤离：

1. Validate：检查当前阶段、存活状态和 AP。
2. Plan：根据实体和当前已锁定意图计算伤害范围。
3. Plan：使用 RNG 抽取一次实际损失。
4. ActionResult：记录 AP、HP、Stress 与战斗结局变化。
5. Commit：统一应用所有变更。
6. 若玩家因撤离伤害死亡，结局为 DEFEAT；否则为 ESCAPE。
7. 返回地图节点结算，不触发胜利奖励。

注意：以上是逻辑结算顺序，具体如何在一次事务内组织，应遵循 Phase 13C 已有框架。

---

## 7. Noise：战斗内噪音

### 7.1 已确认规则

**首版 Noise 仅在当前战斗内生效。**

- 不保存到 FloorState。
- 不产生跨节点追踪状态。
- 不影响下一地图节点。
- 战斗结束后清空。

### 7.2 建议归属

```text
CombatState.noise
```

可能由卡牌、装备和敌人动作改变。

相关规则由当前敌人或 FloorData 中的战斗规则读取。

### 7.3 可能的战斗内效果

- 使敌人的下次行动更危险。
- 达到阈值后触发特殊意图。
- 提升特定实体的攻击或追猎能力。
- 限制某些战斗策略的收益。

首版不要求真实多敌人增援。



---

## 8. FloorData：Level 静态配置

### 8.1 建议字段

- floor_id
- display_name
- description
- visual_theme
- map_generation_config
- encounter_pool
- event_pool
- reward_pool
- cutout_route_pool
- floor_rule_set

### 8.2 Level 差异

不同 Level 可以拥有不同的：

- 地图规模。
- 节点类型权重。
- 战斗频率。
- 精英频率。
- 休息、商店和资源分布。
- 实体种类。
- 特殊事件。
- 战斗内特殊规则。
- 可用 CutOut 路线。

相对安全的 Level 应偏向恢复、交易、整理卡组和情报获取。

高危险 Level 应偏向更强敌人、更少恢复机会与更高价值奖励。

---

## 9. FloorMapState：地图数据与迷雾

### 9.1 已确认规则

- 地图底层采用非线性 DAG。
- 玩家只能沿合法的有向连接前进，不允许回退。
- **节点位置与连接关系可见。**
- **节点的具体内容受迷雾影响。**
- 当前可移动节点必须明确标识。
- 迷雾仅影响玩家掌握的信息，不改变实际地图拓扑。

### 9.2 FloorMapState

建议包含：

```text
FloorMapState
- nodes[]
- edges[]
- current_node_id
- generation_metadata
```

### 9.3 MapNodeState

建议包含：

- node_id
- node_type
- content_id
- visibility / reveal_state
- resolution_state
- 其他必要的节点实例数据

建议至少区分：

**内容揭示状态：**
- UNKNOWN：可见节点位置，但内容未知。
- REVEALED：已知节点类型或内容。

**节点结算状态：**
- UNVISITED
- ACTIVE
- RESOLVED

这两组状态独立，避免“已揭示但还没访问”的节点无法表达。

### 9.4 需要明确的迷雾含义

地图迷雾不等于遮住地图坐标。

例如玩家可以看到：

```text
起点 → ? → ? → EXIT
        ↘ ? → EXIT
```

但不一定知道问号节点分别是战斗、事件、休息还是特殊遭遇。

M.E.G. 情报可以提前揭示部分节点类型或危险信息。

## 10. FloorHistoryState：重复进入 Level

### 10.1 已确认规则

**同一局内重新进入曾经访问的 Level，恢复此前地图与节点状态，不重新生成地图。**

这是整局层面的持久化机制，不是单场战斗状态。

### 10.2 建议逻辑

首次进入某个 Level：

1. 根据 FloorData 生成地图。
2. 创建该 Level 的运行时状态。
3. 登记到 FloorHistoryState。
4. 激活该 Level。

再次进入同一个 Level：

1. 查找已有的楼层运行时状态。
2. 恢复先前的地图拓扑。
3. 恢复节点揭示与结算状态。
4. 根据明确的重入规则选择落点。
5. 将该 Level 重新设为当前活动楼层。

### 10.3 必须保留的数据

- 已生成地图节点与连线。
- 节点已揭示信息。
- 节点访问与结算状态。
- 已领取且不可重复领取的奖励。
- 已结算的一次性事件。
- 出口及其他固定节点状态。
- 当前 Level 需要跨重入保存的特殊状态。

### 10.4 重要设计风险：重新进入后的落点

原地图是不可回退的 DAG，因此不能简单地恢复“上次离开时所处的 EXIT 节点”并要求玩家继续前进。

否则可能出现：

- 玩家重返 Level，却直接站在此前的出口。
- 原来的奖励与事件已经领取，无法继续探索。
- 没有可达的合法前进节点。
- 玩家可以通过反复重入重复刷取出口机会。

因此必须设计明确的重入规则。

---

## 11. CutOutSystem：概率切出

### 11.1 已确认规则

- 正常 CutOut 仅在 EXIT 节点触发。
- **普通切出必定成功。**
- **切出目的地根据概率随机确定。**
- 目的地可以有多个。
- 情报和道具能够影响玩家掌握的信息或最终目的地分布。
- CutOut 与战斗 ESCAPE 是独立机制。

### 11.2 CutOutRouteData

建议：

```text
CutOutRouteData
- route_id
- destinations[]
```

每个目的地：

```text
CutOutDestinationData
- floor_id
- base_weight
```

`base_weight` 表示相对权重，不直接表示百分比。

### 11.3 CutOutPreview

可向玩家显示：

- 已知目的地。
- 未知目的地所占概率。
- 当前归一化概率分布。
- 已生效的情报与道具修正。
- 当前选择的出口。

### 11.4 结算流程

- Validate：检查是否位于合法 EXIT 节点。
- Plan：计算最终权重并抽取目的地。
- ActionResult：记录切出结果、历史楼层保存与激活目标的变更计划。
- Commit：完成跨楼层状态切换。

概率预览不得消耗 RNG，同一次切出不得重复提交。

---

## 12. Event / Encounter：节点与实体关系

### 12.1 基础节点类型

- COMBAT
- ELITE
- EVENT
- REST
- REWARD
- SHOP
- EXIT

### 12.2 EventData

建议支持：

- 事件描述。
- 多个选项。
- 选项条件。
- 资源变化。
- Knowledge 解锁。
- 卡牌与装备奖励。
- 后续事件分支。
- 可能触发战斗。

### 12.3 实体身份与关系

建议分开：

- 敌人在战斗中的能力定义。
- 当前遭遇中的实体关系。
- 事件中玩家能够获知的实体身份。

这样同一种实体可以因为遭遇条件而保持中立、交易或转为敌对。

---

## 13. RewardSystem：构筑成长

### 13.1 奖励来源

- 普通战斗胜利。
- 精英胜利。
- 事件选择。
- 安全 Level 整备。
- 特殊出口。
- 稀有节点。

### 13.2 撤离奖励规则

已确认：

**ESCAPE 不获得本场战斗的胜利奖励。**

撤离不会自动撤销玩家在进入战斗前已经合法取得的资源。

---

## 14. UI 修改要求

### 14.1 地图 UI

- 不规则节点布局。
- 可见节点位置及连接。
- 未知节点以迷雾、灰色或问号呈现。
- 已揭示节点显示类型或风险信息。
- 当前合法路线高亮。
- Level 主题化视觉表现。

### 14.2 战斗 UI

- 玩家 HP、Stress。
- AP / Block / Intel。
- 敌人 HP、状态和公开意图。
- 当前手牌与牌堆信息。
- 撤离按钮。
- 撤离 HP 随机范围和 Stress 增量预览。
- 当前战斗启用 Noise 时显示相应信息。

### 14.3 CutOut UI

- 出口信息。
- 候选目的地与概率。
- 未知目的地比例。
- 已生效的情报和道具。
- 切出确认与结果反馈。

### 14.4 重复 Level 的 UI

玩家返回此前访问过的 Level 时，应恢复相应地图揭示、节点结算和空间状态。

不得用重新生成的空白地图覆盖历史记录。

---

## 15. Phase 13C 迁移清单

### 保留和复用

- RunState 组合根。
- PlayerState 长期玩家状态。
- DeckState。
- EquipmentState。
- RunFlowState。
- 已有 ActionResult 与统一提交机制。
- 已有静态 Resource 内容结构中适用的部分。

---

## 16. Phase 14 实施顺序

### Phase 14A：审查与设计冻结

- 对照 Phase 13C 实际代码。
- 确定状态所有权。
- 整理字段迁移清单。
- 解决重入 Level 入口与软锁问题。
- 冻结基础战斗、地图与切出规则。

**不改代码。**

### Phase 14B：基础卡牌战斗

- CombatState。
- 战斗牌区。
- 3 AP、每回合抽 5 张。
- 单敌人战斗。
- 公开敌人意图。
- 基础胜负结算。

### Phase 14C：M.E.G. 战斗构筑

- Intel。
- 侦察与情报 Combo。
- 初始卡组。
- 核心卡池。
- 基础状态效果。

### Phase 14D：DAG 地图与迷雾

- 地图生成。
- 路线选择。
- 可见节点和连接。
- 隐藏节点内容。
- 节点访问与结算。
- 已生成 Level 的状态保存基础。

### Phase 14E：CutOut 与重复 Level

- EXIT 节点。
- 概率目的地。
- CutOut 预览。
- 跨 Level 转移。
- 已访问 Level 的地图恢复。
- 重入入口和软锁处理。

### Phase 14F：完整游戏循环

- 地图事件。
- 战斗奖励。
- REST。
- SHOP / REWARD 基础流程。
- 卡组和装备成长。
- Level 差异化配置。

### Phase 14G：后室战斗特色

- 统一撤离。
- 实体意图对撤离伤害的修正。
- 战斗内 Noise。
- 少量特色实体行为。

### Phase 14H：验证与清理

- 大量随机种子生成地图。
- 检查重入 Level 是否软锁。
- 检查奖励是否重复领取。
- 检查随机切出结果分布。
- 检查战斗意图与实际结算一致性。
- 检查撤离伤害范围和 AP 合法性。
- 检查旧探索逻辑是否仍被生产流程调用。
- 完成可玩性与平衡测试。

---

## 17. 当前已确认规则汇总

| 项目 | 规则 | 状态 |
|---|---|---|
| 战斗基础 AP | 3 | 已确认 |
| 每回合抽牌 | 5 | 已确认 |
| 撤离 AP 消耗 | 1 | 已确认 |
| 撤离模式 | 统一撤离 | 已确认 |
| 撤离成功 | 满足执行条件即成功，伤害可能致死 | 已确认 |
| 撤离 HP 代价 | 实体基础随机范围 + 当前意图小幅修正 | 已确认 |
| 撤离 Stress | 增加，具体值待定 | 部分确认 |
| 撤离奖励 | 不提供战斗胜利奖励 | 已确认 |
| 地图拓扑 | 非线性 DAG、不可回退 | 已确认 |
| 地图迷雾 | 节点及连接可见、节点内容隐藏 | 已确认 |
| 普通切出 | 必定成功 | 已确认 |
| 切出目的地 | 随机概率分布 | 已确认 |
| 长期 Knowledge | 已知信息集合，不设统一点数 | 已确认 |
| Noise | 仅本场战斗内生效 | 已确认 |
| 重入 Level | 保留已生成地图和节点状态 | 已确认 |
| 重入落点 | 尚未决定 | 待确认 |
| 重入后已结算节点的处理 | 尚未决定 | 待确认 |

