# 后室：切出 Demo

Godot 4.x、Compatibility、类型化 GDScript。打开 `project.godot`，按 F5 运行。
当前实现 Phase 1–6：零层探索与有限搜刮 → 切出 → 六层黑暗与猎犬 → 再次切出到测试终点。
尚未实现 Phase 7，没有独立战斗场景或第二套战斗 AP。

## 权威文档

遵循 AGENTS.md、docs/ARCHITECTURE.md、docs/CODING_RULES.md。
仓库没有 docs/GDD.md 或 docs/GDD.docx，设计依据为
`docs/Backrooms_Card_Roguelike_GDD_v0.4_Demo_Baseline.docx`。
当前阶段用户任务优先于完整 GDD 内容量；所有数值和卡组均是原型。

## 状态与结算

新局：生命 30、压力 0、补给 0、威胁 0、认知 0、回合 1、AP 3。
TurnManager 持有唯一 RunState，当前 FloorState 保存楼层威胁、认知、事件、
资源节点、切出准备、实体实例和临时格挡。RunState 的 Threat/Cognition 读取
仅转发楼层值，不另存副本；HP、压力、补给和 DeckState 随 Run 保留。

```text
UI -> TurnManager -> PlayCardCommand / ExplorationCommand
   -> RuleResolver 完整验证、计算 ActionResult
   -> AP / 牌区 / 楼层 / 实体统一提交 -> 通知 -> UI 读取刷新
```

重要动作没有信号驱动的隐式规则。失败命令不改变牌区、AP、事件、资源、
实体或 RNG。共享 Data Resources 保存定义，运行时值存于各次访问的实例。

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
- 奔跑：1 AP，威胁 +1；使当前活跃实体追击，若实体踉跄则成功脱离。
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
材料箱（1 补给）。电池／材料暂统一折算补给，不引入背包、装备或制作。
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

六层包含三个 Fresh Events、两个唯一 Insight，以及 darkness 楼层旗标。
黑暗规则：每回合第一张成功打出的观察额外耗 1 AP；失败不消耗该标记，
原有 End Turn 清除它。检查只给表层信息。UI 与解析器共用费用查询，
因此实际费用为 2 时卡牌按钮也显示 2。尚未实现光源、装备和开灯交互。

FloorData.entry_entity 配置遭遇，FloorState 每次创建独立 EntityInstance。
EntityData 仅保存 ID、名字、初始状态、最大生命和伤害参数；当前 HP、
状态与意图属于实例。alive/active 从 HP 与脱离状态派生，不保存重复布尔值。
目前唯一实体为 18 HP 猎犬，使用以下小型确定性状态机：

| 状态 | 当前公示意图／回合末行为 |
| --- | --- |
| WATCHING / 凝视 | 靠近，不造成伤害，转为 APPROACHING |
| APPROACHING / 靠近 | 撕咬 4，随后追击 |
| CHASING / 追击 | 扑咬 5，继续追击 |
| STAGGERED / 踉跄 | 重新观察，恢复为 WATCHING |
| DEFEATED / 已击败 | HP 0，死亡、非活跃，无后续意图 |
| DISENGAGED / 已脱离 | 仍存活但非活跃，无后续攻击 |

攻击凝视中的实体会使其靠近；奔跑一般使其直接追击。
完整格挡一次攻击会令其踉跄，部分格挡只减少伤害。
踉跄时奔跑可以脱离。当前只有奔跑作为显式的风险追击触发，不做复杂噪音 AI。
HP 不会低于 0，重复攻击已击败／已脱离实体会被拒绝，不重复结算击败。

UI 的“实体意图”页签显示中文生命、状态、意图和格挡，进入六层时自动选中；
可以随时切回探索或资源与切出，不暂停任何领域规则。
敌方动作只在现有 End Turn 中通过 EntitySystem 规划并由 RuleResolver 提交。
没有实体场景脚本、战斗场景切换、动画 AI、独立战斗时钟或复杂状态系统。

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

## 手动验证

1. F5 启动，在“资源与切出”点强行切出。确认进入六层、猎犬 18/18、凝视、
   意图回合末靠近；AP 仍为 3、回合仍为 1，手牌没有替换。
2. 直接点原来的结束回合：猎犬靠近、尚未造成伤害；AP 3，抽到五张战斗牌。
3. 打出攻击：猎犬生命 18 → 14、AP 3 → 2。打出防御：格挡 4、AP 2 → 1。
   可再打一张攻击；结束回合后撕咬被完全格挡，猎犬踉跄、格挡归零。
4. 按手牌继续攻击／防御；踉跄时若有奔跑，可测试脱离。其他状态下奔跑会
   显示追击、扑咬 5 意图及威胁 +1。结束回合执行意图，部分格挡也应正确减伤。
5. 在探索页调查事件，确认首次观察实际费用为 2，认知只因唯一 Insight 增加。
   战斗期间楼层回合、滞留威胁、抽弃洗和切出都继续运行。
6. 击败后确认猎犬 0/18、已击败、无后续意图，不能再次对其造成伤害。
   或随时直接强行切出，即使零 AP 也能到测试终点；没有额外战斗场景。
7. 若生命降到 0，确认本局停止、命令禁用，不出现新回合 AP 恢复。

## 已知限制

没有 Smiler、多敌人、装备、Boss、复杂状态、暴击／护甲公式、掉落表、
正式胜负结算、元进度或 Phase 7。没有新增插件或依赖，渲染器保持 Compatibility。
六层仅两个 Insight，认知最多 2；没有正式光源／光照效率系统。
Fresh 耗尽后没有 Residual Events；压力目前只累计数值，不执行精神崩溃后果。
攻击、防御、奔跑和状态机参数仍为原型，尚未做图形窗口人工目视验收。

## Phase 6 变更文件清单

以下清单对应本次 Phase 6 增量，包含新增脚本的 Godot UID。

### 新增

- `data/cards/card_attack.tres`
- `data/cards/card_defend.tres`
- `data/cards/card_run.tres`
- `data/cards/demo_deck.tres`
- `data/entities/entity_hound.tres`
- `data/events/event_level6_claw_marks.tres`
- `data/events/event_level6_dark_corridor.tres`
- `data/events/event_level6_wall_seam.tres`
- `data/floors/floor_level_6.tres`
- `data/floors/floor_phase6_exit.tres`
- `data/insights/insight_level6_darkness_limits_vision.tres`
- `data/insights/insight_level6_seams_offer_exit.tres`
- `scripts/entities/entity_data.gd`
- `scripts/entities/entity_data.gd.uid`
- `scripts/entities/entity_instance.gd`
- `scripts/entities/entity_instance.gd.uid`
- `scripts/entities/entity_system.gd`
- `scripts/entities/entity_system.gd.uid`
- `tests/phase_6_validation.gd`
- `tests/phase_6_validation.gd.uid`

### 修改

- `Readme.md`
- `data/floors/floor_level_0.tres`
- `scenes/main/Main.tscn`
- `scripts/cards/card_data.gd`
- `scripts/cutout/cutout_system.gd`
- `scripts/events/event_system.gd`
- `scripts/floors/floor_data.gd`
- `scripts/floors/floor_state.gd`
- `scripts/rules/action_result.gd`
- `scripts/rules/rule_resolver.gd`
- `scripts/turns/turn_manager.gd`
- `scripts/ui/main.gd`
- `tests/phase_2_validation.gd`
- `tests/phase_3_validation.gd`
- `tests/phase_4_validation.gd`
- `tests/phase_5_validation.gd`

### 删除

- `data/floors/floor_level_6_placeholder.tres`
