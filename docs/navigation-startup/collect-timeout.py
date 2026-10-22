"""Retain only Creator lines from the guarded native elapsed-time timeout run."""
from pathlib import Path
import argparse,hashlib,json,re,subprocess,io,tarfile
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[1]
p=argparse.ArgumentParser();p.add_argument('log',type=Path);p.add_argument('folder',type=Path);a=p.parse_args()
sha=lambda b:hashlib.sha256(b).hexdigest()
m=json.loads((a.folder/'manifest.json').read_text(encoding='utf8'))
assert m['case']=='timeout' and m['persistence_disabled'] and len(m['scripts'])==218
assert sha((a.folder/'Windowsill-navigation-startup-review.rbxlx').read_bytes())==m['place_sha256']
source=subprocess.check_output(['git','log','-1','--format=%H','--','roblox_port/src','roblox_port/tests'],cwd=ROOT,text=True).strip()
assert source==m['source']
b=subprocess.check_output(['git','archive','--format=tar',source,'roblox_port/src'],cwd=ROOT)
with tarfile.open(fileobj=io.BytesIO(b)) as tree:
 for t in tree:
  if t.isfile():assert tree.extractfile(t).read()==(ROOT/t.name).read_bytes(),t.name
rows=a.log.read_text(encoding='utf8',errors='replace').splitlines()
begins=[(i,re.search(r'\[NAVIGATION_TIMEOUT_BEGIN\] (\d+)$',s)) for i,s in enumerate(rows) if '[FLog::CreatorOutput]' in s]
begins=[(i,b) for i,b in begins if b];assert len(begins)==1
begin,match=begins[0];run=match[1]
guards=[i for i,s in enumerate(rows[:begin]) if '[FLog::CreatorOutput] [NAVIGATION_NATIVE_GUARD]' in s]
assert guards;start=guards[-1];assert source+' 218 persistence_disabled' in rows[start]
pattern=r'\[NAVIGATION_TIMEOUT_DONE\] '+run+r' (\d+) (\d+) ([0-9.]+) ([0-9.]+) ([0-9.]+) (\d+) ([0-9.]+) ([0-9.]+)$'
done=[(i,re.search(pattern,s)) for i,s in enumerate(rows) if i>begin and '[FLog::CreatorOutput]' in s]
done=[(i,d) for i,d in done if d];assert len(done)==1
end,d=done[0];assert int(d[1])==10 and float(d[3])>=40
kept=[s for s in rows[start:end+1] if re.search(r'\[FLog::Creator(?:Output|Warning|Error)\]',s)]
assert not any('[FLog::CreatorError]' in s or '[NAVIGATION_TIMEOUT_FAIL]' in s for s in kept)
expected=[s for s in kept if '[FLog::CreatorWarning]' in s and 'navigation preparation timed out' in s];assert len(expected)==1
output=('\n'.join(kept)+'\n').encode();(HERE/'native-timeout-output.txt').write_bytes(output)
for name in ['manifest.json','guard.luau']:(HERE/('prepared-timeout-'+name)).write_bytes((a.folder/name).read_bytes())
r=dict(source=source,run_id=run,assertions=10,observed_wait_frames=int(d[2]),actual_owner_elapsed_seconds=float(d[3]),probe_seconds=float(d[4]),max_probe_wait_gap_seconds=float(d[5]),preparation_slices=int(d[6]),viewport=[float(d[7]),float(d[8])],
 place_sha256=m['place_sha256'],probe_sha256=sha((HERE/'timeout-probe.luau').read_bytes()),output_sha256=sha(output),creator_errors=0,expected_timeout_warnings=1,other_creator_warnings=sum('[FLog::CreatorWarning]' in s for s in kept)-1,
 production_clock_and_timeout_unchanged=True,native_elapsed_timeout_verified=True,persistence_disabled=True,physical_input_verified=False,phone_verified=False,network_streaming_verified=False,published=False,
 scope='Actual controller elapsed timeout with surface advance deliberately stalled. Real production clock/40-second constant, splash and state hold. One foreground desktop trial; not full load time, representative FPS or background throttle proof.')
(HERE/'native-timeout-receipt.json').write_text(json.dumps(r,indent=2)+'\n',encoding='utf8',newline='\n');print(json.dumps(r,indent=2))
