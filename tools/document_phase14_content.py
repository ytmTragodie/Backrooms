"""从当前 .tres/索引/映射生成可查阅的内容和缺图表；不覆盖玩法 Resource。"""
from pathlib import Path
from collections import Counter
import json,re
ROOT=Path(__file__).resolve().parents[1]
rows=json.loads((ROOT/'docs/PHASE_14_CONTENT_INDEX.json').read_text(encoding='utf-8'))
assets=json.loads((ROOT/'assets/asset_manifest.json').read_text(encoding='utf-8'))
def source(row): return (ROOT/row['path'].removeprefix('res://')).read_text(encoding='utf-8')
def number(text,key,default='0'):
    m=re.search(r'^'+re.escape(key)+r' = (.+)$',text,re.M)
    return m[1] if m else default
out=['# Phase 14 内容手册','','当前生成集含 **284 个 Resource**。这份索引是内容快照；运行入口是 `data/game.tres`，不是本 JSON。新内容需接入 GameData/FloorData/奖励池才会出现。后室实体的数值、行为和事件都是本原型的可编辑演绎，不声称复刻完整设定。','','## 内容规模','','| 类型 | 数量 |','| --- | ---: |']
for cls,count in Counter(r['type'] for r in rows).items(): out.append(f'| {cls} | {count} |')
out+=['','## 玩家牌（包括装备动作与升级）','','| 名称 | ID | AP | Intel | 来源 | 资源 |','| --- | --- | ---: | ---: | --- | --- |']
for r in rows:
    if r['type']!='CardData': continue
    t=source(r);out.append(f"| {r['name']} | {r['id']} | {number(t,'ap_cost')} | {number(t,'intel_cost')} | {'装备生成' if number(t,'source')=='1' else 'NORMAL'} | [{Path(r['path']).name}](../{r['path'].removeprefix('res://')}) |")
out+=['','## 实体','','统一 EntityInstance/锁定意图/状态系统；普通与精英池分开。笑魇通过两回合黑暗退去；猎犬响应实际噪音；钝人与肢团可被钝击打失衡。其他行为通过优先级、权重、条件与冷却组合。','','| 名称 | HP | 撤离基础伤害 | 压力 | 资源 |','| --- | ---: | --- | ---: | --- |']
for r in rows:
    if r['type']!='EntityData': continue
    t=source(r);out.append(f"| {r['name']} | {number(t,'max_hp')} | {number(t,'escape_damage_min')}–{number(t,'escape_damage_max')} | {number(t,'escape_stress')} | [{r['id']}](../{r['path'].removeprefix('res://')}) |")
out+=['','## 节点事件','','每个事件保留无资源门槛选项；选项可以交易、学习知识、揭示地图、转入战斗或跳到另一文本分支。无面行商以中立身份出现，不需要敌对 EntityData。相同定义出现在不同节点时，各节点是独立的一次性机会。','','| 名称 | 资源 |','| --- | --- |']
for r in rows:
    if r['type']=='EventData': out.append(f"| {r['name']} | [{r['id']}](../{r['path'].removeprefix('res://')}) |")
out+=['','## 如何扩展','','1. 先复用 `EffectData`、`StatusData`、`ConditionData`、`EntityActionData`，不要给具名怪物添加系统分支。','2. 新卡写 effects / 目标 / AP / intel_cost，放入奖励 CardChoice 或起始 DeckData；消耗和保留是独立生命周期标记。','3. 新实体写行为与弱点、HP、撤离区间、奖励，再接入普通或精英池。意图只在回合开始锁定。','4. 新事件写 EventOptionData，至少保留一个无资源门槛选项；分支不能成环。关系与身份写在 EventData，战斗能力仍是 EntityData。','5. 新楼层必须提供地图权重、全部节点内容池与出口；出口用 floor_id，不直接循环引用 FloorData。所有楼层必须能沿正权重出口抵达 run_end。','6. 插画映射到 assets/asset_manifest.json；缺图走 default-cardcover，不修改规则。','7. 运行 tests/run_validation.ps1 和窗口检查。不要把旧探索测试当作 Phase 14 的功能合同。','','## 生成器约定','','`tools/generate_phase14_content.py` 是离线初始数据生成器，会覆盖其管理的资源；**人工调整 .tres 后不要无意重跑它**。平时可直接在 Godot Inspector 编辑。`tools/document_phase14_content.py` 只刷新此手册和当前素材表。']
(ROOT/'docs/PHASE_14_CONTENT.md').write_text('\n'.join(out)+'\n',encoding='utf-8')
active=[r for r in rows if r['type'] in ['CardData','EntityData','EventData','FloorData']]
out=['# Phase 14 当前内容素材映射','','当前 69 个内容视觉 ID。旧清单其他条目保留为历史美术，不授权恢复旧玩法。新缺图统一使用 `assets/cards/default-cardcover.png`；升级牌共享基础插画。','','| ID | 名称 | 状态 | 主路径 | 替代/说明 |','| --- | --- | --- | --- | --- |']
for r in active:
    d=assets[r['id']];out.append(f"| {r['id']} | {r['name']} | {d['status']} | `{d['path']}` | `{d.get('fallback_path','本地默认')}`；{d.get('notes','')} |")
out+=['','## 当前 Missing（同图的升级版本合并）','','| 优先级 | 名称 | 目标路径 | 建议尺寸 | 格式/透明 | 内容要求 |','| --- | --- | --- | --- | --- | --- |']
seen=set()
for r in active:
    d=assets[r['id']]
    if d['status']=='PROVIDED' or d['path'] in seen: continue
    seen.add(d['path']);out.append(f"| {d.get('priority','P1')} | {r['name'].removesuffix('＋')} | `{d['path']}` | {'768×1024' if r['type']=='EntityData' else '660×540'} | PNG / 不必透明 | 与名称语义对应的后室题材插画，无动态文字 |")
out+=['','- P1 另缺：两层环境音、出牌/UI/实体/切出提示等九音频及中文字体；当前安全静音/系统字体。','- P2：节点类型/意图图标、统一特效与按钮皮肤。','- 事件当前是文本界面，专用插画留作扩展映射，不谎称已显示事件插画。','- 放入主路径或改 JSON 后重新导入，无需改玩法代码。']
(ROOT/'docs/PHASE_14_ASSETS.md').write_text('\n'.join(out)+'\n',encoding='utf-8')
print('Updated content handbook and current asset/missing tables.')
