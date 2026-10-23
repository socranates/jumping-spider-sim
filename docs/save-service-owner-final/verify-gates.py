from pathlib import Path
import hashlib,io,json,re,subprocess,tarfile
H=Path(__file__).resolve().parent;ROOT=H.parents[1]
SOURCE='2170f99e001c4c0a42e86454974f594820e86667'
sha=lambda b:hashlib.sha256(b).hexdigest()
assert (H/'windows-full-process.json').exists(),'Windows gate is still live or incomplete'
win=json.loads((H/'windows-full-process.json').read_text(encoding='utf8'));start=json.loads((H/'windows-full-start.json').read_text(encoding='utf8'))
assert win['source']==start['source']==SOURCE and win['exit_code']==0 and win['inputs']==start['inputs']
raw=subprocess.check_output(['git','archive','--format=tar',SOURCE,'roblox_port/src','roblox_port/tests'],cwd=ROOT)
with tarfile.open(fileobj=io.BytesIO(raw)) as archive:
 inputs={m.name:sha(archive.extractfile(m).read()) for m in archive if m.isfile()}
assert inputs==win['inputs']
text=(H/'windows-full.txt').read_text(encoding='utf8');rows=re.findall(r'^([A-Z_0-9 ]+) passed=(\d+) failed=(\d+)',text,re.M)
assert len(rows)==76 and sum(int(p) for _,p,_ in rows)==468506 and all(int(f)==0 for _,_,f in rows),rows
assert not re.search(r'\b(?:fail|failed)=[1-9]\d*\b|\[SELFTEST\] FAIL',text)
checks=json.loads((H/'checks.json').read_text(encoding='utf8'));assert checks['source']==SOURCE and checks['compile_passed']==222
assert checks['compile_sha256']==sha((H/'compile.txt').read_bytes()) and (H/'compile.txt').read_text(encoding='utf8')=='compile 222/222\n'
for step in checks['steps']:assert step['exit_code']==0 and step['output_sha256']==sha((H/(step['name']+'.txt')).read_bytes())
strict=(H/'strict.txt').read_text(encoding='utf8')
assert not [s for s in strict.splitlines() if s and not s.startswith('[INFO]') and 'didChangeWatchedFiles' not in s],strict
runner=(H/'runner.txt').read_text(encoding='utf8');assert 'Ran 5 tests' in runner and re.search(r'\bOK\s*$',runner)
ci=json.loads((H/'ci-final.json').read_text(encoding='utf8'))
assert ci['head_sha']==SOURCE and ci['status']=='completed' and ci['conclusion']=='success'
assert ci['suites']==76 and ci['passed']==468506 and ci['failed']==0 and ci['modules_compiled']==222 and ci['runner_regressions']==5
for name,digest in ci['logs_sha256'].items():assert sha((H/name).read_bytes())==digest
assert subprocess.run(['git','diff','--quiet','HEAD','--','roblox_port/src','roblox_port/tests'],cwd=ROOT).returncode==0
assert subprocess.check_output(['git','log','-1','--format=%H','--','roblox_port/src','roblox_port/tests'],cwd=ROOT,text=True).strip()==SOURCE
result=dict(source=SOURCE,windows_suites=76,windows_passed=468506,windows_failed=0,windows_output_sha256=sha((H/'windows-full.txt').read_bytes()),
 linux_run=ci['id'],linux_suites=76,linux_passed=468506,linux_failed=0,compile=222,strict_clean=True,runner_regressions=5,
 immutable_windows_snapshot_verified=True,owner_factory_default_not_installed_in_engine=True,
 native_full_game_verified=False,real_service_rejoin_verified=False,goal_complete=False,published=False)
(H/'full-verification.json').write_text(json.dumps(result,indent=2)+'\n',encoding='utf8',newline='\n');print(json.dumps(result,indent=2))
