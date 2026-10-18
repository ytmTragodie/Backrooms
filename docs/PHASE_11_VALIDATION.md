# Phase 11：事件重分类与 UI 素材管线

## Event Classification

本次用户要求覆盖旧 Situation＝进度目标的分类。既有进度引擎迁入 Objective，不复制一份隐藏 Event HP。

| 原内容 | 新分类 | 处理 | 原因 |
| --- | --- | --- | --- |
| 异常嗡鸣 | Event / DEBUFF | 重写 | 临时心理压力，不是可破坏/调查对象 |
| 重复的墙痕 | Scene Rule / 重复空间 | 重写 | 持续空间性质；紧凑规则提示，关联原有楼层滞留 |
| 错误的转角 | Objective / 空间裂隙 | 重写展示，保留调查机制 | 有明确调查对象、线索与离层知识 |
| 渗水墙面 | Objective / 受潮补给箱 | 重写展示，保留有限完成奖励 | 将泛环境描述收束到可搜索目标 |
| M.E.G. 断续信号 | Event / OPPORTUNITY | 重写 | 短暂联络窗口，成功搜索条件换奖励 |
| 挤压走廊 | Scene Rule / 黑暗与挤压 | 合并 | 不再用局部“忽视掉血条”冒充持续环境 |
| 失光走廊 | Scene Rule / 黑暗与挤压 | 合并 | 复用整层首次观察加费、光照与 Threat 伤害 |
| 墙后的爪痕 | Event / OMEN / 远处抓挠声 | 重写 | 公示猎犬将入场，噪音会加速 |
| 呼吸的墙缝 | Objective | 保留并明确分类 | 可主动调查的离层路线对象 |
| 应急灯放电 | Objective / 应急发电机 | 重写展示，保留真实光照线索 | 有明确线路调查对象与可验证后果 |

运行时已保留的 Objective 稳定 ID 暂沿用原 `event_…` 前缀；类型、目标掩码、文件夹和素材 ID 已分离，不按前缀判断玩法。历史夹具保留全部旧内容，供旧不变量回归。

## New Event Framework

EventData 声明 DEBUFF／OMEN／OPPORTUNITY；EventInstance 只有定义、剩余回合、匹配次数、结算回合与退场状态。没有 Explore 字段，也没有主动事件命令。EventChange 是一次 ActionResult 内的私有计划。

RuleResolver 在验证、完整计划之后统一提交 AP、移牌、Objective、事件条件、有限资源、装备次数、实体、奖励和 RNG，最后通知 UI。失败不会更新计时或机会条件。机会奖励继续使用 CardRewardSystem，认知使用 InsightSystem。

## Level 0 Events

| 事件 | 生命周期/效果 |
| --- | --- |
| 异常嗡鸣 | 3 回合；每回合末压力 +1；到期退场 |
| M.E.G. 断续信号 | 4 回合；2 张成功 SEARCH 标签牌，补给 +1、唯一信号认知、一次三选一；完成或到期退场 |

不为了数量额外加入零层实体前兆。两个实际 Objective 为「空间裂隙」「受潮补给箱」。

## Level 6 Events

| 事件 | 生命周期/效果 |
| --- | --- |
| 灯光衰减 | 3 回合；回合末伤害 1，可被共享 Guard 抵挡 |
| 远处抓挠声 | 3 回合；NOISE 加速；零时生成现有猎犬 |
| 临时稳定广播 | 4 回合；2 张 OBSERVE 后补给 +2、既有避光 Insight |
| 黑暗中的动静 | 猎犬解决后才符合条件；2 回合；实际 LIGHT/NOISE 加速；零时生成笑魇 |

前两张先入场，广播及笑魇前兆按条件与空位后补。两个实际 Objective 为「呼吸的墙缝」「应急发电机」。

## Omen / Entity Flow

前兆生成的仍是 EntitySystem.spawn 创建的公共 EntityInstance。猎犬原 HP、意图、NOISE、伤害、格挡与脱离状态机保留。笑魇保留 HP 与实际强光状态机；出现时有光则记录曝光，随后熄灯或保持黑暗，可 WITHDRAWN 存活退场。替代认知来自广播或 Objective，仍共用 ID 去重。

零倒计时遇到占用实体槽就等待，不覆盖、不丢失。新生成实体不在同一回合末倒算一次攻击。实体解决事实及已出现事件 ID 阻止重复生成。无追查遭遇按钮。

## Objective Separation

ObjectiveData/Instance/System 承接原来验证过的 Explore、标签修正、阈值、线索、一次性认知/准备与无放回调度。只接受当前 Board 的实际 Objective 引用。旧访问、已解决或移除目标失败且无消耗。

正式两层各两个 Objective，忽视压力都设为零；环境代价放进 Event。安全点仍在完成两目标后达到，三格装备与有限搜索、Retain 切出不重写。

## Multiple Event Rules

- 容量固定为 2；按 FloorData.events 顺序补位，满额候选延后，不随机淘汰。
- 活动实例唯一归 Board；seen_event_ids 只是访问内调度事实。
- 入层/新回合补位；行动中退场不立即补牌；无无限重洗。
- 成功出牌：原语义/目标效果 → 实际实体反应 → 事件标签条件/前兆加速 → 完整奖励计划 → 同步提交。
- 回合末：事件入场顺序压力/计时/到期 → Objective 后果 → 当前实体意图 → 楼层滞留 → 清理 → 下一回合计数/AP/手牌/候选。
- 各环境伤害顺序消耗同一份 Guard，实体只用余额；致命环境伤害跳过实体意图。

## UI Structure Changes

顶部状态图标与中文数值；楼层背景及紧凑 Scene Rule；只读双事件行；Objective/Entity 区；底部唯一手牌、抽弃数量与结束回合。装备只有状态。奖励、安全点与总结独立，F8 调试默认隐藏。

Objective 正文使用牌内滚动容器，避免混合遭遇长文溢出事件行。既有 `%WorldCard` 等场景节点名暂保留以兼容输入测试，牌面已称「目标牌」，不代表旧 Event 进度所有权。

## Asset Folder Structure

```
assets/
  backgrounds/level_0, level_6
  cards/player, events, entities, objectives
  entities/
  ui/frames, icons, buttons, overlays
  fx/
  audio/ambience, sfx, ui
  placeholders/
  asset_manifest.json
```

## Asset Manifest

见 [ASSET_MANIFEST.md](ASSET_MANIFEST.md)。每项有稳定 ID、项目路径、用途、必需性、尺寸/格式、状态及收集提示。JSON 为运行清单；手电/切出等生成牌使用实际 CardData.id 映射，Objective 使用显式 asset_id。

## Placeholder/Fallback Behavior

背景、牌图、框及图标有导入的 SVG 占位。AssetCatalog 只允许 `res://assets/` 路径，先查存在再加载；未知/缺图回退、缺音静音。背景、玩家/世界牌图框、状态/标签图标、可选按钮/高亮/叠层以及环境音/提示音均有展示接线。放入声明文件或修改 JSON path 后重启即可替换，不改玩法脚本。

尚无最终美术或音频；PLACEHOLDER 表示预定文件缺失、正在用通用回退，而非已提供独立插画。历史未使用牌 wait/struggle 不列入当前收集清单。

## Tests Run

严格入口：`tests/run_validation.ps1 -GodotPath <Godot console exe>`。检查导入、Phase 1–10、A/B/C、UI、Phase 11、Main 启动；同时检查退出码、PASS、脚本错误和泄漏。唯一允许的既有环境消息为 Windows 根证书库不可读。

Phase 11 覆盖分类、两事件/溢出、临时费用和撤销、失败原子性、Guard/实体顺序、LIGHT/NOISE 前兆、单次生成/占槽等待、机会完成/超时、旧引用、当前数据无内容离层、素材键/回退及真实 UI 完整路线。最终严格全套 15 套通过：Phase 1–10、A/B/C、UI、Phase 11；导入、Main 和 git diff --check 也通过。Phase 10 保留 1084 检查，Phase 11 463 检查。

Phase 10 旧生产内容冻结于 tests/fixtures/phase10；Phase 1–9 保留已有夹具。调用/类型随 Objective 迁移，不删除原有行为断言。正式新数据另测，避免把旧平衡快照误报为新分类。

## Manual Visual Validation

窗口化运行 `tests/phase_11_graphical_validation.gd`，使用实际 Compatibility OpenGL 渲染器与视口纹理截图；不把 headless 检查称为视觉验收。检查零层双事件/目标、六层入场、猎犬混合、笑魇、总结。实际 Windows OpenGL 3.3 Compatibility / NVIDIA GeForce MX250，1152×648，198 检查通过。五张最终截图均已逐张查看；之前发现的目标长文溢出已修复。

人工走查：正常启动 → 观察/搜索目标，同时留意嗡鸣与信号期限 → 领取已挣得奖励 → 完成两目标查看可选安全点 → 用手牌切入六层 → 读前兆、用攻击/格挡处理猎犬 → 留意笑魇前兆、实际照明/熄灯或避光 → 调查发电机/墙缝 → 切出查看总结。事件行与规则文本不产生主动玩法；F8 仅开发可见。

## Immediate Asset Collection List

优先收集零层/六层 16:9 背景、猎犬/笑魇和四目标插画、当前玩家牌与事件插画、四种透明框；随后状态图标、两层环境音及猎犬/笑魇/前兆提示音。尺寸、透明性、英文命名与加载验证见素材清单末尾操作说明。

## Known Limitations

- 单实体槽保留，前兆占槽等待；没有多敌人或通用世界框架。
- 事件候选顺序固定，Objective 仍沿用种子无放回；原型数值和更短路线尚未做真人计时/最终平衡。
- SceneRuleData 是展示声明，实际规则仍来自 FloorData；修改数值应同时更新规则说明。
- 保留历史 Objective.action_results/completed_interactions、只读 current_objective 别名及 followup_on_light 调度兼容，均无旧玩家旁路。正式六层关闭旧即时光照接续。
- 没有最终素材、混音、动画/着色器、导出包或完整本地化验证。
- 没有新增楼层、敌人、商店、Boss、制作、元进度或奖励卡池。

### 最终验收证据

- 自动完整路线（种子 1）：12 回合，生命 19，压力 3，离层威胁 9；3 张牌奖励、1 次删牌，最终 14 普通牌；6 条唯一认知；猎犬击败，笑魇存活退去；12 次起手无整手无效。该策略放弃零层安全点强化，不要求玩家照搬。
- 截图目录：`C:/Users/030824/.codex/visualizations/2026/10/17/01a14873-5923-76d1-8377-cc7eb2bde1a5/phase11`，五图为 level0_events_objective、level6_entry、hound_mixed、smiler、summary。此绝对路径仅是本地验收证据，不进入运行素材加载。
- 窗口日志：系统临时目录 `backrooms-phase11-windowed.log`；最终完整日志目录：`C:/Users/030824/AppData/Local/Temp/backrooms-validation-5be96161b1c849918a3154f054f6194a`。
- 窗口化自动 UI 命令＋实际截图检查，不声称进行了真人计时游玩、最终音频听测或导出包验证。

素材清单当前共 65 项，均未提供最终美术/音频；四个 SVG 为共享占位。

## Changed Files

下列是本次实际内容变更；Objective 脚本与 UID 由原 Event 引擎迁入，新 Event 使用新的 UID。历史夹具仅供测试。

| 操作 | 文件 |
| --- | --- |
| 修改 | `Agents.md` |
| 修改 | `Readme.md` |
| 新增 | `assets/asset_manifest.json` |
| 新增 | `assets/audio/ambience/.gitkeep` |
| 新增 | `assets/audio/sfx/.gitkeep` |
| 新增 | `assets/audio/ui/.gitkeep` |
| 新增 | `assets/backgrounds/level_0/.gitkeep` |
| 新增 | `assets/backgrounds/level_6/.gitkeep` |
| 新增 | `assets/cards/entities/.gitkeep` |
| 新增 | `assets/cards/events/.gitkeep` |
| 新增 | `assets/cards/objectives/.gitkeep` |
| 新增 | `assets/cards/player/.gitkeep` |
| 新增 | `assets/entities/.gitkeep` |
| 新增 | `assets/fx/.gitkeep` |
| 新增 | `assets/placeholders/.gitkeep` |
| 新增 | `assets/placeholders/background.svg` |
| 新增 | `assets/placeholders/background.svg.import` |
| 新增 | `assets/placeholders/card.svg` |
| 新增 | `assets/placeholders/card.svg.import` |
| 新增 | `assets/placeholders/frame.svg` |
| 新增 | `assets/placeholders/frame.svg.import` |
| 新增 | `assets/placeholders/icon.svg` |
| 新增 | `assets/placeholders/icon.svg.import` |
| 新增 | `assets/ui/buttons/.gitkeep` |
| 新增 | `assets/ui/frames/.gitkeep` |
| 新增 | `assets/ui/icons/.gitkeep` |
| 新增 | `assets/ui/overlays/.gitkeep` |
| 删除 | `data/events/event_level0_damp_wall.tres` |
| 修改 | `data/events/event_level0_humming.tres` |
| 修改 | `data/events/event_level0_meg_signal.tres` |
| 删除 | `data/events/event_level0_wall_marks.tres` |
| 删除 | `data/events/event_level0_wrong_corner.tres` |
| 修改 | `data/events/event_level6_claw_marks.tres` |
| 删除 | `data/events/event_level6_dark_corridor.tres` |
| 新增 | `data/events/event_level6_dark_movement.tres` |
| 删除 | `data/events/event_level6_emergency_light.tres` |
| 新增 | `data/events/event_level6_fading_light.tres` |
| 新增 | `data/events/event_level6_stable_broadcast.tres` |
| 删除 | `data/events/event_level6_unstable_corridor.tres` |
| 删除 | `data/events/event_level6_wall_seam.tres` |
| 修改 | `data/floors/floor_level_0.tres` |
| 修改 | `data/floors/floor_level_6.tres` |
| 新增 | `data/objectives/objective_level0_damp_wall.tres` |
| 新增 | `data/objectives/objective_level0_wrong_corner.tres` |
| 新增 | `data/objectives/objective_level6_emergency_light.tres` |
| 新增 | `data/objectives/objective_level6_wall_seam.tres` |
| 新增 | `data/scene_rules/rule_level0_repetition.tres` |
| 新增 | `data/scene_rules/rule_level6_darkness.tres` |
| 修改 | `docs/ARCHITECTURE_CARD_FIRST_V2_1.md` |
| 新增 | `docs/ASSET_MANIFEST.md` |
| 修改 | `docs/CODING_RULES_CARD_FIRST_V2_1.md` |
| 修改 | `docs/GDD_CARD_FIRST_V2_1.md` |
| 修改 | `docs/MIGRATION_PLAN_CARD_FIRST_V2_1.md` |
| 新增 | `docs/PHASE_11_VALIDATION.md` |
| 修改 | `scenes/main/Main.tscn` |
| 修改 | `scripts/cards/card_data.gd` |
| 修改 | `scripts/cutout/cutout_system.gd` |
| 修改 | `scripts/equipment/equipment_system.gd` |
| 新增 | `scripts/events/event_change.gd` |
| 新增 | `scripts/events/event_change.gd.uid` |
| 修改 | `scripts/events/event_data.gd` |
| 修改 | `scripts/events/event_data.gd.uid` |
| 修改 | `scripts/events/event_instance.gd` |
| 修改 | `scripts/events/event_instance.gd.uid` |
| 修改 | `scripts/events/event_system.gd` |
| 修改 | `scripts/events/event_system.gd.uid` |
| 修改 | `scripts/floors/board_state.gd` |
| 修改 | `scripts/floors/floor_data.gd` |
| 修改 | `scripts/floors/floor_state.gd` |
| 新增 | `scripts/floors/scene_rule_data.gd` |
| 新增 | `scripts/floors/scene_rule_data.gd.uid` |
| 新增 | `scripts/objectives/objective_data.gd` |
| 新增 | `scripts/objectives/objective_data.gd.uid` |
| 新增 | `scripts/objectives/objective_instance.gd` |
| 新增 | `scripts/objectives/objective_instance.gd.uid` |
| 新增 | `scripts/objectives/objective_system.gd` |
| 新增 | `scripts/objectives/objective_system.gd.uid` |
| 修改 | `scripts/rewards/card_reward_system.gd` |
| 修改 | `scripts/rules/action_result.gd` |
| 修改 | `scripts/rules/play_card_command.gd` |
| 修改 | `scripts/rules/rule_resolver.gd` |
| 修改 | `scripts/run/run_metrics.gd` |
| 修改 | `scripts/safe_points/safe_point_system.gd` |
| 修改 | `scripts/turns/turn_manager.gd` |
| 新增 | `scripts/ui/asset_audio.gd` |
| 新增 | `scripts/ui/asset_audio.gd.uid` |
| 新增 | `scripts/ui/asset_catalog.gd` |
| 新增 | `scripts/ui/asset_catalog.gd.uid` |
| 修改 | `scripts/ui/main.gd` |
| 新增 | `tests/fixtures/phase10/cards/card_attack.tres` |
| 新增 | `tests/fixtures/phase10/cards/card_deep_search.tres` |
| 新增 | `tests/fixtures/phase10/cards/card_defend.tres` |
| 新增 | `tests/fixtures/phase10/cards/card_observe.tres` |
| 新增 | `tests/fixtures/phase10/cards/card_run.tres` |
| 新增 | `tests/fixtures/phase10/cards/card_search.tres` |
| 新增 | `tests/fixtures/phase10/cards/card_struggle.tres` |
| 新增 | `tests/fixtures/phase10/cards/card_wait.tres` |
| 新增 | `tests/fixtures/phase10/cards/demo_deck.tres` |
| 新增 | `tests/fixtures/phase10/cards/exploration_deck.tres` |
| 新增 | `tests/fixtures/phase10/cards/generated/card_crowbar.tres` |
| 新增 | `tests/fixtures/phase10/cards/generated/card_cutout_rushed.tres` |
| 新增 | `tests/fixtures/phase10/cards/generated/card_cutout_safe.tres` |
| 新增 | `tests/fixtures/phase10/cards/generated/card_extinguish.tres` |
| 新增 | `tests/fixtures/phase10/cards/generated/card_light.tres` |
| 新增 | `tests/fixtures/phase10/cards/generated/card_water.tres` |
| 新增 | `tests/fixtures/phase10/cards/mixed_deck.tres` |
| 新增 | `tests/fixtures/phase10/cards/rewards/card_careful_observe.tres` |
| 新增 | `tests/fixtures/phase10/cards/rewards/card_counter_strike.tres` |
| 新增 | `tests/fixtures/phase10/cards/rewards/card_crisis_observe.tres` |
| 新增 | `tests/fixtures/phase10/cards/rewards/card_exploit_weakness.tres` |
| 新增 | `tests/fixtures/phase10/cards/rewards/card_heavy_strike.tres` |
| 新增 | `tests/fixtures/phase10/cards/rewards/card_reckless_strike.tres` |
| 新增 | `tests/fixtures/phase10/cards/rewards/card_risky_search.tres` |
| 新增 | `tests/fixtures/phase10/cards/rewards/card_steady_guard.tres` |
| 新增 | `tests/fixtures/phase10/cards/rewards/card_thorough_search.tres` |
| 新增 | `tests/fixtures/phase10/cards/run_deck.tres` |
| 新增 | `tests/fixtures/phase10/cards/starter_deck.tres` |
| 新增 | `tests/fixtures/phase10/entities/entity_hound.tres` |
| 新增 | `tests/fixtures/phase10/entities/entity_smiler.tres` |
| 新增 | `tests/fixtures/phase10/equipment/equip_almond_water.tres` |
| 新增 | `tests/fixtures/phase10/equipment/equip_crowbar.tres` |
| 新增 | `tests/fixtures/phase10/equipment/equip_flashlight.tres` |
| 新增 | `tests/fixtures/phase10/events/event_level0_damp_wall.tres` |
| 新增 | `tests/fixtures/phase10/events/event_level0_humming.tres` |
| 新增 | `tests/fixtures/phase10/events/event_level0_meg_signal.tres` |
| 新增 | `tests/fixtures/phase10/events/event_level0_wall_marks.tres` |
| 新增 | `tests/fixtures/phase10/events/event_level0_wrong_corner.tres` |
| 新增 | `tests/fixtures/phase10/events/event_level6_claw_marks.tres` |
| 新增 | `tests/fixtures/phase10/events/event_level6_dark_corridor.tres` |
| 新增 | `tests/fixtures/phase10/events/event_level6_emergency_light.tres` |
| 新增 | `tests/fixtures/phase10/events/event_level6_unstable_corridor.tres` |
| 新增 | `tests/fixtures/phase10/events/event_level6_wall_seam.tres` |
| 新增 | `tests/fixtures/phase10/floors/floor_level_0.tres` |
| 新增 | `tests/fixtures/phase10/floors/floor_level_6.tres` |
| 新增 | `tests/fixtures/phase10/floors/floor_phase6_exit.tres` |
| 新增 | `tests/fixtures/phase10/insights/insight_level0_damp_air.tres` |
| 新增 | `tests/fixtures/phase10/insights/insight_level0_false_landmarks.tres` |
| 新增 | `tests/fixtures/phase10/insights/insight_level0_hum_changes.tres` |
| 新增 | `tests/fixtures/phase10/insights/insight_level0_layout_repeats.tres` |
| 新增 | `tests/fixtures/phase10/insights/insight_level0_meg_signal.tres` |
| 新增 | `tests/fixtures/phase10/insights/insight_level6_darkness_limits_vision.tres` |
| 新增 | `tests/fixtures/phase10/insights/insight_level6_emergency_cycle.tres` |
| 新增 | `tests/fixtures/phase10/insights/insight_level6_light_attracts.tres` |
| 新增 | `tests/fixtures/phase10/insights/insight_level6_noise_pursuit.tres` |
| 新增 | `tests/fixtures/phase10/insights/insight_level6_seams_offer_exit.tres` |
| 新增 | `tests/fixtures/phase10/resources/resource_level0_battery.tres` |
| 新增 | `tests/fixtures/phase10/resources/resource_level0_scrap.tres` |
| 新增 | `tests/fixtures/phase10/resources/resource_level0_supply.tres` |
| 新增 | `tests/fixtures/phase10/resources/resource_level0_water.tres` |
| 新增 | `tests/fixtures/phase10/resources/resource_level6_battery.tres` |
| 新增 | `tests/fixtures/phase10/resources/resource_level6_crowbar.tres` |
| 新增 | `tests/fixtures/phase10/resources/resource_level6_water.tres` |
| 新增 | `tests/fixtures/phase10/rewards/reward_cards.tres` |
| 新增 | `tests/fixtures/phase10/rewards/reward_remove.tres` |
| 新增 | `tests/fixtures/phase10/rewards/reward_upgrade.tres` |
| 新增 | `tests/fixtures/phase10/safe_points/safe_level0.tres` |
| 新增 | `tests/fixtures/phase10/safe_points/safe_level6.tres` |
| 修改 | `tests/fixtures/phase9/events/event_level0_humming.tres` |
| 修改 | `tests/fixtures/phase9/events/event_level0_wall_marks.tres` |
| 修改 | `tests/fixtures/phase9/events/event_level0_wrong_corner.tres` |
| 修改 | `tests/fixtures/phase9/events/event_level6_claw_marks.tres` |
| 修改 | `tests/fixtures/phase9/events/event_level6_dark_corridor.tres` |
| 修改 | `tests/fixtures/phase9/events/event_level6_unstable_corridor.tres` |
| 修改 | `tests/fixtures/phase9/events/event_level6_wall_seam.tres` |
| 修改 | `tests/fixtures/phase9/floors/floor_level_0.tres` |
| 修改 | `tests/fixtures/phase9/floors/floor_level_6.tres` |
| 修改 | `tests/legacy_fixture.gd` |
| 修改 | `tests/migration_test_base.gd` |
| 修改 | `tests/phase_10_validation.gd` |
| 新增 | `tests/phase_11_graphical_validation.gd` |
| 新增 | `tests/phase_11_graphical_validation.gd.uid` |
| 新增 | `tests/phase_11_validation.gd` |
| 新增 | `tests/phase_11_validation.gd.uid` |
| 修改 | `tests/phase_4_validation.gd` |
| 修改 | `tests/phase_6_validation.gd` |
| 修改 | `tests/phase_7_validation.gd` |
| 修改 | `tests/phase_8_validation.gd` |
| 修改 | `tests/phase_9_validation.gd` |
| 修改 | `tests/rework_a_validation.gd` |
| 修改 | `tests/rework_b_validation.gd` |
| 修改 | `tests/rework_c_validation.gd` |
| 修改 | `tests/run_validation.ps1` |
| 修改 | `tests/ui_validation.gd` |
