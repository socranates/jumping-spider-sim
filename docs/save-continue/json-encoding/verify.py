"""Require exact-current source and both full CLI gates after encoder adoption."""
from pathlib import Path
import hashlib,io,json,re,runpy,subprocess,tarfile
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[2]
sha=lambda b:hashlib.sha256(b).hexdigest()
assert (HERE/'windows-full-process.json').exists(),'Current encoder full Windows gate remains pending'
assert (HERE/'ci-final.json').exists(),'Current encoder full Linux gate remains pending'
runpy.run_path(str(HERE/'verify-prototype.py'))
runpy.run_path(str(HERE.parent/'save-cost/verify.py'))
source=subprocess.check_output(['git','log','-1','--format=%H','--','roblox_port/src','roblox_port/tests'],cwd=ROOT,text=True).strip()
raw=subprocess.check_output(['git','archive','--format=tar',source,'roblox_port/src','roblox_port/tests','.github/workflows/roblox-port.yml'],cwd=ROOT)
with tarfile.open(fileobj=io.BytesIO(raw)) as archive:files={m.name:archive.extractfile(m).read() for m in archive if m.isfile()}
for name,data in files.items():assert (ROOT/name).read_bytes()==data,name
windows=json.loads((HERE/'windows-full-process.json').read_text(encoding='utf8'))
assert windows['source']==source and windows['exit_code']==0
for name,digest in windows['inputs'].items():assert sha(files[name])==digest,name
win_text=(HERE/'windows-full.txt').read_text(encoding='utf8')
rows=re.findall(r'^([A-Z_0-9 ]+) passed=(\d+) failed=(\d+)',win_text,re.M)
assert len(rows)==76 and sum(int(r[1]) for r in rows)==465380 and all(int(r[2])==0 for r in rows)
assert ('JSON_ENCODING','20716','0') in rows and '[SELFTEST] FAIL' not in win_text
ci=json.loads((HERE/'ci-final.json').read_text(encoding='utf8'))
assert ci['head_sha']==source and ci['conclusion']=='success' and ci['status']=='completed'
assert ci['suites']==76 and ci['passed']==465380 and ci['failed']==0 and ci['modules_compiled']==222 and ci['runner_regressions']==5
for name,digest in ci['logs_sha256'].items():assert sha((HERE/name).read_bytes())==digest,name
assert sha(files['.github/workflows/roblox-port.yml'])==ci['workflow_sha256']
for job in ci['jobs_evidence']['jobs']:
 assert job['status']=='completed' and job['conclusion']=='success'
 for step in job['steps']:assert step['status']=='completed' and step['conclusion']=='success'
compiled=json.loads((HERE/'final-check/compile.json').read_text(encoding='utf8'))
assert compiled['total']==compiled['passed']==222
for row in compiled['files']:assert row['exit_code']==0 and sha(files[row['path']])==row['sha256']
for name in ['sourcemap','strict','runner']:assert json.loads((HERE/'final-check'/(name+'-process.json')).read_text(encoding='utf8'))['exit_code']==0
receipt=dict(source=source,current_workspace_inputs_verified=True,windows_suites=76,windows_passed=465380,linux_suites=76,linux_passed=465380,
 failed=0,modules_compiled=222,strict_clean=True,runner_regressions=5,adopted_algorithm_native_paired_assertions=20738,
 native_paired_reference_source='ab8ca9577129e3d9583a0a8ab6824dae1a8cd014',
 current_adopted_game_native_lifecycle_verified=False,whole_game_fps_gain_proven=False,hard_frame_budget_proven=False,
 goal_complete=False,release_rebuilt=False,published=False)
(HERE/'verification.json').write_text(json.dumps(receipt,indent=2)+'\n',encoding='utf8',newline='\n')
print(json.dumps(receipt,indent=2))
