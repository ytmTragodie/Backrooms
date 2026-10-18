# Phase 12：Visual Integration + Production UI Vertical Slice

本次只整合展示层与素材。RunState、TurnManager、RuleResolver、EntitySystem、EquipmentSystem、CutOutSystem、卡池、楼层内容和项目渲染设置均未修改。

## Final UI Structure

```
Main（MainGameView）
├─ SceneBackground：LevelArt + ReadabilityOverlay
├─ TopStatusBar：七项精确状态值
├─ SceneRules：楼层/规则名，悬停读取已公开规则
├─ EventRow：0–2 个 EventCardView
├─ Board：ObjectiveCardView + EntityCardView
├─ EquipmentStatus：只读三格装备计数
├─ HandView：真实 PlayerCardView，支持所有既有来源
├─ BottomControls：抽弃信息、短反馈、可选安全点、结束回合
└─ 独立 RewardPanel / SafePointPanel / RunSummary；隐藏 F8 DebugPanel
```

Main 负责输入转发、只读查询与视图协调。PlayerCardView、EventCardView、ObjectiveCardView、EntityCardView、HandView、TopStatusBar 负责各自呈现；BoardCardView 只共享世界目标视图的艺术窗/标题/选择边框，不创建通用领域模型。GameUITheme 共享展示样式。

## Layout Reference Adaptation

已读取参考包 README、layout.json、cards.example.json、Godot 卡视图示例，查看 LAYOUT_GUIDE、PREVIEW_5_CARDS 和所有独立素材。

- 模板是 750×1050 卡面参考，并非整屏遭遇布局。采用旧纸、暗金、分类色、透明卡框、费用圆章、独立插画、名称与效果纸签。
- 手牌保留约 5:7 比例。截图中 1152×648 约 139×194，1280×720 约 154×216，1920×1080 约 232×324；逻辑高度按视口计算并限至 282，最终像素随现有 canvas_items 伸缩。悬停轻抬 10 个逻辑像素，预留空间防止盖住装备状态。
- 正文使用屏幕像素字号，不把 750px 模板的 25px 正文直接缩成不可读小字。
- 主要世界目标采用横向插画/信息布局，适配 HP、意图、规律与进度；事件使用更轻的横条。
- 不采用模板示例机制、费用 +/- 控件、窃听者或 ARC 内部档案 ID，不导入第二套游戏工程。

## Integrated Assets

完整记录见 [ASSET_MANIFEST.md](ASSET_MANIFEST.md)、[逐文件审计 JSON](ASSET_AUDIT_PHASE_12.json)。审计了 140 个实际媒体文件，包括参考包、重复副本、主资源、默认和历史 SVG；没有提供音频。

运行清单有 75 个稳定 ID，其中 39 项主路径已提供，36 项专用素材缺失并明确列出替代。

接入的内容包括两层背景、观察/攻击/防御/奔跑、仔细观察、手电、撬棍、杏仁水、两种切出、猎犬/笑魇插画，以及纸底、透明玩家/装备/楼层牌框、名称/效果纸签、费用圆章和状态图标。世界牌使用更适合信息阅读的简化分类边框。

原始参考文件保持不改。`art_listener`、窃听者组合样例、`thread.png` 和误放在按钮路径的箭头图标未猜测成当前实体或按钮底板，记录 UNASSIGNED / UNUSED。

三张扩展名为 `.jpeg` 的实际 PNG 触发 Godot 导入错误，已只纠正扩展名；逐字节/哈希验证未改变图像内容，见 [改名记录](ASSET_RENAMES_PHASE_12.json)。

## Player Card Presentation

- 卡面显示中文名称、动态行动点、插画、最多三行主效果、普通/装备/楼层来源及保留/威胁/噪音标记。
- 名称、效果和数值均由当前 CardData/领域查询绘制，不使用模板的烘焙示例文本。
- 普通/悬停/焦点选择/可用/不可用/目标兼容/保留/安全切出升级有不同呈现。灰牌仍可悬停读失败原因。
- 详细效果、条件和原因在 tooltip；不创建动作菜单。保持“先选世界目标，单击手牌直接出牌”。
- Root Button 仍绑定当前真实 CardInstance 和捕获的命令；UI 不生成伪装备牌或第二份牌堆。

## Event Presentation

EventCardView 显示插画、中文分类/名称、可读的当前效果、倒计时/机会条件计数。最多两张，事件行是只读，不是目标或主动执行入口，没有 Explore HP。

保留事件视图引用以显示短暂入场淡入与计时变化；退场依据 BoardState，不由动画决定效果。修复了 `clip_text` 导致说明最小高度仅一像素的问题，并加可读高度断言。

## Entity Presentation

实体图、中文名、HP/生命条、状态、意图/实际伤害、分析进度和已公开规律来自同一 EntityInstance 与 EntitySystem 查询。意图比次级规则更显著，变化时短闪提示。

击败/脱离/退去后按原领域生命周期离开活动牌桌。笑魇仍使用公共 HP 模型，可保持生命而 WITHDRAWN；UI 没有修改状态机。

## Targeting Feedback

悬停或键盘焦点预览卡牌时，分别构造当前 Objective/Entity 引用的只读查询，调用 RuleResolver.validate_card_target；合法目标蓝框，不兼容目标变暗。

当前世界目标的金框与临时预览分开。显式不兼容目标仍会使牌置灰；不能悄悄改选。点击时提交原先捕获的实际卡/访问/目标命令，过期引用继续由领域原子拒绝。

## Equipment / CutOut Presentation

携带栏只有手电电量、撬棍耐久、杏仁水次数，无主动使用按钮。装备生成牌进入同一 HandView，来源与剩余次数可见。

仓促/安全切出都在手牌内，显示楼层临时来源和保留；仓促显示风险/压力代价，安全使用升级色。没有独立离层面板或免费退出例外。

## Safe Point / Reward UI

三个既有面板使用同一暗色、旧纸金色与分类色。奖励选择显示对应插画与当前定义说明，保留三选一原流程。安全点保持独立可选节点，返回/稍后不消费，确认才提交原 SafePointCommand。总结只读取既有 RunMetrics。

没有改变加牌/删牌/升级/休整规则，也没有自由编辑器。

## Audio Integration

保留 AssetAudio 的楼层环境音与出牌、UI、前兆/实体、切出提示接线。当前没有任何实际音频文件，因此静音；不得把静音回退声称为已提供音效。新增的字体路径同样可选，当前使用引擎/系统中文字体。

## Asset Manifest

主路径存在且可加载时优先使用；缺失时使用显式 fallback_path，之后才是确定性 SVG。后续替换实际文件或更新 JSON 路径即可，不修改玩法代码。

清单记录稳定 ID、路径、实际/建议尺寸、编码、透明要求、状态、优先级与内容说明；审计 JSON 额外记录每个实际文件的哈希、重复关系与分配情况。

## Missing Asset List

完整逐项收集表见素材清单，各行包含目标路径、建议尺寸、格式、透明要求及视觉内容。

| 优先级 | 数量 | 当前缺口 | 当前替代 |
| --- | --- | --- | --- |
| P0 | 6 | 搜索、深入搜索、四个 Objective 专用插画 | 开发者提供的中性 default-cardcover |
| P1 | 24 | 六事件、八奖励牌插画、九音频、一中文字体 | 默认封面、静音、系统字体 |
| P2 | 6 | 消耗图标、按钮底板、四种 FX | 默认箭头图标/内建样式/无可选叠层 |

P0 路径：`assets/cards/player/card_search.png`、`card_deep_search.png`；`assets/cards/objectives/objective_level0_damp_wall.png`、`objective_level0_wrong_corner.png`、`objective_level6_emergency_light.png`、`objective_level6_wall_seam.png`。不是缺少六层背景；它已提供并接入。

## Automated Tests

入口：`tests/run_validation.ps1 -GodotPath <Godot console executable>`。保留原 Phase 1–11、A/B/C、UI 全部断言，再增加 Phase 12。检查退出码、PASS、SCRIPT ERROR、非预期 ERROR 和泄漏，不仅看命令退出状态。既有 Windows 根证书库消息单独允许。

新增覆盖：真实主路径加载、缺失/未知图片与音频、全部最终美术缺失仍可构造 UI、三来源玩家牌、事件三分类、目标/事件文本真实可读高度、HP/意图更新与实体退场、目标预览与领域合法性一致、真实鼠标命中、三种分辨率及当前生产数据完整路线。

实际窗口模拟点击会先等待容器排序，再在同一帧发送完整移动/按下/抬起，避免 Windows 原生指针与缩放事件插入模拟手势；仍验证 Viewport GUI 命中，不绕过按钮处理器。

窗口套件 PASS：1,993 项检查、39 张实际渲染截图。日志：`C:/Users/030824/AppData/Local/Temp/backrooms-phase12-windowed.log`。

完整严格回归 PASS：Phase 1–12、Rework A/B/C 与 UI 共 16 组；Phase 12 无窗口部分 1,882 项检查，导入与 Main 启动通过。日志目录：`C:/Users/030824/AppData/Local/Temp/backrooms-validation-ef20e5f88f144c3a85a1c7c45206c47b`。`git diff --check` 通过；只有已知 Windows 根证书库环境提示被明确允许。

三个分辨率均走完当前生产路线：12 回合、生命 22，三次加牌、一次强化、一次删牌；击败猎犬，笑魇保持生命退去。此结果不代表真人耗时或最终平衡。

## Visual Validation

窗口化使用 Compatibility / OpenGL 3.3 / NVIDIA GeForce MX250，验证 1152×648、1280×720、1920×1080。截图来自实际视口渲染，非 headless。每个分辨率覆盖十一类要求状态；额外保存六层入场和安全点候选，共十三图/分辨率。

纯 Objective、无事件猎犬和仓促切出用明确的既有规则夹具构造代表状态；其余状态来自当前生产数据完整路线。夹具只在测试脚本里使用，没有加入默认 UI 测试入口。

已查看三张联系表的全部 39 图，并放大核对零层事件、混合猎犬、笑魇、奖励、安全点、切出和总结代表帧。检查裁切、重叠、文字、缩放、层次和调试泄漏。截图检查发现并修复了目标进度/线索和事件说明被 clip_text 压成一像素、威胁代价不显眼的问题。部分帧保留真实悬停 tooltip，截图没有合成替换 UI。

## Screenshot Paths if generated

根目录：`C:/Users/030824/.codex/visualizations/2026/10/17/01a14873-5923-76d1-8377-cc7eb2bde1a5/phase12/`

每个 `1152x648`、`1280x720`、`1920x1080` 子目录包含：

`level0_normal_objective`、`level0_event`、`level6_hound`、`event_hound`、`smiler`、`equipment_generated`、`rushed_cutout`、`safe_cutout`、`card_reward`、`safe_point`、`summary`；另有 `level6_entry` 与 `safe_point_candidates`。

## Known UI Issues

- 专用插画缺口仍显示默认封面；没有把默认徽记猜测成新阵营或规则。
- 部分提供图含原始水印/摄像机字样，未编辑掉；卡框为近似透明素材，细节可后续精修。
- 1152 下手牌正文是紧凑字号，完整条件与说明使用悬停；世界牌是横向适配，不是逐像素照搬模板。
- 零层背景来自 660×540 示例，铺满会裁切/放大；建议后续替换同路径宽幅图。
- 各提供图标风格/对比度不完全一致，精确中文数值始终保留。
- 当前验证为 Windows 本地窗口、自动 UI 输入与截图检查，不声称真人计时游玩、音频听测或导出包验证。

## Deferred Polish

最终插画/统一图标、字体与混音、完整卡牌飞行/复杂动画、世界牌框精修、最终 shader/粒子、导出包与额外平台适配均未扩展。本次没有新楼层、敌人、卡牌机制、商店、制作、Boss 或元进度。

## Manual Check Steps

1. 正常 F5 开始零层，确认无测试/模式选择器；点击目标不产生收益。
2. 悬停观察/攻击/搜索，确认合法目标高亮、错误目标变暗，实际出牌仍按选定目标与行动点校验。
3. 看事件效果和计时，观察/搜索只推进 Objective；三格装备只显示状态，行动来自手牌。
4. 通过已挣得奖励和安全点选择，不出现自由编辑器；检查返回与稍后不消费。
5. 切入六层，查看猎犬图、HP、意图和混合事件；照明/熄灯与笑魇行为保持既有规则。
6. 检查仓促/安全切出的来源与保留标记，同一手牌离层并显示总结；三种分辨率重复检查。

## Files Changed

- `scenes/main/Main.tscn` 与 `scripts/ui/main.gd`：展示布局与视图协调，保留原领域命令。
- 新增八个展示脚本：`game_ui_theme.gd`、`board_card_view.gd`、`player_card_view.gd`、`hand_view.gd`、`event_card_view.gd`、`objective_card_view.gd`、`entity_card_view.gd`、`top_status_bar.gd`。
- `asset_catalog.gd`、`card_text.gd`、三个既有奖励/安全点/总结面板：默认素材、短文案与样式。
- `assets/asset_manifest.json`、从参考包复制的运行素材、可选字体目录；三处 PNG 扩展名纠正。Godot 生成相应 `.import` / `.uid` 元数据。
- `tests/phase_12_validation.gd`、`phase_12_graphical_validation.gd` 与总验证入口。
- `Readme.md`、素材清单、逐文件审计、改名记录及本报告。

未改动 `data/`、各领域系统或 `project.godot`；参考包原始文件未编辑。
