# AGENTS.md

## Current direction

Godot 4.x 后室卡牌 Roguelike，正式方向为 **Phase 14：地图驱动的战斗 Roguelike**；当前 Phase 15 增量契约见 `docs/PHASE_15_ARCHITECTURE.md`。
Phase 16 的资源、启动导航、主题与声音增量见 `docs/PHASE_16_ARCHITECTURE.md`；正式入口为 `scenes/main/Start.tscn`，原 Main 为游戏视图与回归夹具。
设计主源：`docs/Phase14_GAMEPLAY _Redesign.md`。当前实现契约见 `docs/PHASE_14_ARCHITECTURE.md`，迁移记录见 `docs/PHASE_14_MIGRATION.md`。
发生冲突时：当前用户任务 → Phase 14 设计与已确认规则 → 本文件 → 当前架构/编码规则 → 历史 GDD/Phase。

## Required reading

修改前阅读 Phase 14 设计、当前架构、`docs/ARCHITECTURE.md`、`docs/CODING_RULES.md`；按内容补读 `docs/GDD.md` 和迁移记录。
必须检查真实脚本、调用者、测试与 `.tres`，不能把文档中“建议”当作已存在的 API。

## Gameplay contracts

- MAP → 节点遭遇（COMBAT / ELITE / EVENT / REST / REWARD / SHOP / EXIT）→ 结算 → MAP。
- 卡牌的主要使用场景是战斗。真实手牌来自 NORMAL 持有牌的战斗副本及装备生成行动；没有观察/搜索进度式楼层推进。
- 战斗基础 3 AP、每回合抽至五张基础手牌，最多额外一张装备机会；单敌人。所有角色公开当前锁定意图；M.E.G. 使用战斗 Intel。
- 永久 DeckState 只保存持有牌；CombatDeckState 持有抽/手/弃/消耗。玩家长期状态不保存 AP/Block/Intel/Noise。
- 三个物理装备槽跨战斗、跨楼层保留；物品不进入永久牌组。成功动作才消费次数。
- 非战斗事件通过选项，休息/交易/奖励通过实际节点机会；它们不是免费编辑器。
- 战斗撤离是常驻操作：1 AP、无成功率、承受公开区间内随机 HP 损失与压力；致死为 DEFEAT，否则 ESCAPE。无胜利奖励，不改变 Level。
- CutOut 只在 EXIT；普通切出必定成功，目的地按最终权重随机；预览不消耗 RNG。
- 地图是向前的非线性 DAG；节点及连接公开，内容有迷雾。所有节点可达出口，所有楼层网络可达终局。
- FloorHistoryState 保留同一局的楼层地图；尽量避免重返。重返采用原图入口，已结算节点只通行不重复给收益，不重新生成。
- Knowledge 为长期已知信息集合，不是 Intel 或可消费的统一点数。Noise/状态/光源仅在当前战斗。
- 共用 EntityInstance HP 模型，但允许活着退去；行为与弱点通过标签/条件/效果数据表达，不按具体实体 ID 写分支。

## Engineering

- Godot 4.x / Compatibility / typed GDScript；不引入未经批准的插件/依赖。
- Resource 是只读静态配置；RefCounted 保存运行时；UI 只读并提交带实例上下文的 GameCommand。
- Validate → Plan → 分域 ActionResult → Commit → Notify。失败不改变 AP/资源/牌区/装备/地图/奖励/RNG。
- 每个状态字段一个所有者。RunState 是组合根；Result 是短期草案，不是持久状态或万能兜底桶。
- 显式提交/回合顺序；Signal/动画不触发隐含规则。公开意图与实际执行读取同一份锁定效果。
- 有限、可维护的 Effect/Condition 类型；不创建万能 DSL、大量空 Manager 或按行数拆类。
- 玩家文本简体中文；稳定 ID/代码英文，关键字段、所有权与顺序使用中文注释。
- 素材走 AssetCatalog 稳定映射，缺图默认封面/本地 SVG，缺音静音；素材不驱动规则。
- 待许可字体/音频只按用户授权在本地开发预览启用，发布前替换或补齐许可；原始 UI Pack/ref 的删除需按 `docs/PHASE_16_CLEANUP_PLAN.json` 再经用户确认。
- `archive/phase13c_before_phase14/` 是排除导入的历史原始快照，不是可启动的兼容模式。

## Workflow

先说明影响范围、状态归属与最小步骤，再修改。保护开发者现有修改。
运行 `tests/run_validation.ps1`、检查错误日志、实际打开窗口验证 UI；headless 不能替代视觉验收。
交付需报告变化、验证命令/结果、未完成事项。新内容必须接入池并验证，不只生成空文件。
当前实际支持 Level 0/6/7、单敌人、基础状态与构筑；末端是零代价/代价出口，每条出口保留无条件候选，不以条件门软锁。不顺带实现 Boss、多职业、元进度、制作或复杂环境模拟。
