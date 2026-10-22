"""离线内容生成器；只生成声明式 .tres，不参与游戏运行，不需要第三方包。

策划可直接改生成后的资源。再次执行会覆盖本生成器管理的 data 文件，
因此平时不要把它加入导入/开局流程；修改资源前先保存版本控制差异。
"""
from pathlib import Path
import json

ROOT = Path(__file__).resolve().parents[1]
SCRIPTS = {
    'EffectData': 'effects/effect_data', 'StatusData': 'effects/status_data',
    'CardData': 'cards/card_data', 'DeckData': 'cards/deck_data',
    'EntityData': 'entities/entity_data', 'EntityActionData': 'entities/entity_action_data',
    'EntityBehaviorData': 'entities/entity_behavior_data', 'ConditionData': 'entities/entity_condition_data',
    'TriggerData': 'entities/trigger_data', 'WeaknessData': 'entities/weakness_data',
    'EquipmentData': 'equipment/equipment_data', 'RewardEntryData': 'rewards/reward_entry_data',
    'RewardTableData': 'rewards/reward_table_data', 'EventData': 'events/event_data',
    'EventOptionData': 'events/event_option_data', 'ShopData': 'rewards/shop_data',
    'ShopOfferData': 'rewards/shop_offer_data', 'MapGenerationData': 'maps/map_generation_data',
    'FloorData': 'floors/floor_data', 'GameData': 'run/game_data',
    'CutOutRouteData': 'cutout/cutout_route_data', 'CutOutDestinationData': 'cutout/cutout_destination_data',
    'CutOutModifierData': 'cutout/cutout_modifier_data',
}
class Ref:
    def __init__(self, path): self.path = 'res://' + path
class Arr:
    def __init__(self, cls, values): self.cls, self.values = cls, values
class Expr:
    def __init__(self, value): self.value = value
INDEX = []
def resource(path, cls, **props):
    refs = [('Script', f'res://scripts/{SCRIPTS[cls]}.gd')]
    def external(kind, path):
        item = (kind, path)
        if item not in refs: refs.append(item)
        return f'ExtResource("{refs.index(item)+1}")'
    def encode(v):
        if isinstance(v, Ref): return external('Resource', v.path)
        if isinstance(v, Arr):
            script = external('Script', f'res://scripts/{SCRIPTS[v.cls]}.gd')
            return f'Array[{script}]([' + ', '.join(encode(x) for x in v.values) + '])'
        if isinstance(v, Expr): return v.value
        if isinstance(v, list): return 'Array[StringName]([' + ', '.join('&'+json.dumps(x,ensure_ascii=False) for x in v) + '])'
        if isinstance(v, str): return json.dumps(v, ensure_ascii=False)
        if isinstance(v, bool): return str(v).lower()
        return str(v)
    body = '\n'.join(f'{k} = {encode(v)}' for k,v in props.items())
    header = f'[gd_resource type="Resource" script_class="{cls}" load_steps={len(refs)+1} format=3]\n\n'
    header += '\n'.join(f'[ext_resource type="{kind}" path="{p}" id="{i+1}"]' for i,(kind,p) in enumerate(refs))
    text = header + '\n\n[resource]\nscript = ExtResource("1")\n' + body + '\n'
    target = ROOT/path; target.parent.mkdir(parents=True, exist_ok=True); target.write_text(text, encoding='utf-8')
    INDEX.append({'id': props.get('id',path), 'type': cls, 'path': 'res://'+path, 'name': props.get('display_name','')})
    return Ref(path)

def effect(name, kind, amount=0, target=0, **kwargs):
    return resource(f'data/effects/{name}.tres','EffectData',effect_type=kind,target=target,amount=amount,**kwargs)
statuses = {}
for id,name,desc,values in [
 ('weak','虚弱','每次输出伤害减少 2。',{'outgoing_damage_bonus':-2}),
 ('vulnerable','暴露','每次受到伤害增加 2。',{'incoming_damage_bonus':2}),
 ('burn','灼伤','回合末每层失去 1 点生命。',{'turn_end_damage':1}),
 ('stun','失衡','跳过当前意图。',{'skip_intent':True,'default_duration':1}),
 ('focused','专注','每次输出伤害增加 2。',{'outgoing_damage_bonus':2}),
 ('braced','稳固','每次获得防护增加 2。',{'block_bonus':2}),
 ('enraged','躁怒','下次锁定的意图伤害增加 2。',{'outgoing_damage_bonus':2}),
 ('bleed','流血','回合末每层失去 1 点生命。',{'turn_end_damage':1}),
]:
    statuses[id]=resource(f'data/statuses/{id}.tres','StatusData',id=id,display_name=name,description=desc,**values)
E={}
for n,k,a,t in [('hit4',0,4,2),('hit6',0,6,2),('hit8',0,8,2),('hit10',0,10,2),('hit12',0,12,2),('hit3',0,3,2),('hit2',0,2,2),('block4',1,4,0),('block6',1,6,0),('block8',1,8,0),('draw1',3,1,0),('draw2',3,2,0),('intel1',5,1,0),('intel2',5,2,0),('intel3',5,3,0),('ap1',4,1,0),('heal3',2,3,0),('heal5',2,5,0),('calm2',7,-2,0),('stress1',7,1,0),('noise1',8,1,0),('quiet2',8,-2,0)]:
    E[n]=effect(n,k,a,t,tags=['NOISE'] if n=='noise1' else [])
for id,status in statuses.items():
    for target in ([0,2] if id in ['weak','vulnerable','stun','burn','bleed'] else [0]):
        E[f'{id}{target}']=effect(f'{id}_{target}',6,1,target,status=status)
E['light']=effect('strong_light',9,1,0,tags=['STRONG_LIGHT'])
E['dark']=effect('extinguish',9,0,0,tags=['DARK'])
E['withdraw']=effect('withdraw',10,0,0)
E['blunt8']=effect('blunt8',0,8,2,tags=['BLUNT'])

cards={}; upgrades={}
def card(id,name,cost,eff,target=0,intel=0,**extra):
    return resource(f'data/cards/{id}.tres','CardData',id=id,display_name=name,ap_cost=cost,intel_cost=intel,target_kind=target,effects=Arr('EffectData',[E[e] for e in eff]),**extra)
specs=[
 ('card_attack','攻击',1,['hit4'],1,0),('card_defend','防御',1,['block4'],0,0),
 ('card_recon','战场侦察',1,['intel2','draw1'],0,0),('card_quick_draw','快速整备',0,['draw1'],0,0),
 ('card_calm','控制呼吸',1,['calm2','block4'],0,0),('card_precision','精确打击',1,['hit10'],1,2),
 ('card_intel_guard','预判防线',1,['block8','draw1'],0,1),('card_expose','识破弱点',1,['vulnerable2','hit2'],1,0),
 ('card_feint','佯攻',1,['weak2','hit2'],1,0),('card_heavy_strike','有力打击',2,['hit10','noise1'],1,0),
 ('card_counter_strike','防守反击',1,['block4','hit3'],1,0),('card_steady_guard','稳固防御',1,['block6'],0,0),
 ('card_signal','信号研判',1,['intel3'],0,0),('card_plan','提前部署',0,['ap1'],0,2),
 ('card_quiet','静默行动',1,['quiet2','block4'],0,0),('card_focus','瞄准姿态',1,['focused0','intel1'],0,0),
 ('card_disrupt','打断节奏',1,['stun2'],1,2),('card_burst','临机应变',1,['draw2'],0,0),
 ('card_light_bomb','闪光标记',1,['light','vulnerable2'],1,1),('card_first_aid','现场包扎',1,['heal3','calm2'],0,0),
 ('card_pressure','压制射击',2,['hit8','weak2'],1,0),('card_risky','背水一击',1,['hit8','stress1','noise1'],1,0),
 ('card_brace','固定阵位',1,['braced0','block4'],0,0),('card_thermal','热源诱导',1,['burn2','hit3'],1,1),
]
for id,name,cost,eff,target,intel in specs[:6]:
    stronger=({'card_attack':['hit6'],'card_defend':['block6'],'card_recon':['intel3','draw1'],'card_quick_draw':['draw2'],'card_calm':['calm2','block6'],'card_precision':['hit12']})[id]
    upgrades[id]=card(id+'_plus',name+'＋',cost,stronger,target,intel,description='强化后的同一主语义。',exhaust=(id=='card_quick_draw'))
for i,(id,name,cost,eff,target,intel) in enumerate(specs):
    more={'description':'M.E.G. 原型战术；数值由效果列表定义。','rarity':0 if i<5 else 1}
    if id in upgrades: more['upgrade_to']=upgrades[id]
    if id=='card_quick_draw': more['exhaust']=True
    cards[id]=card(id,name,cost,eff,target,intel,**more)
generated={}
for id,name,eff,target,uses in [('card_equipment_light','照明',['light'],0,1),('card_equipment_extinguish','熄灯',['dark'],0,0),('card_equipment_crowbar','撬棍猛击',['blunt8','noise1'],1,1),('card_equipment_water','饮用杏仁水',['heal5','calm2'],0,1),('card_equipment_baton','电击控制',['hit3','stun2'],1,1)]:
    generated[id]=card(id,name,1,eff,target,source=1,equipment_cost=uses)
gear={}
for id,name,cap,counter,action,active in [('equip_flashlight','手电筒',3,'battery','card_equipment_light','card_equipment_extinguish'),('equip_crowbar','撬棍',3,'durability','card_equipment_crowbar',None),('equip_almond_water','杏仁水',1,'charges','card_equipment_water',None),('equip_baton','便携电击棒',2,'battery','card_equipment_baton',None),('equip_beacon','路线信标',2,'charges',None,None)]:
    p=dict(id=id,display_name=name,capacity=cap,counter_kind=counter)
    if action:p['action_card']=generated[action]
    if active:p['active_action_card']=generated[active]
    gear[id]=resource(f'data/equipment/{id}.tres','EquipmentData',**p)

def entry(id,kind,amount=1,**kw): return resource(f'data/rewards/entries/{id}.tres','RewardEntryData',kind=kind,amount=amount,**kw)
entries={
 'supply2':entry('supply2',1,2),'supply4':entry('supply4',1,4),'heal4':entry('heal4',3,4),
 'heal8':entry('heal8',3,8),'calm3':entry('calm3',4,3),
 'cards':entry('cards',0,cards=Arr('CardData',list(cards.values()))),
 'tactics':entry('tactics',0,cards=Arr('CardData',[cards[k] for k in ['card_precision','card_intel_guard','card_expose','card_disrupt','card_plan']])),
}
for id,g in gear.items(): entries[id]=entry(id,2,equipment=g)
tables={}
for id,guaranteed,randoms,count in [
 ('combat',['supply2','cards'],[],0),('elite',['supply4','tactics'],['equip_baton','equip_beacon','heal4'],1),
 ('cache',['supply2'],['heal4','calm3','equip_almond_water','equip_flashlight'],1),
 ('supplies',['supply4'],[],0),('medical',['heal8','calm3'],[],0),
 ('water',['equip_almond_water'],[],0),('tool',['equip_crowbar'],[],0),('intel',['tactics'],[],0),
 ('beacon',['equip_beacon'],[],0),('calm',['calm3'],[],0),
]: tables[id]=resource(f'data/rewards/{id}.tres','RewardTableData',id='reward_'+id,guaranteed_rewards=Arr('RewardEntryData',[entries[k] for k in guaranteed]),random_rewards=Arr('RewardEntryData',[entries[k] for k in randoms]),random_count=count)

def condition(id,kind,value,op=3,ref=''):
    return resource(f'data/conditions/{id}.tres','ConditionData',type=kind,operator=op,numeric_value=value,reference_id=ref)
C={'first':condition('first_turn',1,1,0),'noise':condition('noise_high',2,2),'light':condition('light',6,1,0),'dark':condition('dark',6,0,0),'turn2':condition('turn2',1,2),'lowhp':condition('low_hp',0,0.5,4)}
def action(id,name,damage=0,**kw):
    effects=[]
    if damage: effects.append(effect('intent_'+id,0,damage,1))
    effects+=kw.pop('extra',[])
    return resource(f'data/entities/actions/{id}.tres','EntityActionData',id=id,display_name=name,effects=Arr('EffectData',effects),**kw)
A={
 'watch':action('watch','警戒靠近',conditions=Arr('ConditionData',[C['first']]),priority=2,state_after='APPROACHING'),
 'bite':action('bite','撕咬',4),
 'lunge':action('lunge','噪声追猎',6,conditions=Arr('ConditionData',[C['noise']]),priority=3,state_after='CHASING',escape_damage_modifier=1),
 'observe':action('observe','注视黑暗',conditions=Arr('ConditionData',[C['dark']]),priority=2),
 'light_strike':action('light_strike','袭击光源',8,conditions=Arr('ConditionData',[C['light']]),priority=3,escape_damage_modifier=2),
 'claw':action('claw','抓挠',3), 'slam':action('slam','沉重撞击',6,escape_damage_modifier=1),
 'rage':action('rage','濒死狂扑',7,conditions=Arr('ConditionData',[C['lowhp']]),priority=4,escape_damage_modifier=1),
 'guard':action('guard','收拢肢体',extra=[effect('enemy_block',1,5,0)],cooldown=1,weight=1),
 'bleed':action('bleed','撕裂',3,extra=[effect('enemy_bleed',6,1,1,status=statuses['bleed'])],cooldown=1,weight=1),
 'dust':action('dust','鳞粉侵扰',2,extra=[effect('enemy_weak',6,1,1,status=statuses['weak']),effect('enemy_stress',7,1,1)],cooldown=1),
}
T={k:resource(f'data/entities/triggers/{k}.tres','TriggerData',trigger_type=v,effect_tag=tag) for k,v,tag in [('noise',1,'NOISE'),('light',1,'STRONG_LIGHT'),('end',3,''),('blunt',0,'BLUNT')]}
W={
 'noise':resource('data/entities/reactions/noise.tres','WeaknessData',id='noise_chase',trigger=T['noise'],conditions=Arr('ConditionData',[C['noise']]),effects=Arr('EffectData',[E['enraged0']]),state_after='CHASING',cooldown=2),
 'light':resource('data/entities/reactions/light.tres','WeaknessData',id='light_agitation',trigger=T['light'],conditions=Arr('ConditionData',[C['light']]),effects=Arr('EffectData',[E['enraged0']]),state_after='AGITATED'),
 'dark':resource('data/entities/reactions/dark.tres','WeaknessData',id='dark_withdrawal',trigger=T['end'],conditions=Arr('ConditionData',[C['dark'],C['turn2']]),effects=Arr('EffectData',[E['withdraw']]),cooldown=1),
 'blunt':resource('data/entities/reactions/blunt.tres','WeaknessData',id='blunt_stagger',trigger=T['blunt'],effects=Arr('EffectData',[E['stun0']]),state_after='STAGGERED',cooldown=2),
}
enemies={}
enemy_specs=[
 ('entity_hound','猎犬',18,['watch','bite','lunge'],['noise'],'combat',2,4),
 ('entity_smiler','笑魇',120,['observe','light_strike'],['light','dark'],'elite',4,7),
 ('entity_deathmoth','死亡飞蛾',15,['claw','dust'],['light'],'combat',2,4),
 ('entity_duller','钝人',21,['claw','guard'],['blunt'],'combat',3,5),
 ('entity_clump','肢团',25,['slam','guard'],['blunt'],'combat',3,6),
 ('entity_skinstealer','窃皮者',22,['bite','bleed'],[],'combat',3,5),
 ('entity_wretch','悲尸',20,['claw','rage'],['noise'],'combat',2,5),
 ('entity_crawler','墙隙爬行者',16,['claw','bleed'],['blunt'],'combat',2,4),
 ('entity_starved_hound','饥饿猎犬',26,['bite','lunge','rage'],['noise'],'elite',4,7),
 ('entity_moth_matriarch','巨型死亡飞蛾',30,['slam','dust'],['light'],'elite',4,6),
 ('entity_dense_clump','密集肢团',34,['slam','guard'],['blunt'],'elite',5,8),
 ('entity_frenzied_wretch','狂躁悲尸',28,['bleed','rage','lunge'],['noise'],'elite',4,7),
]
for id,name,hp,actions,reactions,table,emin,emax in enemy_specs:
    behavior=resource(f'data/entities/behaviors/{id}.tres','EntityBehaviorData',actions=Arr('EntityActionData',[A[k] for k in actions]))
    descriptions={
      'entity_hound':'爪声追着噪音靠近。留意它从警戒转为扑击的时机。',
      'entity_smiler':'笑脸停在黑暗里。强光会激怒它，持续保持黑暗或许能让它离开。',
      'entity_deathmoth':'鳞粉在灯下漂浮，振翅后带来刺痛与无力。',
      'entity_duller':'轮廓在走廊尽头摇晃，抬起的手臂护住了躯干。',
      'entity_clump':'纠缠的肢体缓慢收拢；沉重撞击前有短暂空隙。',
      'entity_skinstealer':'它模仿人的轮廓，却在接近时露出异常的步幅。',
      'entity_wretch':'呻吟越来越急促。受伤后，它的动作可能更加危险。',
      'entity_crawler':'阴影贴着墙缝移动，爪尖在地面留下细痕。',
      'entity_starved_hound':'瘦削的身形不断前探，每一点噪音都让它更加兴奋。',
      'entity_moth_matriarch':'巨大的翅膀遮住了出口，鳞粉落满空气。',
      'entity_dense_clump':'更多肢体缠成沉重团块，收拢后准备撞击。',
      'entity_frenzied_wretch':'它几乎不再停步，撕裂声和急促呼吸填满走廊。',
    }
    enemies[id]=resource(f'data/entities/{id}.tres','EntityData',id=id,display_name=name,description=descriptions[id],asset_id=id,max_hp=hp,behavior_data=behavior,weaknesses=Arr('WeaknessData',[W[k] for k in reactions]),reward_data=tables[table],escape_damage_min=emin,escape_damage_max=emax,escape_stress=2 if table=='combat' else 3,damage_reduction=5 if id=='entity_smiler' else 0,initial_state='HIDDEN' if id=='entity_smiler' else 'WATCHING',behavior_knowledge='light_attracts' if id=='entity_smiler' else '')

events={}
def option(id,label,**kw): return resource(f'data/events/options/{id}.tres','EventOptionData',id=id,display_name=label,**kw)
def event(id,name,text,options):
    actors={'event_faceling':('无面行商',1),'event_meg':('M.E.G. 接线员',2),'event_checkpoint':('M.E.G. 留守小队',2)}
    actor,relation=actors.get(id,('',0))
    events[id]=resource(f'data/events/{id}.tres','EventData',id=id,display_name=name,description=text,asset_id=id,actor_name=actor,relation=relation,options=Arr('EventOptionData',options))
    return events[id]
leave=lambda id:option(id+'_leave','保持距离，继续前进')
event('event_cache','潮湿补给柜','柜门下渗出水迹，一枚生锈挂锁仍挂在门上。',[option('cache_pay','消耗 2 补给，安全拆锁',supply_cost=2,rewards=tables['cache']),option('cache_force','徒手撬开：生命 -3，获得补给',hp_cost=3,rewards=tables['supplies']),leave('cache')])
event('event_meg','断续的 M.E.G. 信号','旧接收器传来简短坐标，报出一段重复的墙面编号。',[option('meg_listen','校对坐标：揭示路线与六层信息',knowledge=['map_survey'],known_floors=['floor_level_6'],known_exits=['level0_service'],reveal_nodes=3),leave('meg')])
event('event_faceling','沉默的无面行商','一个没有面孔的身影将密封水瓶摆在桌上。',[option('face_trade','交付 3 补给，交换杏仁水',supply_cost=3,rewards=tables['water'],known_entities=['entity_faceling']),leave('face')])
event('event_hum','异常嗡鸣','日光灯的节奏与脚步短暂重合。墙上的粉笔箭头分成两路。',[option('hum_mark','记录重复节奏，揭示前方两节点',knowledge=['layout_repeats'],reveal_nodes=2),leave('hum')])
event('event_battery','遗落的工具袋','电池和撬棍被整齐包在绝缘布里，袋子背面有新鲜抓痕。',[option('bag_take','取走工具：压力 +1',stress_cost=1,rewards=tables['tool']),option('bag_follow','追寻抓痕，遭遇猎犬',encounter=enemies['entity_hound']),leave('bag')])
event('event_medic','应急医疗箱','一张纸条提示不要同时打开所有储物格。',[option('med_open','消耗 2 补给，取出药品',supply_cost=2,rewards=tables['medical']),leave('med')])
event('event_lights','不该亮起的指示灯','黑暗尽头有一盏持续发亮的灯，灯光旁的笑脸正在变大。',[option('lights_note','遮住视线，记住强光反应',knowledge=['light_attracts']),option('lights_stare','靠近灯光，遭遇笑魇',encounter=enemies['entity_smiler']),leave('lights')])
event('event_seam','呼吸的墙缝','墙缝在固定间隔张开，似乎通向另一段走廊。',[option('seam_map','消耗 1 补给标记出口',supply_cost=1,knowledge=['seam_route','route_floor_level_0'],reveal_nodes=2),leave('seam')])
event('event_ration','遗留口粮','包装上的日期无法辨认，密封条却仍完好。',[option('ration_take','取走一份有限补给',rewards=tables['supplies']),leave('ration')])
event('event_footsteps','错拍脚步','你停下来时，另一组脚步还多走了一步。',[option('foot_wait','耐心等候：压力 +1，获得喘息',stress_cost=1,rewards=tables['calm']),option('foot_call','出声回应，遭遇窃皮者',encounter=enemies['entity_skinstealer']),leave('foot')])
event('event_insulation','绝缘维修间','检修台留着带编号的绝缘夹和一张记录卡。',[option('insulation_read','阅读记录，取得战术选择',required_knowledge='layout_repeats',rewards=tables['intel']),leave('insulation')])
event('event_sleep','无法关上的门','门后的小房间暂时没有嗡鸣，地面有折叠的纸毯。',[option('sleep_rest','短暂休息：补给 -1，恢复状态',supply_cost=1,rewards=tables['medical']),leave('sleep')])
event('event_moth_nest','墙角鳞粉','一团细碎的粉末顺着通风口落下，底下压着物资。',[option('moth_take','与飞蛾交战，争取物资',encounter=enemies['entity_deathmoth']),leave('moth')])
event('event_diary','褪色日志','最后一页只剩几条简短标记：不要把战斗撤离当作离层。',[option('diary_read','记录地图测绘法',knowledge=['map_survey'],reveal_nodes=3),leave('diary')])
event('event_beacon','废弃信标','损坏的路线仪仍有一枚可以拆下的信标核心。',[option('beacon_buy','消耗 4 补给，带走路线信标',supply_cost=4,rewards=tables['beacon']),leave('beacon')])
event('event_blackout','停电间隙','灯光熄灭后，远处的注视短暂消失。',[option('blackout_learn','确认避光规律',knowledge=['light_attracts'],reveal_nodes=1),leave('blackout')])
event('event_checkpoint','遗弃的检查站','墙上留有可辨认的 M.E.G. 标志，路线记录被分开保存。',[option('checkpoint_swap','消耗 2 补给，换取地图与战术',supply_cost=2,rewards=tables['intel'],knowledge=['route_floor_level_6'],reveal_nodes=2),leave('checkpoint')])
branch=event('event_supply_inner','柜内的第二层','内层隔板后传来刮擦声，物资就在声音旁边。',[option('inner_take','抓紧取走补给：压力 +2',stress_cost=2,rewards=tables['cache']),option('inner_fight','打开隔板，与钝人交战',encounter=enemies['entity_duller']),leave('inner')])
event('event_locked_room','双层储藏室','外门可以轻易推开，内门似乎曾被人反复加固。',[option('room_enter','查看内层，不立即领取奖励',next_event=branch),leave('room')])
event('event_water_pipe','温热水管','水管上的振动沿墙角向前延伸，能听见微弱的金属敲击。',[option('pipe_follow','按敲击节奏测绘：压力 +1',stress_cost=1,reveal_nodes=3),option('pipe_strike','敲击回应，遭遇肢团',encounter=enemies['entity_clump']),leave('pipe')])

shops=[]
for id,name,offer_specs in [('meg_exchange','M.E.G. 交换箱',[('medical',3,'heal8'),('tactics',4,'tactics'),('water',3,'equip_almond_water')]),('wanderer','流浪者临时摊位',[('crowbar',4,'equip_crowbar'),('beacon',5,'equip_beacon'),('calm',2,'calm3')]),('maintenance','维修员物资箱',[('flashlight',4,'equip_flashlight'),('baton',5,'equip_baton'),('supply',1,'supply2')])]:
    offers=[]
    for oid,price,rid in offer_specs:
        offers.append(resource(f'data/shops/offers/{id}_{oid}.tres','ShopOfferData',id=id+'_'+oid,display_name={'medical':'医疗包','tactics':'战术卡选择','water':'杏仁水','crowbar':'撬棍','beacon':'路线信标','calm':'镇静物资','flashlight':'手电筒','baton':'电击棒','supply':'打折补给'}[oid],price=price,reward=entries[rid]))
    shops.append(resource(f'data/shops/{id}.tres','ShopData',id=id,display_name=name,offers=Arr('ShopOfferData',offers)))

routes={}
for id,name,dests in [('level0_service','维修通道',[('floor_level_6',9),('floor_level_0',1)]),('level0_seam','错位墙缝',[('floor_level_6',7),('floor_level_0',3)]),('level0_marked','标记出口',[('floor_level_6',12),('floor_level_0',1)]),('level6_signal','广播坐标',[('run_end',8),('floor_level_0',2)]),('level6_seam','暗处裂缝',[('run_end',6),('floor_level_0',4)]),('level6_emergency','应急通道',[('run_end',9),('floor_level_6',1)])]:
    destinations=[resource(f'data/cutout/destinations/{id}_{i}.tres','CutOutDestinationData',floor_id=fid,base_weight=float(w)) for i,(fid,w) in enumerate(dests)]
    target=dests[0][0]
    modifiers=[resource(f'data/cutout/modifiers/{id}_knowledge.tres','CutOutModifierData',display_name='已确认路线标记',knowledge_id='seam_route',destination_id=target,multiplier=1.4),resource(f'data/cutout/modifiers/{id}_beacon.tres','CutOutModifierData',display_name='携带路线信标',equipment_id='equip_beacon',destination_id=target,multiplier=1.6)]
    routes[id]=resource(f'data/cutout/{id}.tres','CutOutRouteData',id=id,display_name=name,destinations=Arr('CutOutDestinationData',destinations),modifiers=Arr('CutOutModifierData',modifiers))
floors=[]
for id,name,description,weights,encounters,elites,event_ids,route_ids in [
 ('floor_level_0','零层','重复的黄色走廊；补给、交换与路线信息较多。',[25,5,35,15,12,8],['entity_hound','entity_duller','entity_skinstealer','entity_crawler'],['entity_starved_hound','entity_dense_clump'],['event_cache','event_meg','event_faceling','event_hum','event_battery','event_medic','event_ration','event_insulation','event_sleep','event_diary','event_checkpoint','event_locked_room'],['level0_service','level0_seam','level0_marked']),
 ('floor_level_6','六层','黑暗的路线更危险；Noise 达到 3 时，下次锁定攻击额外 +1。',[40,12,25,8,10,5],['entity_hound','entity_smiler','entity_wretch','entity_clump','entity_deathmoth'],['entity_moth_matriarch','entity_frenzied_wretch','entity_dense_clump'],['event_lights','event_seam','event_footsteps','event_moth_nest','event_beacon','event_blackout','event_water_pipe','event_sleep','event_ration','event_locked_room'],['level6_signal','level6_seam','level6_emergency'])]:
    config=resource(f'data/maps/{id}.tres','MapGenerationData',depth=5,lanes=3,node_weights=Expr('PackedInt32Array('+', '.join(map(str,weights))+')'),reveal_depth=1)
    floors.append(resource(f'data/floors/{id}.tres','FloorData',id=id,display_name=name,description=description,asset_id=id,map_config=config,encounter_pool=Arr('EntityData',[enemies[k] for k in encounters]),elite_pool=Arr('EntityData',[enemies[k] for k in elites]),event_pool=Arr('EventData',[events[k] for k in event_ids]),reward_pool=tables['cache'],shops=Arr('ShopData',shops),cutout_route_pool=Arr('CutOutRouteData',[routes[k] for k in route_ids]),noise_damage_threshold=3 if id=='floor_level_6' else 0,noise_damage_bonus=1 if id=='floor_level_6' else 0))
starter=resource('data/cards/starter_deck.tres','DeckData',cards=Arr('CardData',[cards['card_attack']]*4+[cards['card_defend']]*4+[cards['card_recon']]*2+[cards['card_quick_draw'],cards['card_precision']]))
resource('data/game.tres','GameData',floors=Arr('FloorData',floors),starting_floor='floor_level_0',starter_deck=starter,starting_equipment=Arr('EquipmentData',[gear[k] for k in ['equip_flashlight','equip_crowbar','equip_almond_water']]),statuses=Arr('StatusData',list(statuses.values())),card_pool=Arr('CardData',list(cards.values())),starting_supply=5,revisit_weight_multiplier=0.15)
(ROOT/'docs/PHASE_14_CONTENT_INDEX.json').write_text(json.dumps(INDEX,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print('Generated',len(INDEX),'Resource definitions:',len(cards),'normal cards,',len(upgrades),'upgrades,',len(enemies),'entities,',len(events),'events,',len(gear),'equipment.')
