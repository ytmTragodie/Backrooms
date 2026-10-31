# Phase 16 素材来源与发布限制

核对日期：2026-10-31。用户已明确授权：**许可待补素材仅限本地开发预览，发布前替换或补齐许可**。没有下载新字体、图像或音频。

## 已采用 UI Pack

来源：用户提供的 `assets/ui_asset_pack/`，Kenney UI Pack 2.0（2024-06-12）。原包 `License.txt` 明示 CC0，允许个人/商业项目。实际只复制 3 个按钮 SVG、1 个箭头 SVG、4 个短交互音；逐项原/新路径见 `PHASE_16_ADOPTED_PACK.json`。许可原文保存到 `assets/licenses/Kenney-UI-Pack.txt`。感谢 [Kenney](https://kenney.nl/)。原包保留，没有执行删除。

**字体例外**：包中两款 Kenney Future 字体的嵌入 name 表写有 CC BY-SA 3.0，与包级 CC0 描述不一致。本阶段不采用、不复制这些字体，发布前若要用，需另核对字体作者许可，不能直接套用 SVG 的 CC0 结论。

## 字体审计与实际选择

覆盖取自本地字体 cmap；完整 name/copyright/license 字段与缺字样本在 `PHASE_16_ASSET_AUDIT.json`。数量为本工具统计的编码点，并非简体中文字数或完整字符质量保证。

| 文件 / 实际 family | 编码点 | 覆盖与用途 | 本阶段状态 |
| --- | ---: | --- | --- |
| ShinsyokuMincho-Regular.ttf / ShinsyokuMincho | 16691 | 日系侵蚀明朝，含汉字/英文/数字；缺“压、补、给、动、报、结”等简体字 | 选作菜单标题、Level 标题和剧情；中文缺字回退 |
| bahnschrift.ttf / Bahnschrift | 896 | 英文、数字，缺中文及部分全角符号 | 选作档案英文与数字；仅开发预览 |
| STXINWEI.TTF / STXinwei（华文新魏） | 7819 | 示例简体字覆盖较全，但展示书写感强 | 未使用，不作为长正文 |
| HARLOWSI.TTF / Harlow Solid Italic | 240 | 英文装饰连笔，不含中文 | 未使用，与工业档案风格不符 |
| Inkfree.ttf / Ink Free | 1050 | 英文手写，不含中文 | 未使用 |
| おそろしげ明朝.ttf / OsorosigeMincho | 16728 | 日系恐怖明朝，也缺部分简体字 | 作者页可核对 OFL；本阶段未同时混用第二种展示字体 |
| Kenney Future / Narrow | 各 214 | 英文/数字，无中文 | 未使用；包级/字体元数据许可冲突待核对 |

[侵食明朝作者页面](https://booth.pm/ja/items/8571086)明确声明 SIL OFL 1.1 与游戏嵌入方向；本地文件嵌入字段也写 OFL 1.1。[おそろしげ明朝作者页面](https://booth.pm/en/items/7204864)同样声明 OFL 1.1。发布时仍应附字体的完整许可与版权说明，核对本地文件版本；当前没有把一个网页摘要充当完整随包授权文件，因此新字体条目仍按开发预览处理。

Bahnschrift、Ink Free 的嵌入声明引用 Microsoft 产品使用条款；Harlow 写有 URW 版权，华文新魏写有 SinoType 版权。**本地有文件并不等于获得游戏分发权**；未取得适用的再分发/嵌入授权证明，本阶段不作发布许可确认。

正文使用 `SystemFont` 请求 Microsoft YaHei UI / Microsoft YaHei / Noto Sans CJK SC / WenQuanYi Micro Hei，通过操作系统选字体，不复制系统字体文件。选定的提供字体由 `FontVariation + SystemFont` 回退组合使用，不修改原 FontFile。没有为了使用所有字体而混搭。

## 音频

本地音频共 31 文件：用户新增的 13 首 OGG / 8 个实体 WAV、原 UI Pack 6 个 OGG、选用的正式目录 4 个交互音副本。实际采用 5 个独立音乐/环境文件、2 个实体 WAV、4 个 CC0 交互音；多个语义音效 ID 可复用同一个短音。

- 菜单：Beige_Nocturne_loop_L；开场/零层：hum_loop_L；六层：Mormo_loop_L；七层：DamplyDry_loop1_L；战斗：Unusable_Eyelid_loop_L。
- 原音频标签均写 `ARTIST=Crow Shade`，但多个不同文件都写 `TITLE=Mormo`，元数据不能独立证明每首来源。[作者 Senescence 页面](https://crowshade.itch.io/backrooms-senescence)允许作品内使用并限制原文件转售/Content ID，要求查看原包完整许可。当前本地未附该原包的完整许可，因此以上音乐仅本地预览，发布前补原文件来源和完整许可。
- 使用 Entity 1 / 5 作为猎犬/笑魇的本地预览声音。[juanjo_sound 作者页](https://juanjosound.itch.io/backrooms-entity-sound-effects)允许游戏/视频使用，禁止原音频独立转售。仍需确认本地文件版本与来源包相符；本阶段保留预览限制，记录署名“Entity sounds by juanjo_sound”。
- 按钮/悬停/出牌/抽牌/奖励/攻击/受击/防护/状态/CutOut 先用 Kenney 短音提供反馈。攻击、受击、防护与切出当前是**中性短音替代**，不声称已有完整专用战斗音效库。

## 生效范围与发布阻塞

既有 AssetCatalog 增加 `usage_scope=development_preview`；默认只有带 editor feature 的本地 Godot 运行启用。普通导出运行不加载这些字体/音频，缺字体回系统字体，缺声音静音。CC0 采用素材可正常使用。

此运行时限制**不等于已经完成发行包审计**：当前没有导出预设，正式打包前还必须排除待许可原文件、补完整许可/署名或更换资源，并实际验证无开发预览素材混入。项目现有的用户插画/AI 参考层沿用此前位置与默认回退，也需由项目所有者核对最终发布权利；本阶段未补造其来源证明。
