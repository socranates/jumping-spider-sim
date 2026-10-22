from pathlib import Path
import argparse,hashlib,json,re
HERE=Path(__file__).resolve().parent
p=argparse.ArgumentParser();p.add_argument('--log',required=True);a=p.parse_args()
m=json.loads((HERE/'prepared-native-manifest.json').read_text(encoding='utf8'));source=m['source']
lines=Path(a.log).read_text(encoding='utf8').splitlines();guard='[NATIVE_PREY_READY_GUARD] '+source+' 225 persistence_disabled'
start=[i for i,l in enumerate(lines) if guard in l and ' > ' not in l][-1]
ends=[i for i,l in enumerate(lines) if i>start and '[NATIVE_READY_SEQUENCE_END]' in l];assert len(ends)==1
span=lines[start:ends[0]+1]
assert not any('[NATIVE_READINESS_FAIL]' in l or '[NATIVE_PREY_READY_FAIL]' in l or '[FLog::CreatorError]' in l for l in span)
rows=[l.split('[FLog::CreatorOutput] ',1)[1] for l in span if '[FLog::CreatorOutput]' in l and re.search(r'\[NATIVE_(?:PREY_READY|READINESS|READY_SEQUENCE)_',l) and ' > ' not in l]
text='\n'.join(rows)+'\n'
creature=re.search(r'\[NATIVE_READINESS_PASS\] (\d+) 11',text);prey=re.search(r'\[NATIVE_PREY_READY_PASS\] (\d+) 11',text);sequence=re.search(r'\[NATIVE_READY_SEQUENCE_END\] (\d+)',text)
assert creature and prey and sequence and len(rows)==8
sha=lambda b:hashlib.sha256(b).hexdigest()
(HERE/'native-output.txt').write_text(text,encoding='utf8',newline='\n')
r=dict(source=source,sequence=sequence[1],creature_run=creature[1],prey_run=prey[1],assertions=22,scripts=225,creator_errors=0,persistence_disabled=True,
 output_sha256=sha(text.encode()),place_sha256=m['place_sha256'],no_concurrent_cli=True,manual_ticks_while_menu_paused=True,
 scope='Real client gate and cached PreyWorld objects, locally removed/restored geometry and manual ticks; no naturally induced server streaming or FPS proof',published=False)
(HERE/'native-receipt.json').write_text(json.dumps(r,indent=2)+'\n',encoding='utf8',newline='\n');print(json.dumps(r,indent=2))
