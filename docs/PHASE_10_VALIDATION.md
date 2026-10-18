# Phase 10 验证与设计记录

日期：2026-10-18。范围仅限现有两层 Demo；规则权威为 AGENTS／GDD／Architecture／Coding Rules／Migration Plan。

## Reward Economy Changes

普通嗡鸣、墙痕、转角不再给构筑调整。零层 M.E.G. 主要局势、六层猎犬、实际经历光照的笑魇各给一次三选一。
完整探索 3 张 NORMAL，提前离层可少拿。触发完全由资源声明，不按全局计数硬截断；选项仍由 run RNG 生成。

## Safe Point Flow

每层一个临时安全点，任意两张局势完成后达到；当前实体／待选牌奖励处理完后可整备。
休整／整理牌组／强化只能消费同一次机会。查看、返回、稍后不改变状态，可不用而切出。
零层休整 6 HP／3 压力，六层 8／4；NORMAL-only、单实例升级和最低五张规则沿用。
命令携带实际 Board／SafePoint／Card 引用，失败、旧访问和重复选择均零消耗。

## Level 0 Content

嗡鸣 12、墙痕 14、转角 14、渗水墙面 12、M.E.G. 信号 18。
前者教观察修正，中间分别强调搜索风险、忽视压力、有限补给，最后提供较长目标与稀有牌奖励。
嗡鸣首先出现，其余 Fresh 无放回；五条规律提供不同准备／收获，单个事件缺失不锁出口。

## Level 6 Content

挤压走廊 12、失光走廊 12、爪痕 14、墙缝 14、应急灯 14。
维持 Hound／Smiler 技术模型；应急灯线索产生真实 LIGHT，复用已有反应和接续。
局势 Pressure／实体 Intent 同桌竞争 AP，不新增模式。电池、工具补给、杏仁水均有有限搜索节点。

## Deckbuilding Pacing

十二张起始牌调整为 7 调查／2 攻击／2 防护／1 奔跑；保留九张奖励牌，不加新玩家牌。
三次加牌、一次升级与一次移除的脚本路线，最终 14 张，新牌确实经历后续抽牌／洗牌。
装备生成与楼层 Retain 牌不参与永久构筑。

## Balance Changes

- 普通局势目标 12–14，主要目标 18；脚本大部分约 2–4 回合，主要局势有更长目标与牌奖励。
- 仓促出口需要第三回合及累计实际调查 6；第六回合独立兜底。安全标准 2 稳定／1 目的地认知，通常需要额外规律。
- 零层滞留 6／3，六层 4／2；六层每 4 Threat 额外伤害 1、封顶 2，公示与实际伤害共用函数。
- 满额装备不浪费纯补充缓存。EquipmentSystem 提交搜索规划的电量／耐久／次数，不引入制作或修理按钮。

## Board / Targeting Fixes

正式局势完整结算后退场，下一回合补入 Fresh；实体在最终结果后退场。旧目标不能重新获益。
选择实体使环境搜索置灰；选择局势使攻击置灰。空局势时仍有有限资源，可选择周围环境再出搜索牌；没有独立搜刮。
没有模式／模板选择器；安全点是已挣得的一次机会，不是任意玩法按钮。

## Full Demo Flow

正常 F5 → 零层多局势／资源／唯一认知 → 一次主要牌奖励 → 可选安全点 → Retain 切出 → 六层混合局势／猎犬
→ 光照／笑魇行为解法 → 两次实体牌奖励 → 可选安全点 → 切出 → 中文总结 → 正常新局。
不要求调试开局，不把程序执行时间伪装成 10–20 分钟真人体验。

## Run Summary

记录总回合、完成楼层、获得牌／升级／移除、唯一认知、击败及存活解决实体、最终 HP／压力／离层 Threat、种子。
数据来自 RunState.metrics 已提交事实；离层前记录 Threat 和牌数，终点状态不会覆盖旧楼层指标。

## Automated Tests

严格入口：`tests/run_validation.ps1`（`--import` → Phase 1–10／A/B/C／UI → Main）。
旧 Phase 1–9 内容冻结在 `tests/fixtures/phase9`，保留原事务／来源／状态／数值回归；正式资源由 Phase 10 覆盖。
Phase 10 检查奖励预算／去重、安全点三分支及失败边界、有限装备补给、Threat、空内容两层出口、实际 UI 多种子闭环和总结。

| Seed | 全程回合 | 新牌／升级／移除 | 最终牌数 | 最终 HP | 猎犬回合 | 死手／检查起手 | 多选项起手 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 1 | 28 | 3／1／1 | 14 | 29 | 4 | 0／28 | 28 |
| 3 | 27 | 3／1／1 | 14 | 19 | 4 | 0／27 | 27 |
| 8 | 27 | 3／1／1 | 14 | 19 | 4 | 0／27 | 27 |
| 21 | 24 | 3／1／1 | 14 | 21 | 5 | 0／24 | 23 |

最终严格验证通过：导入、14 套测试、Main 启动、`git diff --check`；Phase 10 为 1084 项检查。
没有 SCRIPT ERROR、资源泄漏或其他异常；仅允许本机已有 Windows 根证书读取提示。
完整日志目录：`C:/Users/030824/AppData/Local/Temp/backrooms-validation-c3da351b2149488f803169518c91c850`。

## Graphical / Manual Validation

窗口脚本：`tests/phase_10_graphical_validation.gd`，运行实际 Compatibility 窗口，使用同一生产路线／输入，并保存 Viewport 渲染图。
已运行真实 Windows 窗口：OpenGL 3.3 Compatibility／NVIDIA GeForce MX250，1152×648。
窗口化生产路线通过 259 项检查，12 张 Viewport PNG 已逐张目视检查；不是 headless 截图替代。
覆盖零层、目标置灰、奖励、安全点与候选、仓促／安全牌、六层转场、猎犬退场、笑魇与最终总结。
目视后修复了长候选列表返回键不可见、六张手牌横向溢出和总结背后清零数值；候选显示实际牌区，奖励牌补充噪音说明。
最终总结隐藏实时牌桌，避免终点 Threat 0 与最终离层 Threat 10 同屏混淆。

输出目录：`C:/Users/030824/.codex/visualizations/2026/10/17/01a14873-5923-76d1-8377-cc7eb2bde1a5/phase10`。
画面：`level0_targeting`、`rushed_cutout`、`prepared_cutout`、`safe_point`、`safe_point_candidates`、`card_reward`、
`safe_cutout`、`transition`、`hound_targeting`、`hound_removed`、`smiler`、`summary`（均为 .png）。
日志：`%TEMP%/backrooms-phase10-windowed.log`，退出码 0，没有脚本异常／泄漏。
这是窗口化自动输入与截图目视检查，尚未替代真人 10–20 分钟计时、高 DPI／其他分辨率或发布包测试。
开发者完整手测步骤见 README「完整手动检查」。

## Debug Metrics

仅 debug 日志与隐藏 F8 读数：累计牌奖励、平均每回合出牌、局势完成／耗时、实体解决耗时、离层 Threat／牌数、死手和多选项起手。
不引入 analytics、网络或第二份实时战斗状态。

## Known Balance Issues

10–20 分钟需要真人读牌／决策计时，24–28 回合仅为脚本基线。猎犬一条路线为 5 回合，属于混合遭遇目标范围但略超主动战斗目标。
完整清场路线离层 Threat 常到 10；保守路线与快速离层的收益差仍需真人反馈。笑魇正确行为可快速解决，是刻意保留的规则解法。
默认新局仍使用可复现种子 1；多种子覆盖由测试显式设置，尚未增加玩家 Seed 输入或随机新局入口。
早期 floorless NO_OP 测试、旧事件动作字段／只读别名和稳定 ID `resource_level0_scrap` 留作兼容历史；后者实际是工具补给，不是制作材料。

## Deferred Phase 11 Work

真人计时、更多策略与极端手牌平衡、发布包验证。没有授权增加楼层、Boss、商店、货币、遗物、元进度、制作或网络。

## Files Changed

核心：floor/event/entity/resource/equipment/cutout 现有模型与系统，RuleResolver／TurnManager／RunState／ActionResult。
新增：`scripts/safe_points/*`、`scripts/run/run_metrics.gd`、安全点与总结 UI 脚本／场景。
内容：两层定义、十张局势、资源补充／Insight、安全点资源、Smiler 奖励、起始牌比例；九张奖励牌保持不变。
验证：`phase_10_validation.gd`、`phase_10_graphical_validation.gd`、严格入口及 Phase 9 内容夹具／旧调用者。
文档：Agents、四份 V2.1 文档、README 与本报告。未更改 renderer、项目设置或引入依赖／插件。

### 具体变更文件

以下包含随新脚本生成的 UID；历史夹具单独列明，不混入生产牌池。

```text
Agents.md
Readme.md
data/cards/run_deck.tres
data/entities/entity_smiler.tres
data/events/event_level0_damp_wall.tres
data/events/event_level0_humming.tres
data/events/event_level0_meg_signal.tres
data/events/event_level0_wall_marks.tres
data/events/event_level0_wrong_corner.tres
data/events/event_level6_claw_marks.tres
data/events/event_level6_dark_corridor.tres
data/events/event_level6_emergency_light.tres
data/events/event_level6_unstable_corridor.tres
data/events/event_level6_wall_seam.tres
data/floors/floor_level_0.tres
data/floors/floor_level_6.tres
data/insights/insight_level0_damp_air.tres
data/insights/insight_level0_false_landmarks.tres
data/insights/insight_level0_meg_signal.tres
data/insights/insight_level6_emergency_cycle.tres
data/insights/insight_level6_noise_pursuit.tres
data/resources/resource_level0_battery.tres
data/resources/resource_level0_scrap.tres
data/resources/resource_level0_supply.tres
data/resources/resource_level0_water.tres
data/resources/resource_level6_battery.tres
data/resources/resource_level6_crowbar.tres
data/resources/resource_level6_water.tres
data/safe_points/safe_level0.tres
data/safe_points/safe_level6.tres
docs/ARCHITECTURE_CARD_FIRST_V2_1.md
docs/CODING_RULES_CARD_FIRST_V2_1.md
docs/GDD_CARD_FIRST_V2_1.md
docs/MIGRATION_PLAN_CARD_FIRST_V2_1.md
docs/PHASE_10_VALIDATION.md
scenes/main/Main.tscn
scenes/ui/RunSummary.tscn
scenes/ui/SafePointPanel.tscn
scripts/cutout/cutout_system.gd
scripts/entities/entity_data.gd
scripts/entities/entity_instance.gd
scripts/entities/entity_system.gd
scripts/equipment/equipment_system.gd
scripts/events/event_data.gd
scripts/events/event_instance.gd
scripts/events/event_system.gd
scripts/floors/floor_data.gd
scripts/floors/floor_state.gd
scripts/floors/resource_node_data.gd
scripts/floors/resource_node_system.gd
scripts/rewards/card_reward_system.gd
scripts/rules/action_result.gd
scripts/rules/rule_resolver.gd
scripts/run/run_metrics.gd
scripts/run/run_metrics.gd.uid
scripts/run/run_state.gd
scripts/safe_points/safe_point_command.gd
scripts/safe_points/safe_point_command.gd.uid
scripts/safe_points/safe_point_data.gd
scripts/safe_points/safe_point_data.gd.uid
scripts/safe_points/safe_point_state.gd
scripts/safe_points/safe_point_state.gd.uid
scripts/safe_points/safe_point_system.gd
scripts/safe_points/safe_point_system.gd.uid
scripts/turns/turn_manager.gd
scripts/ui/card_text.gd
scripts/ui/main.gd
scripts/ui/run_summary_panel.gd
scripts/ui/run_summary_panel.gd.uid
scripts/ui/safe_point_panel.gd
scripts/ui/safe_point_panel.gd.uid
tests/fixtures/phase9/cards/run_deck.tres
tests/fixtures/phase9/entities/entity_hound.tres
tests/fixtures/phase9/entities/entity_smiler.tres
tests/fixtures/phase9/events/event_level0_humming.tres
tests/fixtures/phase9/events/event_level0_wall_marks.tres
tests/fixtures/phase9/events/event_level0_wrong_corner.tres
tests/fixtures/phase9/events/event_level6_claw_marks.tres
tests/fixtures/phase9/events/event_level6_dark_corridor.tres
tests/fixtures/phase9/events/event_level6_unstable_corridor.tres
tests/fixtures/phase9/events/event_level6_wall_seam.tres
tests/fixtures/phase9/floors/floor_level_0.tres
tests/fixtures/phase9/floors/floor_level_6.tres
tests/fixtures/phase9/floors/floor_phase6_exit.tres
tests/fixtures/phase9/insights/insight_level0_false_landmarks.tres
tests/fixtures/phase9/insights/insight_level0_hum_changes.tres
tests/fixtures/phase9/insights/insight_level0_layout_repeats.tres
tests/fixtures/phase9/insights/insight_level6_darkness_limits_vision.tres
tests/fixtures/phase9/insights/insight_level6_light_attracts.tres
tests/fixtures/phase9/insights/insight_level6_noise_pursuit.tres
tests/fixtures/phase9/insights/insight_level6_seams_offer_exit.tres
tests/fixtures/phase9/resources/resource_level0_battery.tres
tests/fixtures/phase9/resources/resource_level0_scrap.tres
tests/fixtures/phase9/resources/resource_level0_supply.tres
tests/migration_test_base.gd
tests/phase_10_graphical_validation.gd
tests/phase_10_graphical_validation.gd.uid
tests/phase_10_validation.gd
tests/phase_10_validation.gd.uid
tests/phase_1_validation.gd
tests/phase_2_validation.gd
tests/phase_3_validation.gd
tests/phase_9_validation.gd
tests/rework_a_validation.gd
tests/rework_b_validation.gd
tests/rework_c_validation.gd
tests/run_validation.ps1
tests/ui_validation.gd
```
