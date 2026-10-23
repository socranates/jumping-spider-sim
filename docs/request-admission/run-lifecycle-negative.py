"""Restore the exact old Runtime timeout branch to reproduce its queued leak."""
from pathlib import Path
import hashlib,importlib.util,json,subprocess,tempfile,time
H=Path(__file__).resolve().parent;ROOT=H.parents[1]
spec=importlib.util.spec_from_file_location('lifecycle_negative',H/'run-lifecycle.py');m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
prefix='lifecycle-timeout-negative-1';out=H/(prefix+'-output.txt');assert not out.exists()
bundle,paths=m.build(True);assert bundle.count('self.departure:expire(j)')==1
old='''j.scope.owner:finishDeparture(j.scope,false);j.state,j.problem="refused","routing departure deadline reached"
   j.result={progressPreserved=false,leaseReleased=false,sessionClosed=true,gameplayAuthorized=false}'''
bundle=bundle.replace('self.departure:expire(j)',old)
sha=lambda b:hashlib.sha256(b).hexdigest();inputs={p.relative_to(ROOT).as_posix():sha(p.read_bytes()) for p in paths};started=time.time()
with tempfile.TemporaryDirectory(prefix='windowsill-lifecycle-negative-') as tmp:
 p=Path(tmp)/'run.luau';p.write_text(bundle,encoding='utf8',newline='\n')
 r=subprocess.run([r'C:/Users/natha/.codex/.chatgpt-projects/g-p-6ac2f32f82a48191b0c7151a11eab0fd/roblox_tools/luau/luau.exe',str(p)],cwd=ROOT,capture_output=True,text=True)
assert inputs=={p.relative_to(ROOT).as_posix():sha(p.read_bytes()) for p in paths}
output=r.stdout+r.stderr;out.write_text(output,encoding='utf8',newline='\n')
assert r.returncode!=0 and 'Runtime timeout stranded queued departure' in output
assert 'LIFECYCLE_RECOVERED_CASE\tunresolved-aba-progress-is-reconciled-by-typed-departure\t3464' in output
receipt=dict(inputs=inputs,bundle_sha256=sha(bundle.encode()),output_sha256=sha(output.encode()),exit_code=r.returncode,elapsed_seconds=time.time()-started,
 expected_failure='Runtime timeout stranded queued departure',only_mutation='Restore former direct Runtime departure-state mutation at timeout',native_verified=False,published=False)
(H/(prefix+'-receipt.json')).write_text(json.dumps(receipt,indent=2)+'\n',encoding='utf8',newline='\n')
print(output[-2000:]);print('EXPECTED NEGATIVE FAILURE CONFIRMED')
