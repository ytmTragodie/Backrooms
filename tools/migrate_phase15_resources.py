"""Phase 16A：显式、可重跑的 Resource 路径迁移，不覆盖数据或删除参考素材。"""
from pathlib import Path
import json
import re

ROOT = Path(__file__).resolve().parents[1]
FOLDERS = {
    'MapRuleData':'maps/rules','MapRegionData':'maps/regions','MapGenerationData':'maps',
    'FloorEntranceData':'floors/entrances','TravelRequirementData':'cutout/requirements',
    'CutOutRouteData':'cutout','CutOutDestinationData':'cutout/destinations',
    'EntityData':'entities','EntityBehaviorData':'entities/behaviors','EntityActionData':'entities/actions',
    'WeaknessData':'entities/reactions','TriggerData':'entities/triggers','EffectData':'effects',
    'RewardTableData':'rewards','RewardEntryData':'rewards/entries','EventData':'events','EventOptionData':'events/options',
}
def path_for_resource(name, cls):
    filename = 'floor_level_7' if name == 'map_level7' else name
    return f'data/{FOLDERS[cls]}/{filename}.tres'

def migrate():
    old_dir = ROOT/'data'/'phase15'
    report_path = ROOT/'docs/PHASE_16_RESOURCE_MIGRATION.json'
    if not old_dir.exists():
        print('Migration already complete; no stage directory exists.')
        return
    mapping = {}
    for source in sorted(old_dir.glob('*.tres')):
        text = source.read_text(encoding='utf-8')
        cls = re.search(r'script_class="([^"]+)"',text).group(1)
        target = ROOT/path_for_resource(source.stem,cls)
        if target.exists(): raise RuntimeError(f'Collision, refusing overwrite: {target}')
        if not source.resolve().is_relative_to(ROOT) or not target.resolve().is_relative_to(ROOT): raise RuntimeError('Outside workspace')
        mapping[source.relative_to(ROOT).as_posix()] = target.relative_to(ROOT).as_posix()
    # 全部目的路径确认后才移动；文件头中的 authored UID 与 sidecar 原样保留。
    for old,new in mapping.items():
        source,target = ROOT/old,ROOT/new
        target.parent.mkdir(parents=True,exist_ok=True)
        source.rename(target)
        sidecar = Path(str(source)+'.uid')
        if sidecar.exists(): sidecar.rename(Path(str(target)+'.uid'))
    changed = []
    for directory in ['data','scenes','scripts','tests','docs']:
        for path in (ROOT/directory).rglob('*'):
            if not path.is_file() or path.suffix not in ['.tres','.tscn','.gd','.json']: continue
            text = path.read_text(encoding='utf-8')
            after = text
            for old,new in mapping.items(): after = after.replace(old,new)
            if after != text:
                path.write_text(after,encoding='utf-8')
                changed.append(path.relative_to(ROOT).as_posix())
    if not any(old_dir.iterdir()): old_dir.rmdir()  # 只移除已空的本次阶段分类目录。
    report_path.write_text(json.dumps({'moves':mapping,'reference_files':changed},ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    print(f'Moved {len(mapping)} resources; updated {len(changed)} referencing files; no business data removed.')

if __name__ == '__main__': migrate()
