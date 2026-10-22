# CODING_RULES｜AI 编程与代码审查规范

> **Phase 14 当前覆盖**：遵循 [PHASE_14_ARCHITECTURE.md](PHASE_14_ARCHITECTURE.md)。AP/Block/Intel/Noise 属于 CombatState，持有牌属于 DeckState、四牌区属于 CombatDeckState。有限 EffectData 列表、文本事件选项、地图节点和常驻战斗撤离是本次已授权设计，不应受下文旧“所有主动行为来自统一探索手牌”的历史规则阻挡。单写入者、原子计划、类型和中文注释规范继续适用。

> 版本：2026-10-20。适用于 Godot 4.x / GDScript。以 `ARCHITECTURE.md` 规定的权威状态、领域边界和事务流程为准。**先读仓库现有代码，不能把文档示例当作已存在的类/字段/API。**

## 1. 目标：让人能读、能改、能扩展

本项目由开发者持续亲自维护。AI 生成代码优先级：**正确 → 领域归属清晰 → 可复用 → 可测试 → 易读 → 适度性能**。

- 小函数有清楚语义；有不同规则分支时先考虑 `_plan_progress / _plan_condition / _plan_sequence`，不要把大量 `if` 堆在一个函数。
- 拆分依据是**职责、生命周期、独立不变量**，不是“为了模块化把每一行装进一个新类”。小项目不引入万能 Effect DSL、Service Locator、复杂抽象继承或无意义 Manager。
- 优先复用现有 Data/Instance/State/System 和测试；除非确需改变接口，否则保持已有类型、命名、调用路径。
- 使用类型化 GDScript；文件/变量/函数 `snake_case`，类名 `PascalCase`，稳定 ID 英文小写；**玩家 UI 中文，代码和稳定 ID 英文，重要注释中文**。
- 对外/跨模块函数的名称应表达动作：`validate_*`、`plan_*`、`commit`、`draw_*`、`resolve_*`。避免 `handle_everything()`、`do_stuff()`。

## 2. 所有权：字段应放在哪里？

新增字段前先回答：它是静态配置还是运行时状态？**谁最终写它？** 它跨回合还是跨楼层？是否已有同义字段？

| 例子                      | 正确类型/所有权                                              |
| ------------------------- | ------------------------------------------------------------ |
| Objective 所需进度 6      | `ObjectiveData.progress_threshold`                           |
| 这次 Objective 进度 4     | `ObjectiveInstance.progress`                                 |
| 目标完成额外给予 2 Supply | `ObjectiveData.completion_supply`（配置）→ `PlayerActionResult.supply_delta`（计划）→ 玩家权威 State（实际） |
| 玩家拥有牌堆与携带槽      | `PlayerState` 持有 `DeckState / EquipmentState` 引用（迁移目标）；现有仓库先沿用 `RunState` 真实字段 |
| 手牌/抽弃牌               | 只能由 `DeckState` 持有，不能在 Player/UI 再复制一套         |
| 具体手电的剩余电量        | `EquipmentInstance`，不是共享 `EquipmentData`                |
| 本层 Threat、Cognition    | `FloorState`，不是 PlayerData                                |
| 奖励待选择                | Run 的 pending 队列；实际牌组改变在 DeckState                |

**大类收敛规则**：若 `RunState` 或某 System 因新增功能持续膨胀，优先把同一子领域的字段与不变量移到 `PlayerState / DeckState / EquipmentState / RunMapState` 等明确子对象。父类只持有引用及少量协调字段。迁移前列出所有读取、写入、测试、存档和 `.tres` 依赖；**不能保留两份可写权威状态**。

## 3. 事务规则：只在 commit 写状态

一次有效游戏行为统一：

```text
Command → Validate → Plan（各 System）→ ActionResult → Commit（各所有者）→ Notify/UI
```

- `plan_*` 只读权威 State、填充本次 `ActionResult`；允许调用其他领域的 `plan_*` 或规划它们的结果字段。
- `commit` 只修改本领域**拥有**的状态，不重新计算条件、不重新抽随机数、不触发隐式二次发奖。
- `RuleResolver` 汇集一份完整结果，检查全部合法性后按显式顺序提交；`TurnManager` 专注回合生命期。失败时 AP、卡牌、装备次数、状态、奖励、RNG 都不能产生部分变化。
- Signal/动画只通知与表现，不执行规则；UI 不得直接 `state.hp -= 1`。

```gdscript
# Objective 完成可同时规划多领域后果，但不能直接修改它们的 State。
static func _plan_completion(
        result: ActionResult,
        definition: ObjectiveData,
        floor: FloorState
) -> void:
    # 这里的 objective.resolved 已由当前目标类型的规划阶段确定。
    result.player.supply_delta += definition.completion_supply
    if definition.completion_insight != null:
        InsightSystem.plan_confirmation(result, definition.completion_insight, floor)
    # 卡牌奖励机会仍由 CardRewardSystem.plan 统一汇总，防止重复产生。
```

上例为**组织方式**，不是可直接粘贴替代仓库函数的签名。`ObjectiveSystem.commit` 只能落地 Objective 自己的变化；玩家 Supply 的落地要通过实际负责玩家字段的唯一提交路径。一个 Result 变化只有一个提交者。

### 3.1 分域 ActionResult

- 沿用项目**已完成的分组**：如 `result.objective / player / entity / floor / equipment / deck / flow`。不要继续给顶层 `ActionResult` 增加几十个松散字段。
- 按“变化归谁”分，不按“谁触发”分。Objective 发放玩家资源 ≠ 在 ObjectiveResult 记录 Supply；Entity 掉牌 ≠ EntitySystem 直接修改 Deck。
- `flow` 仅负责 Run 阶段与待办机会（pending rewards、安全点、地图选择、结局），不能容纳所有未知字段。实际卡牌新增/移除归 Deck，Threat 归 Floor。
- 每个字段尽量有单一含义、单一单位、约定的空值；用明确类型，避免大量 `Dictionary` 魔法键和含混布尔标志。
- Result 只是一次动作的计划，不能持久保存作另一个 State；局内事实日志也不应充当权威状态。

### 3.2 规则与数据

- 优先复用标签/条件/修正/状态转移；具体“猎犬听到噪音”“笑魇受到光照”应由内容定义表达，而非散落的具名 ID 判断。
- **实体环境反应必须读取实际生效的条件**。不要扩展 `entity_light_exposed / entity_noise_exposed / ...` 式专用布尔堆；选用已有条件组件或小型 ReactionData。
- 一张 CardData 只有一个主动作语义；情境数值修正和合法目标选择允许，菜单里切换另一种动词不允许。
- Event = 临时环境修正/倒计时/机会，不持有 Objective 的 Explore 进度。Objective 才持有 PROGRESS/CONDITION/SEQUENCE 的推进状态。Entity 以公共 HP/State/Intent/Trigger 模型运行。
- 严禁伪造“成功但无效果”的出牌、单一具名对象钥匙牌、旧独立 Search/Loot/Light/CutOut 游戏按钮。

## 4. 注释规范（重点）

**目的不是增加注释行数，而是让维护者知道字段含义、归属和代码为什么这样做。** 对定义字段较多的 `Data / Instance / State / ActionResult` 尤其严格：

- **字段组注释**：按“身份 / 策划配置 / 阶段状态 / 奖励 / 运行标记”等分组，组前解释作用。
- **复杂字段逐项注释**：说明业务语义、数值单位/上限、作用范围（单次动作/本层/整局）、默认值或特殊哨兵值（如 `-1` 表示本次不更新）。只凭名字读不懂就必须加注释。
- **字段名字应有区分**：`progress_threshold`（目标总量）与 `progress`（当前量），`supply_delta`（本次差量）与 `supply`（当前库存）；不使用两个近义字段保存同一事实。
- **类顶端**用 1–3 行解释它负责的领域与权威状态；**对外/关键函数**说明何时调用、读什么、计划/提交什么、特别不变量。
- **关键顺序和例外**要说明 *why*：失败不能扣电、先完成实体再处理后续生成、首次 Insight 只能奖励一次、弃置临时离层牌仍要保障可重抽等。
- 不机械注释 `i += 1`、“循环遍历数组”等显然代码；旧注释随代码一起更新，禁止说法相反。
- 中文注释优先；Godot Inspector 的 `@export` 字段说明应写得能给策划/维护者看。

推荐样式：

```gdscript
class_name ObjectiveInstance
extends RefCounted
## 一次楼层访问中单个 Objective 的运行时状态；不保存策划阈值。

# 身份：关联静态 ObjectiveData 的稳定 ID，不作为同次访问的唯一实例身份。
var objective_id: StringName

# PROGRESS：本实例已推进的量，范围 [0, ObjectiveData.progress_threshold]。
var progress: int = 0

# CONDITION：已达成的条件/动作 ID；不得重复计算同一条件。
var completed_interactions: Array[StringName] = []

# SEQUENCE：下一步需要匹配的序列下标，从 0 开始。
var sequence_index: int = 0

# 公共生命周期：本次出现是否已经解决；完成奖励只允许规划一次。
var resolved: bool = false
```

```gdscript
class_name ObjectiveActionResult
extends RefCounted
## 单次动作针对 Objective 的计划修改；commit 前不能改 ObjectiveInstance。

# -1 表示本次动作不改变 PROGRESS；0 表示计划设为零。
var progress_after: int = -1

# 本次第一次达成的 CONDITION；空 ID 表示无新增条件。
var completed_condition: StringName

# SEQUENCE 在本次动作之后的位置；-1 表示未推进。
var sequence_after: int = -1
```

## 5. 类型、Godot 与可维护性

- 优先显式类型和 `StringName` 稳定 ID，重要引用做 null/访问期/实例身份校验；失效目标不能被自动重定向。
- `Resource` 共享，禁止在 `.tres` 定义对象上修改单局 HP、电量、进度、次数；运行状态存 `RefCounted` State/Instance。
- 不让领域层找场景树路径，也不通过 UI 的 Node 引用传递规则；Autoload 仅用于真正的应用级服务。
- RNG 集中管理，失败不推进；视效随机与玩法随机分离。
- 复杂分支用具名私有函数、early return；不写带多个无意义 boolean 位置参数的巨大接口。
- 性能优先保证正确与可读，回合制逻辑避免每帧 `_process()` 轮询规则。

## 6. 修改协议与验收

AI 每次写代码前必须：**读当前相关脚本与 Resources → 列出影响范围/真实字段 → 说明最小修改步骤 → 在开始前指出与文档冲突的未决设计**。不得自行把“目标设计”视为已实现功能，也不得利用顺便重构扩大范围。

改完需说明：修改文件、行为变化、验证命令/输出、未完成项目。至少覆盖成功、非法、边界三个场景；对状态迁移或 Result 重构，检查所有引用、`.tres`、测试夹具、异常流程与失败无部分写入。

**验收底线**：项目可导入且无解析错误；测试与完整 demo 主循环无回归；不同来源牌不混入永久牌堆；奖励/Insight 不重复；种子可复现；旧 UI 按钮没有旁路；视图验收必须实际打开窗口，不得拿 headless 结果冒充截图。

> 不得只因“编译通过”就声称玩法完整，也不得为了让老测试通过悄悄恢复被废弃的系统。历史变更记录请查 `MIGRATION_PLAN.md`，但历史记录不覆盖本规范。
