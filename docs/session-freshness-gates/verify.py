"""Current full gates plus the exact adopted fresh-read modules and native proof."""
from pathlib import Path
import hashlib,io,json,re,runpy,subprocess,tarfile
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[1];sha=lambda b:hashlib.sha256(b).hexdigest()
SOURCE='f4053597d03b99a61cb97e2eef1ec64ed174f22a'
for name in ['windows-full-process.json','ci-final.json']:
 assert (HERE/name).exists(),'Current save-freshness full gate pending: '+name
source=subprocess.check_output(['git','log','-1','--format=%H','--','roblox_port/src','roblox_port/tests'],cwd=ROOT,text=True).strip();assert source==SOURCE
raw=subprocess.check_output(['git','archive','--format=tar',source,'roblox_port/src','roblox_port/tests','.github/workflows/roblox-port.yml'],cwd=ROOT)
with tarfile.open(fileobj=io.BytesIO(raw)) as archive:files={m.name:archive.extractfile(m).read() for m in archive if m.isfile()}
for name,data in files.items():assert (ROOT/name).read_bytes()==data,name
adopt=json.loads((HERE.parent/'save-slot-isolation/session-fresh-adoption.json').read_text())
for name,digest in adopt['adopted'].items():assert sha(files[name])==digest,name
assert sha(files[adopt['regression_file']])==adopt['regression_sha256'] and adopt['added_assertions']==111
changed=subprocess.check_output(['git','diff','--name-only',adopt['base_source'],source,'--','roblox_port/src','roblox_port/tests'],cwd=ROOT,text=True).splitlines()
assert set(changed)==set(adopt['adopted'])|{adopt['regression_file']}
windows=json.loads((HERE/'windows-full-process.json').read_text());assert windows['source']==source and windows['exit_code']==0
for name,digest in windows['inputs'].items():assert sha(files[name])==digest,name
text=(HERE/'windows-full.txt').read_text();rows=re.findall(r'^([A-Z_0-9 ]+) passed=(\d+) failed=(\d+)',text,re.M)
assert len(rows)==76 and sum(int(r[1]) for r in rows)==468225 and all(int(r[2])==0 for r in rows)
assert ('STATE','1124','0') in rows and '[SELFTEST] FAIL' not in text
ci=json.loads((HERE/'ci-final.json').read_text());assert ci['head_sha']==source and ci['conclusion']=='success' and ci['status']=='completed'
assert ci['suites']==76 and ci['passed']==468225 and ci['failed']==0 and ci['modules_compiled']==222 and ci['runner_regressions']==5
for job in ci['jobs_evidence']['jobs']:
 assert job['status']=='completed' and job['conclusion']=='success'
 for step in job['steps']:assert step['status']=='completed' and step['conclusion']=='success'
for name,digest in ci['logs_sha256'].items():assert sha((HERE/name).read_bytes())==digest,name
assert sha(files['.github/workflows/roblox-port.yml'])==ci['workflow_sha256']
runpy.run_path(str(HERE.parent/'save-slot-isolation/verify-session-cache.py'))
v=json.loads((HERE.parent/'save-slot-isolation/session-cache-verification.json').read_text())
assert v['native_assertions']==111 and v['native_scripts']==224 and v['creator_errors']==0 and v['strict_clean']
assert sha(files['roblox_port/src/Shared/Persistence/SaveSession.luau'])==v['candidates']['session-fresh-candidate.luau']
assert sha(files['roblox_port/src/Server/DataStoreBackend.luau'])==v['candidates']['fresh-read-backend-candidate.luau']
pond=json.loads((HERE.parent/'animal-presentation-cost/pond-candidate-v2.json').read_text())
assert sha(files[pond['path']])==pond['candidate_sha256']
r=dict(source=source,current_workspace_inputs_verified=True,windows_suites=76,windows_passed=468225,linux_suites=76,linux_passed=468225,failed=0,modules_compiled=222,strict_clean=True,runner_regressions=5,native_session_assertions=111,native_session_scope='Real adapter/session; fake cached datastore; actual engine options; all production scripts disabled; exact adopted module bytes',real_datastore_verified=False,progress_import_implemented=False,whole_game_fps_gain_proven=False,goal_complete=False,published=False)
(HERE/'verification.json').write_text(json.dumps(r,indent=2)+'\n',encoding='utf8',newline='\n');print(json.dumps(r,indent=2))
