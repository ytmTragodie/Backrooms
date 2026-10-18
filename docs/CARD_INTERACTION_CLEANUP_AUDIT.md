# Card Interaction Cleanup — 旧句审计

本文件是本次修改前的定位快照；下列旧句均为审查材料，不构成玩法规则。当前规则以权威文档的 Single-Semantic Card Rule 和迁移计划 §0.5 为准。

## 编码前报告的迁移对照

| 旧动作 | 新归属 | 删除入口 |
| --- | --- | --- |
| 照明 | 独立装备牌 | 普通牌模式 |
| 熄灯 | 光照状态替换的独立装备牌 | 普通牌模式 |
| 搜索／搜刮资源 | Search 环境结果同次领取有限奖励 | discover／loot 及资源选择 |
| 追查遭遇 | 已解决入口实体＋实际光照的声明式世界条件 | encounter |
| 调查地标 | 六层局势线索确认相同 Insight | landmark |
| 撬棍增强／杏仁水 | 各自装备牌 | 选择增强／消耗物模式 |
| 准备切出 | 探索线索／唯一 Insight 自动奖励 | 准备牌／生成器／主动准备 |
| 仓促／安全切出 | 保留独立楼层牌及原位升级 | 模式参数 |
| 强行切出 | 退役 | 旧资源／分支解释 |

## 文档逐处定位

列出包含动作选择措辞及已过时主动入口的旧行。战斗模式、技术基线、类名等同词异义不在此表；禁止模式的句子保留为约束，不视为授权。

### Agents.md

| 原行号 | 修改前句子／折行 |
| --- | --- |
| 32 | light switching, looting, landmark investigation, encounter interaction, |

### docs/GDD_CARD_FIRST_V2_1.md

| 原行号 | 修改前句子／折行 |
| --- | --- |
| 20 | ／ §23.5、§24.3、§25.3、§31.1 的独立基础检查／搜索／搜刮 ／ 废弃，不能作为没抽到牌的后备按钮 ／ |
| 41 | 奔跑、潜行、搜刮、装备主动使用、开灯／熄灯、查阅地标、主动追查遭遇、切出准备及切出尝试。 |
| 59 | 或成功 no-op 当作“通用用途”。必要的坏手处理应由牌序／弃抽／次级模式等正式机制解决，而不是伪造效果。 |
| 77 | 如果某类遭遇会让大量卡牌暂时失效，应通过遭遇构成、卡组比例、弃抽／换牌或次级模式解决， |
| 166 | CardInstance 绑定实际装备引用，进入统一手牌后才可打出。没有装备／照明／饮用常驻按钮或普通牌菜单分支。 |
| 185 | - 资源有限且不会自然刷新；主动定位／搜刮也通过玩家牌，资源不因此变成玩家手牌。 |
| 192 | 不能以独立强行退出按钮或普通牌菜单分支作为兼容后门。 |
| 207 | 本次决定替代先前装备／切出挂在普通牌菜单中的方案，其余 REWORK C 数值与领域规则保留。 |
| 216 | - 有补给且准备未满时，每个楼层回合至多生成一张非 Retain 的“切出准备”，占基础手牌位， |
| 222 | - 五张基础目标包含 Retain 退出牌及准备牌，退出牌挤占一格普通补牌是有意的贪探索成本。 |
| 224 | - 退役普通牌的装备／准备／安全／仓促／强行切出分支及旧“两张普通牌零 AP 连续退出”证明。 |

### docs/ARCHITECTURE_CARD_FIRST_V2_1.md

| 原行号 | 修改前句子／折行 |
| --- | --- |
| 93 | landmark investigation, encounter interaction, cut-out preparation and attempts |
| 251 | Player Card baseline + declared target/branch |
| 300 | composition, draw/discard/secondary-mode rules and encounter composition. |
| 844 | CardData.actions references small CardActionData Resources for declared optional modes. |
| 846 | PlayCardCommand carries an actual mode reference owned by that CardData, current Board, |
| 850 | A rejected planner cannot expose a partial ActionResult. UI queries the same mode validation/cost rules. |

### docs/CODING_RULES_CARD_FIRST_V2_1.md

| 原行号 | 修改前句子／折行 |
| --- | --- |
| 237 | identity / availability, chosen baseline branch, equipment and final AP cost. |
| 278 | dead-hand rate through explicit deck composition, draw/discard/secondary modes and |
| 310 | card's declared useful baseline available; invalid requested enhanced branches |
| 781 | Optional CardActionData modes must belong to the selected CardData by Resource identity. |
| 784 | Mode cost is the single final AP charge. Planner failure discards its private ActionResult |

### docs/MIGRATION_PLAN_CARD_FIRST_V2_1.md

| 原行号 | 修改前句子／折行 |
| --- | --- |
| 57 | 所有次级模式属于 CardData.actions 中的 CardActionData；命令必须带真实手牌和所属模式引用。 |
| 58 | CardActionSystem 只验证／规划这一小组模式并调用原系统；RuleResolver 仍是唯一提交与通知边界。 |
| 62 | ／ search_nearby ／ 搜索的 discover 模式，1 AP ／ ResourceNodeSystem ／ C 资源测试、Phase 5：有限发现／耗尽 ／ |
| 63 | ／ deep_search 发现并搜刮 ／ 深搜的 deep_loot 模式，2 AP、Threat +1 ／ ResourceNodeSystem ／ 隐藏优先、一次奖励、耗尽失败 ／ |
| 64 | ／ loot(node_id) ／ 搜索的 loot，实际访问内 ResourceNode 引用 ／ ResourceNodeSystem ／ 同 ID 外来／跨访问／重复搜刮失败快照 ／ |
| 76 | 原型选择现已明确：杏仁水保留物理消耗物形态；主动装备模式统一只收牌模式 AP， |
| 79 | 不新增稀有退出牌或免费换牌；当时每张正式牌显式声明 forced 次级模式。 |
| 80 | 当前十二张正式牌和全部非强行模式费用至少 1；每回合五张、3 AP，至少留两张。 |
| 91 | Phase 5–8 的直接命令调用改为真实手牌。原“搜刮／切出不移牌”“熄灯免费”的断言退休， |
| 107 | - 删除全局「手牌模式」、装备与资源下拉框，不保留第二份全局行动选择状态。 |
| 108 | - 每张真实手牌提供左键基础效果、右键／牌内「⋯」行动菜单；装备／已发现资源作为该牌菜单的具体目标。 |
| 109 | 菜单项只构造原有 PlayCardCommand，仍由原解析器验证、统一提交；打开／取消菜单没有玩法效果。 |
| 110 | - 基础行动暂不可用时，牌内菜单仍可访问，零 AP 强行切出继续消耗实际手牌。 |
| 113 | - 回归测试改为直接操作具体手牌菜单；新增 UI 套件覆盖默认入口、控件范围、F8、 |
| 114 | 菜单纯选择、实际鼠标命中、零 AP 连续离层及旧菜单目标失败。全套脚本现在运行 12 套。 |
| 118 | 本节及 GDD §9.1 替代 §0.2／§0.3 的装备菜单、切出菜单与零 AP 强行退出方案。 |
| 123 | ／ 观察 light 菜单 ／ 装备生成“照明” ／ 引用实际手电；成功 -1 电量，用后移除 ／ |
| 124 | ／ 攻击 crowbar 菜单 ／ 装备生成“撬棍猛击” ／ 保留 8 伤害／NOISE；成功 -1 耐久，用后移除 ／ |
| 125 | ／ 防御 recover 菜单 ／ 装备生成“饮用杏仁水” ／ 保留恢复值；成功 -1 次，用后移除，耗尽不再生成 ／ |
| 126 | ／ 普通牌 prepare 菜单 ／ 楼层生成“切出准备” ／ 1 AP＋1 补给；每楼层回合至多一张，非 Retain，占基础格位 ／ |
| 127 | ／ 普通牌 rushed/safe 菜单 ／ 楼层生成仓促切出，原位升级安全切出 ／ Retain，1 AP；失败保牌，成功离层后清理旧访问牌 ／ |
| 128 | ／ 普通牌 forced 菜单 ／ 已退役 ／ 不保留零 AP 普通牌旁路；领域内部旧算法不作为玩家入口 ／ |
| 140 | 原 C 的“普通牌出装备模式”“三次装备同回合”“所有成功牌进弃牌堆”“零 AP 强行退出”断言退休， |
| 143 | UI 继续保留隐藏 F8 调试面板；生产默认布局没有模式／装备／退出旁路。 |
| 155 | ／ v0.4 §23.5、§24.3、§25.3、§31.1 ／ 不必抽到牌，使用独立检查／搜索／搜刮；牌只是更强交互 ／ DEPRECATE：主动玩法必须出玩家牌 ／ |
| 170 | - `scripts/ui/main.gd` 与 `scenes/main/Main.tscn` 直接提供检查、搜索、搜刮、准备／尝试切出、 |
| 209 | ／ 资源、地标、切出准备与尝试 ／ ResourceNodeSystem、InsightSystem、CutOutSystem ／ 以牌效果触达；保留有限奖励和安全／仓促／强行语义，不提前实现 Exit／Resource 世界卡类型 ／ |
| 210 | ／ 笑魇遭遇及替代规律发现 ／ EntitySystem、FloorData、InsightData ／ 牌／已声明世界规则触发遭遇与行为，替代路线仍用同一 Insight ID，无独立追查／地标按钮 ／ |
| 234 | - 独立检查、搜索、搜刮、装备主动操作、开关灯、查阅地标、追查遭遇、准备与尝试切出的按钮。 |
| 255 | ／ 面向正常牌的 NO_OP／PLACEHOLDER_DAMAGE 旧执行分支、旧按钮断言 ／ 有效基线及旧测试替代覆盖全部落地 ／ 事务失败／守恒／RNG／通知等不变量测试 ／ |
| 257 | 不是删除后再补迁移。切换完成后，旧直接玩法入口不得继续对玩家开放成为“暂时兼容模式”。 |
| 299 | ／ 如何控制不同遭遇下的死牌率？ ／ Guard 可抵御 Situation Pressure；Damage 不强行作用于所有环境。需选择有限换牌、次级模式、卡池比例／遭遇共存中的主要保险 ／ 保持语义可信的同时，避免纯环境或纯实体局面频繁形成整手废牌 ／ |
| 302 | ／ 玩家牌的装备操作结构 ／ 通用工具／照明牌还是其他方案，缺装备时的基础用途、增强分支、AP／次数成本 ／ 避免纯装备钥匙死牌与 AP 重复收取 ／ |
| 304 | ／ 熄灯与避光应对如何可达？ ／ 主动熄灯牌、低噪牌或牌的模式；如何防止抽不到应对而只能点旁路 ／ 保留规则型实体的公平提示与可操作性 ／ |

### Readme.md

| 原行号 | 修改前句子／折行 |
| --- | --- |
| 20 | 点击世界牌仅选目标，左键手牌打出主行动。普通牌少量资源／地标／遭遇／熄灯行动仍在右键／「⋯」菜单； |
| 21 | **装备、准备和切出没有普通牌菜单项或独立玩法按钮**。装备与切出生成自己的真实手牌。 |
| 27 | ／ FLOOR_TEMPORARY 楼层临时牌 ／ 本次访问满足条件生成 ／ 切出牌 Retain，失败保牌；准备牌用后／回合末移除；成功过层清理旧访问全部临时牌 ／ |
| 32 | 基础手牌目标五张，包含 Retain 退出牌及可用的准备牌；先预留楼层牌格位，再补普通牌。 |
| 52 | 有补给且准备未满时，每个楼层回合最多生成一张“切出准备”：1 AP＋补给 1，稳定度／目的地认知各 +1。 |
| 57 | 安全切出 1 AP，成功换层。成功后旧楼层退出／准备牌全部移除；下一层重新产生自己的机会。 |
| 60 | 旧普通牌 0 AP 强行切出分支已退役；不再承诺零 AP／HP 1 无伤连续退出。 |
| 69 | 4. 深搜牌「⋯」→「深度搜刮」，领取有限缓存；手牌出现“切出准备”。左键打出它，花费剩余 1 AP／补给 1。 |
| 71 | 6. 第三回合左键安全切出：进入六层，AP 3→2。确认旧退出牌和旧准备牌消失，新层尚无自己的切出牌。 |
| 77 | 10. 猎犬击败／脱离后，观察牌「⋯」→「追查遭遇」出现笑魇。正确保持黑暗可令其存活退去； |
| 119 | 早期无楼层占位测试数据和未对玩家开放的 forced 领域算法仍是遗留；没有对应可执行的玩家菜单旁路。 |
