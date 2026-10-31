"""生成待确认清单，永不删除文件。生产引用与 byte-identical 副本分别记录。"""
from pathlib import Path
import hashlib
import json
import re
ROOT=Path(__file__).resolve().parents[1]
ORIGINALS=('assets/ui_asset_pack/','assets/ref/')
def digest(path): return hashlib.sha256(path.read_bytes()).hexdigest()
def main():
    active=set()
    for folder in ['scripts','scenes','data']:
        for path in (ROOT/folder).rglob('*'):
            if path.is_file() and path.suffix in ['.gd','.tres','.tscn']:
                active.update(x[6:] for x in re.findall(r'[\"\x27](res://assets/[^\"\x27]+)[\"\x27]',path.read_text(encoding='utf-8')))
    manifest=json.loads((ROOT/'assets/asset_manifest.json').read_text(encoding='utf-8'))
    for entry in manifest.values():
        for key in ['path','fallback_path']:
            if entry.get(key,'').startswith('res://assets/'): active.add(entry[key][6:])
    formal={}
    for path in (ROOT/'assets').rglob('*'):
        relative=path.relative_to(ROOT).as_posix()
        if not path.is_file() or path.suffix=='.import' or relative.startswith(ORIGINALS): continue
        formal.setdefault(digest(path),[]).append(relative)
    proposed=[]; retained=[]
    for directory in ORIGINALS:
        for path in sorted((ROOT/directory).rglob('*')):
            if not path.is_file(): continue
            relative=path.relative_to(ROOT).as_posix()
            matches=formal.get(digest(path),[]) if path.suffix!='.import' else []
            record={'path':relative,'bytes':path.stat().st_size,'sha256':digest(path),'formal_duplicates':matches}
            if relative in active:
                record['reason']='正式引用仍存在，禁止删除'; retained.append(record)
            elif directory.endswith('ui_asset_pack/'):
                record['reason']='原始包已排除导入，采用的 8 项及许可已复制到正式目录'; proposed.append(record)
            elif path.name in ['README.md','layout.json','LAYOUT_GUIDE.png','cards.example.json'] and '/godot_demo/' not in relative:
                record['reason']='保留有价值的布局说明/源配置'; retained.append(record)
            elif path.name=='.gdignore':
                record['reason']='保留参考目录的导入隔离标记'; retained.append(record)
            elif matches or '/godot_demo/' in relative or '/samples/' in relative or path.name.startswith('PREVIEW_') or path.suffix=='.import':
                record['reason']='字节相同的正式副本已存在，或为不再启动的示例工程/合成预览/导入旁文件'; proposed.append(record)
            else:
                record['reason']='独有原始美术，无正式相同副本；保留待人工筛选'; retained.append(record)
    result={'status':'AWAITING_USER_APPROVAL_NO_DELETION','proposed':proposed,'retained':retained,'active_original_references':sorted(x for x in active if x.startswith(ORIGINALS))}
    (ROOT/'docs/PHASE_16_CLEANUP_PLAN.json').write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    print('Proposed:',len(proposed),'files /',sum(x['bytes'] for x in proposed),'bytes; retained:',len(retained),'; active original references:',result['active_original_references'])
if __name__=='__main__': main()
