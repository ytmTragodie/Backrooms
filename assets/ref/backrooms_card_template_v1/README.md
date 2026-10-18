# 后室档案卡牌通用模板 v1（Godot 4）

这是**可重复使用的多卡模板**，不再绑定“应急手电”。5 种卡牌共享相同尺寸（750×1050）与图层坐标，差异由 `kind`、插画与数据决定。

## 快速查看
- `PREVIEW_5_CARDS.png`：5 种卡牌并排预览。
- `samples/*.png`：每张单独的组合预览（示例数字和文字在合成时才写入）。
- `LAYOUT_GUIDE.png`：透明布局定位参考。
- `godot_demo/`：可独立运行的 Godot 4 示例工程，内置 5 张卡、切换费用按钮。

## 真正可复用的图层
- `assets/background_grunge.png`：共用底板，不透明。
- `assets/frame_{item,skill,entity,event,location}.png`：5 类卡框，RGBA 透明（不含卡名/属性）。
- `assets/panel_name.png`、`panel_description.png`、`panel_stat.png`、`panel_type.png`：透明纸签与属性底座。
- `assets/cost_medallion.png`：无数字费用圆章。
- `assets/icon_*.png`：图标；只做图标，数字由引擎画。
- `assets/art_*.png`：5 张示例插画；可用任意图片替换。
- `assets/blank_ui_overlay.png`：组合好的空白 UI 层（注意没有插画）。

## 新增卡牌：只需 2 步
1. 把无文字的插画（推荐 660×540，或者更高分辨率同等比例）放进 `godot_demo/assets/`。
2. 在 `godot_demo/data/cards.json` 增加一个对象：`id`、`kind`、`name`、`cost`、`type`、`art`、`description`、`stats`（最多三个 `icon`+`value`）。

`kind` 取值：`item`、`skill`、`entity`、`event`、`location`。`art` 是 assets 目录中的文件名。

## Godot 使用
Godot 4 打开 `godot_demo/project.godot`，F6/F5 运行示例。卡牌的中文名称、费用、类型、描述和属性都是运行时 Label 动态渲染；点击“手电费用 -1 / +1”按钮验证数据变化，不修改任何 PNG。

## 质量和限制
- 通用美术层源自 AI 拼版的后期裁切和修补，边框/纸签是**近似透明化**，不是 AI 原生透明图层，适合原型验证。
- 样例插画从旧卡牌中央无标题区域裁切，可能保留部分 VHS 画面噪点；替换独立插画即可。
- 透明 PNG 本身不包含 Godot 场景逻辑；`godot_demo` 提供可运行示例。
- 未附带字体文件。Godot 若无法显示中文，请在项目中设置合法来源的中文字体资源（如思源黑体）。
- 数据数值仅用于展示排版，**不代表你游戏的正式机制与平衡设定**。
