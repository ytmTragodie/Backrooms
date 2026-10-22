# 后室：切出 — Phase 14

当前为地图驱动的卡牌战斗 Roguelike。F5 从零层地图开始，选择前向节点，处理事件/战斗、构筑或交易，在出口按概率切出至六层，最终抵达 M.E.G. 撤收点。
Godot 4.7.2 / Compatibility / 类型化 GDScript；无外部插件。

## 设计与实现

- [Phase 14 主设计](<docs/Phase14_GAMEPLAY _Redesign.md>)
- [当前运行架构](docs/PHASE_14_ARCHITECTURE.md)
- [审查与迁移](docs/PHASE_14_MIGRATION.md)
- [内容手册](docs/PHASE_14_CONTENT.md) · [完整 Resource 索引](docs/PHASE_14_CONTENT_INDEX.json)
- [当前素材/缺图表](docs/PHASE_14_ASSETS.md)
- [验证与手动走查](docs/PHASE_14_VALIDATION.md)

## 操作与边界

- 地图绿色节点可前进；连接和位置公开，问号仅隐藏内容，不能回退。
- 战斗使用真实手牌：基础 3 AP、抽五张，最多额外一张装备机会。侦察获得 Intel，战术牌消费 Intel。所有敌人公开当前意图。
- 战斗常驻撤离消耗 1 AP，承受预览范围内伤害及压力，不提供本场胜利奖励，也不会离层。
- 非战斗事件用选项处理；休息、奖励和商店属于已到达节点的一次性机会。
- 出口切出必定成功，但目的地随机；已访问楼层降低权重。重返原图入口，已结算节点只经过，不刷收益。
- 永久牌组和战斗四牌区分离，三格装备跨战斗/楼层保留；没有旧探索进度、Objective 或临时切出牌入口。

## 内容配置

运行入口 `data/game.tres`。当前生成集：24 普通牌、6 升级、5 装备动作、12 实体、20 文本事件、5 装备、8 状态、两层地图、六出口、三商店及奖励/条件/效果等，共 284 Resource。
可直接用 Inspector 编辑；新增配置需接入实际内容池。数据生成器仅用于离线初始样本，重跑会覆盖其管理的 `.tres`，请先保存人工修改。
缺少专用插画时使用开发者默认封面；新内容没有伪造专用美术。音频缺失安全静音。

## 验证

```powershell
./tests/run_validation.ps1 -GodotPath 'C:/path/to/Godot_console.exe'
git diff --check
```

严格检查导入、Phase 14 测试与 Main 启动的退出码/PASS/异常/泄漏。Windows 根证书库环境提示单独允许。

实际窗口与截图：

```powershell
$env:BACKROOMS_PLAYTEST_OUTPUT = 'C:/your/output/phase14'
& 'C:/path/to/Godot_console.exe' --path . --rendering-method gl_compatibility --script res://tests/phase_14_graphical_validation.gd
```

覆盖三种分辨率、真实地图/手牌鼠标输入、代表节点界面与生产数据完整路线；夹具截图明确以 fixture 标记。

## 历史版本

`archive/phase13c_before_phase14/` 完整保存本次修改前的 scripts/data/scenes/tests，包括开发者未完成的字段修改；`.gdignore` 排除导入。
归档不是第二套可运行玩法，旧资源的 res:// 引用未改造成独立工程。旧玩法测试不再作为 Phase 14 验收合同；仍有效的不变量已迁入新测试。

## 当前限制

同一局楼层历史为内存状态，没有磁盘存档迁移；只实际支持单敌人与两层。数字仍是原型，未做真人时长/最终平衡/发布导出验证。地图和节点图标、专用美术与进一步动画仍可后续完善。
