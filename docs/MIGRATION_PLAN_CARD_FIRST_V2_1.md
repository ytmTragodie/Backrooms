# CARD-FIRST V2.1 — Migration Plan

日期：2026-10-18。状态：**REWORK A／B／C 已实现**；Phase 5–8 的玩家输入已迁移，尚无构筑奖励或后续内容。V2.1 保留 Situation/Environment World Cards 与统一牌局。
前次文档方向任务不修改玩法；REWORK A／B／C 依据各自用户授权完成下列有限迁移，不构成后续阶段实现授权。
设计规范见 [GDD.md](GDD_CARD_FIRST_V2_1.md)，职责与状态归属见 [ARCHITECTURE.md](ARCHITECTURE_CARD_FIRST_V2_1.md)，
实现约束见 [CODING_RULES.md](CODING_RULES_CARD_FIRST_V2_1.md)。优先级遵循 AGENTS.md。

## 0. REWORK A 已实现范围与选择

- 主场景：状态栏、局势世界牌、五张玩家手牌、抽弃牌计数、结束回合。
- BoardState 唯一持有 active_event；FloorState.current_event 为只读兼容读取。
  现有单实体引用也经 BoardState 转发，不改实体算法、不实现双实体。
- CardData 使用 explore_amount、threat_cost、tags 输出真实 Explore；观察 2、搜索 3／风险 1、
  深搜 5／风险 1，费用 1／1／2。异常嗡鸣按 OBSERVE 标签额外 +1。
- 三张零层局势：3 调查线索、6 调查完成与唯一 Insight；已知 Insight 不重复认知或准备收益。
- 未解进度跨回合保留；同回合完全没有推进则回合末 Stress +1。
  已推进或已解决不收该压力，同一楼层回合不重复结算。
- 解决结果保留到结束回合，随后同一 TurnManager 补入下一符合条件的 Fresh；不立即跨牌转移溢出。
- PlayCardCommand 携带实际手牌、事件实例与访问内 Board 引用，旧目标／已解决目标失败不消耗。
- 新零层拒绝独立 inspect/search_nearby/observe/deep_search 等探索命令；新主屏幕没有旧主动按钮。
- Phase 1–3 的领域不变量继续回归，UI 断言迁移到新屏幕；Phase 4–8 使用明确隔离的
  LegacyMain 和 legacy 楼层配置继续验证，不修改它们的规则断言。
- 玩家初始携带物、CutOut／资源／实体领域能力保留，未进入新主屏幕的主动玩法。
- 三张 Fresh 耗尽后明确结束本次调查；没有 Residual、离层牌、完整资源／实体／装备迁移。

`card_first_exploration` 是 FloorData 的访问规则配置，不是事件／战斗模式切换；
不存在另一套 AP、手牌或时钟。Legacy 配置只是迁移期间旧内容的隔离夹具，待相应后续任务删除。
本节记录当前进度；下列旧基线与计划继续保留供逐项迁移参考，未完成项不能宣称已落地。

### 0.1 REWORK B 已实现范围与选择

- 同一个 Main 场景增加「新局：六层混合原型」系统入口，创建独立新局测试，不冒充零层切出。
  六层入场同时实例化异常走廊与猎犬；无战斗场景、战斗模式或第二份 AP／手牌／回合。
- 保留 BoardState 的单实体槽，直接持有现有 EntityInstance；实体牌只渲染 HP、状态、意图、知识。
- PlayCardCommand 增加 target_entity，与 target_event 互斥，均要求相同访问的 Board 和实际实例引用。
  Explore 可选局势或尚有知识进度的实体；Damage／Run 只选活跃实体；Guard 保护玩家、不选世界目标。
  同定义 ID 的替换实例、移除、跨访问、失活／已解目标都不能静默重定向。
- 猎犬保留 18 HP、4／5 伤害、完全格挡踉跄及奔跑脱离；成功 NOISE 行动触发追逐。
  调查实体达到 4 揭示噪音规律并确认唯一 Insight；异常走廊完成提供相同 ID 的替代路线。
- 异常走廊 4 调查揭示线索、9 调查完成；未推进时回合末造成 2 可格挡环境伤害。
  原零层 Stress Pressure 保持原值，不把所有后果统一成一种数值。
- 固定回合末提交：Situation Pressure → Entity Intent → 楼层滞留 → 清理 Guard／临时光照／观察标记。
  Pressure 先消耗 Guard，意图只能使用余额；致命 Pressure 跳过意图，清理后不进入下一回合。
  存活时由原 TurnManager 弃手牌、推进计数、恢复 3 AP、补符合条件的 Fresh、抽至五张，再通知 UI。
- 保留六层每回合首次观察黑暗加费；新路径按 OBSERVE 标签查询同一最终费用函数。
- 混合原型十张牌：4 调查／3 攻击／2 防御／1 奔跑。穷举完整五张手牌组合验证两类需求下有行动；
  本步选择卡组比例而非新增换牌机制，不宣称解决最终牌池／残余手牌费用／离层防卡手问题。
- 新楼层对所有非 End Turn 的独立探索命令及独立装备请求返回 card_required；不是只隐藏 UI。
  Smiler、装备、资源、CutOut 未卡牌化；LegacyMain 及两个 legacy 楼层资源供旧 Phase 4–8 回归。
  Phase 6–8 只迁移六层资源引用，原规则断言保留。REWORK A 测试继续运行。

这些是本次用户明确授权的有限原型选择。§7 其余未决规则仍未批准，不启动 REWORK C。

### 0.2 REWORK C 历史迁移记录

Phase 5–8 曾先迁为普通牌次级动作，随后由来源纠偏和单语义清理替代。
该菜单方案已经退役；原句／原行号见 [清理审计](CARD_INTERACTION_CLEANUP_AUDIT.md)，不作为当前实施建议。
原 RunState、TurnManager、EntitySystem、EquipmentSystem、ResourceNodeSystem、InsightSystem、CutOutSystem 保留。
LegacyMain、两个 legacy 楼层及独立探索／装备命令已删除。原子性、有限资源、唯一奖励、实体行为与成功才换层等不变量继续回归。

### 0.3 UI 纠偏记录

主屏保留状态、世界牌、手牌、抽弃牌计数、结束回合及只读装备。测试开局与原始读数进入默认隐藏 F8 面板。
曾有的右键／省略号动词菜单现已彻底删除；当前点击手牌只执行固定语义，右键没有额外玩法动作。

### 0.4 三类手牌来源

CardData/CardInstance 保留 NORMAL / EQUIPMENT / FLOOR_TEMPORARY。DeckState.hand 是唯一手牌集合，
只有 NORMAL 进入普通抽弃洗与永久牌组计数。装备物品跨层保留，生成牌引用实际实例。
五张基础目标包含 Retain 退出牌；每个全局回合最多额外生成一张装备机会，当前上限六张。
先前的准备牌与普通牌熄灯／地标／追查动作现由 §0.5 替代。

### 0.5 Card Interaction Cleanup：当前锁定规则

**Single-Semantic Card Rule：一张牌只有一个清楚的主玩法语义。**
目标选择、情境数值修正和条件奖励允许；无关动词菜单、卡牌模式、泛型行动分支选择器禁止。
不同动词必须使用不同 CardData。右键仅可查看只读详情。

| 旧动作／入口 | 当前归属 | 删除的接口／解释 |
| --- | --- | --- |
| 观察牌照明模式 | 独立装备牌照明 | 普通牌动作列表 |
| 普通牌熄灯模式 | 独立装备牌熄灯 | 普通牌动作列表 |
| discover／loot／deep_loot | 搜索／深搜推进环境并同次领取有限奖励 | 资源模式及节点选择参数 |
| encounter／追查遭遇 | 六层声明“入口实体已解决＋实际 LIGHT”自动生成笑魇 | 玩家追查命令 |
| landmark／调查地标 | 六层现有局势线索确认同 ID 光照 Insight | 手动地标命令 |
| 撬棍增强／饮用模式 | 撬棍猛击／饮用杏仁水装备牌 | 通用增强选择 |
| 准备切出 | 线索／唯一 Insight 自动提升 CutOutState | 准备牌、模板、生成器和主动准备 API |
| rushed／safe 模式 | Retain 楼层牌与原位升级 | 动作选择参数 |
| forced | 退役 | 旧资源和解释分支 |

- 删除 CardData.actions、CardActionData、CardActionSystem、旧动作 Resources；PlayCardCommand 不再接受模式、
  任意装备或资源节点参数，只携带真实卡牌、当时定义、访问 Board 和世界目标。升级／替换后的异义旧请求原子拒绝。
- 观察只调查局势／可分析实体。搜索／深搜只搜索环境：Explore 与一次有限奖励一起提交，不另发发现／领取命令。
  资源耗尽且没有活动局势时拒绝搜索；有局势时仍可正常推进。无关实体不能成为搜索目标。
- 手电 LIGHT 关时为照明，开灯后同实例原位替换熄灯；关灯后有电恢复照明，无电移除。
  不增加手牌数量或生成预算。照明 1 AP／一电量；熄灯 1 AP／不耗电，最后电量仍可熄灯。
- 撬棍 1 AP／8 伤害／NOISE／一耐久；杏仁水 1 AP／原恢复效果／一次消耗。三件物品与普通牌区分离。
- 六层 followup_on_light 是原型世界条件；活跃猎犬不被覆盖，已解决入口实体在实际 LIGHT 下自动换入笑魇。
  旧目标的 HP／状态先提交，再替换槽位，避免把猎犬致命伤写进新笑魇；状态机保持原实现。
- 六层走廊的首次线索确认与笑魇行为相同的光照 Insight；任何发现路线最多 Cognition +1 一次。
- 零层现有线索声明稳定度 +1，完成 Insight 仍提供原准备奖励。六层的线索／完成 Insight 同样自动改善准备，
  不需要消耗补给的主动准备牌。补给当前仅作为有限探索收获累计，不新增制作／修理／资源消耗系统。
- 原最低条件（稳定度正值或本层第二回合）、Retain 占位、1 AP 尝试、仓促失败保牌、安全原位升级、
  成功才移除旧访问牌、新层产生新机会全部保留。不保证零 AP 或无伤生存。
- A/B/C 和 Phase 1–8 保留领域不变量；旧“搜索不获资源”“单一走廊只给一份事实”“手动追查／地标／准备”断言退役，
  由自动收集、独立线索奖励、世界触发和纯目标选择覆盖。完整 UI 路线不使用调试开局或注入玩法状态。
- 完整验证仍为 Phase 1–8、A/B/C、UI 共 12 套，另进行导入、Main 启动、日志／退出码／泄漏检查。

## 1. 迁移前仓库审查基线（历史记录）

审查覆盖仓库已跟踪文件：Phase 1–8 脚本、数据、主场景、配置、测试、README、
AGENTS.md、架构／编码规则，以及完整 v0.4 DOCX。初始工作区干净。
原仓库没有 docs/GDD.md；这次新建的是 v2 权威 GDD，DOCX 完整保留为历史资料。

### 1.1 冲突的旧文档假设

| 来源 | 旧假设 | v2 决定 |
| --- | --- | --- |
| v0.4 §23.5、§24.3、§25.3、§31.1 | 不必抽到牌，使用独立检查／搜索／搜刮；牌只是更强交互 | DEPRECATE：主动玩法必须出玩家牌 |
| 旧 ARCHITECTURE §2.3 | use equipment、inspect、search、loot、attempt cut-out 是独立玩家命令 | ADAPT：这些保留为效果语义，经手牌命令进入 |
| v0.4 §33.2／§42 及旧架构 §4.5 | 装备不入牌组，被旧实现解释为随时可点主动使用 | 保留物品不入牌组；废弃绕过玩家牌的主动入口 |
| v0.4 §31／§41／§43 | 旧锁定参数、唯一规则源、Canonical 字样仍可能覆盖新设计 | 仅历史资料；当前 Markdown 明确承接的规则才有权威性 |
| 旧 README 与 Phase 测试 | 按钮流程、两次 Observe 旗标推进、占位效果是当前玩法合同 | 旧构建复现资料；逐项迁移，不作为 v2 设计依据 |

### 1.2 REWORK A 之前的代码事实（历史，不是当前实现）

- `scripts/cards/card_data.gd` 只有固定 EffectType、exploration_action 与 effect_value，
  没有通用 Explore、玩家牌标签或目标描述；NO_OP／PLACEHOLDER_DAMAGE 仍存在。
- `scripts/rules/rule_resolver.gd` 有出牌、直接装备、直接探索三个入口；观察／深搜按动作名
  连接事件；无事件／已解决事件可能只移牌，攻击无实体会拒绝，等待是成功无效果。
- `scripts/events/event_data.gd`、`event_action_data.gd` 与六个 `.tres` 以动作 ID、
  required_flags、granted_flags 表达调查；EventInstance 没有 Explore 进度和数值阈值。
- `scripts/floors/floor_state.gd` 保存 current_event 和单个 entity；不存在 BoardState。
- `scripts/ui/main.gd` 与 `scenes/main/Main.tscn` 直接提供检查、搜索、搜刮、准备／尝试切出、
  装备使用、后续遭遇、地标、熄灯按钮；它们虽经 RuleResolver，仍绕开手牌。
- `scripts/entities/entity_system.gd` 已有公共 HP、猎犬追击与笑魇光照状态机。
  笑魇通过独立 encounter 按钮接续猎犬；熄灯和替代地标 Insight 也依赖独立命令。
- 当前主场景十张玩家牌，三格装备，手电／撬棍 3 次、杏仁水 1 次；事件每层三个，
  没有 Residual。不要把旧 DOCX 的十二张起始牌组或“六选五”误报为当前实现。
- Phase 1–8 测试覆盖状态、抽弃洗、事务、资源、切出、实体与装备；同时也有需要废弃的按钮
  和占位行为断言。已有测试通过不等于 Card-First v2 已完成。

## 2. KEEP

保留技术边界与已经验证的领域不变量，避免因更换玩家入口重写整个项目。

| 保留项 | 当前文件／范围 | 保留理由 |
| --- | --- | --- |
| 类型化 GDScript、Compatibility、Godot 4.x、英文稳定 ID、中文 UI | 项目配置与全部领域模型 | 技术方向与本次变更无冲突 |
| 一个 RunState、3 AP、同一 TurnManager、玩家牌组与手牌 | run、turns、cards | 不引入独立战斗循环 |
| Data 与运行时实例隔离、局内 RNG | Card／Event／Entity／Equipment 的 Data 与 Instance | 防共享 Resource 状态污染、保证确定性 |
| 玩家牌的抽／手／弃唯一归属、洗牌与实例守恒 | DeckState、CardSystem | 继续是 Player Card 专属牌区 |
| 完整验证 → 计划 → 提交 → 通知 | RuleResolver、ActionResult、领域 plan/commit | 新效果和目标验证扩展此边界 |
| 有限资源、防重复领奖、楼层内 Threat／Cognition | resource_node_system、InsightSystem、FloorState | 不恢复资源、不刷认知 |
| 切出状态／尝试记录、成功才换层、Run 与装备过层保留 | CutOutSystem、RunState | 改输入而不丢失过层事务保障 |
| 公共实体 HP、状态／意图、猎犬与笑魇的不同解法 | EntityData、EntityInstance、EntitySystem | 统一技术模型不等于只能击杀 |
| 三格实体装备与有限次数 | EquipmentData／Instance／System | 物品不混入玩家牌组，成功才消耗 |
| 唯一 Insight 多路径、防软锁、死亡停止推进 | 现有领域规则与相关测试 | 新卡牌经济仍须满足这些要求 |

“KEEP”保留的是责任和不变量，不表示每个旧方法签名、牌费或测试快照永远不变。

## 3. ADAPT

| 迁移对象 | 当前文件 | 最小迁移方向 |
| --- | --- | --- |
| Player Card 定义与实例 | `scripts/cards/card_data.gd`、`card_instance.gd`、`data/cards/*.tres` | 唯一主语义、标签、合法目标／条件与数值修正；先定稿空场用途，不造巨型万能卡 |
| 探索输出 | RuleResolver、ActionResult | 引入有实际消费者的 Explore，区分基础值、修正、实际进度与奖励；不把 Explore 当 Cognition |
| 事件定义／实例／规则 | `scripts/events/*.gd`、`data/events/*.tres` | 迁移为 Situation：Objective（先用 Explore）、Pressure／回合后果、阶段阈值与一次性结果；标签修正取代固定动作名，不再是独立事件小游戏 |
| 活动世界内容所有权 | FloorState、FloorData、新的最小 BoardState | 一个 Event 槽和 0–2 Entity 的设计容量；活动实例迁移一次，不保留第二份可写列表 |
| 目标引用 | PlayCardCommand、RuleResolver、ActionResult | 当前手牌 + 世界种类 + 楼层访问内的实例键；不只按 definition ID 寻找目标 |
| 实体反应 | EntitySystem、EntityData、Hound／Smiler `.tres` | 响应实际生效的 LIGHT／NOISE 等标签，复用领域状态机；多实体顺序先定稿 |
| 装备主动效果 | EquipmentSystem、RuleResolver、EquipmentData | 由牌的声明效果调用；保留物品和次数，统一 AP 计算，缺少可选装备不使普通牌失效 |
| 资源、地标、切出准备与尝试 | ResourceNodeSystem、InsightSystem、CutOutSystem | 以牌效果触达；保留有限自动奖励和安全／仓促语义，不提前实现 Exit／Resource 世界卡类型 |
| 笑魇遭遇及替代规律发现 | EntitySystem、FloorData、InsightData | 声明式世界条件触发遭遇，照明／熄灯触发行为，替代路线仍用同一 Insight ID，无独立追查／地标按钮 |
| 牌桌展示与选目标 | `scripts/ui/main.gd`、`scenes/main/Main.tscn` | World Card 区展示 Situation 的 Objective／Pressure 与 Entity 的 HP／Intent；支持纯环境、纯实体、混合遭遇，玩家牌仍是唯一主动执行入口 |
| 测试与 README | `tests/phase_1_validation.gd` 至 `phase_8_validation.gd`、Readme | 保留不变量，迁移调用者和断言；每个退休断言记录原因和替代覆盖 |

### 3.1 各阶段测试的迁移重点

| 旧测试 | KEEP 的覆盖 | ADAPT／退休的旧假设 |
| --- | --- | --- |
| Phase 1 | 初始值、独立 Run、AP 恢复、回合信号 | UI 入口与新增牌桌归属 |
| Phase 2 | 抽弃洗、实例守恒、RNG、真实手牌命令 | 固定九／十张内容快照，World Card 不入玩家牌区的扩展覆盖 |
| Phase 3 | 事务失败、费用、通知顺序、快照检测 | 成功 NO_OP、仅占位伤害；计划需包含 Explore、目标与装备原子性 |
| Phase 4 | 条件、唯一 Insight、上限、Threat、中文显示 | 独立 inspect/search_nearby、两按钮解决事件，改为牌标签与阈值 |
| Phase 5 | 有限资源、无重复奖励、成功换层、防软锁 | 直接 loot/prepare/cutout 命令改为牌效果并验证抽牌可达性 |
| Phase 6 | HP／意图／伤害／格挡／脱离、共同回合、死亡边界 | 显式目标与缺目标时的普通牌基线，世界实体展示 |
| Phase 7 | 三槽、实例隔离、有限次数、失败不扣、跨层保留 | 直接 request_use_equipment 和常驻主动按钮，改为牌请求 |
| Phase 8 | 光照升级、存活退去、双路径 Insight 去重、猎犬回归 | 独立 encounter/extinguish_light/study_landmark，改为牌／世界规则 |

旧测试不是整体丢弃，也不能为了全部维持旧断言而长期保留第二套玩法入口。

## 4. DEPRECATE

以下从本次文档生效起不再是后续开发可依赖的设计规则；旧输入已按 §0.5 迁移，以下列为禁止恢复的旧假设。

- “没抽到牌时点击基础场景交互，卡牌只是更高效”的交互模型。
- 独立检查、搜索、搜刮、装备主动操作、开关灯、查阅地标、追查遭遇、准备与尝试切出的按钮。
- 把零 AP 熄灯／强行退出当成纯系统控制，或用常驻卡牌外观按钮绕开真实抽牌。
- 某张正常牌只有指定 Event／Entity 在场才有用途；空场成功 no-op／占位数值也视为有用。
- 世界卡牌与玩家牌堆共享实例、计数、抽弃洗逻辑，或用一个巨型 CardData 合并所有领域。
- 用 v0.4 DOCX 的“锁定／Canonical”段落或旧 README／旧测试推翻 v2 的约束。

End Turn 等纯系统控制不在废弃范围；自动实体意图与楼层规则也继续属于统一结算。

## 5. REMOVE LATER

以下是迁移前的删除条件记录；当前已删除的输入以 §0.5 为准，不授权保留兼容菜单。未使用的事件字段／派生别名可后续独立清理。

| 待退休入口／状态 | 删除前的条件 | 必须保留的能力 |
| --- | --- | --- |
| Main.tscn 的 InspectAction／SearchNearbyAction、UI 的独立 loot 按钮 | Explore／资源牌与事件阈值路径可玩 | 有限资源和替代 Insight 路径 |
| 携带栏 UseEquipment 的独立主动执行、TurnManager.request_use_equipment 的公开旁路 | 专用装备牌与统一费用、失败原子性测试通过 | 装备计数展示、EquipmentSystem 规划／提交，不必删除系统本身 |
| PrepareCutOut／SafeCutOut／RushedCutOut／ForcedCutOut 独立执行 | 卡牌准备／尝试与坏抽牌离层保障已验证 | CutOutSystem、尝试结果与成功过层边界 |
| EncounterAction／LandmarkAction／ExtinguishLight 独立执行 | 卡牌／世界规则可触发遭遇、双路径理解、可达避光应对 | Smiler 状态机、存活退去、Insight 唯一性 |
| ExplorationCommand / UseEquipmentCommand 的对玩家旁路与 UI 接线 | 所有主动效果通过真实手牌调用；绕过 UI 的直接调用也被拒绝 | End Turn 的生命周期入口与内部领域效果函数，不机械删除整个解析器 |
| EventActionData 旧独立按钮 action_id 契约、completed_interactions 旧解法 | 全部事件转为标签／进度／阶段，奖励去重回归通过 | 稳定事件／Insight ID、可用内容描述、未解事件跨回合状态 |
| FloorState.current_event / entity 的旧可写所有权 | 活动实例唯一归 BoardState，必要只读别名有明确退休点 | 精确同一对象引用，不能复制进度或 HP |
| 面向正常牌的 NO_OP／PLACEHOLDER_DAMAGE 旧执行分支、旧按钮断言 | 有效基线及旧测试替代覆盖全部落地 | 事务失败／守恒／RNG／通知等不变量测试 |

不是删除后再补迁移。切换完成后，旧直接玩法入口不得继续对玩家开放成为“暂时兼容模式”。

## 6. 建议迁移顺序与每步退出条件

这些是迁移建议边界；REWORK A／B／C 完成情况以 §0 至 §0.5 为准，其余均需后续明确任务，不自动启动下一阶段。

1. **先关闭设计缺口**：回答 §7 中首批阻塞问题，列出最小玩家牌、有效基线、Explore 接收与
   离层保障。不允许用隐藏按钮或无限免费牌替代设计。
2. **最小 Player Card／Situation 垂直切片**：在统一解析路径加入 Explore／标签，把一个旧事件迁移为
   Objective + Pressure；验证基础 Explore、OBSERVE 修正、阶段奖励去重，以及 Pressure 由 TurnManager 自动结算。
3. **唯一 BoardState 与三种遭遇构成**：迁移活动实例所有权，先展示一个 Situation 和至多一个 Entity，
   证明 Situation-only、Entity-only、Situation+Entity 三种 BoardState 都不切换模式、不复制状态。双实体容量暂不实现。
4. **混合遭遇垂直切片**：让一个未解决 Situation 与 Hound 同桌存在；验证 3 AP 同时竞争环境 Objective、
   Event Pressure 与 Entity Intent。这一步通过后，才继续迁移资源、装备、地标、照明、切出等主动路径。
5. **迁移其余主动路径并验收实体规则／离层**：逐项改为牌效果，移除对应 UI 旁路；用牌处理 Hound 与
   Smiler，验证 WITHDRAWN、多路线 Insight、防软锁与失败事务。两实体同时结算只在单独授权后加入。
6. **清理旧契约**：按 §5 逐项退休入口、只读兼容别名与旧断言；更新运行说明。
   增加“直接调用旧命令也无法绕过手牌”的测试，不能只隐藏按钮。

迁移过程每步运行相应旧不变量回归和新规则测试，检查 SCRIPT ERROR，不仅看进程退出码。
只有新主流程与退役检查全通过，才可把 README 的“尚未迁移”改成“已完成 v2”。

### 6.1 最终验收矩阵

- 从玩家牌组抽牌，在手牌内选择牌和合法世界目标；只点击世界牌不会执行额外动作。
- 玩家牌／世界牌／装备三个集合不混用，UI 没有玩法状态副本。
- 正常牌不以某个具名 Event/Entity 作为唯一用途；暂时无合法目标时不会伪造 no-op／荒谬效果，整手死牌由明确的牌序与遭遇设计控制。
- 异常嗡鸣的 Objective 阈值、OBSERVE 修正、Pressure、一次跨多阈值与重复奖励均有确定性验证。
- Situation-only、Entity-only、Situation+Entity 使用同一 3 AP／手牌／TurnManager，不存在事件／战斗模式切换。
- 换层／被移除／已解决目标的旧引用被拒绝，且 AP、牌区、装备次数、世界状态和 RNG 不变。
- 整个牌动作成功才扣成本；观察者只能看到完整结果，不出现重复 AP／电量收费。
- Hound 可战斗／规避，Smiler 可通过正确出牌存活退去；两者使用同一回合与实体模型。
- 同一 Insight 不论从事件还是实体／替代牌路径确认，最多 Cognition +1，且不超过 5。
- 资源有限不刷新；没有指定事件、物资或 Insight，以及不利抽牌／Exhaust 时仍有卡牌离层路线。
- 已废弃的独立按钮和公开命令无法执行玩法；纯系统控制仍可工作，玩家文案保持简体中文。

## 7. Unresolved Design Questions

下表保留原迁移前的问题。REWORK C 已选定的装备、杏仁水、熄灯、当前两层离层保障以 §0.5 和 GDD §9.1 为准；其余未来扩展仍待确认。

| 问题 | 需要决定的内容 | 为何阻塞 |
| --- | --- | --- |
| 如何控制不同遭遇下的死牌率？ | Guard 可抵御 Situation Pressure；Damage 不强行作用于所有环境。需选择有限换牌、单语义牌组合、卡池比例／遭遇共存中的主要保险 | 保持语义可信的同时，避免纯环境或纯实体局面频繁形成整手废牌 |
| 没有活动 Situation/Event 时 Explore 去哪里？ | 优先通过遭遇调度保证探索回合存在 Objective；是否还需要有限楼层探索／离层准备接收者 | 不能用无消费者的 Explore 数值掩盖死牌，也不能无限刷资源 |
| Explore 的目标、溢出和阶段顺序 | 是否选目标／分配；超过阈值是否保留；一牌解决事件后是否继续作用下一个 | 影响成本、奖励去重与事务计划 |
| 玩家牌的装备操作结构 | 已锁定为装备生成的专用行动牌；未来仅继续平衡生成频率、AP／次数成本 | 避免纯装备钥匙死牌与 AP 重复收取 |
| 杏仁水最终形态 | 已锁定为携带消耗物生成饮用牌；次数只保存在物品实例 | v0.4 与 Phase 7 现状不同，本次没有指定新选择 |
| 熄灯与避光应对如何可达？ | 已锁定为独立熄灯装备牌，按实际光照替换；未来仅调整平衡与牌池 | 保留规则型实体的公平提示与可操作性 |
| 离层牌如何防卡手／耗尽？ | 获取、抽取、Retain／Exhaust 限制、回收保证，以及零 AP 情况的代价 | 防软锁和全卡牌入口必须同时成立；不能只靠等随机牌 |
| Situation 什么时候替换？ | 未解决局势跨回合持续；完成后补牌时机、Fresh／Residual 最小池 | 不得丢进度或重复一次性奖励，也不要求本次补完整内容池 |
| 纯环境／纯实体／混合遭遇的节奏 | Threat、Situation 规则或回合条件何时生成 Entity，各类遭遇比例 | 直接决定事件与战斗融合感、卡牌有效率和 AP 竞争强度 |
| 最多两实体时的目标与意图顺序 | 单／多目标、确定性顺序、目标失活后的结果；本步是否仍只使用一个实体 | 防隐藏耦合与非确定性，避免提前扩成多敌人系统 |
| 首轮卡组与数值 | Deep Search Threat +1 还是 +2，Struggle Damage、Guard 值、卡组数量及离层牌比例 | 用户示例锚点不是对所有旧数值的批量修改授权 |

本次文档方向已确定：所有上述方案必须满足 Player Card 入口、卡牌不绑定单一具名内容、世界牌隔离、
统一回合、唯一 Insight 和防软锁。待决项不能被解释为恢复旧场景按钮的例外。

## 8. 本次文档变更与验证边界

- 修改：`Agents.md`（现有 AGENTS.md 的实际 Git 文件名）、`docs/ARCHITECTURE.md`、
  `docs/CODING_RULES.md`、`Readme.md`。
- 新增：`docs/GDD.md`、`docs/MIGRATION_PLAN.md`。
- 保留：完整 v0.4 DOCX；旧代码、数据、场景、测试、配置与 UID 均不改。
- 检查文档链接、规则一致性与 git diff；对比审查前后的文件内容哈希确认修改范围。
- 本任务不运行或修改玩法测试，不声称 v2 运行时已经实现；后续迁移按 §6 验收。
