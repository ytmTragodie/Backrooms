"""一次性 Phase 15 数据迁移。仅更新本阶段列明的配置，不调用旧内容生成器。
再次执行会覆盖 Phase 15 资源；编辑资源后请勿直接重跑。
"""
from pathlib import Path
import json
import re

ROOT = Path(__file__).resolve().parents[1]
SCRIPTS = {
 'MapRuleData':'maps/map_rule_data', 'MapRegionData':'maps/map_region_data',
 'MapGenerationData':'maps/map_generation_data','FloorData':'floors/floor_data',
 'FloorEntranceData':'floors/floor_entrance_data','TravelRequirementData':'cutout/travel_requirement_data',
 'CutOutDestinationData':'cutout/cutout_destination_data','CutOutRouteData':'cutout/cutout_route_data',
 'EntityData':'entities/entity_data','EntityBehaviorData':'entities/entity_behavior_data',
 'EntityActionData':'entities/entity_action_data','WeaknessData':'entities/weakness_data',
 'ConditionData':'entities/entity_condition_data','TriggerData':'entities/trigger_data',
 'EffectData':'effects/effect_data','RewardTableData':'rewards/reward_table_data',
 'RewardEntryData':'rewards/reward_entry_data','EventData':'events/event_data','EventOptionData':'events/event_option_data',
 'EquipmentData':'equipment/equipment_data','ShopData':'rewards/shop_data',
}
class Ref:
 def __init__(self,path): self.path='res://'+path
class Arr:
 def __init__(self,cls,values): self.cls,self.values=cls,values
class Expr:
 def __init__(self,value): self.value=value
INDEX=[]
def resource(path,cls,**props):
 refs=[('Script',f'res://scripts/{SCRIPTS[cls]}.gd')]
 def external(kind,path):
  pair=(kind,path)
  if pair not in refs: refs.append(pair)
  return f'ExtResource("{refs.index(pair)+1}")'
 def encode(v):
  if isinstance(v,Ref): return external('Resource',v.path)
  if isinstance(v,Arr):
   script=external('Script',f'res://scripts/{SCRIPTS[v.cls]}.gd')
   return f'Array[{script}](['+', '.join(encode(x) for x in v.values)+'])'
  if isinstance(v,Expr): return v.value
  if isinstance(v,list): return 'Array[StringName](['+', '.join('&'+json.dumps(x,ensure_ascii=False) for x in v)+'])'
  if isinstance(v,str): return json.dumps(v,ensure_ascii=False)
  if isinstance(v,bool): return str(v).lower()
  return str(v)
 body='\n'.join(f'{k} = {encode(v)}' for k,v in props.items())
 header=f'[gd_resource type="Resource" script_class="{cls}" load_steps={len(refs)+1} format=3]\n\n'
 header+='\n'.join(f'[ext_resource type="{kind}" path="{p}" id="{i+1}"]' for i,(kind,p) in enumerate(refs))
 target=ROOT/path
 target.parent.mkdir(parents=True,exist_ok=True)
 target.write_text(header+'\n\n[resource]\nscript = ExtResource("1")\n'+body+'\n',encoding='utf-8')
 INDEX.append({'path':'res://'+path,'type':cls,'id':props.get('id','')})
 return Ref(path)

def make(name,cls,**props): return resource('data/phase15/'+name+'.tres',cls,**props)
def old(category,id): return Ref(f'data/{category}/{id}.tres')
def array(cls,refs): return Arr(cls,refs)
def table(name,kind,amount):
 entry=make('reward_'+name,'RewardEntryData',kind=kind,amount=amount)
 return make(name,'RewardTableData',id=name,guaranteed_rewards=array('RewardEntryData',[entry]))
high_reward=table('salvage_supplies',1,6)
calm=table('shelter_calm',4,3)
toys=table('toy_cache',1,2)

def event(id,name,desc,knowledge=(),known_floors=(),known_exits=(),reward=None):
 props=dict(id=id+'_read',display_name='记录线索，继续前进',knowledge=list(knowledge),known_floors=list(known_floors),known_exits=list(known_exits))
 if reward: props['rewards']=reward
 option=make(id+'_read','EventOptionData',**props)
 leave=make(id+'_leave','EventOptionData',id=id+'_leave',display_name='不作停留')
 return make(id,'EventData',id=id,display_name=name,description=desc,options=array('EventOptionData',[option,leave]),asset_id=id)

waves=event('event_waves','黑暗中的潮声','阶梯下传来微弱海浪声。记录上写着：先到客厅，再看见海。',known_floors=['floor_level_7'],known_exits=['level6_waves'],knowledge=['route_floor_level_7'])
room=event('event_slanted_room','倾斜的客厅','荧光灯下的地板看似倾斜，脚下的重力却很正常。门外是冰冷的海。',knowledge=['ocean_gravity'],reward=calm)
bath=event('event_bathroom','渗水的白窗','浅海水从破窗渗进浴室。墙上的警告：淋浴温度不定，不要冒险取暖。',knowledge=['cold_water_warning'])
bed=event('event_toy_room','嗡鸣的儿童房','玩具箱似乎取之不尽，但能携走的补给有限。你只整理一次有用的材料。',reward=toys)
camp=event('event_diver_notes','研究队的防水笔记','残页警告：巨影畏惧强光。清楚它的反应比试图杀死它更有用。',knowledge=['abyss_light'])
bones=event('event_seabed_bones','潮湿沙地上的骸骨','水下暗处铺着近似湿地毯的沙层。巨大鱼骨旁留有一段折断的照明杆。',knowledge=['abyss_light'])
cave=event('event_cave_chart','水下洞穴草图','草图将洞穴标成通往八层的传闻。此路线尚未开放；附近的撤收绳索才是当前能走的路。',knowledge=['lore_level_8'],known_exits=['level7_cave'])
door=event('event_fire_door','漏水的防火门','旧营地记录称门后曾通往四层。现有绳索已接到撤收队；不要把历史记录当作当前保证。',knowledge=['lore_level_4'],known_exits=['level7_fire_door'])

# 新实体仍使用共用 HP/意图/弱点管线，不做 Boss 或新状态。
hit=make('abyss_hit','EffectData',effect_type=0,target=1,amount=6)
action=make('abyss_surge','EntityActionData',id='abyss_surge',display_name='暗潮撞击',effects=array('EffectData',[hit]))
behavior=make('abyss_behavior','EntityBehaviorData',actions=array('EntityActionData',[action]))
trigger=make('abyss_light_trigger','TriggerData',trigger_type=1,effect_tag='STRONG_LIGHT')
reaction=make('abyss_light_reaction','WeaknessData',id='abyss_light_withdraw',trigger=trigger,effects=array('EffectData',[old('effects','withdraw')]),state_after='WITHDRAWN')
thing=make('entity_thing7','EntityData',id='entity_thing7',display_name='七层之物 · 逼近的巨影',description='巨影遮住了去路，难以靠正面伤害压倒。先前的防水笔记或许能派上用场；也可承受公开代价撤离。',asset_id='entity_thing7',max_hp=90,damage_reduction=2,initial_state='APPROACHING',behavior_data=behavior,weaknesses=array('WeaknessData',[reaction]),reward_data=high_reward,escape_damage_min=4,escape_damage_max=7,escape_stress=3,behavior_knowledge='abyss_light')

entrances={}
for level,label in [(0,'维护入口'),(6,'黑暗阶梯'),(7,'房屋客厅')]:
 entrances[level]=make(f'entrance_{level}','FloorEntranceData',id='entry',display_name=label)
for path in sorted((ROOT/'data/cutout/destinations').glob('*.tres')):
 text=path.read_text(encoding='utf-8')
 if not re.search(r'^id =',text,re.M): text += f'id = "{path.stem}"\n'
 path.write_text(text,encoding='utf-8')
# 一次迁移：modifier 目标从楼层身份改成连接身份；不保留双匹配逻辑。
for path in sorted((ROOT/'data/cutout/modifiers').glob('*.tres')):
 text=path.read_text(encoding='utf-8'); route=path.stem.rsplit('_',1)[0]
 floor=re.search(r'destination_id = "([^"]+)"',text).group(1)
 for dest in (ROOT/'data/cutout/destinations').glob(route+'_*.tres'):
  if f'floor_id = "{floor}"' in dest.read_text(encoding='utf-8'):
   text=re.sub(r'destination_id = "[^"]+"',f'destination_id = "{dest.stem}"',text); break
 path.write_text(text,encoding='utf-8')

def destination(id,floor,weight=1,requirements=()): return make(id,'CutOutDestinationData',id=id,floor_id=floor,base_weight=weight,requirements=array('TravelRequirementData',list(requirements)))
def route(id,name,destinations,hp=0,stress=0): return make(id,'CutOutRouteData',id=id,display_name=name,destinations=array('CutOutDestinationData',destinations),hp_cost=hp,stress_cost=stress)
waves_route=route('level6_waves','潮声阶梯',[destination('waves_house','floor_level_7')])
gear_req=make('crowbar_requirement','TravelRequirementData',kind=1,id='equip_crowbar',description='携带尚可使用的撬棍')
knowledge_req=make('cave_requirement','TravelRequirementData',kind=0,id='lore_level_8',description='读过洞穴草图')
# 条件只改变额外候选；无条件候选始终存在。未知的八层/四层仅出现在事件传闻里。
fire=route('level7_fire_door','防火门撤收索',[destination('fire_evac','run_end',8),destination('fire_maintenance','floor_level_0',2,[gear_req])])
deep=route('level7_cave','洞穴边缘的撤收绳',[destination('cave_evac','run_end',8),destination('cave_stairs','floor_level_6',2,[knowledge_req])],hp=3,stress=2)

def rule(id,kind,**kw): return make(id,'MapRuleData',id=id,kind=kind,**kw)
limits={n:rule(f'limit_{n}',3,required=True,max_consecutive=2 if n==0 else 3) for n in [0,6,7]}
preferred=rule('preferred_pacing',3,probability=.8,max_consecutive=2)
anchor=rule('abyss_anchor',0,required=True,target_kind=1,target_content_id='entity_thing7',min_layer=4,max_layer=4)
intel=rule('abyss_intel',1,required=True,target_kind=1,target_content_id='entity_thing7',anchor_rule_id='abyss_anchor',min_layer=4,max_layer=4,clue_event=camp,mandatory_path=True)
support=rule('abyss_salvage',2,required=True,target_kind=1,target_content_id='entity_thing7',anchor_rule_id='abyss_anchor',min_layer=4,max_layer=4,support_kind=4,reward=high_reward)
optional=rule('occasional_bones',1,probability=.45,target_kind=1,min_layer=4,clue_event=bones)
wave_rule=rule('occasional_waves',0,probability=.6,target_kind=2,target_content_id='event_waves',min_layer=2,max_layer=3)
tracks=event('event_warning_tracks','爪痕旁的字条','字条提醒：猎犬会追逐噪音。更安静的行动不会把调查进度变成伤害；战斗时留意公开意图。',knowledge=['hound_noise'])
level0_optional=rule('hound_intel',1,probability=.45,target_kind=1,target_content_id='entity_starved_hound',min_layer=4,clue_event=tracks)
for n,rules in [(0,[limits[0],level0_optional]),(6,[limits[6],preferred,wave_rule])]:
 path=ROOT/f'data/maps/floor_level_{n}.tres'
 text=path.read_text(encoding='utf-8')
 # 用独立配置资源，避免复杂原文件插入器。
 props=dict(depth=5,lanes=3,node_weights=Expr('PackedInt32Array(35, 8, 30, 12, 10, 5)'),reveal_depth=1,exit_count=3,rules=array('MapRuleData',rules))
 if n==6: props['node_weights']=Expr('PackedInt32Array(38, 14, 25, 10, 8, 5)')
 resource(f'data/maps/floor_level_{n}.tres','MapGenerationData',**props)
house=make('house_region','MapRegionData',id='house',display_name='房屋',first_layer=1,last_layer=2,node_weights=Expr('PackedInt32Array(0, 0, 65, 20, 10, 5)'),event_ids=['event_slanted_room','event_bathroom','event_toy_room','event_diver_notes'])
sea=make('ocean_region','MapRegionData',id='ocean',display_name='海洋',first_layer=3,last_layer=6,node_weights=Expr('PackedInt32Array(28, 15, 30, 10, 12, 5)'),event_ids=['event_seabed_bones','event_cave_chart','event_fire_door'],encounter_ids=['entity_thing7'],elite_ids=['entity_thing7'])
config=make('map_level7','MapGenerationData',depth=6,lanes=3,exit_count=2,rules=array('MapRuleData',[anchor,limits[7],preferred,intel,support,optional]),regions=array('MapRegionData',[house,sea]))
floor7=resource('data/floors/floor_level_7.tres','FloorData',id='floor_level_7',display_name='七层 · 恐海',description='先经过房屋，再进入冰冷海洋。海中巨影可借强光驱离；末端出口公开生命与压力代价。',asset_id='floor_level_7',map_config=config,encounter_pool=array('EntityData',[thing]),elite_pool=array('EntityData',[thing]),event_pool=array('EventData',[room,bath,bed,camp,bones,cave,door]),reward_pool=old('rewards','cache'),additional_rewards=array('RewardTableData',[high_reward]),shops=array('ShopData',[old('shops','meg_exchange')]),cutout_route_pool=array('CutOutRouteData',[fire,deep]),entrances=array('FloorEntranceData',[entrances[7]]))

def append_ref(path,property,cls,refs):
 text=path.read_text(encoding='utf-8')
 for index,ref in enumerate(refs):
  key=f'p15_{property}_{index}'
  if f'id="{key}"' not in text: text=text.replace('[resource]',f'[ext_resource type="Resource" path="{ref.path}" id="{key}"]\n\n[resource]')
  if re.search(rf'^{property} =',text,re.M):
   line=re.search(rf'^{property} =.*$',text,re.M).group(0)
   if f'ExtResource("{key}")' not in line: text=text.replace(line,line[:-2]+f', ExtResource("{key}")])')
  else:
   skey=f'p15_type_{property}'
   if f'id="{skey}"' not in text: text=text.replace('[resource]',f'[ext_resource type="Script" path="res://scripts/{SCRIPTS[cls]}.gd" id="{skey}"]\n\n[resource]')
   text+=f'{property} = Array[ExtResource("{skey}")]([ExtResource("{key}")])\n'
 count=len(re.findall(r'^\[ext_resource',text,re.M))+1
 text=re.sub(r'load_steps=\d+',f'load_steps={count}',text)
 path.write_text(text,encoding='utf-8')
for n in [0,6]: append_ref(ROOT/f'data/floors/floor_level_{n}.tres','entrances','FloorEntranceData',[entrances[n]])
append_ref(ROOT/'data/floors/floor_level_6.tres','event_pool','EventData',[waves])
append_ref(ROOT/'data/floors/floor_level_0.tres','event_pool','EventData',[tracks])
append_ref(ROOT/'data/floors/floor_level_6.tres','cutout_route_pool','CutOutRouteData',[waves_route])
# 六层保留旧路线池，并由地图生成器抽取三个不同的实际末端。
append_ref(ROOT/'data/game.tres','floors','FloorData',[floor7])
(ROOT/'docs/PHASE_15_CONTENT_INDEX.json').write_text(json.dumps(INDEX,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
manifest_path=ROOT/'assets/asset_manifest.json'
manifest=json.loads(manifest_path.read_text(encoding='utf-8'))
for row in INDEX:
 if row['type'] not in ['FloorData','EventData','EntityData']: continue
 manifest.setdefault(row['id'],{'path':'','status':'PLACEHOLDER','category':'背景' if row['type']=='FloorData' else '插画','fallback_path':'res://assets/placeholders/background.svg' if row['type']=='FloorData' else 'res://assets/cards/default-cardcover.png','notes':'Phase 15：缺少专属素材，使用本地默认；素材不影响玩法。','missing_priority':'P1'})
manifest_path.write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print(f'Phase 15: {len(INDEX)} connected/configured resources')
