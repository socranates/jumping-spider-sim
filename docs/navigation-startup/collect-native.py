"""Collect a bounded guarded native run; exclude Studio/account telemetry."""
from pathlib import Path
import argparse,hashlib,json,re,subprocess,tarfile,io
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[1]
p=argparse.ArgumentParser();p.add_argument('mode',choices=['success','failure']);p.add_argument('log',type=Path);p.add_argument('folder',type=Path);a=p.parse_args()
sha=lambda b:hashlib.sha256(b).hexdigest()
m=json.loads((HERE/('prepared-'+a.mode+'-manifest.json')).read_text(encoding='utf8'))
assert m['case']==a.mode and m['persistence_disabled'] and len(m['scripts'])==218
assert sha((a.folder/'Windowsill-navigation-startup-review.rbxlx').read_bytes())==m['place_sha256']
rows=a.log.read_text(encoding='utf8',errors='replace').splitlines()
begins=[(i,re.search(r'\[NAVIGATION_NATIVE_BEGIN\] (\d+) '+a.mode+r'$',s)) for i,s in enumerate(rows) if '[FLog::CreatorOutput]' in s]
begins=[(i,b) for i,b in begins if b];assert len(begins)==1
begin,match=begins[0];run=match[1]
guards=[i for i,s in enumerate(rows[:begin]) if '[FLog::CreatorOutput] [NAVIGATION_NATIVE_GUARD]' in s]
assert guards;start=guards[-1];assert m['source']+' 218 persistence_disabled' in rows[start]
done=[(i,re.search(r'\[NAVIGATION_NATIVE_DONE\] '+run+' '+a.mode+r' (\d+) (\d+) ([0-9.]+) (\d+) ([0-9.]+) ([0-9.]+)$',s)) for i,s in enumerate(rows) if i>begin and '[FLog::CreatorOutput]' in s]
done=[(i,d) for i,d in done if d];assert len(done)==1
end,d=done[0];checks,frames=int(d[1]),int(d[2]);assert checks==(10 if a.mode=='success' else 8)
kept=[s for s in rows[start:end+1] if re.search(r'\[FLog::Creator(?:Output|Warning|Error)\]',s)]
assert not any('[FLog::CreatorError]' in s or '[NAVIGATION_NATIVE_FAIL]' in s for s in kept)
synthetic=[s for s in kept if '[FLog::CreatorWarning]' in s and 'synthetic native startup route failure' in s]
assert len(synthetic)==(0 if a.mode=='success' else 1)
output=('\n'.join(kept)+'\n').encode();(HERE/('native-'+a.mode+'-output.txt')).write_bytes(output)
release=subprocess.check_output(['git','log','-1','--format=%H','--','roblox_port/src','roblox_port/tests'],cwd=ROOT,text=True).strip()
def blobs(commit):
 b=subprocess.check_output(['git','archive','--format=tar',commit,'roblox_port/src'],cwd=ROOT)
 with tarfile.open(fileobj=io.BytesIO(b)) as t:return {x.name:t.extractfile(x).read() for x in t if x.isfile()}
assert blobs(release)==blobs(m['source'])
r=dict(release_snapshot=release,guarded_runtime_snapshot=m['source'],production_bytes_identical=True,run_id=run,mode=a.mode,assertions=checks,
 observed_wait_frames=frames,observed_probe_seconds=float(d[3]),preparation_slices=int(d[4]),viewport=[float(d[5]),float(d[6])],
 scripts=218,persistence_disabled=True,place_sha256=m['place_sha256'],output_sha256=sha(output),creator_errors=0,
 expected_synthetic_warnings=len(synthetic),other_creator_warnings=sum('[FLog::CreatorWarning]' in s for s in kept)-len(synthetic),
 native_startup_path_verified=True,scope='Studio-only playback hook, actual controller/splash; fixture mode changes and synthetic failure. Timing from hook to probe completion, not full load or representative FPS.',
 online_save_accessed=False,physical_input_verified=False,phone_verified=False,automatic_network_streaming_verified=False,published=False)
(HERE/('native-'+a.mode+'-receipt.json')).write_text(json.dumps(r,indent=2)+'\n',encoding='utf8',newline='\n');print(json.dumps(r,indent=2))
