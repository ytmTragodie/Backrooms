# Phase 12 素材清单与审计

> 当前 Phase 14 内容及新增缺图见 [PHASE_14_ASSETS.md](PHASE_14_ASSETS.md)。本文件保留 Phase 12 逐文件审计，不意味着旧 Objective/探索牌仍属于正式玩法。运行映射仍使用 assets/asset_manifest.json。

运行清单：`assets/asset_manifest.json`。素材优先级：专用主路径 → 明确 `fallback_path` → 内置 SVG；音频缺失静音，字体缺失使用 Godot/系统中文后备。**PLACEHOLDER 表示专用素材仍 missing，并非已完成美术。**

## 运行素材映射

| 稳定 ID | 实际/目标路径 | 分类／用途 | 实际尺寸；建议尺寸 | 格式；透明要求 | 状态 | 默认/说明 |
| --- | --- | --- | --- | --- | --- | --- |
| floor_level_0 | `res://assets/backgrounds/level_0/background.png` | 背景／0层背景 | 660×540；1920×1080 | PNG；透明：否 | PROVIDED | `内建默认`；提供的 660×540 零层示例图；安全裁切铺满，后续可换宽幅图。 |
| floor_level_6 | `res://assets/backgrounds/level_6/background.png` | 背景／6层背景 | 2720×1520；1920×1080 | PNG；透明：否 | PROVIDED | `内建默认`；开发者主资源目录提供；已检查编码/尺寸，动态数值仍由当前规则绘制。 |
| event_level0_humming | `res://assets/cards/events/event_level0_humming.png` | 事件／异常嗡鸣 | 缺失；512×768 | PNG；透明：否 | PLACEHOLDER | `res://assets/cards/default-cardcover.png`；保持文字区域干净；文字由界面绘制。 当前使用明确默认素材；专用最终素材仍缺失。 |
| event_level0_meg_signal | `res://assets/cards/events/event_level0_meg_signal.png` | 事件／M.E.G. 断续信号 | 缺失；512×768 | PNG；透明：否 | PLACEHOLDER | `res://assets/cards/default-cardcover.png`；保持文字区域干净；文字由界面绘制。 当前使用明确默认素材；专用最终素材仍缺失。 |
| event_level6_claw_marks | `res://assets/cards/events/event_level6_claw_marks.png` | 事件／远处抓挠声 | 缺失；512×768 | PNG；透明：否 | PLACEHOLDER | `res://assets/cards/default-cardcover.png`；保持文字区域干净；文字由界面绘制。 当前使用明确默认素材；专用最终素材仍缺失。 |
| event_level6_dark_movement | `res://assets/cards/events/event_level6_dark_movement.png` | 事件／黑暗中的动静 | 缺失；512×768 | PNG；透明：否 | PLACEHOLDER | `res://assets/cards/default-cardcover.png`；保持文字区域干净；文字由界面绘制。 当前使用明确默认素材；专用最终素材仍缺失。 |
| event_level6_fading_light | `res://assets/cards/events/event_level6_fading_light.png` | 事件／灯光衰减 | 缺失；512×768 | PNG；透明：否 | PLACEHOLDER | `res://assets/cards/default-cardcover.png`；保持文字区域干净；文字由界面绘制。 当前使用明确默认素材；专用最终素材仍缺失。 |
| event_level6_stable_broadcast | `res://assets/cards/events/event_level6_stable_broadcast.png` | 事件／临时稳定广播 | 缺失；512×768 | PNG；透明：否 | PLACEHOLDER | `res://assets/cards/default-cardcover.png`；保持文字区域干净；文字由界面绘制。 当前使用明确默认素材；专用最终素材仍缺失。 |
| objective_level0_damp_wall | `res://assets/cards/objectives/objective_level0_damp_wall.png` | 目标／受潮补给箱 | 缺失；512×768 | PNG；透明：否 | PLACEHOLDER | `res://assets/cards/default-cardcover.png`；保持文字区域干净；文字由界面绘制。 当前使用明确默认素材；专用最终素材仍缺失。 |
| objective_level0_wrong_corner | `res://assets/cards/objectives/objective_level0_wrong_corner.png` | 目标／空间裂隙 | 缺失；512×768 | PNG；透明：否 | PLACEHOLDER | `res://assets/cards/default-cardcover.png`；保持文字区域干净；文字由界面绘制。 当前使用明确默认素材；专用最终素材仍缺失。 |
| objective_level6_emergency_light | `res://assets/cards/objectives/objective_level6_emergency_light.png` | 目标／应急发电机 | 缺失；512×768 | PNG；透明：否 | PLACEHOLDER | `res://assets/cards/default-cardcover.png`；保持文字区域干净；文字由界面绘制。 当前使用明确默认素材；专用最终素材仍缺失。 |
| objective_level6_wall_seam | `res://assets/cards/objectives/objective_level6_wall_seam.png` | 目标／呼吸的墙缝 | 缺失；512×768 | PNG；透明：否 | PLACEHOLDER | `res://assets/cards/default-cardcover.png`；保持文字区域干净；文字由界面绘制。 当前使用明确默认素材；专用最终素材仍缺失。 |
| entity_hound | `res://assets/cards/entities/entity_hound.png` | 实体／猎犬 | 2048×1152；512×768 | PNG；透明：否 | PROVIDED | `内建默认`；参考包提供；运行时动态文字，不使用示例数值。 |
| entity_smiler | `res://assets/cards/entities/entity_smiler.png` | 实体／笑魇 | 2720×1520；512×768 | PNG；透明：否 | PROVIDED | `内建默认`；参考包提供；运行时动态文字，不使用示例数值。 |
| portrait_hound | `res://assets/entities/hound.png` | 实体立绘／hound独立立绘 | 2048×1152；1024×1024 | PNG；透明：是 | PROVIDED | `内建样式/无叠层`；透明背景；不含文字。 |
| portrait_smiler | `res://assets/entities/smiler.png` | 实体立绘／smiler独立立绘 | 2720×1520；1024×1024 | PNG；透明：是 | PROVIDED | `内建样式/无叠层`；透明背景；不含文字。 |
| frame_player | `res://assets/ui/frames/player.png` | 界面／玩家牌框 | 750×1050；512×768 | PNG；透明：是 | PROVIDED | `内建默认`；参考包提供；运行时动态文字，不使用示例数值。 |
| frame_event | `res://assets/ui/frames/event.png` | 界面／事件牌框 | 750×1050；512×768 | PNG；透明：是 | PROVIDED | `内建默认`；参考包提供；运行时动态文字，不使用示例数值。 |
| frame_entity | `res://assets/ui/frames/entity.png` | 界面／实体牌框 | 750×1050；512×768 | PNG；透明：是 | PROVIDED | `内建默认`；参考包提供；运行时动态文字，不使用示例数值。 |
| frame_objective | `res://assets/ui/frames/objective.png` | 界面／目标牌框 | 750×1050；512×768 | PNG；透明：是 | PROVIDED | `内建默认`；参考包提供；运行时动态文字，不使用示例数值。 |
| icon_hp | `res://assets/ui/icons/hp.png` | 图标／生命 | 200×200；64×64 | PNG；透明：是 | PROVIDED | `内建默认`；参考包提供；运行时动态文字，不使用示例数值。 |
| icon_stress | `res://assets/ui/icons/stress.png` | 图标／压力 | 200×200；64×64 | PNG；透明：是 | PROVIDED | `内建默认`；开发者主资源目录提供；已检查编码/尺寸，动态数值仍由当前规则绘制。 |
| icon_threat | `res://assets/ui/icons/threat.png` | 图标／威胁 | 64×64；64×64 | PNG；透明：是 | PROVIDED | `内建默认`；参考包提供；运行时动态文字，不使用示例数值。 |
| icon_cognition | `res://assets/ui/icons/cognition.png` | 图标／认知 | 64×64；64×64 | PNG；透明：是 | PROVIDED | `内建默认`；开发者主资源目录提供；已检查编码/尺寸，动态数值仍由当前规则绘制。 |
| icon_ap | `res://assets/ui/icons/ap.png` | 图标／行动点 | 200×200；64×64 | PNG；透明：是 | PROVIDED | `内建默认`；开发者主资源目录提供；已检查编码/尺寸，动态数值仍由当前规则绘制。 |
| icon_guard | `res://assets/ui/icons/guard.png` | 图标／防护 | 64×64；64×64 | PNG；透明：是 | PROVIDED | `内建默认`；参考包提供；运行时动态文字，不使用示例数值。 |
| icon_light | `res://assets/ui/icons/light.png` | 图标／光照 | 64×64；64×64 | PNG；透明：是 | PROVIDED | `内建默认`；参考包提供；运行时动态文字，不使用示例数值。 |
| icon_noise | `res://assets/ui/icons/noise.png` | 图标／噪音 | 64×64；64×64 | PNG；透明：是 | PROVIDED | `内建默认`；开发者主资源目录提供；已检查编码/尺寸，动态数值仍由当前规则绘制。 |
| icon_retain | `res://assets/ui/icons/retain.png` | 图标／保留 | 64×64；64×64 | PNG；透明：是 | PROVIDED | `内建默认`；开发者主资源目录提供；已检查编码/尺寸，动态数值仍由当前规则绘制。 |
| icon_exhaust | `res://assets/ui/icons/exhaust.png` | 图标／消耗 | 缺失；64×64 | PNG；透明：是 | PLACEHOLDER | `res://assets/defaults/icon_arrow.png`；透明背景，单色轮廓，在小尺寸可辨。 当前使用明确默认素材；专用最终素材仍缺失。 |
| button_primary | `res://assets/ui/buttons/primary_background.png` | 界面／主要按钮 | 缺失；320×80 | PNG；透明：否 | MISSING | `内建样式/无叠层`；原 primary.png 为箭头图标而非按钮底板，未强行映射；当前按钮使用内建皮肤。 |
| fx_vhs_noise | `res://assets/ui/overlays/vhs_noise.png` | 特效／录像噪点 | 缺失；1920×1080 | PNG；透明：是 | MISSING | `内建样式/无叠层`；透明叠加，无最终 shader/动画。 |
| fx_damage_flash | `res://assets/fx/damage_flash.png` | 特效／受伤闪光 | 缺失；1920×1080 | PNG；透明：是 | MISSING | `内建样式/无叠层`；透明叠加，无最终 shader/动画。 |
| fx_card_highlight | `res://assets/fx/card_highlight.png` | 特效／手牌高亮 | 缺失；512×768 | PNG；透明：是 | MISSING | `内建样式/无叠层`；透明叠加，无最终 shader/动画。 |
| fx_target_highlight | `res://assets/fx/target_highlight.png` | 特效／目标高亮 | 缺失；512×768 | PNG；透明：是 | MISSING | `内建样式/无叠层`；透明叠加，无最终 shader/动画。 |
| ambience_level_0 | `res://assets/audio/ambience/level_0.ogg` | 音频／0层循环环境 | 缺失；30–60秒 | OGG；透明：不适用 | MISSING | `静音`；可循环，无首尾爆音；低音量。 |
| ambience_level_6 | `res://assets/audio/ambience/level_6.ogg` | 音频／6层循环环境 | 缺失；30–60秒 | OGG；透明：不适用 | MISSING | `静音`；可循环，无首尾爆音；低音量。 |
| audio_card_play | `res://assets/audio/sfx/card_play.ogg` | 音频／出牌 | 缺失；0.2–3秒 | OGG/WAV；透明：不适用 | MISSING | `静音`；短音效，峰值留余量。 |
| audio_hound | `res://assets/audio/sfx/hound.ogg` | 音频／猎犬预警 | 缺失；0.2–3秒 | OGG/WAV；透明：不适用 | MISSING | `静音`；短音效，峰值留余量。 |
| audio_smiler | `res://assets/audio/sfx/smiler.ogg` | 音频／笑魇预警 | 缺失；0.2–3秒 | OGG/WAV；透明：不适用 | MISSING | `静音`；短音效，峰值留余量。 |
| audio_cutout | `res://assets/audio/sfx/cutout.ogg` | 音频／切出 | 缺失；0.2–3秒 | OGG/WAV；透明：不适用 | MISSING | `静音`；短音效，峰值留余量。 |
| audio_event | `res://assets/audio/sfx/event.ogg` | 音频／事件入场 | 缺失；0.2–3秒 | OGG/WAV；透明：不适用 | MISSING | `静音`；短音效，峰值留余量。 |
| audio_omen | `res://assets/audio/sfx/omen.ogg` | 音频／前兆倒计时 | 缺失；0.2–3秒 | OGG/WAV；透明：不适用 | MISSING | `静音`；短音效，峰值留余量。 |
| audio_button_click | `res://assets/audio/ui/button_click.ogg` | 音频／按钮点击 | 缺失；0.2–3秒 | OGG/WAV；透明：不适用 | MISSING | `静音`；短音效，峰值留余量。 |
| card_attack | `res://assets/cards/player/card_attack.png` | 玩家牌／攻击 | 1280×1920；512×768 | PNG；透明：否 | PROVIDED | `内建默认`；参考包提供；运行时动态文字，不使用示例数值。 |
| card_deep_search | `res://assets/cards/player/card_deep_search.png` | 玩家牌／深入搜索 | 缺失；512×768 | PNG；透明：否 | PLACEHOLDER | `res://assets/cards/default-cardcover.png`；保持文字区域干净；文字由界面绘制。 当前使用明确默认素材；专用最终素材仍缺失。 |
| card_defend | `res://assets/cards/player/card_defend.png` | 玩家牌／防御 | 1280×1920；512×768 | PNG；透明：否 | PROVIDED | `内建默认`；开发者主资源目录提供；已检查编码/尺寸，动态数值仍由当前规则绘制。 |
| card_observe | `res://assets/cards/player/card_observe.png` | 玩家牌／观察 | 1664×2496；512×768 | PNG；透明：否 | PROVIDED | `内建默认`；开发者主资源目录提供；已检查编码/尺寸，动态数值仍由当前规则绘制。 |
| card_run | `res://assets/cards/player/card_run.png` | 玩家牌／奔跑 | 1664×2496；512×768 | PNG；透明：否 | PROVIDED | `内建默认`；开发者主资源目录提供；已检查编码/尺寸，动态数值仍由当前规则绘制。 |
| card_search | `res://assets/cards/player/card_search.png` | 玩家牌／搜索 | 缺失；512×768 | PNG；透明：否 | PLACEHOLDER | `res://assets/cards/default-cardcover.png`；保持文字区域干净；文字由界面绘制。 当前使用明确默认素材；专用最终素材仍缺失。 |
| card_equipment_crowbar | `res://assets/cards/player/card_crowbar.png` | 玩家牌／撬棍猛击 | 2048×2048；512×768 | PNG；透明：否 | PROVIDED | `内建默认`；参考包提供；运行时动态文字，不使用示例数值。 |
| card_floor_cutout_rushed | `res://assets/cards/player/card_cutout_rushed.png` | 玩家牌／仓促切出 | 2048×2048；512×768 | PNG；透明：否 | PROVIDED | `内建默认`；参考包提供；运行时动态文字，不使用示例数值。 |
| card_floor_cutout_safe | `res://assets/cards/player/card_cutout_safe.png` | 玩家牌／安全切出 | 2048×2048；512×768 | PNG；透明：否 | PROVIDED | `内建默认`；参考包提供；运行时动态文字，不使用示例数值。 |
| card_equipment_extinguish | `res://assets/cards/player/card_extinguish.png` | 玩家牌／熄灯 | 365×392；512×768 | PNG；透明：否 | PROVIDED | `内建默认`；参考包提供；运行时动态文字，不使用示例数值。 |
| card_equipment_light | `res://assets/cards/player/card_light.png` | 玩家牌／照明 | 365×392；512×768 | PNG；透明：否 | PROVIDED | `内建默认`；参考包提供；运行时动态文字，不使用示例数值。 |
| card_equipment_water | `res://assets/cards/player/card_water.png` | 玩家牌／饮用杏仁水 | 549×359；512×768 | PNG；透明：否 | PROVIDED | `内建默认`；参考包提供；运行时动态文字，不使用示例数值。 |
| card_careful_observe | `res://assets/cards/player/card_careful_observe.png` | 玩家牌／仔细观察 | 1664×2496；512×768 | PNG；透明：否 | PROVIDED | `内建默认`；开发者提供的仔细检查插画，用于同属观察语义的仔细观察；正式数值由 CardData 决定。 |
| card_counter_strike | `res://assets/cards/player/card_counter_strike.png` | 玩家牌／防守反击 | 缺失；512×768 | PNG；透明：否 | PLACEHOLDER | `res://assets/cards/default-cardcover.png`；保持文字区域干净；文字由界面绘制。 当前使用明确默认素材；专用最终素材仍缺失。 |
| card_crisis_observe | `res://assets/cards/player/card_crisis_observe.png` | 玩家牌／临危调查 | 缺失；512×768 | PNG；透明：否 | PLACEHOLDER | `res://assets/cards/default-cardcover.png`；保持文字区域干净；文字由界面绘制。 当前使用明确默认素材；专用最终素材仍缺失。 |
| card_exploit_weakness | `res://assets/cards/player/card_exploit_weakness.png` | 玩家牌／洞悉弱点 | 缺失；512×768 | PNG；透明：否 | PLACEHOLDER | `res://assets/cards/default-cardcover.png`；保持文字区域干净；文字由界面绘制。 当前使用明确默认素材；专用最终素材仍缺失。 |
| card_heavy_strike | `res://assets/cards/player/card_heavy_strike.png` | 玩家牌／有力打击 | 缺失；512×768 | PNG；透明：否 | PLACEHOLDER | `res://assets/cards/default-cardcover.png`；保持文字区域干净；文字由界面绘制。 当前使用明确默认素材；专用最终素材仍缺失。 |
| card_reckless_strike | `res://assets/cards/player/card_reckless_strike.png` | 玩家牌／鲁莽猛击 | 缺失；512×768 | PNG；透明：否 | PLACEHOLDER | `res://assets/cards/default-cardcover.png`；保持文字区域干净；文字由界面绘制。 当前使用明确默认素材；专用最终素材仍缺失。 |
| card_risky_search | `res://assets/cards/player/card_risky_search.png` | 玩家牌／冒险搜寻 | 缺失；512×768 | PNG；透明：否 | PLACEHOLDER | `res://assets/cards/default-cardcover.png`；保持文字区域干净；文字由界面绘制。 当前使用明确默认素材；专用最终素材仍缺失。 |
| card_steady_guard | `res://assets/cards/player/card_steady_guard.png` | 玩家牌／稳固防御 | 缺失；512×768 | PNG；透明：否 | PLACEHOLDER | `res://assets/cards/default-cardcover.png`；保持文字区域干净；文字由界面绘制。 当前使用明确默认素材；专用最终素材仍缺失。 |
| card_thorough_search | `res://assets/cards/player/card_thorough_search.png` | 玩家牌／严密搜索 | 缺失；512×768 | PNG；透明：否 | PLACEHOLDER | `res://assets/cards/default-cardcover.png`；保持文字区域干净；文字由界面绘制。 当前使用明确默认素材；专用最终素材仍缺失。 |
| frame_equipment | `res://assets/ui/frames/equipment.png` | 界面／装备行动牌框 | 750×1050；按提供尺寸 | PNG；透明：是 | PROVIDED | `内建默认`；参考包提供；运行时动态文字，不使用示例数值。 |
| ui_card_background | `res://assets/ui/overlays/card_paper.png` | 界面／共用旧纸卡底 | 750×1050；按提供尺寸 | PNG；透明：否 | PROVIDED | `内建默认`；参考包提供；运行时动态文字，不使用示例数值。 |
| ui_cost | `res://assets/ui/icons/cost_medallion.png` | 界面／行动点费用圆章 | 116×116；按提供尺寸 | PNG；透明：是 | PROVIDED | `内建默认`；参考包提供；运行时动态文字，不使用示例数值。 |
| ui_name_panel | `res://assets/ui/frames/name_panel.png` | 界面／名称纸签 | 624×106；按提供尺寸 | PNG；透明：是 | PROVIDED | `内建默认`；参考包提供；运行时动态文字，不使用示例数值。 |
| ui_description_panel | `res://assets/ui/frames/description_panel.png` | 界面／效果纸签 | 624×180；按提供尺寸 | PNG；透明：是 | PROVIDED | `内建默认`；参考包提供；运行时动态文字，不使用示例数值。 |
| ui_stat_panel | `res://assets/ui/frames/stat_panel.png` | 界面／属性底座 | 194×95；按提供尺寸 | PNG；透明：是 | PROVIDED | `内建默认`；参考包提供；运行时动态文字，不使用示例数值。 |
| ui_type_panel | `res://assets/ui/frames/type_panel.png` | 界面／分类底座 | 145×69；按提供尺寸 | PNG；透明：是 | PROVIDED | `内建默认`；参考包提供；运行时动态文字，不使用示例数值。 |
| icon_search | `res://assets/ui/icons/search.png` | 界面／icon_search | 64×64；按提供尺寸 | PNG；透明：是 | PROVIDED | `内建默认`；参考包提供；运行时动态文字，不使用示例数值。 |
| ui_default_art | `res://assets/cards/default-cardcover.png` | 默认插画／缺少专用插画时的中性默认封面 | 2048×2048；2048×2048 | PNG；透明：否 | PROVIDED | `内建默认`；开发者提供；不能把徽记猜测成新阵营或新玩法。 |
| font_chinese | `res://assets/ui/fonts/chinese_regular.ttf` | 字体／可选专用中文界面字体 | 缺失；正文14–18px清晰 | TTF/OTF；透明：不适用 | MISSING | `内建默认`；当前使用 Godot/系统中文后备字体；字体文件后续放入此路径即可替换。 |

## Missing：按 P0 / P1 / P2 收集

以下每行均缺少专用文件；当前默认已经接入，不阻止运行。路径固定，不需要修改玩法代码。

### P0 — 当前画面的一致性

| 名称 / ID | 目标路径 | 建议尺寸 | 格式 | 透明 | 期望视觉内容 |
| --- | --- | --- | --- | --- | --- |
| 受潮补给箱 / objective_level0_damp_wall | `res://assets/cards/objectives/objective_level0_damp_wall.png` | 512×768 | PNG | 否 | 零层受潮的有限补给箱，无文字 |
| 空间裂隙 / objective_level0_wrong_corner | `res://assets/cards/objectives/objective_level0_wrong_corner.png` | 512×768 | PNG | 否 | 零层错位转角中的空间裂隙，无人物 UI |
| 应急发电机 / objective_level6_emergency_light | `res://assets/cards/objectives/objective_level6_emergency_light.png` | 512×768 | PNG | 否 | 黑暗环境中的故障应急发电机及线路 |
| 呼吸的墙缝 / objective_level6_wall_seam | `res://assets/cards/objectives/objective_level6_wall_seam.png` | 512×768 | PNG | 否 | 黑暗墙体中按节奏张开的缝隙 |
| 深入搜索 / card_deep_search | `res://assets/cards/player/card_deep_search.png` | 512×768 | PNG | 否 | 深入隐蔽处搜索，表现更高风险 |
| 搜索 / card_search | `res://assets/cards/player/card_search.png` | 512×768 | PNG | 否 | 搜查遗留物或检查补给容器 |

### P1 — 重要完善

| 名称 / ID | 目标路径 | 建议尺寸 | 格式 | 透明 | 期望视觉内容 |
| --- | --- | --- | --- | --- | --- |
| 异常嗡鸣 / event_level0_humming | `res://assets/cards/events/event_level0_humming.png` | 512×768 | PNG | 否 | 异常嗡鸣；保持文字区域干净；文字由界面绘制 |
| M.E.G. 断续信号 / event_level0_meg_signal | `res://assets/cards/events/event_level0_meg_signal.png` | 512×768 | PNG | 否 | M.E.G. 断续信号；保持文字区域干净；文字由界面绘制 |
| 远处抓挠声 / event_level6_claw_marks | `res://assets/cards/events/event_level6_claw_marks.png` | 512×768 | PNG | 否 | 远处抓挠声；保持文字区域干净；文字由界面绘制 |
| 黑暗中的动静 / event_level6_dark_movement | `res://assets/cards/events/event_level6_dark_movement.png` | 512×768 | PNG | 否 | 黑暗中的动静；保持文字区域干净；文字由界面绘制 |
| 灯光衰减 / event_level6_fading_light | `res://assets/cards/events/event_level6_fading_light.png` | 512×768 | PNG | 否 | 灯光衰减；保持文字区域干净；文字由界面绘制 |
| 临时稳定广播 / event_level6_stable_broadcast | `res://assets/cards/events/event_level6_stable_broadcast.png` | 512×768 | PNG | 否 | 临时稳定广播；保持文字区域干净；文字由界面绘制 |
| 0层循环环境 / ambience_level_0 | `res://assets/audio/ambience/level_0.ogg` | 30–60秒 | OGG | 不适用 | 0层循环环境；可循环，无首尾爆音；低音量 |
| 6层循环环境 / ambience_level_6 | `res://assets/audio/ambience/level_6.ogg` | 30–60秒 | OGG | 不适用 | 6层循环环境；可循环，无首尾爆音；低音量 |
| 出牌 / audio_card_play | `res://assets/audio/sfx/card_play.ogg` | 0.2–3秒 | OGG/WAV | 不适用 | 出牌；短音效，峰值留余量 |
| 猎犬预警 / audio_hound | `res://assets/audio/sfx/hound.ogg` | 0.2–3秒 | OGG/WAV | 不适用 | 猎犬预警；短音效，峰值留余量 |
| 笑魇预警 / audio_smiler | `res://assets/audio/sfx/smiler.ogg` | 0.2–3秒 | OGG/WAV | 不适用 | 笑魇预警；短音效，峰值留余量 |
| 切出 / audio_cutout | `res://assets/audio/sfx/cutout.ogg` | 0.2–3秒 | OGG/WAV | 不适用 | 切出；短音效，峰值留余量 |
| 事件入场 / audio_event | `res://assets/audio/sfx/event.ogg` | 0.2–3秒 | OGG/WAV | 不适用 | 事件入场；短音效，峰值留余量 |
| 前兆倒计时 / audio_omen | `res://assets/audio/sfx/omen.ogg` | 0.2–3秒 | OGG/WAV | 不适用 | 前兆倒计时；短音效，峰值留余量 |
| 按钮点击 / audio_button_click | `res://assets/audio/ui/button_click.ogg` | 0.2–3秒 | OGG/WAV | 不适用 | 按钮点击；短音效，峰值留余量 |
| 防守反击 / card_counter_strike | `res://assets/cards/player/card_counter_strike.png` | 512×768 | PNG | 否 | 防守反击；保持文字区域干净；文字由界面绘制 |
| 临危调查 / card_crisis_observe | `res://assets/cards/player/card_crisis_observe.png` | 512×768 | PNG | 否 | 临危调查；保持文字区域干净；文字由界面绘制 |
| 洞悉弱点 / card_exploit_weakness | `res://assets/cards/player/card_exploit_weakness.png` | 512×768 | PNG | 否 | 洞悉弱点；保持文字区域干净；文字由界面绘制 |
| 有力打击 / card_heavy_strike | `res://assets/cards/player/card_heavy_strike.png` | 512×768 | PNG | 否 | 有力打击；保持文字区域干净；文字由界面绘制 |
| 鲁莽猛击 / card_reckless_strike | `res://assets/cards/player/card_reckless_strike.png` | 512×768 | PNG | 否 | 鲁莽猛击；保持文字区域干净；文字由界面绘制 |
| 冒险搜寻 / card_risky_search | `res://assets/cards/player/card_risky_search.png` | 512×768 | PNG | 否 | 冒险搜寻；保持文字区域干净；文字由界面绘制 |
| 稳固防御 / card_steady_guard | `res://assets/cards/player/card_steady_guard.png` | 512×768 | PNG | 否 | 稳固防御；保持文字区域干净；文字由界面绘制 |
| 严密搜索 / card_thorough_search | `res://assets/cards/player/card_thorough_search.png` | 512×768 | PNG | 否 | 严密搜索；保持文字区域干净；文字由界面绘制 |
| 可选专用中文界面字体 / font_chinese | `res://assets/ui/fonts/chinese_regular.ttf` | 正文14–18px清晰 | TTF/OTF | 不适用 | 可选专用中文界面字体；当前使用 Godot/系统中文后备字体；字体文件后续放入此路径即可替换 |

### P2 — 后续可选细化

| 名称 / ID | 目标路径 | 建议尺寸 | 格式 | 透明 | 期望视觉内容 |
| --- | --- | --- | --- | --- | --- |
| 消耗 / icon_exhaust | `res://assets/ui/icons/exhaust.png` | 64×64 | PNG | 是 | 消耗；透明背景，单色轮廓，在小尺寸可辨 |
| 主要按钮 / button_primary | `res://assets/ui/buttons/primary_background.png` | 320×80 | PNG | 否 | 主要按钮；原 primary.png 为箭头图标而非按钮底板，未强行映射；当前按钮使用内建皮肤 |
| 录像噪点 / fx_vhs_noise | `res://assets/ui/overlays/vhs_noise.png` | 1920×1080 | PNG | 是 | 录像噪点；透明叠加，无最终 shader/动画 |
| 受伤闪光 / fx_damage_flash | `res://assets/fx/damage_flash.png` | 1920×1080 | PNG | 是 | 受伤闪光；透明叠加，无最终 shader/动画 |
| 手牌高亮 / fx_card_highlight | `res://assets/fx/card_highlight.png` | 512×768 | PNG | 是 | 手牌高亮；透明叠加，无最终 shader/动画 |
| 目标高亮 / fx_target_highlight | `res://assets/fx/target_highlight.png` | 512×768 | PNG | 是 | 目标高亮；透明叠加，无最终 shader/动画 |

## 全部文件审计

已检查全部实际图像（包含参考包、重复副本、默认和旧占位），逐项记录在 [ASSET_AUDIT_PHASE_12.json](ASSET_AUDIT_PHASE_12.json)。下表列实际尺寸、透明性、状态、分配情况；重复关系和 SHA256 在 JSON。

| 稳定审计 ID | 实际文件路径 | 尺寸 / 编码 | 透明 | 状态 / 分配 | 用途 / 备注 |
| --- | --- | --- | --- | --- | --- |
| floor_level_0 | `res://assets/backgrounds/level_0/background.png` | [660, 540] / PNG | 否 | PROVIDED / MAPPED | 运行素材 |
| floor_level_6 | `res://assets/backgrounds/level_6/background.png` | [2720, 1520] / PNG | 否 | PROVIDED / MAPPED | 运行素材 |
| ui_default_art | `res://assets/cards/default-cardcover.png` | [2048, 2048] / PNG | 否 | PROVIDED / MAPPED | 运行素材 |
| entity_hound | `res://assets/cards/entities/entity_hound.png` | [2048, 1152] / PNG | 否 | PROVIDED / MAPPED | 运行素材 |
| entity_smiler | `res://assets/cards/entities/entity_smiler.png` | [2720, 1520] / PNG | 否 | PROVIDED / MAPPED | 运行素材 |
| source_6b4b831d0693 | `res://assets/cards/events/art_hallway.png` | [660, 540] / PNG | 否 | UNUSED / REFERENCE_ONLY | 备选/重复/参考；不进入运行素材映射 |
| source_f7f0ffb930e0 | `res://assets/cards/events/art_listener.png` | [660, 540] / PNG | 否 | UNUSED / UNASSIGNED | 无法确认为当前领域/按钮用途；未擅自映射。 |
| card_attack | `res://assets/cards/player/card_attack.png` | [1280, 1920] / PNG | 否 | PROVIDED / MAPPED | 运行素材 |
| card_careful_observe | `res://assets/cards/player/card_careful_observe.png` | [1664, 2496] / PNG | 否 | PROVIDED / MAPPED | 运行素材 |
| card_equipment_crowbar | `res://assets/cards/player/card_crowbar.png` | [2048, 2048] / PNG | 否 | PROVIDED / MAPPED | 运行素材 |
| card_floor_cutout_rushed | `res://assets/cards/player/card_cutout_rushed.png` | [2048, 2048] / PNG | 否 | PROVIDED / MAPPED | 运行素材 |
| card_floor_cutout_safe | `res://assets/cards/player/card_cutout_safe.png` | [2048, 2048] / PNG | 否 | PROVIDED / MAPPED | 运行素材 |
| card_defend | `res://assets/cards/player/card_defend.png` | [1280, 1920] / PNG | 否 | PROVIDED / MAPPED | 运行素材 |
| card_equipment_extinguish | `res://assets/cards/player/card_extinguish.png` | [365, 392] / PNG | 否 | PROVIDED / MAPPED | 运行素材 |
| card_equipment_light | `res://assets/cards/player/card_light.png` | [365, 392] / PNG | 否 | PROVIDED / MAPPED | 运行素材 |
| card_observe | `res://assets/cards/player/card_observe.png` | [1664, 2496] / PNG | 否 | PROVIDED / MAPPED | 运行素材 |
| card_run | `res://assets/cards/player/card_run.png` | [1664, 2496] / PNG | 否 | PROVIDED / MAPPED | 运行素材 |
| card_equipment_water | `res://assets/cards/player/card_water.png` | [549, 359] / PNG | 否 | PROVIDED / MAPPED | 运行素材 |
| source_040e8093dbb8 | `res://assets/cards/player/行动-仔细检查.png` | [1664, 2496] / PNG | 否 | UNUSED / REFERENCE_ONLY | 备选/重复/参考；不进入运行素材映射 |
| source_c1bdbb79ac8c | `res://assets/cards/player/行动-挣扎.png` | [1664, 2496] / PNG | 否 | UNUSED / REFERENCE_ONLY | 备选/重复/参考；不进入运行素材映射 |
| source_a00e28582fff | `res://assets/defaults/art_flicker.png` | [660, 540] / PNG | 否 | UNUSED / REFERENCE_ONLY | 备选/重复/参考；不进入运行素材映射 |
| source_f35476a3ffc5 | `res://assets/defaults/art_hallway.png` | [660, 540] / PNG | 否 | UNUSED / REFERENCE_ONLY | 备选/重复/参考；不进入运行素材映射 |
| source_3150aba04937 | `res://assets/defaults/icon_alert.png` | [64, 64] / PNG | 是 | UNUSED / REFERENCE_ONLY | 备选/重复/参考；不进入运行素材映射 |
| source_97e29ee37183 | `res://assets/defaults/icon_arrow.png` | [64, 64] / PNG | 是 | PROVIDED / MAPPED | 默认替代：icon_exhaust |
| source_39e3950af2bc | `res://assets/defaults/icon_gear.png` | [64, 64] / PNG | 是 | UNUSED / REFERENCE_ONLY | 备选/重复/参考；不进入运行素材映射 |
| source_fbd7d52f3195 | `res://assets/defaults/icon_search.png` | [64, 64] / PNG | 是 | UNUSED / REFERENCE_ONLY | 备选/重复/参考；不进入运行素材映射 |
| source_905f43f6f6c5 | `res://assets/defaults/icon_shield.png` | [64, 64] / PNG | 是 | UNUSED / REFERENCE_ONLY | 备选/重复/参考；不进入运行素材映射 |
| source_babc44f9b284 | `res://assets/defaults/icon_stack.png` | [64, 64] / PNG | 是 | UNUSED / REFERENCE_ONLY | 备选/重复/参考；不进入运行素材映射 |
| portrait_hound | `res://assets/entities/hound.png` | [2048, 1152] / PNG | 否 | PROVIDED / MAPPED | 运行素材 |
| portrait_smiler | `res://assets/entities/smiler.png` | [2720, 1520] / PNG | 否 | PROVIDED / MAPPED | 运行素材 |
| source_57cc36b8ba32 | `res://assets/placeholders/background.svg` | ['1152', '648'] / SVG | 是 | PLACEHOLDER / REFERENCE_ONLY | 确定性引擎回退，最终素材仍可缺失 |
| source_b9f026f7d5a5 | `res://assets/placeholders/card.svg` | ['128', '192'] / SVG | 是 | PLACEHOLDER / REFERENCE_ONLY | 确定性引擎回退，最终素材仍可缺失 |
| source_0fb19ec92ac8 | `res://assets/placeholders/frame.svg` | ['128', '192'] / SVG | 是 | PLACEHOLDER / REFERENCE_ONLY | 确定性引擎回退，最终素材仍可缺失 |
| source_6c12ee976d43 | `res://assets/placeholders/icon.svg` | ['64', '64'] / SVG | 是 | PLACEHOLDER / REFERENCE_ONLY | 确定性引擎回退，最终素材仍可缺失 |
| source_ac8e216dd53e | `res://assets/ref/backrooms_card_template_v1/assets/art_flashlight.png` | [365, 392] / PNG | 否 | UNUSED / REFERENCE_ONLY | 备选/重复/参考；不进入运行素材映射 |
| source_353032bdc3ac | `res://assets/ref/backrooms_card_template_v1/assets/art_flicker.png` | [660, 540] / PNG | 否 | UNUSED / REFERENCE_ONLY | 备选/重复/参考；不进入运行素材映射 |
| source_3a5f040f40d5 | `res://assets/ref/backrooms_card_template_v1/assets/art_hallway.png` | [660, 540] / PNG | 否 | UNUSED / REFERENCE_ONLY | 备选/重复/参考；不进入运行素材映射 |
| source_31812a942200 | `res://assets/ref/backrooms_card_template_v1/assets/art_level0.png` | [660, 540] / PNG | 否 | UNUSED / REFERENCE_ONLY | 备选/重复/参考；不进入运行素材映射 |
| source_5a4bf6545334 | `res://assets/ref/backrooms_card_template_v1/assets/background_grunge.png` | [750, 1050] / PNG | 否 | UNUSED / REFERENCE_ONLY | 备选/重复/参考；不进入运行素材映射 |
| source_0ed0542ba814 | `res://assets/ref/backrooms_card_template_v1/assets/blank_ui_overlay.png` | [750, 1050] / PNG | 是 | UNUSED / REFERENCE_ONLY | 备选/重复/参考；不进入运行素材映射 |
| source_b0fed19ecfcd | `res://assets/ref/backrooms_card_template_v1/assets/cost_medallion.png` | [116, 116] / PNG | 是 | UNUSED / REFERENCE_ONLY | 备选/重复/参考；不进入运行素材映射 |
| source_b2e54af41f09 | `res://assets/ref/backrooms_card_template_v1/assets/frame_entity.png` | [750, 1050] / PNG | 是 | UNUSED / REFERENCE_ONLY | 备选/重复/参考；不进入运行素材映射 |
| source_9294d60cf5cb | `res://assets/ref/backrooms_card_template_v1/assets/frame_entity_a.png` | [750, 1050] / PNG | 是 | UNUSED / REFERENCE_ONLY | 备选/重复/参考；不进入运行素材映射 |
| source_ce68e3bf124c | `res://assets/ref/backrooms_card_template_v1/assets/frame_event.png` | [750, 1050] / PNG | 是 | UNUSED / REFERENCE_ONLY | 备选/重复/参考；不进入运行素材映射 |
| source_8b715f280b52 | `res://assets/ref/backrooms_card_template_v1/assets/frame_event_a.png` | [750, 1050] / PNG | 是 | UNUSED / REFERENCE_ONLY | 备选/重复/参考；不进入运行素材映射 |
| source_319cd1be493d | `res://assets/ref/backrooms_card_template_v1/assets/frame_item.png` | [750, 1050] / PNG | 是 | UNUSED / REFERENCE_ONLY | 备选/重复/参考；不进入运行素材映射 |
| source_0ac1db3994d4 | `res://assets/ref/backrooms_card_template_v1/assets/frame_location.png` | [750, 1050] / PNG | 是 | UNUSED / REFERENCE_ONLY | 备选/重复/参考；不进入运行素材映射 |
| source_24c8c7f6b780 | `res://assets/ref/backrooms_card_template_v1/assets/frame_location_a.png` | [750, 1050] / PNG | 是 | UNUSED / REFERENCE_ONLY | 备选/重复/参考；不进入运行素材映射 |
| source_4f0de411fe04 | `res://assets/ref/backrooms_card_template_v1/assets/frame_skill.png` | [750, 1050] / PNG | 是 | UNUSED / REFERENCE_ONLY | 备选/重复/参考；不进入运行素材映射 |
| source_a3430d6e8d4b | `res://assets/ref/backrooms_card_template_v1/assets/frame_skill_a.png` | [750, 1050] / PNG | 是 | UNUSED / REFERENCE_ONLY | 备选/重复/参考；不进入运行素材映射 |
| source_c5ecef767f69 | `res://assets/ref/backrooms_card_template_v1/assets/icon_alert.png` | [64, 64] / PNG | 是 | UNUSED / REFERENCE_ONLY | 备选/重复/参考；不进入运行素材映射 |
| source_e0583bfd26c3 | `res://assets/ref/backrooms_card_template_v1/assets/icon_arrow.png` | [64, 64] / PNG | 是 | UNUSED / REFERENCE_ONLY | 备选/重复/参考；不进入运行素材映射 |
| source_e1d433472a59 | `res://assets/ref/backrooms_card_template_v1/assets/icon_event_category.png` | [64, 64] / PNG | 是 | UNUSED / REFERENCE_ONLY | 备选/重复/参考；不进入运行素材映射 |
| source_5f645767c500 | `res://assets/ref/backrooms_card_template_v1/assets/icon_flashlight.png` | [64, 64] / PNG | 是 | UNUSED / REFERENCE_ONLY | 备选/重复/参考；不进入运行素材映射 |
| source_1734c11cb3bc | `res://assets/ref/backrooms_card_template_v1/assets/icon_gear.png` | [64, 64] / PNG | 是 | UNUSED / REFERENCE_ONLY | 备选/重复/参考；不进入运行素材映射 |
| source_0ce35830fb3b | `res://assets/ref/backrooms_card_template_v1/assets/icon_heart.png` | [64, 64] / PNG | 是 | UNUSED / REFERENCE_ONLY | 备选/重复/参考；不进入运行素材映射 |
| source_129bcd92296b | `res://assets/ref/backrooms_card_template_v1/assets/icon_item_category.png` | [64, 64] / PNG | 是 | UNUSED / REFERENCE_ONLY | 备选/重复/参考；不进入运行素材映射 |
| source_43c11cefdfe5 | `res://assets/ref/backrooms_card_template_v1/assets/icon_search.png` | [64, 64] / PNG | 是 | UNUSED / REFERENCE_ONLY | 备选/重复/参考；不进入运行素材映射 |
| source_abccfda93975 | `res://assets/ref/backrooms_card_template_v1/assets/icon_shield.png` | [64, 64] / PNG | 是 | UNUSED / REFERENCE_ONLY | 备选/重复/参考；不进入运行素材映射 |
| source_546f589830c0 | `res://assets/ref/backrooms_card_template_v1/assets/icon_skill_category.png` | [64, 64] / PNG | 是 | UNUSED / REFERENCE_ONLY | 备选/重复/参考；不进入运行素材映射 |
| source_3905bce15439 | `res://assets/ref/backrooms_card_template_v1/assets/icon_stack.png` | [64, 64] / PNG | 是 | UNUSED / REFERENCE_ONLY | 备选/重复/参考；不进入运行素材映射 |
| source_fef0275b0022 | `res://assets/ref/backrooms_card_template_v1/assets/icon_status_category.png` | [64, 64] / PNG | 是 | UNUSED / REFERENCE_ONLY | 备选/重复/参考；不进入运行素材映射 |
| source_1f500d4453d0 | `res://assets/ref/backrooms_card_template_v1/assets/panel_description.png` | [624, 180] / PNG | 是 | UNUSED / REFERENCE_ONLY | 备选/重复/参考；不进入运行素材映射 |
| source_9908b4fbecb0 | `res://assets/ref/backrooms_card_template_v1/assets/panel_name.png` | [624, 106] / PNG | 是 | UNUSED / REFERENCE_ONLY | 备选/重复/参考；不进入运行素材映射 |
| source_6d28223c9c64 | `res://assets/ref/backrooms_card_template_v1/assets/panel_stat.png` | [194, 95] / PNG | 是 | UNUSED / REFERENCE_ONLY | 备选/重复/参考；不进入运行素材映射 |
| source_58210103c7b9 | `res://assets/ref/backrooms_card_template_v1/assets/panel_type.png` | [145, 69] / PNG | 是 | UNUSED / REFERENCE_ONLY | 备选/重复/参考；不进入运行素材映射 |
| source_3c6853fa05e3 | `res://assets/ref/backrooms_card_template_v1/assets/切出-仓促切出.png` | [2048, 2048] / PNG | 否 | UNUSED / REFERENCE_ONLY | 备选/重复/参考；不进入运行素材映射 |
| source_f8428c88498d | `res://assets/ref/backrooms_card_template_v1/assets/切出-安全切出.png` | [2048, 2048] / PNG | 否 | UNUSED / REFERENCE_ONLY | 备选/重复/参考；不进入运行素材映射 |
| source_410c7c6a59ea | `res://assets/ref/backrooms_card_template_v1/assets/实体-Hound.png` | [2048, 1152] / PNG | 否 | UNUSED / REFERENCE_ONLY | 备选/重复/参考；不进入运行素材映射 |
| source_f7f4ccf952c0 | `res://assets/ref/backrooms_card_template_v1/assets/实体：笑魇.png` | [2720, 1520] / PNG | 否 | UNUSED / REFERENCE_ONLY | 备选/重复/参考；不进入运行素材映射 |
| source_b90556459473 | `res://assets/ref/backrooms_card_template_v1/assets/物品-撬棍.png` | [2048, 2048] / PNG | 否 | UNUSED / REFERENCE_ONLY | 备选/重复/参考；不进入运行素材映射 |
| source_b886f757c098 | `res://assets/ref/backrooms_card_template_v1/assets/物品-杏仁水.png` | [549, 359] / PNG | 否 | UNUSED / REFERENCE_ONLY | 备选/重复/参考；不进入运行素材映射 |
| source_3e1344b1e9c2 | `res://assets/ref/backrooms_card_template_v1/assets/行动-挣扎.png` | [1664, 2496] / PNG | 否 | UNUSED / REFERENCE_ONLY | 备选/重复/参考；不进入运行素材映射 |
| source_b204a73ad818 | `res://assets/ref/backrooms_card_template_v1/godot_demo/assets/art_flashlight.png` | [365, 392] / PNG | 否 | UNUSED / REFERENCE_ONLY | 备选/重复/参考；不进入运行素材映射 |
| source_93c018f54ea0 | `res://assets/ref/backrooms_card_template_v1/godot_demo/assets/art_flicker.png` | [660, 540] / PNG | 否 | UNUSED / REFERENCE_ONLY | 备选/重复/参考；不进入运行素材映射 |
| source_ad94ca1d4c0b | `res://assets/ref/backrooms_card_template_v1/godot_demo/assets/art_hallway.png` | [660, 540] / PNG | 否 | UNUSED / REFERENCE_ONLY | 备选/重复/参考；不进入运行素材映射 |
| source_b509a81c3ae5 | `res://assets/ref/backrooms_card_template_v1/godot_demo/assets/art_level0.png` | [660, 540] / PNG | 否 | UNUSED / REFERENCE_ONLY | 备选/重复/参考；不进入运行素材映射 |
| source_173a3a4430e2 | `res://assets/ref/backrooms_card_template_v1/godot_demo/assets/art_listener.png` | [660, 540] / PNG | 否 | UNUSED / UNASSIGNED | 无法确认为当前领域/按钮用途；未擅自映射。 |
| source_5078c1190929 | `res://assets/ref/backrooms_card_template_v1/godot_demo/assets/background_grunge.png` | [750, 1050] / PNG | 否 | UNUSED / REFERENCE_ONLY | 备选/重复/参考；不进入运行素材映射 |
| source_1fddd10dc087 | `res://assets/ref/backrooms_card_template_v1/godot_demo/assets/blank_ui_overlay.png` | [750, 1050] / PNG | 是 | UNUSED / REFERENCE_ONLY | 备选/重复/参考；不进入运行素材映射 |
| source_8805374751e7 | `res://assets/ref/backrooms_card_template_v1/godot_demo/assets/cost_medallion.png` | [116, 116] / PNG | 是 | UNUSED / REFERENCE_ONLY | 备选/重复/参考；不进入运行素材映射 |
| source_14c0cb8f7323 | `res://assets/ref/backrooms_card_template_v1/godot_demo/assets/frame_entity.png` | [750, 1050] / PNG | 是 | UNUSED / REFERENCE_ONLY | 备选/重复/参考；不进入运行素材映射 |
| source_3d664f6e18f4 | `res://assets/ref/backrooms_card_template_v1/godot_demo/assets/frame_event.png` | [750, 1050] / PNG | 是 | UNUSED / REFERENCE_ONLY | 备选/重复/参考；不进入运行素材映射 |
| source_e69c9d0c5374 | `res://assets/ref/backrooms_card_template_v1/godot_demo/assets/frame_item.png` | [750, 1050] / PNG | 是 | UNUSED / REFERENCE_ONLY | 备选/重复/参考；不进入运行素材映射 |
| source_a74decc772d4 | `res://assets/ref/backrooms_card_template_v1/godot_demo/assets/frame_location.png` | [750, 1050] / PNG | 是 | UNUSED / REFERENCE_ONLY | 备选/重复/参考；不进入运行素材映射 |
| source_7fc2975317e5 | `res://assets/ref/backrooms_card_template_v1/godot_demo/assets/frame_skill.png` | [750, 1050] / PNG | 是 | UNUSED / REFERENCE_ONLY | 备选/重复/参考；不进入运行素材映射 |
| source_65f41764bd9e | `res://assets/ref/backrooms_card_template_v1/godot_demo/assets/icon_alert.png` | [64, 64] / PNG | 是 | UNUSED / REFERENCE_ONLY | 备选/重复/参考；不进入运行素材映射 |
| source_402715004b6c | `res://assets/ref/backrooms_card_template_v1/godot_demo/assets/icon_arrow.png` | [64, 64] / PNG | 是 | UNUSED / REFERENCE_ONLY | 备选/重复/参考；不进入运行素材映射 |
| source_68912de5b343 | `res://assets/ref/backrooms_card_template_v1/godot_demo/assets/icon_event_category.png` | [64, 64] / PNG | 是 | UNUSED / REFERENCE_ONLY | 备选/重复/参考；不进入运行素材映射 |
| source_9a62be6f4e28 | `res://assets/ref/backrooms_card_template_v1/godot_demo/assets/icon_flashlight.png` | [64, 64] / PNG | 是 | UNUSED / REFERENCE_ONLY | 备选/重复/参考；不进入运行素材映射 |
| source_3f4846e67e68 | `res://assets/ref/backrooms_card_template_v1/godot_demo/assets/icon_gear.png` | [64, 64] / PNG | 是 | UNUSED / REFERENCE_ONLY | 备选/重复/参考；不进入运行素材映射 |
| source_3bc3a23610ad | `res://assets/ref/backrooms_card_template_v1/godot_demo/assets/icon_heart.png` | [64, 64] / PNG | 是 | UNUSED / REFERENCE_ONLY | 备选/重复/参考；不进入运行素材映射 |
| source_e3b4d170d62c | `res://assets/ref/backrooms_card_template_v1/godot_demo/assets/icon_item_category.png` | [64, 64] / PNG | 是 | UNUSED / REFERENCE_ONLY | 备选/重复/参考；不进入运行素材映射 |
| source_cd18b929258a | `res://assets/ref/backrooms_card_template_v1/godot_demo/assets/icon_search.png` | [64, 64] / PNG | 是 | UNUSED / REFERENCE_ONLY | 备选/重复/参考；不进入运行素材映射 |
| source_14fc937b85e6 | `res://assets/ref/backrooms_card_template_v1/godot_demo/assets/icon_shield.png` | [64, 64] / PNG | 是 | UNUSED / REFERENCE_ONLY | 备选/重复/参考；不进入运行素材映射 |
| source_42ec2b771939 | `res://assets/ref/backrooms_card_template_v1/godot_demo/assets/icon_skill_category.png` | [64, 64] / PNG | 是 | UNUSED / REFERENCE_ONLY | 备选/重复/参考；不进入运行素材映射 |
| source_f603002fc6eb | `res://assets/ref/backrooms_card_template_v1/godot_demo/assets/icon_stack.png` | [64, 64] / PNG | 是 | UNUSED / REFERENCE_ONLY | 备选/重复/参考；不进入运行素材映射 |
| source_30f031d38b9f | `res://assets/ref/backrooms_card_template_v1/godot_demo/assets/icon_status_category.png` | [64, 64] / PNG | 是 | UNUSED / REFERENCE_ONLY | 备选/重复/参考；不进入运行素材映射 |
| source_58e020482c25 | `res://assets/ref/backrooms_card_template_v1/godot_demo/assets/panel_description.png` | [624, 180] / PNG | 是 | UNUSED / REFERENCE_ONLY | 备选/重复/参考；不进入运行素材映射 |
| source_c7051c27a497 | `res://assets/ref/backrooms_card_template_v1/godot_demo/assets/panel_name.png` | [624, 106] / PNG | 是 | UNUSED / REFERENCE_ONLY | 备选/重复/参考；不进入运行素材映射 |
| source_803217c8b1bd | `res://assets/ref/backrooms_card_template_v1/godot_demo/assets/panel_stat.png` | [194, 95] / PNG | 是 | UNUSED / REFERENCE_ONLY | 备选/重复/参考；不进入运行素材映射 |
| source_62004525c59a | `res://assets/ref/backrooms_card_template_v1/godot_demo/assets/panel_type.png` | [145, 69] / PNG | 是 | UNUSED / REFERENCE_ONLY | 备选/重复/参考；不进入运行素材映射 |
| source_5a3118950fbb | `res://assets/ref/backrooms_card_template_v1/LAYOUT_GUIDE.png` | [750, 1050] / PNG | 是 | PROVIDED / REFERENCE_ONLY | 已查看的布局参考，非运行卡牌/游戏数据 |
| source_8ec2d7f78a5d | `res://assets/ref/backrooms_card_template_v1/PREVIEW_5_CARDS.png` | [1100, 1130] / PNG | 否 | PROVIDED / REFERENCE_ONLY | 已查看的布局参考，非运行卡牌/游戏数据 |
| source_41ba0c6072bd | `res://assets/ref/backrooms_card_template_v1/samples/flashlight.png` | [750, 1050] / PNG | 否 | UNUSED / REFERENCE_ONLY | 备选/重复/参考；不进入运行素材映射 |
| source_9c52e1404d6e | `res://assets/ref/backrooms_card_template_v1/samples/flashlight_cost_0.png` | [750, 1050] / PNG | 否 | UNUSED / REFERENCE_ONLY | 备选/重复/参考；不进入运行素材映射 |
| source_4ed4959f7172 | `res://assets/ref/backrooms_card_template_v1/samples/flicker.png` | [750, 1050] / PNG | 否 | UNUSED / REFERENCE_ONLY | 备选/重复/参考；不进入运行素材映射 |
| source_c6a39aecf744 | `res://assets/ref/backrooms_card_template_v1/samples/level0.png` | [750, 1050] / PNG | 否 | UNUSED / REFERENCE_ONLY | 备选/重复/参考；不进入运行素材映射 |
| source_1ca7cf1a526d | `res://assets/ref/backrooms_card_template_v1/samples/listener.png` | [750, 1050] / PNG | 否 | UNUSED / UNASSIGNED | 无法确认为当前领域/按钮用途；未擅自映射。 |
| source_6ebf7b0f99c7 | `res://assets/ref/backrooms_card_template_v1/samples/stealth.png` | [750, 1050] / PNG | 否 | UNUSED / REFERENCE_ONLY | 备选/重复/参考；不进入运行素材映射 |
| source_b556dcec52e3 | `res://assets/ui/buttons/primary.png` | [64, 64] / PNG | 是 | UNUSED / UNASSIGNED | 无法确认为当前领域/按钮用途；未擅自映射。 |
| ui_description_panel | `res://assets/ui/frames/description_panel.png` | [624, 180] / PNG | 是 | PROVIDED / MAPPED | 运行素材 |
| frame_entity | `res://assets/ui/frames/entity.png` | [750, 1050] / PNG | 是 | PROVIDED / MAPPED | 运行素材 |
| frame_equipment | `res://assets/ui/frames/equipment.png` | [750, 1050] / PNG | 是 | PROVIDED / MAPPED | 运行素材 |
| frame_event | `res://assets/ui/frames/event.png` | [750, 1050] / PNG | 是 | PROVIDED / MAPPED | 运行素材 |
| source_c925bf525927 | `res://assets/ui/frames/frame_location_a.png` | [750, 1050] / PNG | 是 | UNUSED / REFERENCE_ONLY | 备选/重复/参考；不进入运行素材映射 |
| ui_name_panel | `res://assets/ui/frames/name_panel.png` | [624, 106] / PNG | 是 | PROVIDED / MAPPED | 运行素材 |
| frame_objective | `res://assets/ui/frames/objective.png` | [750, 1050] / PNG | 是 | PROVIDED / MAPPED | 运行素材 |
| frame_player | `res://assets/ui/frames/player.png` | [750, 1050] / PNG | 是 | PROVIDED / MAPPED | 运行素材 |
| ui_stat_panel | `res://assets/ui/frames/stat_panel.png` | [194, 95] / PNG | 是 | PROVIDED / MAPPED | 运行素材 |
| ui_type_panel | `res://assets/ui/frames/type_panel.png` | [145, 69] / PNG | 是 | PROVIDED / MAPPED | 运行素材 |
| source_d15d9902664e | `res://assets/ui/icons/aahp.png` | [64, 64] / PNG | 是 | UNUSED / REFERENCE_ONLY | 备选/重复/参考；不进入运行素材映射 |
| icon_ap | `res://assets/ui/icons/ap.png` | [200, 200] / PNG | 是 | PROVIDED / MAPPED | 运行素材 |
| icon_cognition | `res://assets/ui/icons/cognition.png` | [64, 64] / PNG | 是 | PROVIDED / MAPPED | 运行素材 |
| ui_cost | `res://assets/ui/icons/cost_medallion.png` | [116, 116] / PNG | 是 | PROVIDED / MAPPED | 运行素材 |
| icon_guard | `res://assets/ui/icons/guard.png` | [64, 64] / PNG | 是 | PROVIDED / MAPPED | 运行素材 |
| icon_hp | `res://assets/ui/icons/hp.png` | [200, 200] / PNG | 是 | PROVIDED / MAPPED | 运行素材 |
| source_0c423b0bb250 | `res://assets/ui/icons/icon_event_category.png` | [64, 64] / PNG | 是 | UNUSED / REFERENCE_ONLY | 备选/重复/参考；不进入运行素材映射 |
| source_2b3656f06b70 | `res://assets/ui/icons/icon_gear.png` | [64, 64] / PNG | 是 | UNUSED / REFERENCE_ONLY | 备选/重复/参考；不进入运行素材映射 |
| source_c116d06b95e1 | `res://assets/ui/icons/icon_item_category.png` | [64, 64] / PNG | 是 | UNUSED / REFERENCE_ONLY | 备选/重复/参考；不进入运行素材映射 |
| source_cfea236668eb | `res://assets/ui/icons/icon_skill_category.png` | [64, 64] / PNG | 是 | UNUSED / REFERENCE_ONLY | 备选/重复/参考；不进入运行素材映射 |
| source_c9011fe653b6 | `res://assets/ui/icons/icon_status_category.png` | [64, 64] / PNG | 是 | UNUSED / REFERENCE_ONLY | 备选/重复/参考；不进入运行素材映射 |
| icon_light | `res://assets/ui/icons/light.png` | [64, 64] / PNG | 是 | PROVIDED / MAPPED | 运行素材 |
| icon_noise | `res://assets/ui/icons/noise.png` | [64, 64] / PNG | 是 | PROVIDED / MAPPED | 运行素材 |
| icon_retain | `res://assets/ui/icons/retain.png` | [64, 64] / PNG | 是 | PROVIDED / MAPPED | 运行素材 |
| icon_search | `res://assets/ui/icons/search.png` | [64, 64] / PNG | 是 | PROVIDED / MAPPED | 运行素材 |
| icon_stress | `res://assets/ui/icons/stress.png` | [200, 200] / PNG | 是 | PROVIDED / MAPPED | 运行素材 |
| source_878df612e6e0 | `res://assets/ui/icons/thread.png` | [200, 200] / PNG | 是 | UNUSED / UNASSIGNED | 无法确认为当前领域/按钮用途；未擅自映射。 |
| icon_threat | `res://assets/ui/icons/threat.png` | [64, 64] / PNG | 是 | PROVIDED / MAPPED | 运行素材 |
| ui_card_background | `res://assets/ui/overlays/card_paper.png` | [750, 1050] / PNG | 否 | PROVIDED / MAPPED | 运行素材 |

## UNASSIGNED 与导入修正

- `art_listener.png`／窃听者合成样例：不属于当前 Hound/Smiler，未猜测成新实体。
- `ui/icons/thread.png`：未与现有稳定 ID 匹配，保留原文件。
- `ui/buttons/primary.png`：实际为箭头图标，不作为按钮底板。
- 部分提供插画自带水印/摄像机字样，原样保留；不是本游戏动态文字。
- 三个 `.jpeg` 实际是 PNG，已只修正扩展名；字节内容经 SHA256 比较完全保留，详见 [改名记录](ASSET_RENAMES_PHASE_12.json)。
  - `res://assets/backgrounds/level_6/background.jpeg` → `res://assets/backgrounds/level_6/background.png`
  - `res://assets/cards/player/card_attack.jpeg` → `res://assets/cards/player/card_attack.png`
  - `res://assets/cards/player/card_defend.jpeg` → `res://assets/cards/player/card_defend.png`

## 给美术/素材收集者的操作说明

1. 图片按表放入 `assets/backgrounds`、`cards`、`ui`；音频放入 `audio/ambience`、`sfx`、`ui`。参考包保留在 `assets/ref`，不运行其测试工程或导入其数值。
2. 首选 PNG，编码必须与扩展名一致；音效 OGG/WAV，字体 TTF/OTF。不要把 PNG 改成 .jpeg。
3. 原卡框参考 750×1050；玩家牌推荐 512×768，独立插画推荐 660×540 或等比更大。背景推荐 1920×1080。手牌中文字由引擎独立绘制，不烘焙姓名/费用/数值。
4. 卡框、图标、FX 要透明；背景/插画不要求透明。不要用完整合成样例图替代透明卡框。
5. 英文 snake_case 文件名；放到目标 path 后 Godot 重新导入/重启，优先使用专用图；需要改位置只改 JSON path，保留稳定 ID。fallback_path 可保持为缺图时的替代。
6. `AssetCatalog.is_provided(ID)` 检查主路径；运行 Phase 12 测试确认资源真实加载和三种分辨率。更换后同步清单状态为 PROVIDED，不需要改 RuleResolver 等领域代码。
7. 优先收集上面的 P0 六张专用插画，其次事件/奖励牌、音频和字体；最后补可选 FX、按钮皮肤。
8. 当前默认素材来自开发者提供的 default-cardcover 和模板图层，未联网下载、未引入插件；缺音不造假为已集成音频。
