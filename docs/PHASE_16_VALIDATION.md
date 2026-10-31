# Phase 16：资源整理与 UI 升级验收

完成日期：2026-10-31。16A–16D 与 16E 的验证/清理规划已完成；**原包/ref 删除尚未执行，等待用户确认清单**。

## 分阶段结果

| 阶段 | 改动与主要文件 | 验证 | 剩余事项 |
| --- | --- | --- | --- |
| 16A | 65 个 data/phase15 Resource 按类型迁至现有功能目录；更新 36 个引用文件、资源索引和旧生成工具；新增迁移/审计记录 | 351 个 Data Resource 全部加载，内容验证通过；65 个迁移文本与 HEAD 对比，除对应路径替换外逐字一致，UID 头保留；未修改已有 .uid 文件 | 不擅自合并业务数据；命名含混资源保留 |
| 16B | Start.tscn / start_screen.gd；opening_story_data.gd / opening_story_view.gd；data/ui/opening_story.tres；project.godot 正式入口改为菜单 | 菜单无 RunState；重复开始、重复结束、跳过和自然结束都只创建一次原 Main/Run；剧情不消耗玩法 RNG；真实退出按钮正常退出 | 继续/设置/图鉴禁用，有说明和稳定导航接口，未实现存档业务 |
| 16C | 复用 AssetCatalog/GameUITheme，字体角色/中文回退；3 个按钮 SVG、箭头、资源/节点图标、事件插画、费用圆章；保留动态卡名/费用/效果文字 | 常用字/符号回退验证；1152×648、1280×720、1920×1080 实际窗口截图与点击检查；旧节点界面图形回归通过 | 待许可字体仅本地预览；现有背景清晰度受原图限制 |
| 16D | 扩展 AssetAudio 为唯一 Autoload GameAudio；菜单/剧情/地图/战斗上下文，交叉淡化、短音池、悬停限频、音量总线 API | 实际窗口验证 BGM 正在播放；快速切换后至多一条背景声；缺音淡出静音；音量作用于真实总线；退出释放流 | 攻击/受击/防护/切出先用中性短音；音乐完整许可待补，主观听感需继续调校 |
| 16E | 原始 UI Pack/ref 加导入隔离，不删除；选用的 8 项与许可复制到正式目录；列逐文件建议删除/保留清单 | 原始素材生产路径引用为 0；完整回归、实际窗口、清洁退出、diff 检查通过 | 522 项建议删除仍待用户确认，10 项保留 |

## 状态与架构

没有修改 RunState、TurnManager、RuleResolver、战斗、实体 AI、地图生成或 CutOut 核心规则。Main 保留为原游戏视图和测试夹具；StartScreen 仅拥有界面导航阶段。开场文字为只读 Resource，Tween 不触发任何玩法规则。

StartScreen.request_section 与 section_requested 提供继续/设置/图鉴接入点；当前反馈占位，不创建空业务场景。结果页返回正式主菜单。

既有 AssetAudio 成为唯一应用级服务，不再随 Main 重复创建。Music/SFX 总线及真实音量 API 为后续设置页复用。故事/菜单/地图/战斗只请求静态素材 ID。声音与动画只响应显示或已提交动作，不参与 AP、HP、装备或 RNG 的提交。

更完整契约见 [PHASE_16_ARCHITECTURE.md](PHASE_16_ARCHITECTURE.md)。

## 完整验证命令

```powershell
./tests/run_validation.ps1 -GodotPath 'C:/Users/030824/Desktop/backrooms/Godot_v4.7.2-stable_win64_console.exe'
```

| 检查 | 最终输出 |
| --- | --- |
| Godot import | PASS |
| Phase 14 | PASS，20,786 项 |
| Phase 15 | PASS，4,932 项 |
| Phase 16 | PASS，537 项 |
| 退出入口 | PASS，由按钮实际调度退出，测试没有替它直接 quit |
| 200 种子模拟 | PASS，14,516 项；0 非法策略动作，0 停滞 |
| 正式主场景启动 | PASS，进入菜单 |
| git diff --check | PASS |

严格脚本日志原目录：`C:/Users/030824/AppData/Local/Temp/backrooms-phase14-fbe9a01d6d8a4b13bbf195aefddb6d89`，副本保存到 `outputs/phase16/strict/`。目录/模拟文件名沿用原脚本，不表示漏跑新阶段。

初次导入原始完整 Pack 在其字体导入阶段没有完成。选用素材复制后，原始 Pack/ref 隔离导入，后续完整 import 均通过；没有因此断言或删除“损坏字体”。

早期发现 Dummy 音频驱动在无窗口快速退树时出现缓冲释放告警；已改为 headless 不混音、真实窗口测播放，并增加停止/清流/退出等待。最终严格日志没有脚本错误、资源泄漏或失败断言。仍有本机原有根证书读取警告，使用的是原脚本原有精确豁免，没有放宽错误匹配。

## 实际窗口验证

使用 Compatibility / OpenGL，运行并检查：

```powershell
$env:BACKROOMS_PLAYTEST_OUTPUT = 'C:/Users/030824/Desktop/backrooms/Backrooms/outputs/phase16'
& 'C:/Users/030824/Desktop/backrooms/Godot_v4.7.2-stable_win64_console.exe' --path . --rendering-method gl_compatibility --script res://tests/phase_16_graphical_validation.gd
& 'C:/Users/030824/Desktop/backrooms/Godot_v4.7.2-stable_win64_console.exe' --path . --rendering-method gl_compatibility --script res://tests/phase_16_quit_validation.gd
```

- Phase 16 图形验收：**PASS，580 项**；实际鼠标点击开始、跳过、手牌，三个分辨率均通过，验证真实音乐播放器正在播放。
- 实际点击桌面退出：**PASS**，声音先释放，进程正常结束。
- 补跑旧 `phase_14_graphical_validation.gd`：**PASS，20,818 项**；事件、休息、商店、奖励、战斗、切出、结局及完整旧流程正常，未出现主题升级造成的操作区越界。
- 截图：新版菜单/剧情/地图/战斗 13 张；旧核心流程与节点夹具 32 张。分别位于 `outputs/phase16/`、`outputs/phase16/core/`，目录排除 Godot 素材导入。
- 已查看实际渲染截图：主菜单、剧情、地图、战斗、事件插画与选项。动态文字未依赖图片里的写死内容。图形日志副本为 graphical.log、quit-window.log、core-window.log。

这属于实际窗口自动交互和截图复查，不声称已完成长时间真人听感/平衡测试。现有地图/战斗数值完全不在本阶段调整。

## 手动验收步骤

1. 正常运行项目：先看到主菜单，而不是地图；三个未开放入口为禁用状态，悬停有说明。
2. 点击“开始游戏”：环境变暗、短暂闪烁，逐句打字演出。连点开始不得生成多个剧情或多个新局。
3. 按 Esc 或点“跳过开场”：进入零层原地图。另测完整播完：也只初始化一次。
4. 查看零层/六层/七层地图、战斗、事件和出口：文本/插画/图标可见，仍通过真实节点、手牌与原命令结算。
5. 观察资源、AP、意图、装备次数和卡牌费用仍来自真实状态；事件选项、休息、奖励、商店和 CutOut 正常。
6. 检查菜单→剧情→探索→战斗的声音切换；按钮/悬停/出牌/抽牌/伤害/防护/奖励/状态/CutOut 有基础反馈，快速切换不持续叠加 BGM。
7. 结束一局后返回主菜单，再开始新局；退出按钮及窗口关闭应正常结束进程。
8. 发布预览（禁用 development_preview）时，待许可字体/音乐不应加载；系统文字与默认视觉仍工作、缺音静音。

## 许可与待清理事项

用户授权未知许可素材仅本地开发预览，已在 AssetCatalog 限制。Bahnschrift 等字体、Crow Shade 音乐与实体声音的完整包许可/版本仍需核对；未新增网络字体或音频。普通导出运行会回退，但**发行包物理排除和完整许可审计尚未完成**，当前不应视为可直接商用发布。

- [字体/音频/Pack 许可与来源](PHASE_16_LICENSES.md)
- [完整素材与 Data 审计](PHASE_16_ASSET_AUDIT.json)
- [65 项资源迁移表](PHASE_16_RESOURCE_MIGRATION.json)
- [8 项 UI Pack 采用表](PHASE_16_ADOPTED_PACK.json)
- [安全清理说明](PHASE_16_CLEANUP.md) / [522 项逐文件待确认清单](PHASE_16_CLEANUP_PLAN.json)

功能性 P0 缺失：无。发布阻塞：待许可素材的完整许可与打包排除。P1：独立简体正文分发字体、高清宽幅背景、专用战斗/CutOut 声音；P2：独立状态图标与更细的声音混音/氛围润色。未实现的中毒等机制不为使用素材而新增。
