"""Collect an actually completed guarded native cleanup run; never infer execution."""
from pathlib import Path
import argparse,hashlib,json,re,subprocess
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[1]
p=argparse.ArgumentParser();p.add_argument('log',type=Path);p.add_argument('folder',type=Path);p.add_argument('--run',help='Explicit run id when the Studio log contains multiple attempts');a=p.parse_args()
sha=lambda b:hashlib.sha256(b).hexdigest()
m=json.loads((HERE/'prepared-native-manifest.json').read_text(encoding='utf8'))
source=subprocess.check_output(['git','log','-1','--format=%H','--','roblox_port/src','roblox_port/tests'],cwd=ROOT,text=True).strip()
assert m['source']==source and m['case']=='cleanup' and m['persistence_disabled'] and len(m['scripts'])==218
assert sha((a.folder/'Windowsill-lease-cleanup-review.rbxlx').read_bytes())==m['place_sha256']
rows=a.log.read_text(encoding='utf8',errors='replace').splitlines()
begin=[(i,re.search(r'\[LEASE_CLEANUP_NATIVE_BEGIN\] (\d+)$',s)) for i,s in enumerate(rows) if '[FLog::CreatorOutput]' in s]
begin=[(i,b) for i,b in begin if b and (a.run is None or b[1]==a.run)];assert len(begin)==1, 'choose one exact run with --run'
start_run,b=begin[0];run=b[1]
guards=[i for i,s in enumerate(rows[:start_run]) if '[FLog::CreatorOutput] [LEASE_CLEANUP_NATIVE_GUARD] '+source+' 218 persistence_disabled' in s]
assert guards;start=guards[-1]
done=[i for i,s in enumerate(rows) if i>start_run and '[FLog::CreatorOutput] [LEASE_CLEANUP_NATIVE_DONE] '+run+' 9 62' in s];assert len(done)==1
kept=[s for s in rows[start:done[0]+1] if re.search(r'\[FLog::Creator(?:Output|Warning|Error)\]',s)]
assert not any('[FLog::CreatorError]' in s or '[LEASE_CLEANUP_NATIVE_FAIL]' in s for s in kept)
cases=[]
for s in kept:
 match=re.search(r'\[LEASE_CLEANUP_NATIVE_CASE\] '+run+r' (\d+) (.*?) (\d+)$',s)
 if match:cases.append(dict(index=int(match[1]),name=match[2],assertions_so_far=int(match[3])))
names=re.findall(r'^case\("([^"]+)"',(HERE/'cases.luau').read_text(encoding='utf8'),re.M)
assert [c['index'] for c in cases]==list(range(1,10)) and [c['name'] for c in cases]==names and cases[-1]['assertions_so_far']==62
output=('\n'.join(kept)+'\n').encode();(HERE/'native-output.txt').write_bytes(output)
r=dict(source=source,run_id=run,cases=cases,case_count=9,assertions=62,creator_errors=0,creator_warnings=sum('[FLog::CreatorWarning]' in s for s in kept),
 place_sha256=m['place_sha256'],probe_sha256=sha((HERE/'native-probe.luau').read_bytes()),fixture_sha256=sha((HERE/'cases.luau').read_bytes()),output_sha256=sha(output),persistence_disabled=True,
 native_synthetic_cleanup_verified=True,online_save_accessed=False,online_rejoin_verified=False,device_verified=False,performance_verified=False,published=False,
 scope='Actual native preserve captures for Normal/Free/Easy, then nine synthetic MemoryBackend session cases through Studio-only playback. No online DataStore, physical device, network or performance proof.')
(HERE/'native-receipt.json').write_text(json.dumps(r,indent=2)+'\n',encoding='utf8',newline='\n');print(json.dumps(r,indent=2))
