# 后室：切出 Demo

> **迁移状态：CARD-FIRST V2 已成为权威设计，玩法代码尚未迁移。**
> 下文描述 Phase 1–8 旧构建，保留用于复现与回归；其中独立检查、搜刮、装备、
> 地标、开关灯和切出按钮已被新方向废弃，不是后续实现规范。
> 当前设计见 [GDD.md](docs/GDD.md)，迁移分类见 [MIGRATION_PLAN.md](docs/MIGRATION_PLAN.md)。

Godot 4.x、Compatibility、类型化 GDScript。打开 `project.godot`，按 F5 运行。
当前实现 Phase 1–8：零层探索与有限搜刮 → 切出 → 六层猎犬／笑魇遭遇 → 再次切出到测试终点。
三格携带装备在本局中持续保留，独立于抽弃牌循环；没有独立战斗场景或第二套战斗 AP。

## 权威文档

遵循 AGENTS.md、docs/ARCHITECTURE.md、docs/CODING_RULES.md 与新建的 docs/GDD.md。
`docs/Backrooms_Card_Roguelike_GDD_v0.4_Demo_Baseline.docx` 仅保留为历史设计资料，
不再是当前规则源。当前用户任务优先；下文数值、卡组、按钮流程和测试结果是旧原型说明。
本轮仅更新文档，没有实现 BoardState、Explore 进度或世界卡牌界面。

## 状态与结算

新局：生命 30、压力 0、补给 0、威胁 0、认知 0、回合 1、AP 3。
TurnManager 持有唯一 RunState，当前 FloorState 保存楼层威胁、认知、事件、
资源节点、切出准备、实体实例和临时格挡。RunState 的 Threat/Cognition 读取
仅转发楼层值，不另存副本；HP、压力、补给、DeckState 和三格装备随 Run 保留。

```text
UI -> TurnManager -> PlayCardCommand / ExplorationCommand / UseEquipmentCommand
   -> RuleResolver 完整验证、计算 ActionResult
   -> AP / 牌区 / 楼层 / 实体 / 装备统一提交 -> 通知 -> UI 读取刷新
```

重要动作没有信号驱动的隐式规则。失败命令不改变牌区、AP、事件、资源、
实体、装备次数或 RNG。共享 Data Resources 保存定义，楼层实例随访问创建，
装备实例随 Run 保留；临时照明属于当前 FloorState。

## 统一卡牌与回合

主场景使用 `data/cards/demo_deck.tres` 的十张临时牌：观察 ×2、挣扎 ×1、
深入搜索 ×1、等待 ×1、攻击 ×2、防御 ×2、奔跑 ×1。
初始五张仍为观察、挣扎、观察、深入搜索、等待；下一批为攻击、防御、奔跑、
攻击、防御。原九张 `starter_deck.tres` 保留为早期回归夹具与管理器默认定义。
这是一个跨楼层使用的牌组，不存在切进战斗后替换手牌的逻辑。

- 观察：基础 1 AP，读取事件条件确认唯一 Insight，不自动增加认知。
- 深入搜索：2 AP，威胁 +1，强化调查并定位、直接搜刮一个未发现节点。
- 攻击：1 AP，实际伤害 4，要求当前存在活跃实体。
- 防御：1 AP，本回合格挡 +4，可叠加；意图执行后未使用的部分也消失。
- 奔跑：1 AP，威胁 +1；使当前活跃猎犬追击，若猎犬踉跄则成功脱离；不对笑魇套用追击状态。
- 挣扎：1 AP，有实体目标时应用已有的 2 伤害；零层无目标时保留旧占位结果。
- 等待：0 AP，无额外效果，可在零 AP 时打出。

每张卡必须在手牌中，成功后进入弃牌堆。每次 End Turn 先经过原解析器结算
楼层滞留与实体已公示意图，再弃掉剩余手牌、推进原回合计数、恢复 3 AP、
抽至 5 张。抽牌堆耗尽时用本局 RNG 洗弃牌堆；默认种子为 1。
实体存在、攻击、受击或防御都不会产生另一套 AP、手牌或回合循环。
HP 到 0 时立即停止回合推进和所有玩家命令，不恢复 AP；尚无正式结算界面。

## 事件、资源与切出

零层保留三个 Fresh Events。事件实例从未调查到调查中，再到已解决；
未完成事件跨回合保留，已解决事件只在下次回合开始推进。
检查环境和搜索附近是各事件限一次的场景交互，各耗 1 AP，不进入牌区。
基础线索可由观察验证，深入搜索也是独立的确认路径；同一 Insight 只奖励一次。
Cognition 上限 5，Threat 上限 10；第 3、5、7……楼层回合末滞留威胁 +1。

零层有三个有限节点：补给储物柜（2 补给）、隐藏电池缓存（2 补给）、
材料箱（1 补给）。电池／材料暂统一折算补给，不会给携带装备补充电量或耐久。
节点状态为 UNDISCOVERED → DISCOVERED → LOOTED → DEPLETED。
搜索附近定位表层节点，已定位节点花 1 AP 搜刮；深入搜索优先处理隐藏节点。
已搜刮和枯竭均禁止再次领奖，回合末只改变标记，不刷新资源。

CutOutState 随本次楼层访问创建，保存稳定度、目的地认知与候选 ID。
唯一 Insight 可按定义改善准备；或花 1 AP + 1 补给，使稳定度与目的地认知各 +1。
上限分别为 3 和 2，完全准备后不再消耗补给。

| 切出方式 | AP | 原型规则 |
| --- | --- | --- |
| 准备充分后切出 | 1 | 稳定度至少 2、目的地认知至少 1，必定成功，无额外压力 |
| 仓促切出 | 1 | 成功率 55% + 稳定度×10% + 目的地认知×5%，最高 90%；压力 +1，失败另加威胁 1 |
| 强行切出 | 0 | 不要求事件、资源、Insight、准备或击败实体，必定成功，压力 +2 |

合法的仓促失败是一次完整命令提交（ActionResult.success=true），但
cutout_attempt.succeeded=false，保留当前楼层及再次尝试能力。
尝试记录由 RunState.last_cutout_attempt 保存，不依赖 UI。
随机尝试先用本局 RNG 副本规划，完整提交时才推进权威 RNG。

生产流程由 FloorData 配置：零层 → 活跃六层 → 无玩法的测试切出终点。
新楼层事件和实例在私有计划对象上初始化，成功提交才切换权威 FloorState；
同步对应 FloorData 后才发送通知。整个过渡不更换 TurnManager、RunState、
DeckState、手牌，不恢复 AP，也不偷偷执行一次实体意图。
资源耗尽、事件缺失、低生命或零 AP 不会阻断存活玩家的强行退出。
这仅是 Demo 路径，不是完整楼层网络。

## 六层与实体

六层包含三个 Fresh Events 提供的两个唯一 Insight，新增避光规则 Insight 共三个，
以及 darkness 楼层旗标。
未照明时，每回合第一张成功打出的观察额外耗 1 AP；失败不消耗该标记，
原有 End Turn 清除它。检查只给表层信息。UI 与解析器共用费用查询，
因此实际费用为 2 时卡牌按钮也显示 2。手电筒开启后，本回合观察只花基础 1 AP，
并可经事件数据中的 requires_light 路径直接验证当前事件的既有 Insight。
重复 Insight 不再奖励认知或切出准备；结束回合清除临时照明。

FloorData.entry_entity 配置遭遇，FloorState 每次创建独立 EntityInstance。
EntityData 保存 ID、名字、初始状态、最大生命、伤害参数、行为类型与规则 Insight；
当前 HP、状态、意图与是否经历过光照反应属于实例。alive/active 从 HP、脱离／退去
状态派生，不保存重复布尔值。18 HP 猎犬仍使用原确定性状态机：

| 状态 | 当前公示意图／回合末行为 |
| --- | --- |
| WATCHING / 凝视 | 靠近，不造成伤害，转为 APPROACHING |
| APPROACHING / 靠近 | 撕咬 4，随后追击 |
| CHASING / 追击 | 扑咬 5，继续追击 |
| STAGGERED / 踉跄 | 重新观察，恢复为 WATCHING |
| DEFEATED / 已击败 | HP 0，死亡、非活跃，无后续意图 |
| DISENGAGED / 已脱离 | 仍存活但非活跃，无后续攻击 |

攻击凝视中的猎犬会使其靠近；奔跑一般使其直接追击。
完整格挡一次猎犬攻击会令其踉跄，部分格挡只减少伤害。
踉跄时奔跑可以脱离。当前只有奔跑作为显式的风险追击触发，不做复杂噪音 AI。
HP 不会低于 0，重复攻击已击败／已脱离实体会被拒绝，不重复结算击败。

UI 的“实体意图”页签显示中文生命、状态、意图和格挡，进入六层时自动选中；
可以随时切回探索或资源与切出，不暂停任何领域规则。
敌方动作只在现有 End Turn 中通过 EntitySystem 规划并由 RuleResolver 提交。
没有实体场景脚本、战斗场景切换、动画 AI、独立战斗时钟或复杂状态系统。

## 携带装备（Phase 7）

主场景开局携带以下三件装备，每件占一格。EquipmentData 只保存静态定义，
EquipmentInstance.remaining_uses 保存本局电量／耐久／次数，EquipmentSystem
负责装备验证、效果规划和提交；RuleResolver 统一验证并提交 AP 与效果。
任何失败均不扣 AP 或次数。卡牌描述行动方式，装备描述实际携带物；装备使用
不要求抽到装备卡，也不会进入抽牌堆、手牌或弃牌堆。

| 装备 | 初始次数 | AP | 原型效果 |
| --- | --- | --- | --- |
| 手电筒 | 电量 3 | 1 | 黑暗楼层内开启本回合照明，重复开启被拒绝 |
| 撬棍 | 耐久 3 | 1 | 对活跃实体造成 4 伤害，共用卡牌的伤害规划入口 |
| 杏仁水 | 次数 1 | 1 | 压力降低 2；使用前压力至少 7 时额外恢复 1 HP，上限 30 |

手电筒和撬棍采用本阶段要求的 3 次，覆盖 GDD 原型的 4／5 次。
杏仁水依本阶段要求作为携带消耗品，恢复方向沿用 GDD 的压力恢复规则；
没有可恢复效果时拒绝消耗。不更改原有十张牌组。

耗尽装备仍占槽；当前不提供拾取、丢弃、更换、充电或维修。跨层保留同一装备实例，
不会刷新次数，临时照明不跨层。装备 tags 留作后续条件匹配的数据入口，尚未实现组合。
UI 的“携带装备”页签固定显示三格、名字、计数与按钮，只读取状态并转发槽位命令。

## 笑魇规则遭遇（Phase 8）

六层保留猎犬入场流程。猎犬被击败或成功脱离后，在“实体意图”页签花 1 AP
追查远处异常，进入一次可选笑魇遭遇。FloorData.followup_entity 配置后续定义，
仍只有一个当前实体；已经活跃的猎犬不能被覆盖，笑魇结束后不能重复生成。
遭遇不更换 RunState、FloorState、TurnManager、手牌或装备，不恢复 AP。

EntityData.behavior_type 选择 PURSUIT 或 LIGHT_REACTIVE 两个小型规则模型，
EntitySystem 统一规划与提交，代码不按 entity_smiler ID 分支。
笑魇使用同一个 EntityInstance，120 HP，可受普通卡牌／撬棍伤害，HP 0 仍为 DEFEATED。
高 HP 只是原型锚点，正常目标是理解光照规则并让它存活退去。

| 状态 | 原型行为／可见意图 |
| --- | --- |
| HIDDEN / 潜藏 | 不开灯，回合末直接退去；没有验证规律则不奖励 Insight |
| OBSERVING / 观察 | 第一次开灯进入；暂不攻击，再次开灯会躁动 |
| AGITATED / 躁动 | 第二次开灯进入并因反复强光增加 1 Threat；若回合末仍有光，准备进攻 |
| ATTACKING / 进攻 | 第三次开灯或被主动攻击进入；回合末仍有光时攻击 6，可正常格挡 |
| WITHDRAWN / 已退去 | 无光回合末进入；仍有 HP，非活跃，不再攻击 |

普通原型手电视为强光。成功开启才触发实体反应，重复开启已亮光源等失败动作
不消耗电量、不改变状态。手动熄灯后同一回合再开也会升级；第二次及后续开灯
每次 Threat +1，仍遵守楼层 10 上限，并记录 repeated_strong_light 原因。
第一次亮灯的回合末不造成伤害；第二次会给出进攻意图，后续才执行条件攻击。

“关闭光源”是现有 ExplorationCommand 的零 AP 命令，不额外消耗电量，
所以零 AP 也能纠正行为。必须在仍存活时熄灯，再结束回合；意图规划先检查
实际光照，之后统一提交才清除本回合光源。也可以直接停用手电一个完整回合。
格挡仍有效，但笑魇不会因为完整格挡变成猎犬的 STAGGERED。

经历过光照反应，再观察到无光退去，会确认 insight_level6_light_attracts：
认知 +1、切出稳定度 +1。只攻击后退去不能假装验证光照规律；击杀本身不奖励此 Insight。
另一条路径是花 1 AP 查阅楼层地标的避光警示，不依赖事件、实体是否存活或剩余电量。
两条路径共用 InsightSystem.plan_confirmation 与原楼层唯一 ID 记录，互相不能重复领奖。
新 Insight 不改变原有两个事件 Insight，也不是离层门槛，强行切出始终保留。

## 验证

从项目目录运行，将 godot 替换为本机 Godot 控制台路径：

```powershell
godot --headless --path . --editor --quit
godot --headless --path . --script res://tests/phase_1_validation.gd
godot --headless --path . --script res://tests/phase_2_validation.gd
godot --headless --path . --script res://tests/phase_3_validation.gd
godot --headless --path . --script res://tests/phase_4_validation.gd
godot --headless --path . --script res://tests/phase_5_validation.gd
godot --headless --path . --script res://tests/phase_6_validation.gd
godot --headless --path . --script res://tests/phase_7_validation.gd
godot --headless --path . --script res://tests/phase_8_validation.gd
godot --headless --path . --quit-after 3
git diff --check
```

同时检查退出码、PASS 结果及 SCRIPT ERROR 日志；GDScript 运行时错误可能不会
自动使脚本进程返回非零，不能只看退出码。当前环境仍有系统证书存储读取错误。

Phase 1–3 保留初始值、AP／抽弃洗、实例守恒、RNG、事务失败和 UI 结果断言。
Phase 2 UI 计数迁移到主场景十张牌组；Phase 3 快照新增 effect_value。
Phase 4 UI 使用原九张探索牌夹具，保留原探索路径，继续检查所有中文 UI 文本。
Phase 5 域测试保留可配置占位终点夹具，其真实主场景测试更新为进入活跃六层。
Phase 6 覆盖初始遭遇、意图、伤害／防御、击败去重、脱离、黑暗费用、三事件两
Insight、失败不写入、死亡停止回合、威胁与切出共存、跨层状态身份和中文意图 UI。
另以默认种子、实际主场景十张牌组执行攻击／防御，验证可存活击败猎犬并继续切出。
Phase 7 覆盖三格容量、定义与实例隔离、成功扣次数、失败完整快照不变、耗尽／损坏、
杏仁水条件恢复与一次性消耗、照明费用与 Insight 去重、装备不入牌区、跨层身份保留，
以及真实主场景的三格中文 UI、按钮命令和空槽布局。
Phase 8 覆盖通用 HP、照明跨回合升级、熄灯纠正、不照明规避、有限电量耗尽、
唯一 Insight 两条路径与上限、伤害／格挡、技术击杀、坏定义／失败事务、
猎犬击败和脱离后的可选遭遇，以及实际主场景十张牌组的完整按钮流程。

## 手动验证

1. F5 启动，打开“携带装备”：三格依次为手电筒 3/3、撬棍 3/3、杏仁水 1/1。
   初始五张手牌与原十张牌组不变。零层使用手电筒或撬棍会被拒绝，AP／次数不变。
2. 在“资源与切出”强行切出到六层：压力 2、AP 3、装备实例与次数保留，猎犬 18 HP。
3. 开启手电筒：AP 2、电量 2。探索页显示本回合已照明，观察按钮费用 1。
   打出观察：AP 1、确认当前事件的唯一 Insight；装备没有进入任何牌区。
4. 使用撬棍：猎犬 18 → 14、AP 0、耐久 2。再次点击应提示 AP 不足，耐久仍为 2。
5. 结束回合：沿用原猎犬意图与抽弃牌循环，AP 恢复 3；照明结束，电量和耐久不会恢复。
6. 饮用杏仁水：压力 2 → 0、AP 2、次数 0，按钮显示已耗尽；不能再饮用。
7. 继续攻击／防御／奔跑或强行切出到测试终点，确认装备次数保留。
   高压力恢复 HP、容量超限及全部失败边界由确定性脚本另行验证。

### Phase 8 手动验证

1. F5 从零层进入六层。保留至少 1 次手电电量，用原攻击／防御牌击败猎犬，
   或完整格挡后奔跑脱离。确认“追查远处异常：笑魇”按钮启用。
2. 结束回合补足 3 AP，点追查：消耗 1 AP，出现 120/120 HP 的潜藏笑魇。
   也可以直接不照明结束回合，验证无伤规避；此时没有自动 Insight。
3. 验证光照路径：在潜藏时使用手电，状态为观察；点“关闭光源”，再结束回合。
   确认笑魇 120/120、已退去；认知与切出稳定度各加 1。
4. 尝试“查阅墙上避光警示”，应已禁用且不能重复奖励。另开一局先查阅警示，
   无需遭遇或使用电量也能确认同一 Insight；后续实体退去不重复奖励。
5. 另开一局保留三次电量：遭遇后连续各回合开灯，依次观察 → 躁动 → 进攻。
   第三次亮灯结束回合预计受到 6 伤害，防御可减伤；也可在进攻前零 AP 熄灯避免攻击。
6. 装备耗尽后，不再开灯的回合仍能使笑魇退去。任意存活阶段也可强行切出，
   确认沿用原牌组、AP、Threat、装备和切出流程。

## 已知限制

没有实现 Phase 9、多敌人、Boss、复杂状态、正式胜负结算或元进度。
装备只有三件，无维修、制作、升级、稀有度、双槽装备或复杂卡牌组合。
没有新增插件或依赖，渲染器保持 Compatibility；照明仅为本回合玩法状态，暂无视觉光照。
六层仅三个 Insight，认知最多 3；Fresh 耗尽后没有 Residual Events。
笑魇采用明确的可选后续遭遇，不实现完整实体刷新池、危险阈值随机生成、弱光／红光分类。
压力尚不执行精神崩溃后果。参数仍为原型，尚未做图形窗口人工目视验收。

## Phase 8 变更文件清单

以下为本次 Phase 8 增量；未修改 Phase 1–7 测试或项目配置。

### 新增

- `data/entities/entity_smiler.tres`
- `data/insights/insight_level6_light_attracts.tres`
- `tests/phase_8_validation.gd`
- `tests/phase_8_validation.gd.uid`

### 修改

- `Readme.md`
- `data/floors/floor_level_6.tres`
- `scenes/main/Main.tscn`
- `scripts/cutout/cutout_system.gd`
- `scripts/entities/entity_data.gd`
- `scripts/entities/entity_instance.gd`
- `scripts/entities/entity_system.gd`
- `scripts/equipment/equipment_system.gd`
- `scripts/floors/floor_data.gd`
- `scripts/floors/insight_system.gd`
- `scripts/rules/action_result.gd`
- `scripts/rules/rule_resolver.gd`
- `scripts/ui/main.gd`

### 删除

无。
