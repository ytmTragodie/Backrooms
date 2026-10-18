# 后室：切出 Demo

当前主场景已完成 **REWORK A：零层探索核心 + REWORK B：局势与猎犬混合遭遇**。
打开 project.godot，按 F5：上方状态、中央局势世界牌、下方五张玩家手牌。
同一个 RunState、TurnManager、3 AP、抽弃洗牌循环继续工作。未启动 REWORK C。

## REWORK B：混合遭遇与手动验证

F5 后点击「新局：六层混合原型」，在同一个 Main 场景开始一局六层测试。
这是新的 Run，不是零层切出或战斗模式切换；「新局：零层调查」可重开 REWORK A。

- BoardState 持有唯一 EventInstance 和 EntityInstance；右侧实体牌直接展示猎犬的生命、状态、
  意图与已揭示规律，不建 WorldCard 状态副本。猎犬保持 18 HP、4／5 伤害及原状态机。
- 左侧异常走廊 9 调查完成、4 调查揭示线索；未推进的回合造成 2 环境伤害，可由防御抵挡。
- 十张混合牌组：4 调查、3 攻击、2 防御、1 奔跑，仍从同一 DeckState 抽五张；无战斗牌组切换。
- 点击左／右世界牌选目标不消耗行动。调查牌可推进局势或实体知识；攻击／奔跑要求实体目标。
  防御作用于玩家，不以世界牌为目标。旧引用、同 ID 的其他实例、跨访问或失活目标全部失败且不消耗。
- 实体调查 4 时揭示噪音与踉跄脱离规律，确认唯一 Insight。局势完成也可确认同一个 Insight，
  两条路线合计认知只增加一次。已完全调查的实体不能继续接收调查，调查从不等同伤害。
- 成功深搜的 NOISE 会立即使猎犬追逐，公布扑击意图；失败出牌不会触发反应。奔跑保留原型风险：
  踉跄时脱离，否则追逐，威胁 +1。击败／脱离猎犬不会停止局势调查或 Pressure。
- 六层黑暗仍使每回合首次 OBSERVE 多花 1 AP（按标签，不按牌名或旧按钮动作名）。

可复现第一回合：

1. 新局后同桌显示异常走廊 0/9 与猎犬 18/18，五张手牌，3 AP。
2. 选择走廊，打搜索：1 AP、调查 +3、威胁 +1。
3. 选择猎犬，打攻击：1 AP、HP 18 → 14，意图变为撕咬。
4. 打防御：1 AP、Guard +4。结束回合：走廊已推进免伤，4 Guard 完全挡下撕咬，猎犬踉跄。
5. 后续继续选世界牌出牌。深搜可快速推进走廊，但噪音会改为追逐；足够格挡可再次令猎犬踉跄，
   随后抽到奔跑可脱离；也可持续攻击至 HP 0。局势和实体各自解决，另一个仍继续运作。
6. 另开一局直接结束回合：环境伤害 2、猎犬靠近；再结束回合会同时受到环境伤害 2 和撕咬 4。
7. 另开一局选择猎犬打观察，确认只增加规律调查且首次花 2 AP；下次观察达到 4，揭示规律并确认认知。

回合末固定顺序：局势 Pressure → 猎犬已公示意图 → 楼层滞留 Threat → 清除 Guard／临时光照／
黑暗首次观察标记 → 存活时弃手牌、推进唯一回合并恢复 3 AP、补 Fresh、抽至五张 → 通知界面。
Pressure 优先消耗 Guard，实体只用余额；4 Guard 对环境 2 + 撕咬 4 总共抵挡 4，仍受 2 伤害。
Pressure 致命时跳过实体意图，仍结束本回合后果／清理，不抽牌或开启下一回合。

暂未批准换牌的具体规则，本轮用卡组比例保证任意完整五张手牌在仍有局势／实体需求时有相应行动，
这不是最终平衡或剩余少量手牌永不卡费的保证。无目标的攻击不会伪造调查或成功 no-op。

## 权威文档与实际文件名

遵循 Agents.md 和用户更新后的四份 V2.1 文档：

- [GDD](docs/GDD_CARD_FIRST_V2_1.md)
- [Architecture](docs/ARCHITECTURE_CARD_FIRST_V2_1.md)
- [Coding Rules](docs/CODING_RULES_CARD_FIRST_V2_1.md)
- [Migration Plan](docs/MIGRATION_PLAN_CARD_FIRST_V2_1.md)

本仓库当前四份文档带版本后缀，未擅自改名或补入另一份权威文本。
其中笑魇、装备、资源、切出仍未迁移，不能据此宣称全部 v2 已完成。

## REWORK A：实际玩法与原型选择

- BoardState 持有唯一 active_event。FloorState.current_event 是只读转发；UI 不保存进度副本。
- 玩家牌与 Event 世界牌仍是不同的领域类型；Event 从不进入玩家牌区。
- 主场景使用 exploration_deck.tres：十张观察／搜索／深入搜索，开局抽五张。
- 观察：1 AP、2 Explore、OBSERVE。搜索：1 AP、3 Explore、Threat +1、SEARCH。
- 深入搜索：2 AP、5 Explore、Threat +1、SEARCH/NOISE；不会暗中调用旧资源搜刮逻辑。
- 三张零层局势均为 6 调查完成、3 调查揭示线索；异常嗡鸣对 OBSERVE 额外 +1。
- 未解局势本回合完全未推进时，结束回合压力 +1；推进过则免于该局势压力。
  此后果与既有楼层滞留／实体意图在同一个解析结果内规划，不另建事件回合。
- 进度和线索跨回合保留。解决后留在桌面显示结果，结束回合恢复 3 AP、抽至五张时补入下一张。
- 溢出调查只截到当前阈值，不转移到下一事件；里程碑与唯一 Insight 只领奖一次。
- 点击世界牌只选择／查看，不能执行玩法；零层旧 inspect/search_nearby/observe/deep_search
  等独立探索命令返回 card_required，直接绕过 UI 调用也不会扣 AP 或推进调查。
- 目标同时携带事件实例与 Board 引用；缺少、过期、其他访问或已解决目标不消耗牌、AP、风险或 RNG。
- 手电／撬棍／杏仁水依旧开局装入 RunState；本界面没有它们的主动按钮，也没有制作／升级／奖励。

所有玩家文字为简体中文；Explore、OBSERVE 等英文只用于数据和技术日志。
新效果以 CardData.explore_amount/threat_cost/tags 表达；旧效果枚举与 exploration_action
留给未迁移兼容路径，REWORK A 的结算结果是实际 explore，不是成功占位 no-op。

## REWORK A：手动验证

1. F5：生命 30、压力 0、威胁 0、认知 0、行动点 3、回合 1；中央为异常嗡鸣 0/6，手牌五张。
2. 点击中央世界牌：只有选择提示，AP、牌区、调查进度均不变。
3. 打出第一张观察：花 1 AP，调查 0 → 3，揭示线索；认知仍为 0。
4. 打出搜索：再花 1 AP，调查 3 → 6，威胁 +1、认知 +1，显示已解决。
   其余手牌不能继续调查这个已解决目标；不会通过移牌伪造成功。
5. 结束回合：同一局恢复 3 AP、抽至五张，下一张局势从 0/6 开始；旧已解局势不再施加压力。
6. 不打牌直接结束回合：压力 +1，当前局势不换；再调查一次并结束回合，进度保留且当回合免于压力。
7. 对无 OBSERVE 加成的局势打观察，只增加 2；深入搜索增加 5、花 2 AP、威胁 +1。
8. 用同一副牌解决三张局势，确认各出现一次、认知最终 3、牌组总数始终 10。
   Fresh 耗尽后明确显示本次调查结束；没有伪造 Residual、无限奖励或自动离层。

## 验证命令与覆盖

从项目目录执行，将 godot 换成本机控制台路径：

```powershell
godot --headless --path . --editor --quit
godot --headless --path . --script res://tests/rework_a_validation.gd
godot --headless --path . --script res://tests/rework_b_validation.gd
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

REWORK B 另覆盖混合共存、共享费用／牌区／回合、环境与意图同回合结算、Guard 消耗顺序、
实体调查与双路线唯一 Insight、噪音、击败／踉跄脱离、过期／移除目标失败快照、旧主动命令拒绝、
所有完整五张手牌组合、真实主屏幕存活完成双需求、中文与布局。
REWORK A 检查覆盖实例所有权、基础与标签调查、卡牌风险、跨回合进度与压力、同回合压力去重、
跨越两阈值、唯一 Insight 与上限、Fresh 条件／耗尽、过期／跨访问目标、坏数据与失败快照、
完整提交后的通知、旧 API 拒绝、真实 UI 按钮完整流程、中文和视口布局。
Phase 1–3 的状态、费用、守恒、RNG、失败事务与通知顺序覆盖继续保留；UI 断言适配新主屏幕。
零 AP Wait 和占位伤害只留在早期无楼层夹具，不是新探索牌组内容。
检查日志中的 SCRIPT ERROR 与泄漏，不能只看退出码；本环境仍有系统证书存储读取错误。

## 保留的旧路径与限制

旧 Main 场景／UI 移为 scenes/main/LegacyMain.tscn 与 scripts/ui/legacy_main.gd，
使用 floor_level_0_legacy.tres 和 floor_level_6_legacy.tres（关闭调查规则）。它不在新主屏幕提供入口，
仅用于 Phase 4–8 回归与独立打开的历史验证；原规则断言没有削弱。

旧实体、装备、切出、资源领域系统和直接命令仍保留。原项目的固定 starter_deck／demo_deck
未改内容；旧界面仍可验证猎犬、笑魇、物资与切出。这些路径不代表符合全套 Card-First 规范。
完整资源、装备动作牌、笑魇迁移、离层牌与最终防卡手保障都属于后续工作，本次不实施。
新零层／六层领域入口拒绝旧主动探索／装备命令，不只隐藏按钮；旧兼容夹具仍能验证历史行为。

三个零层 Fresh 局势调查完后停在有限结果；六层原型直接新局进入，尚未实现卡牌离层和连续过层。
六层只有一张原型局势、一个猎犬；无 Residual、奖励、升级或双实体。忽视压力可通过一次真实推进避免，
长期风险节奏仍待平衡。几何布局经过无窗口测试，未做图形窗口目视验收。

## Phase 1–8 历史构建说明（仅兼容场景）

> 以下保留旧原型信息与手动流程，只适用于 LegacyMain 场景，不能当作新主场景的玩法说明。

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

## REWORK A 变更文件清单

### 新增

- `data/cards/card_search.tres`
- `data/cards/exploration_deck.tres`
- `data/floors/floor_level_0_legacy.tres`
- `scenes/main/LegacyMain.tscn`
- `scripts/floors/board_state.gd`
- `scripts/floors/board_state.gd.uid`
- `scripts/ui/legacy_main.gd`
- `scripts/ui/legacy_main.gd.uid`
- `tests/rework_a_validation.gd`
- `tests/rework_a_validation.gd.uid`

### 修改

- `Readme.md`
- `data/cards/card_deep_search.tres`
- `data/cards/card_observe.tres`
- `data/events/event_level0_humming.tres`
- `data/events/event_level0_wall_marks.tres`
- `data/events/event_level0_wrong_corner.tres`
- `data/floors/floor_level_0.tres`
- `docs/MIGRATION_PLAN_CARD_FIRST_V2_1.md`
- `scenes/main/Main.tscn`
- `scripts/cards/card_data.gd`
- `scripts/events/event_data.gd`
- `scripts/events/event_instance.gd`
- `scripts/events/event_system.gd`
- `scripts/floors/floor_data.gd`
- `scripts/floors/floor_state.gd`
- `scripts/rules/action_result.gd`
- `scripts/rules/play_card_command.gd`
- `scripts/rules/rule_resolver.gd`
- `scripts/turns/turn_manager.gd`
- `scripts/ui/main.gd`
- `tests/phase_1_validation.gd`
- `tests/phase_2_validation.gd`
- `tests/phase_3_validation.gd`
- `tests/phase_4_validation.gd`
- `tests/phase_5_validation.gd`
- `tests/phase_6_validation.gd`
- `tests/phase_7_validation.gd`
- `tests/phase_8_validation.gd`

### 删除

无。旧 UI 保留为显式隔离的 LegacyMain，而非新主屏幕的并行入口。
