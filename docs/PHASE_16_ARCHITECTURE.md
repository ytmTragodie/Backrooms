# Phase 16：启动与展示层增量契约

只改变资源组织、应用导航、主题和声音反馈；Phase 14/15 的地图生成、战斗、AI、切出规则和状态提交顺序保持原状。

## 资源与目录

65 个阶段目录资源按真实类型迁移至已有功能目录，目标路径见 `PHASE_16_RESOURCE_MIGRATION.json`。没有删除/合并业务数据。新设的有限子目录仅为 maps/rules、maps/regions、floors/entrances、cutout/requirements；其他沿用现有 events/options、entities/behaviors/actions/reactions/triggers、effects、rewards/entries 等。

移动保留原静态 ID/字段/作者 UID 头及 sidecar（如有），修正 `.tres`、测试和资源索引的路径，不调用自制 UID 注册器。`create_phase15_content.py` 也改走功能路径，以免未来重跑恢复阶段目录；不在游戏启动时运行内容生成器。全部 Data 共 351 个 Resource，含 1 个独立剧情配置。

## 应用启动边界

正式入口 `scenes/main/Start.tscn`，StartScreen 仅持有 MENU / INTRO / GAME / CLOSING 展示阶段。

`启动 → 菜单 → begin_run → OpeningStoryView → completed → 实例化旧 Main.tscn → TurnManager._ready → start_run`

- 菜单/剧情没有 TurnManager，不提前初始化 RunState。begin_run 先切阶段；重复输入直接返回。
- OpeningStoryData 是只读 Resource，配置文字、背景、声音、速度/停留；Tween 仅改文字可见比例、透明度和暗场。跳过按钮/Esc/自然结束统一走幂等 finish。
- StartScreen 的 completed 消费也验证 INTRO 阶段，故不会重复实例化 Main。界面随机/时间均不接触 Run RNG。
- 保留原 Main 场景作游戏视图与回归夹具；其业务初始化仍由原 TurnManager 完成。结果页发 return_to_menu_requested，应用外壳销毁已结束视图再返回菜单。
- 继续/设置/图鉴为禁用入口，附明确 tooltip；`request_section(continue/settings/codex)` 与 `section_requested` 是稳定导航接入点，当前仅反馈占位。没有伪造存档和空业务场景。设置可复用 GameAudio.set_volume 的实际总线入口，存档业务仍未实现。
- 桌面退出按钮和窗口关闭共用 CLOSING 流程，先释放声音再退出；本局无持久存档，不提供假的继续功能。

## 主题与字体

沿用 GameUITheme：body、display、archive、numbers 四个用途，剧情复用 display，控制实际字体种类。路径仍通过 AssetCatalog，正文为清晰系统中文，展示为侵食明朝，编号/数字为 Bahnschrift；缺字使用 SystemFont 回退，避免直接改共享 FontFile。

UI Pack 只采用灰系按钮/箭头/中性短音，主题着色成昏黄/炭色；不把所有控件换成鲜亮 Pack 演示风格。保留纸签卡框，卡名、费用、效果和次数仍为运行时 Label。主界面增加资源/地图图标与并排事件插画，不改数据结算。

## 唯一声音服务

扩展原 AssetAudio 并注册应用级 Autoload `GameAudio`，Main/菜单/剧情只请求逻辑音频 ID。没有另起一套 AudioManager，也不再为每个 Main 创建声音实例。

两路背景声仅用于短暂交叉淡化，稳定状态至多一条播放；同文件跨上下文延续，不重复重启。独立六路短音池避免按钮/出牌立即打断彼此；悬停限频。Music/SFX 发送 Master，真实总线保存音量，未来设置页不需再建一份平行音量状态。

声音由已提交结果和实际 UI 卡牌动作触发，失败不播放成功效果；按钮操作音本身不代表业务成功。实体叫声通过静态素材 ID 约定映射，音频不驱动实体规则。头部数字/动画都是只读显示。

Headless 不启动混音，仍验证资源、上下文和总线；实际窗口验证播放器播放与淡出。此分离修复 Dummy 驱动快速退树时的音频缓冲释放告警，不能据此声称无窗口测试已验证听感。退出还会清除声音流和字体缓存。

## 原始素材与发布

原包/ref 保留并排除导入；正式采用物有独立路径和许可副本。未知许可素材仅本地预览，导出运行回退；发行前仍需物理排除/补许可与署名。完整限制见 `PHASE_16_LICENSES.md`。未经用户确认不执行 `PHASE_16_CLEANUP_PLAN.json` 的删除建议。
