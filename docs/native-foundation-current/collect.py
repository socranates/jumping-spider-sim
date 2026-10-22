"""Collect exact-source native fixture output, without account/engine telemetry."""
from pathlib import Path
import argparse, hashlib, json, re, shutil
HERE=Path(__file__).resolve().parent
p=argparse.ArgumentParser();p.add_argument('log',type=Path);p.add_argument('folder',type=Path);a=p.parse_args()
sha=lambda b:hashlib.sha256(b).hexdigest()
m=json.loads((a.folder/'manifest.json').read_text(encoding='utf8'))
assert m['source']=='8e02b5ee5f443ab332cf7e70f5951a304cb89eea'
assert m['persistence_disabled'] and len(m['scripts'])==217
assert m['place_sha256']==sha((a.folder/'Windowsill-observed-life-review.rbxlx').read_bytes())
assert next(r['sha256'] for r in m['scripts'] if r['path'].endswith('.SilkPlayback'))==sha((HERE/'native-probe.luau').read_bytes())
rows=a.log.read_text(encoding='utf8',errors='replace').splitlines()
start=max(i for i,s in enumerate(rows) if '[FLog::CreatorOutput] [FOUNDATION_NATIVE_GUARD]' in s)
rows=[s for s in rows[start:] if re.search(r'\[FLog::Creator(?:Output|Warning|Error)\]',s)]
assert not any('[FLog::CreatorError]' in s or '_FAIL]' in s for s in rows)
def group(prefix,count,total):
 cases=[re.search(r'\['+prefix+r'_CASE\] (\d+) (\d+) (\d+) (.*)$',s) for s in rows]
 cases=[m for m in cases if m];assert len(cases)==count
 assert [int(m[2]) for m in cases]==list(range(1,count+1))
 run=cases[0][1];assert all(m[1]==run for m in cases) and int(cases[-1][3])==total
 assert any('['+prefix+'_DONE] '+run+' '+str(count)+' '+str(total) in s for s in rows)
 return dict(run_id=run,cases=count,assertions=total)
shadow=group('SHADOW_CLEANUP',7,1513);save=group('OBSERVED_LIFE',8,45)
output=('\n'.join(rows)+'\n').encode();(HERE/'native-output.txt').write_bytes(output)
for name in ['manifest.json','guard.luau']:shutil.copyfile(a.folder/name,HERE/('prepared-'+name))
receipt=dict(source=m['source'],place_sha256=m['place_sha256'],scripts=217,persistence_disabled=True,
 shadow=shadow,save=save,output_sha256=sha(output),creator_errors=0,
 scope='Real Instance shadow lifecycle and native-captured checkpoint fixtures against synthetic MemoryBackend save sessions',
 online_store_accessed=False,real_client_rejoin_verified=False,automatic_network_streaming_verified=False,
 performance_improvement_verified=False,published=False)
(HERE/'receipt.json').write_text(json.dumps(receipt,indent=2)+'\n',encoding='utf8',newline='\n')
print(json.dumps(receipt,indent=2))
