# Phase 14 审查、冻结与字段迁移

## 审查结论

迁移前仓库已做了一部分 Phase 14 结构修改，但调用链未完成：PlayerState 去掉 AP/Block 后 PlayerSystem/TurnManager 仍写原字段；CardData 删除旧 EffectType 后 RuleResolver/CardText/PlayerCardView 仍引用它。基线 Godot 导入报告解析错误，不是可直接继续游玩的完成版。

原模型仍保留旧 Explore/Threat、永久牌区中的手牌和旧 CutOut；新 CombatState/CombatDeckState/KnowledgeState/EffectData/行为数据尚未接入生产生命周期。Entity 弱点字段存在 `weekness / efftect_tag` 拼写与未完成的单条件结构。

## 已确认设计

开发者确认：尽量避免重返；必须重返时采用原图入口落点、已结算节点只通行。实现以此及 Phase 14 文档为准，覆盖旧“所有主动行为必须来自牌”“探索战斗永远同一回合”“安全/仓促切出牌”等冲突。

基础数值：HP 30，Supply 5，战斗 AP 3，抽五张；Intel 初始 0、每场清空；Noise/光源/Block/状态只在本场。获得 AP 可临时超过基础 3，下一回合仍回复 3。地图与事件不使用战斗 AP。

## 字段/API 迁移

| 原入口/字段 | 当前唯一所有者/替代 |
| --- | --- |
| PlayerState.ap/block 或旧 Run 平铺字段 | CombatState.ap/block |
| DeckState.hand/draw/discard | CombatDeckState 四牌区；DeckState.cards 仅持有牌 |
| CombatState.Enemies/turn/CombatResult | enemies/turn_number/Outcome；未结局为 NONE |
| CardData.effect_type/effect_value/explore_amount/ap_like_cost | effects[]、intel_cost；没有泛型 AP-like 数值 |
| EntityInstance.intent:StringName | current_intent:EnemyIntent（已锁定效果） |
| EntityWeeknessData/TriggerData.efftect_tag | WeaknessData/TriggerData.effect_tag，条件数组与冷却 |
| status_effects 只存 ID | StatusInstance 记录 definition/stacks/remaining_turns |
| EventData DEBUFF/OMEN/OPPORTUNITY | 节点文本 EventData + EventOptionData + 关系 |
| FloorState 旧 Board/探索累计 | FloorState.definition/map，MapNode 保存揭示与一次性结算 |
| CutOutState 稳定度/安全/仓促尝试 | EXIT + CutOutRouteData 正权重目的地 + 纯预览 |
| 旧换层整体重建访问 | FloorHistoryState 保存实际 FloorState，入口重入 |
| 旧独立战斗按钮/装备按钮 | 战斗真实手牌；唯独 Phase 14 明确授权的常驻撤离按钮 |
| 旧 Observe/Search推进/资源按钮 | MAP 节点、文本选项、真实 RewardOpportunity |
| 平铺/旧分域 Result 字段 | ActionResult.player/combat/deck/equipment/floor/flow |
| 旧 PlayCardCommand / 旧安全点命令 | GameCommand 捕获 revision/访问/战斗/真实实例 |

## 文件与归档

保留复用：Run 聚合思想、Player/Equipment/牌实例模型、素材 AssetCatalog/AssetAudio/GameUITheme、Resource 数据管线、结果分域与单写入者原则。

改造：Run/Player/Flow、Card/Deck、Entity/Intent/弱点、Effect/Status、Floor/History/Map、Reward/Equipment/CutOut、RuleResolver/TurnManager、Main/UI 与正式 `.tres`。

新建：DAG/节点配置、锁定意图、撤离预览、节点选项、商店/路线权重 Resource、内容校验器、Phase 14 测试与内容手册。

完整迁移前源在 archive，**不作为第二套正式兼容系统**。主场景仍是 `scenes/main/Main.tscn`，renderer 与 project.godot 不变。

## 测试映射

旧 Phase 1–13C 中仍有效的领域不变量迁入当前测试：新局独立、初始 HP、战斗 AP 重置、牌实例守恒、来源隔离、静态定义不变、失败无副作用、旧目标拒绝、奖励唯一、装备失败不扣次、公开意图、存活解决实体、合法离层、跨层携带。

失效的旧玩法断言（Explore、三类手牌探索循环、压力 Event、旧切出失败规则等）归档，不能为了“老测试全部绿”恢复它们。
