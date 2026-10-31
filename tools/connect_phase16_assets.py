"""选用少量已审查素材并更新既有 AssetCatalog；不修改原包，不下载素材。"""
from pathlib import Path
import shutil
import json
ROOT = Path(__file__).resolve().parents[1]
def run():
    manifest_path = ROOT/'assets/asset_manifest.json'
    data = json.loads(manifest_path.read_text(encoding='utf-8'))
    copies = {
        'Vector/Grey/button_rectangle_depth_flat.svg':'ui/buttons/archive_normal.svg',
        'Vector/Grey/button_rectangle_border.svg':'ui/buttons/archive_hover.svg',
        'Vector/Grey/button_rectangle_flat.svg':'ui/buttons/archive_pressed.svg',
        'Vector/Grey/arrow_basic_e.svg':'ui/icons/navigation_arrow.svg',
        'Sounds/click-a.ogg':'audio/ui/click.ogg',
        'Sounds/tap-a.ogg':'audio/ui/hover.ogg',
        'Sounds/switch-a.ogg':'audio/ui/card.ogg',
        'Sounds/tap-b.ogg':'audio/ui/confirm.ogg',
    }
    for source,target in copies.items():
        dest=ROOT/'assets'/target
        dest.parent.mkdir(parents=True,exist_ok=True)
        if not dest.exists(): shutil.copy2(ROOT/'assets/ui_asset_pack'/source,dest)
    license_dir=ROOT/'assets/licenses'; license_dir.mkdir(exist_ok=True)
    shutil.copy2(ROOT/'assets/ui_asset_pack/License.txt',license_dir/'Kenney-UI-Pack.txt')
    def register(id,path,category,preview=False):
        data[id]={'path':'res://assets/'+path,'category':category,'status':'PROVIDED','usage_scope':'development_preview' if preview else 'project','source':'用户本地素材；许可状态见 docs/PHASE_16_LICENSES.md'}
    for name in ['normal','hover','pressed']: register('ui_archive_'+name,'ui/buttons/archive_'+name+'.svg','UI')
    register('icon_navigation','ui/icons/navigation_arrow.svg','图标')
    register('menu_background','backgrounds/level_0/background.png','背景')
    register('intro_background','defaults/art_flicker.png','背景')
    for id,file in [('font_display','ShinsyokuMincho-Regular.ttf'),('font_archive','bahnschrift.ttf'),('font_numbers','bahnschrift.ttf')]: register(id,'ui/fonts/'+file,'字体',True)
    for id,file in [('audio_button_click','click'),('audio_button_hover','hover'),('audio_card_play','card'),('audio_card_draw','card'),('audio_reward','confirm'),('audio_block','confirm'),('audio_attack','card'),('audio_hit','click'),('audio_status','confirm'),('audio_cutout','confirm')]: register(id,'audio/ui/'+file+'.ogg','音效')
    for id,file in [('music_menu','Beige_Nocturne_loop_L'),('music_intro','hum_loop_L'),('ambience_level_0','hum_loop_L'),('ambience_level_6','Mormo_loop_L'),('ambience_level_7','DamplyDry_loop1_L'),('music_combat','Unusable_Eyelid_loop_L')]: register(id,'audio/ambience/'+file+'.ogg','环境/音乐',True)
    register('audio_hound','audio/sfx/juanjo_sound - Backrooms Entity 1.wav','实体音',True)
    register('audio_smiler','audio/sfx/juanjo_sound - Backrooms Entity 5.wav','实体音',True)
    for id,file in [('icon_supply','icon_item_category'),('icon_intel','search'),('icon_event','icon_event_category'),('icon_combat','icon_skill_category'),('icon_reward','icon_item_category'),('icon_shop','icon_gear'),('icon_status','icon_status_category')]: register(id,'ui/icons/'+file+'.png','图标')
    manifest_path.write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    (ROOT/'docs/PHASE_16_ADOPTED_PACK.json').write_text(json.dumps({'source':'assets/ui_asset_pack','license':'assets/licenses/Kenney-UI-Pack.txt','copies':copies},ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    print('Selected eight pack files; originals retained; updated existing catalog.')
if __name__=='__main__': run()
