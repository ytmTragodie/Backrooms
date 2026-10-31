# Phase 16E：待确认的安全清理清单

**没有删除原始 UI Pack/ref 文件。** 用户要求先审查并给出清单，确认后才删除，本阶段按此执行。

完整逐文件列表：[PHASE_16_CLEANUP_PLAN.json](PHASE_16_CLEANUP_PLAN.json)。可重跑 `tools/plan_reference_cleanup.py` 更新审计；该工具没有删除功能。

| 分类 | 拟删除数量（含导入旁文件） | 原因 |
| --- | ---: | --- |
| assets/ui_asset_pack | 400 | 原包已排除导入，实际采用的 8 项及许可已复制到正式目录；不再有生产引用 |
| assets/ref | 122 | 有字节相同正式副本的旧素材、旧示例工程、合成预览和其导入旁文件 |
| 合计 | 522，约 50.18 MiB | 仅提出，尚未执行 |

另外保留 10 项：ref 的导入隔离标记、README、layout.json、cards.example.json、LAYOUT_GUIDE.png，以及 5 个没有字节相同正式副本的独有原始叠层/边框。它们有参考/源文件价值，不因“没有运行时引用”就擅自认定无用。

生产依赖检查覆盖 scripts/scenes/data 的 res:// 引用及 AssetCatalog 清单（包含 fallback_path），结果：**对原包/ref 的实际生产路径引用为 0**。原始素材使用 `.gdignore` 隔离，只从正式复制位置加载。`.import` 和嵌套 Godot 示例不作为当前游戏的依赖。

尚不建议自动删除：来源不明的正式字体/音频、未接入的业务 Data、命名含混但独有的图标（如 aahp.png / thread.png）、未使用的原型卡牌美术。这些需要内容/许可选择，不以文件名或重复意图直接合并。

确认本清单后才可执行删除；执行前须再次检查工作区变更、正式副本 hash、实时引用与清单差异。任何新增引用或独有源文件都应从删除批次移出。
