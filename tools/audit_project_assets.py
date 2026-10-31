"""Phase 16 只读资源审计。使用标准库解析 sfnt 字体与音频标签，不安装依赖。"""
from pathlib import Path
import hashlib
import json
import struct
import wave
import re

ROOT = Path(__file__).resolve().parents[1]
def font_info(path):
    raw = path.read_bytes()
    tables = {}
    for i in range(struct.unpack_from('>H', raw, 4)[0]):
        tag, _, offset, length = struct.unpack_from('>4sIII', raw, 12 + i * 16)
        tables[tag] = raw[offset:offset+length]
    names = {}
    name = tables.get(b'name', b'')
    if name:
        _, count, base = struct.unpack_from('>HHH', name)
        for i in range(count):
            platform, encoding, language, key, length, offset = struct.unpack_from('>HHHHHH', name, 6+i*12)
            if key not in [0, 1, 2, 4, 6, 8, 9, 11, 13, 14]: continue
            value = name[base+offset:base+offset+length].decode('utf-16-be' if platform in [0,3] else 'mac_roman', errors='replace')
            names.setdefault(str(key), [])
            if value not in names[str(key)]: names[str(key)].append(value)
    codepoints = set()
    cmap = tables.get(b'cmap', b'')
    for i in range(struct.unpack_from('>H', cmap, 2)[0] if cmap else 0):
        platform, encoding, offset = struct.unpack_from('>HHI', cmap, 4+i*8)
        if platform not in [0,3]: continue
        fmt = struct.unpack_from('>H', cmap, offset)[0]
        if fmt == 12:
            groups = struct.unpack_from('>I', cmap, offset+12)[0]
            for j in range(groups):
                start,end,glyph = struct.unpack_from('>III',cmap,offset+16+j*12)
                codepoints.update(range(start,end+1))
        elif fmt == 4:
            segments = struct.unpack_from('>H',cmap,offset+6)[0]//2
            ends = offset+14
            starts = ends+2*segments+2
            deltas = starts+2*segments
            offsets = deltas+2*segments
            for j in range(segments):
                end = struct.unpack_from('>H',cmap,ends+2*j)[0]
                start = struct.unpack_from('>H',cmap,starts+2*j)[0]
                delta = struct.unpack_from('>h',cmap,deltas+2*j)[0]
                relative = struct.unpack_from('>H',cmap,offsets+2*j)[0]
                for cp in range(start,min(end,65534)+1):
                    at = offsets+2*j+relative+2*(cp-start)
                    glyph = ((cp+delta)&65535) if not relative else struct.unpack_from('>H',cmap,at)[0] if at+2 <= len(cmap) else 0
                    if glyph: codepoints.add(cp)
    sample = '后室切出生命压力补给行动点情报噪音探索结束回合0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ→＋－？：'
    return {'path':str(path.relative_to(ROOT)).replace('\\','/'),'names':names,'mapped_codepoints':len(codepoints),'sample_present':''.join(c for c in sample if ord(c) in codepoints),'sample_missing':''.join(c for c in sample if ord(c) not in codepoints)}

def audio_info(path):
    raw = path.read_bytes()
    info = {'path':str(path.relative_to(ROOT)).replace('\\','/'),'bytes':len(raw)}
    if path.suffix.lower() == '.wav':
        with wave.open(str(path)) as stream:
            info.update(seconds=round(stream.getnframes()/stream.getframerate(),3),channels=stream.getnchannels(),rate=stream.getframerate())
        info['metadata_strings'] = re.findall(rb'[ -~]{12,}',raw[:512])[:8]
        info['metadata_strings'] = [s.decode('ascii') for s in info['metadata_strings']]
    elif path.suffix.lower() == '.ogg':
        marker = raw.find(b'\x03vorbis')
        comments = []
        if marker >= 0:
            pos = marker+7
            length = struct.unpack_from('<I',raw,pos)[0]; pos += 4
            info['vendor'] = raw[pos:pos+length].decode(errors='replace'); pos += length
            count = struct.unpack_from('<I',raw,pos)[0]; pos += 4
            for i in range(count):
                length = struct.unpack_from('<I',raw,pos)[0]; pos += 4
                comments.append(raw[pos:pos+length].decode(errors='replace')); pos += length
        info['comments'] = comments
    return info

def audit():
    files = [p for p in (ROOT/'assets').rglob('*') if p.is_file() and p.suffix != '.import' and p.name != '.gitkeep']
    groups = {}
    for path in files: groups.setdefault(hashlib.sha256(path.read_bytes()).hexdigest(),[]).append(str(path.relative_to(ROOT)).replace('\\','/'))
    report = {
        'data_inventory':[{'path':p.relative_to(ROOT).as_posix(),'class':(re.search(r'script_class="([^"]+)"',p.read_text(encoding='utf-8')).group(1) if 'script_class=' in p.read_text(encoding='utf-8') else 'Resource'),'authored_uid':(re.search(r'\buid="([^"]+)"',p.read_text(encoding='utf-8')).group(1) if re.search(r'\buid="([^"]+)"',p.read_text(encoding='utf-8')) else None)} for p in sorted((ROOT/'data').rglob('*.tres'))],
        'fonts':[font_info(p) for p in files if p.suffix.lower() in ['.ttf','.otf']],
        'audio':[audio_info(p) for p in files if p.suffix.lower() in ['.ogg','.wav']],
        'license_files':[str(p.relative_to(ROOT)).replace('\\','/') for p in files if any(s in p.name.lower() for s in ['license','licence','readme','credit','copying'])],
        'identical_files':[g for g in groups.values() if len(g)>1],
        'inventory':[{'path':str(p.relative_to(ROOT)).replace('\\','/'),'bytes':p.stat().st_size} for p in files],
    }
    target = ROOT/'docs/PHASE_16_ASSET_AUDIT.json'
    target.write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    print('Fonts:',[(p['path'],p['names'].get('1'),p['mapped_codepoints'],p['sample_missing']) for p in report['fonts']])
    print('Audio:',[(p['path'],p.get('comments'),p.get('metadata_strings')) for p in report['audio']])
    print('Licenses:',report['license_files'])
    print('Assets:',len(files),'duplicate groups:',len(report['identical_files']))

if __name__ == '__main__': audit()
