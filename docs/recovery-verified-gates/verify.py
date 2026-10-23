"""Bind paced recovery adoption, full platforms and the exact native-tested module."""
from pathlib import Path
import hashlib,io,json,re,runpy,subprocess,tarfile
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[1];sha=lambda b:hashlib.sha256(b).hexdigest()
for name in ['cohort-source.json','windows-full-process.json','ci-final.json']:
 assert (HERE/name).exists(),'Current recovery pacing full gate pending: '+name
SOURCE=json.loads((HERE/'cohort-source.json').read_text())['source']
source=subprocess.check_output(['git','log','-1','--format=%H','--','roblox_port/src','roblox_port/tests'],cwd=ROOT,text=True).strip();assert source==SOURCE
raw=subprocess.check_output(['git','archive','--format=tar',source,'roblox_port/src','roblox_port/tests','.github/workflows/roblox-port.yml'],cwd=ROOT)
with tarfile.open(fileobj=io.BytesIO(raw)) as archive:files={m.name:archive.extractfile(m).read() for m in archive if m.isfile()}
for name,data in files.items():assert (ROOT/name).read_bytes()==data,name
adopt=json.loads((HERE.parent/'save-slot-isolation/session-verified-adoption.json').read_text())
assert sha(files['roblox_port/src/Shared/Persistence/SaveSession.luau'])==adopt['session_sha256']
assert sha(files['roblox_port/tests/state.luau'])==adopt['regression_sha256'] and adopt['added_assertions']==127
changed=subprocess.check_output(['git','diff','--name-only',adopt['base_source'],source,'--','roblox_port/src','roblox_port/tests'],cwd=ROOT,text=True).splitlines()
assert set(changed)=={'roblox_port/src/Shared/Persistence/SaveSession.luau','roblox_port/tests/state.luau'}
windows=json.loads((HERE/'windows-full-process.json').read_text());assert windows['source']==source and windows['exit_code']==0
for name,digest in windows['inputs'].items():assert sha(files[name])==digest,name
text=(HERE/'windows-full.txt').read_text();rows=re.findall(r'^([A-Z_0-9 ]+) passed=(\d+) failed=(\d+)',text,re.M)
assert len(rows)==76 and sum(int(r[1]) for r in rows)==468352 and all(int(r[2])==0 for r in rows)
assert ('STATE','1251','0') in rows and '[SELFTEST] FAIL' not in text
ci=json.loads((HERE/'ci-final.json').read_text());assert ci['head_sha']==source and ci['conclusion']=='success' and ci['status']=='completed'
assert ci['suites']==76 and ci['passed']==468352 and ci['failed']==0 and ci['modules_compiled']==222 and ci['runner_regressions']==5
for job in ci['jobs_evidence']['jobs']:
 assert job['status']=='completed' and job['conclusion']=='success'
 for step in job['steps']:assert step['status']=='completed' and step['conclusion']=='success'
for name,digest in ci['logs_sha256'].items():assert sha((HERE/name).read_bytes())==digest,name
assert sha(files['.github/workflows/roblox-port.yml'])==ci['workflow_sha256']
runpy.run_path(str(HERE.parent/'save-slot-isolation/verify-session-verified-native.py'))
v=json.loads((HERE.parent/'save-slot-isolation/session-verified-native-qualification.json').read_text())
assert v['candidate_sha256']==adopt['session_sha256'] and v['native_assertions']==127 and v['native_scripts']==224 and v['creator_errors']==0 and v['strict_clean']
pond=json.loads((HERE.parent/'animal-presentation-cost/pond-candidate-v2.json').read_text());assert sha(files[pond['path']])==pond['candidate_sha256']
r=dict(source=source,current_workspace_inputs_verified=True,windows_suites=76,windows_passed=468352,linux_suites=76,linux_passed=468352,failed=0,modules_compiled=222,strict_clean=True,runner_regressions=5,native_recovery_assertions=127,native_scope='Exact adopted session; MemoryBackend; actual coroutine yielding/cancellation; all production scripts disabled',real_datastore_verified=False,full_game_transport_verified=False,progress_import_implemented=False,whole_game_fps_gain_proven=False,goal_complete=False,published=False)
(HERE/'verification.json').write_text(json.dumps(r,indent=2)+'\n',encoding='utf8',newline='\n');print(json.dumps(r,indent=2))
