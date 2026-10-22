# Phase 14 内容手册

当前生成集含 **284 个 Resource**。这份索引是内容快照；运行入口是 `data/game.tres`，不是本 JSON。新内容需接入 GameData/FloorData/奖励池才会出现。后室实体的数值、行为和事件都是本原型的可编辑演绎，不声称复刻完整设定。

## 内容规模

| 类型 | 数量 |
| --- | ---: |
| StatusData | 8 |
| EffectData | 51 |
| CardData | 35 |
| EquipmentData | 5 |
| RewardEntryData | 12 |
| RewardTableData | 10 |
| ConditionData | 6 |
| EntityActionData | 11 |
| TriggerData | 4 |
| WeaknessData | 4 |
| EntityBehaviorData | 12 |
| EntityData | 12 |
| EventOptionData | 46 |
| EventData | 20 |
| ShopOfferData | 9 |
| ShopData | 3 |
| CutOutDestinationData | 12 |
| CutOutModifierData | 12 |
| CutOutRouteData | 6 |
| MapGenerationData | 2 |
| FloorData | 2 |
| DeckData | 1 |
| GameData | 1 |

## 玩家牌（包括装备动作与升级）

| 名称 | ID | AP | Intel | 来源 | 资源 |
| --- | --- | ---: | ---: | --- | --- |
| 攻击＋ | card_attack_plus | 1 | 0 | NORMAL | [card_attack_plus.tres](../data/cards/card_attack_plus.tres) |
| 防御＋ | card_defend_plus | 1 | 0 | NORMAL | [card_defend_plus.tres](../data/cards/card_defend_plus.tres) |
| 战场侦察＋ | card_recon_plus | 1 | 0 | NORMAL | [card_recon_plus.tres](../data/cards/card_recon_plus.tres) |
| 快速整备＋ | card_quick_draw_plus | 0 | 0 | NORMAL | [card_quick_draw_plus.tres](../data/cards/card_quick_draw_plus.tres) |
| 控制呼吸＋ | card_calm_plus | 1 | 0 | NORMAL | [card_calm_plus.tres](../data/cards/card_calm_plus.tres) |
| 精确打击＋ | card_precision_plus | 1 | 2 | NORMAL | [card_precision_plus.tres](../data/cards/card_precision_plus.tres) |
| 攻击 | card_attack | 1 | 0 | NORMAL | [card_attack.tres](../data/cards/card_attack.tres) |
| 防御 | card_defend | 1 | 0 | NORMAL | [card_defend.tres](../data/cards/card_defend.tres) |
| 战场侦察 | card_recon | 1 | 0 | NORMAL | [card_recon.tres](../data/cards/card_recon.tres) |
| 快速整备 | card_quick_draw | 0 | 0 | NORMAL | [card_quick_draw.tres](../data/cards/card_quick_draw.tres) |
| 控制呼吸 | card_calm | 1 | 0 | NORMAL | [card_calm.tres](../data/cards/card_calm.tres) |
| 精确打击 | card_precision | 1 | 2 | NORMAL | [card_precision.tres](../data/cards/card_precision.tres) |
| 预判防线 | card_intel_guard | 1 | 1 | NORMAL | [card_intel_guard.tres](../data/cards/card_intel_guard.tres) |
| 识破弱点 | card_expose | 1 | 0 | NORMAL | [card_expose.tres](../data/cards/card_expose.tres) |
| 佯攻 | card_feint | 1 | 0 | NORMAL | [card_feint.tres](../data/cards/card_feint.tres) |
| 有力打击 | card_heavy_strike | 2 | 0 | NORMAL | [card_heavy_strike.tres](../data/cards/card_heavy_strike.tres) |
| 防守反击 | card_counter_strike | 1 | 0 | NORMAL | [card_counter_strike.tres](../data/cards/card_counter_strike.tres) |
| 稳固防御 | card_steady_guard | 1 | 0 | NORMAL | [card_steady_guard.tres](../data/cards/card_steady_guard.tres) |
| 信号研判 | card_signal | 1 | 0 | NORMAL | [card_signal.tres](../data/cards/card_signal.tres) |
| 提前部署 | card_plan | 0 | 2 | NORMAL | [card_plan.tres](../data/cards/card_plan.tres) |
| 静默行动 | card_quiet | 1 | 0 | NORMAL | [card_quiet.tres](../data/cards/card_quiet.tres) |
| 瞄准姿态 | card_focus | 1 | 0 | NORMAL | [card_focus.tres](../data/cards/card_focus.tres) |
| 打断节奏 | card_disrupt | 1 | 2 | NORMAL | [card_disrupt.tres](../data/cards/card_disrupt.tres) |
| 临机应变 | card_burst | 1 | 0 | NORMAL | [card_burst.tres](../data/cards/card_burst.tres) |
| 闪光标记 | card_light_bomb | 1 | 1 | NORMAL | [card_light_bomb.tres](../data/cards/card_light_bomb.tres) |
| 现场包扎 | card_first_aid | 1 | 0 | NORMAL | [card_first_aid.tres](../data/cards/card_first_aid.tres) |
| 压制射击 | card_pressure | 2 | 0 | NORMAL | [card_pressure.tres](../data/cards/card_pressure.tres) |
| 背水一击 | card_risky | 1 | 0 | NORMAL | [card_risky.tres](../data/cards/card_risky.tres) |
| 固定阵位 | card_brace | 1 | 0 | NORMAL | [card_brace.tres](../data/cards/card_brace.tres) |
| 热源诱导 | card_thermal | 1 | 1 | NORMAL | [card_thermal.tres](../data/cards/card_thermal.tres) |
| 照明 | card_equipment_light | 1 | 0 | 装备生成 | [card_equipment_light.tres](../data/cards/card_equipment_light.tres) |
| 熄灯 | card_equipment_extinguish | 1 | 0 | 装备生成 | [card_equipment_extinguish.tres](../data/cards/card_equipment_extinguish.tres) |
| 撬棍猛击 | card_equipment_crowbar | 1 | 0 | 装备生成 | [card_equipment_crowbar.tres](../data/cards/card_equipment_crowbar.tres) |
| 饮用杏仁水 | card_equipment_water | 1 | 0 | 装备生成 | [card_equipment_water.tres](../data/cards/card_equipment_water.tres) |
| 电击控制 | card_equipment_baton | 1 | 0 | 装备生成 | [card_equipment_baton.tres](../data/cards/card_equipment_baton.tres) |

## 实体

统一 EntityInstance/锁定意图/状态系统；普通与精英池分开。笑魇通过两回合黑暗退去；猎犬响应实际噪音；钝人与肢团可被钝击打失衡。其他行为通过优先级、权重、条件与冷却组合。

| 名称 | HP | 撤离基础伤害 | 压力 | 资源 |
| --- | ---: | --- | ---: | --- |
| 猎犬 | 18 | 2–4 | 2 | [entity_hound](../data/entities/entity_hound.tres) |
| 笑魇 | 120 | 4–7 | 3 | [entity_smiler](../data/entities/entity_smiler.tres) |
| 死亡飞蛾 | 15 | 2–4 | 2 | [entity_deathmoth](../data/entities/entity_deathmoth.tres) |
| 钝人 | 21 | 3–5 | 2 | [entity_duller](../data/entities/entity_duller.tres) |
| 肢团 | 25 | 3–6 | 2 | [entity_clump](../data/entities/entity_clump.tres) |
| 窃皮者 | 22 | 3–5 | 2 | [entity_skinstealer](../data/entities/entity_skinstealer.tres) |
| 悲尸 | 20 | 2–5 | 2 | [entity_wretch](../data/entities/entity_wretch.tres) |
| 墙隙爬行者 | 16 | 2–4 | 2 | [entity_crawler](../data/entities/entity_crawler.tres) |
| 饥饿猎犬 | 26 | 4–7 | 3 | [entity_starved_hound](../data/entities/entity_starved_hound.tres) |
| 巨型死亡飞蛾 | 30 | 4–6 | 3 | [entity_moth_matriarch](../data/entities/entity_moth_matriarch.tres) |
| 密集肢团 | 34 | 5–8 | 3 | [entity_dense_clump](../data/entities/entity_dense_clump.tres) |
| 狂躁悲尸 | 28 | 4–7 | 3 | [entity_frenzied_wretch](../data/entities/entity_frenzied_wretch.tres) |

## 节点事件

每个事件保留无资源门槛选项；选项可以交易、学习知识、揭示地图、转入战斗或跳到另一文本分支。无面行商以中立身份出现，不需要敌对 EntityData。相同定义出现在不同节点时，各节点是独立的一次性机会。

| 名称 | 资源 |
| --- | --- |
| 潮湿补给柜 | [event_cache](../data/events/event_cache.tres) |
| 断续的 M.E.G. 信号 | [event_meg](../data/events/event_meg.tres) |
| 沉默的无面行商 | [event_faceling](../data/events/event_faceling.tres) |
| 异常嗡鸣 | [event_hum](../data/events/event_hum.tres) |
| 遗落的工具袋 | [event_battery](../data/events/event_battery.tres) |
| 应急医疗箱 | [event_medic](../data/events/event_medic.tres) |
| 不该亮起的指示灯 | [event_lights](../data/events/event_lights.tres) |
| 呼吸的墙缝 | [event_seam](../data/events/event_seam.tres) |
| 遗留口粮 | [event_ration](../data/events/event_ration.tres) |
| 错拍脚步 | [event_footsteps](../data/events/event_footsteps.tres) |
| 绝缘维修间 | [event_insulation](../data/events/event_insulation.tres) |
| 无法关上的门 | [event_sleep](../data/events/event_sleep.tres) |
| 墙角鳞粉 | [event_moth_nest](../data/events/event_moth_nest.tres) |
| 褪色日志 | [event_diary](../data/events/event_diary.tres) |
| 废弃信标 | [event_beacon](../data/events/event_beacon.tres) |
| 停电间隙 | [event_blackout](../data/events/event_blackout.tres) |
| 遗弃的检查站 | [event_checkpoint](../data/events/event_checkpoint.tres) |
| 柜内的第二层 | [event_supply_inner](../data/events/event_supply_inner.tres) |
| 双层储藏室 | [event_locked_room](../data/events/event_locked_room.tres) |
| 温热水管 | [event_water_pipe](../data/events/event_water_pipe.tres) |

## 如何扩展

1. 先复用 `EffectData`、`StatusData`、`ConditionData`、`EntityActionData`，不要给具名怪物添加系统分支。
2. 新卡写 effects / 目标 / AP / intel_cost，放入奖励 CardChoice 或起始 DeckData；消耗和保留是独立生命周期标记。
3. 新实体写行为与弱点、HP、撤离区间、奖励，再接入普通或精英池。意图只在回合开始锁定。
4. 新事件写 EventOptionData，至少保留一个无资源门槛选项；分支不能成环。关系与身份写在 EventData，战斗能力仍是 EntityData。
5. 新楼层必须提供地图权重、全部节点内容池与出口；出口用 floor_id，不直接循环引用 FloorData。所有楼层必须能沿正权重出口抵达 run_end。
6. 插画映射到 assets/asset_manifest.json；缺图走 default-cardcover，不修改规则。
7. 运行 tests/run_validation.ps1 和窗口检查。不要把旧探索测试当作 Phase 14 的功能合同。

## 生成器约定

`tools/generate_phase14_content.py` 是离线初始数据生成器，会覆盖其管理的资源；**人工调整 .tres 后不要无意重跑它**。平时可直接在 Godot Inspector 编辑。`tools/document_phase14_content.py` 只刷新此手册和当前素材表。
