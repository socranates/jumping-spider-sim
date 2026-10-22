"""Reconstruct bounded native rig events; never converts isolated CPU time into game FPS."""
from pathlib import Path
import argparse,json,re,zlib,hashlib
p=argparse.ArgumentParser();p.add_argument('--events',required=True);p.add_argument('--out',required=True);a=p.parse_args()
path=Path(a.events);text=path.read_text(encoding='utf-8',errors='replace')
assert 'CreatorError' not in text and '[CHET_RIG_FAIL]' not in text
assert '[CHET_RIG_GUARD] 3647a94c67f83076a0c7be09d75ef4a60bb0b4d5 176' in text
done=re.findall(r'\[CHET_RIG_DONE\]\s+(\d+)\s+(\d+)',text);assert len(done)==1 and done[0][1]=='16'
run=done[0][0];records={}
for m in re.finditer(r'\[CHET_RIG_BEGIN\]\s+(\d+)\s+(\S+)\s+(\d+)\s+(\d+)\s+(\d+)',text):
 r,kind,length,n,crc=m.groups();assert r==run and kind not in records
 pieces={}
 for d in re.finditer(r'\[CHET_RIG_DATA\]\s+'+re.escape(run)+r'\s+'+re.escape(kind)+r'\s+(\d+)\s+(".*")',text):
  i=int(d[1]);assert i not in pieces;pieces[i]=json.loads(d[2])
 assert set(pieces)==set(range(1,int(n)+1))
 assert len(re.findall(r'\[CHET_RIG_END\]\s+'+re.escape(run)+r'\s+'+re.escape(kind)+r'\s*$',text,re.M))==1
 data=''.join(pieces[i] for i in range(1,int(n)+1)).encode()
 assert len(data)==int(length) and zlib.adler32(data)==int(crc)
 records[kind]=json.loads(data)
assert len(records)==17
header=records.pop('header');assert header['source']=='3647a94c67f83076a0c7be09d75ef4a60bb0b4d5'
here=Path(__file__).resolve().parent
old=json.loads((here/'manifest-v1d.json').read_text());new=json.loads((here/'manifest-v1e.json').read_text())
assert {r['path']:r['sha256'] for r in old['scripts']}=={r['path']:r['sha256'] for r in new['scripts']}
assert len(new['scripts'])==176 and new['source']==header['source']
ids={'brachypelma_hamorii','chromatopelma_cyaneopubescens','first_spider','first_spider_male','maratus_volans_male','myrmarachne_formicaria_female','rival_spider'}
assert set(records)=={i+'_'+t+'_walk' for i in ids for t in ('full','low')}|{'first_spider_full_stand','first_spider_full_growth_hang'}
def stats(v):
 s=sorted(v);return {'n':len(v),'mean':sum(v)/len(v),'p95':s[__import__('math').ceil(len(v)*.95)-1],'max':s[-1]}
for kind,r in records.items():
 assert r['n']==(240 if kind.startswith('first_spider_full_') else 90)
 assert r['focus_preserved'] and r['viewport_unchanged'],kind
 assert r['max_position_error']<1e-4 and r['max_axis_error']<2e-3 and r['max_size_error']<1e-5,kind
 assert set(r['raw_ms'])=={'original','cached','instrumented'}
 for name,v in r['raw_ms'].items():
  assert len(v)==r['n'] and all(x>=0 for x in v)
  calculated=stats(v)
  assert all(abs(calculated[k]-r['cpu_ms'][name][k])<1e-8 for k in calculated),(kind,name)
result={'source':header['source'],'run':run,'header':header,'cases':records,'native_pose_verified':True,
 'events_sha256':hashlib.sha256(path.read_bytes()).hexdigest(),'scope':'One isolated rig CPU trial; three rigs, validation and probe overhead; not game FPS',
 'production_changed':False,'whole_game_speedup_verified':False,'published':False}
Path(a.out).write_text(json.dumps(result,indent=2)+'\n',encoding='utf-8',newline='\n')
print('native rig: 16 cases, chunk checksums, poses, focus, viewport and recomputed CPU summaries passed')
