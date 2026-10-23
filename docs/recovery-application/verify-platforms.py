"""Bind terminal current platform gates; deliberately makes no native/release claim."""
from pathlib import Path
import hashlib,io,json,re,subprocess,sys,tarfile
H=Path(__file__).resolve().parent;ROOT=H.parents[1]
SOURCE='216b83c7f2b5136230d8bda58653717433eccc51';sha=lambda b:hashlib.sha256(b).hexdigest()
raw=subprocess.check_output(['git','archive','--format=tar',SOURCE,'roblox_port/src','roblox_port/tests'],cwd=ROOT)
with tarfile.open(fileobj=io.BytesIO(raw)) as archive:inputs={m.name:sha(archive.extractfile(m).read()) for m in archive if m.isfile()}
win=json.loads((H/'windows-full-process.json').read_text(encoding='utf8'))
assert win['source']==SOURCE and win['exit_code']==0 and win['inputs']==inputs
text=(H/'windows-full.txt').read_text(encoding='utf8');rows=re.findall(r'^([A-Z_0-9 ]+) passed=(\d+) failed=(\d+)',text,re.M)
assert len(rows)==78 and sum(int(p) for _,p,_ in rows)==468959 and all(int(f)==0 for _,_,f in rows)
assert 'RECOVERY_APPLICATION passed=23 failed=0' in text and 'RECOVERY_TEMPLATES passed=56 failed=0' in text
assert not re.search(r'\b(?:fail|failed)=[1-9]\d*\b|\[SELFTEST\] FAIL',text)
checks=json.loads((H/'checks.json').read_text(encoding='utf8'));assert checks['source']==SOURCE and checks['compile_passed']==224
assert (H/'compile.txt').read_text(encoding='utf8')=='compile 224/224\n' and checks['compile_sha256']==sha((H/'compile.txt').read_bytes())
for step in checks['steps']:assert step['exit_code']==0 and sha((H/(step['name']+'.txt')).read_bytes())==step['output_sha256']
strict=(H/'strict.txt').read_text(encoding='utf8');assert not [s for s in strict.splitlines() if s and not s.startswith('[INFO]') and 'didChangeWatchedFiles' not in s]
runner=(H/'runner.txt').read_text(encoding='utf8');assert 'Ran 5 tests' in runner and re.search(r'\bOK\s*$',runner)
ci=json.loads((H/'ci-final.json').read_text(encoding='utf8'));assert ci['head_sha']==SOURCE and ci['status']=='completed' and ci['conclusion']=='success'
assert ci['suites']==78 and ci['passed']==468959 and ci['failed']==0 and ci['modules_compiled']==224
for name,digest in ci['logs_sha256'].items():assert sha((H/name).read_bytes())==digest,name
subprocess.run([sys.executable,str(H/'verify-private.py')],cwd=ROOT,check=True)
v=json.loads((H/'private-verification.json').read_text(encoding='utf8'));assert v['source']==SOURCE and v['total_checks']==204900
result=dict(source=SOURCE,windows_suites=78,windows_checks=468959,windows_failed=0,windows_output_sha256=sha((H/'windows-full.txt').read_bytes()),
 linux_run=ci['id'],linux_suites=78,linux_checks=468959,linux_failed=0,compile=224,strict_clean=True,runner_regressions=5,
 private_checks=204900,private_named_groups=31,private_candidates=40,application_game_checks=65,ordinary_startup_recovery_enabled=False,
 protected_new_life_retirement_policy_installed=False,native_application_recovery_verified=False,real_datastore_verified=False,
 production_candidate_built=False,whole_game_verified=False,published=False,goal_complete=False)
(H/'platform-verification.json').write_text(json.dumps(result,indent=2)+'\n',encoding='utf8',newline='\n');print(json.dumps(result,indent=2))
