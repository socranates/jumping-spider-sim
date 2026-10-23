"""Reproduce the obsolete due()/aggregate-cap coupling in the actual save loop."""
from pathlib import Path
import hashlib,importlib.util,json,subprocess,tempfile,time
H=Path(__file__).resolve().parent;ROOT=H.parents[1]
spec=importlib.util.spec_from_file_location('saving_negative',H/'run-saving.py');m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
prefix='saving-old-due-negative-1';out=H/(prefix+'-output.txt');assert not out.exists()
bundle,paths=m.build(True)
old='''-- The shared typed gate owns capacity; keep only per-key debounce here.
  -- Calling due() would silently retain the obsolete aggregate 10-start cap.
  if self.options.admission then
   if s.now()<s.sched.items.progress.nextAt then return false end
  elseif not s.sched:due("progress",s.now()) then return false end'''
assert bundle.count(old)==1
bundle=bundle.replace(old,'if not s.sched:due("progress",s.now()) then return false end')
sha=lambda b:hashlib.sha256(b).hexdigest();inputs={p.relative_to(ROOT).as_posix():sha(p.read_bytes()) for p in paths};started=time.time()
with tempfile.TemporaryDirectory(prefix='windowsill-saving-negative-') as tmp:
 p=Path(tmp)/'run.luau';p.write_text(bundle,encoding='utf8',newline='\n')
 r=subprocess.run([r'C:/Users/natha/.codex/.chatgpt-projects/g-p-6ac2f32f82a48191b0c7151a11eab0fd/roblox_tools/luau/luau.exe',str(p)],cwd=ROOT,capture_output=True,text=True)
assert inputs=={p.relative_to(ROOT).as_posix():sha(p.read_bytes()) for p in paths}
output=r.stdout+r.stderr;out.write_text(output,encoding='utf8',newline='\n')
assert r.returncode!=0 and 'progress still depended on obsolete aggregate capacity' in output
assert 'SAVING_ADMISSION_CASE\tcommitted-rest-cancel-drains-before-account-replacement\t1742' in output
receipt=dict(inputs=inputs,bundle_sha256=sha(bundle.encode()),output_sha256=sha(output.encode()),exit_code=r.returncode,elapsed_seconds=time.time()-started,
 expected_failure='progress still depended on obsolete aggregate capacity',only_mutation='Restore former SaveScheduler.due call at recovered progress scheduling',native_verified=False,published=False)
(H/(prefix+'-receipt.json')).write_text(json.dumps(receipt,indent=2)+'\n',encoding='utf8',newline='\n')
print(output[-2500:]);print('EXPECTED NEGATIVE FAILURE CONFIRMED')
