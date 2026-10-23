"""Prove the full platform gates for the committed runtime; reject incomplete runs."""
from pathlib import Path
import hashlib,io,json,re,subprocess,tarfile
H=Path(__file__).resolve().parent;ROOT=H.parents[1];W=H/'full-windows'
SOURCE='441eacaec05d0e1164473f19764f7d56f12b8482'
assert (W/'windows-full-process.json').exists(),'Windows gate is still running or incomplete'
win=json.loads((W/'windows-full-process.json').read_text(encoding='utf8'))
start=json.loads((W/'windows-full-start.json').read_text(encoding='utf8'))
assert win['source']==start['source']==SOURCE and win['exit_code']==0
assert win['inputs']==start['inputs']
raw=subprocess.check_output(['git','archive','--format=tar',SOURCE,'roblox_port/src','roblox_port/tests'],cwd=ROOT)
with tarfile.open(fileobj=io.BytesIO(raw)) as archive:
 inputs={m.name:hashlib.sha256(archive.extractfile(m).read()).hexdigest() for m in archive if m.isfile()}
assert inputs==win['inputs']
runner=json.loads((H/'runner.json').read_text(encoding='utf8'))
runner_text=(H/'runner.txt').read_text(encoding='utf8')
assert runner['source']==SOURCE and runner['exit_code']==0
assert hashlib.sha256((H/'runner.txt').read_bytes()).hexdigest()==runner['output_sha256']
assert 'Ran 5 tests' in runner_text and re.search(r'\bOK\s*$',runner_text)
for name,digest in runner['inputs'].items():
 data=(ROOT/name).read_bytes();assert hashlib.sha256(data).hexdigest()==digest
 committed=subprocess.check_output(['git','show',SOURCE+':'+name],cwd=ROOT)
 assert data.replace(b'\r\n',b'\n')==committed.replace(b'\r\n',b'\n')
text=(W/'windows-full.txt').read_text(encoding='utf8')
rows=re.findall(r'^([A-Z_0-9 ]+) passed=(\d+) failed=(\d+)',text,re.M)
assert len(rows)==76 and sum(int(r[1]) for r in rows)==468487 and all(int(r[2])==0 for r in rows)
assert not re.search(r'\b(?:fail|failed)=[1-9]\d*\b|\[SELFTEST\] FAIL',text)
ci=json.loads((H/'ci-final.json').read_text(encoding='utf8'))
assert ci['head_sha']==SOURCE and ci['status']=='completed' and ci['conclusion']=='success'
assert ci['suites']==76 and ci['passed']==468487 and ci['failed']==0 and ci['modules_compiled']==222 and ci['runner_regressions']==5
for name,digest in ci['logs_sha256'].items():assert hashlib.sha256((H/name).read_bytes()).hexdigest()==digest
assert subprocess.run(['git','diff','--quiet','HEAD','--','roblox_port/src','roblox_port/tests'],cwd=ROOT).returncode==0
assert subprocess.check_output(['git','log','-1','--format=%H','--','roblox_port/src','roblox_port/tests'],cwd=ROOT,text=True).strip()==SOURCE
result=dict(source=SOURCE,windows_suites=76,windows_passed=468487,windows_failed=0,windows_output_sha256=hashlib.sha256((W/'windows-full.txt').read_bytes()).hexdigest(),linux_run=ci['id'],linux_suites=76,linux_passed=468487,linux_failed=0,compile=222,strict_clean=True,runner_regressions=5,immutable_windows_snapshot_verified=True,native_full_game_verified=False,real_service_rejoin_verified=False,goal_complete=False,published=False)
native=json.loads((H/'native-receipt.json').read_text(encoding='utf8'))
assert native['source']==SOURCE and native['assertions']==17 and native['script_fingerprints']==223 and native['persistence_disabled']
assert native['events_sha256']==hashlib.sha256((H/'native-events.txt').read_bytes()).hexdigest()
closed=json.loads((H/'native-close.json').read_text(encoding='utf8'))
assert closed['process_present'] is False and closed['window_present'] is False
assert closed['original_package_sha256']==native['place_sha256']
result.update(native_actual_client_fixture_assertions=17,native_script_fingerprints=223,native_hud_and_clock_wiring_verified=True,native_evidence_sha256=hashlib.sha256((H/'native-receipt.json').read_bytes()).hexdigest(),native_diagnostic_closed=True)
(H/'full-verification.json').write_text(json.dumps(result,indent=2)+'\n',encoding='utf8',newline='\n');print(json.dumps(result,indent=2))
