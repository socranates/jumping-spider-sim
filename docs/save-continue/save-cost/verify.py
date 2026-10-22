"""Current full Linux gate, exact live bytes; native/Windows scope stays explicit."""
from pathlib import Path
import hashlib,io,json,re,runpy,subprocess,tarfile
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[2]
SOURCE='ab8ca9577129e3d9583a0a8ab6824dae1a8cd014'
BASE='4ee6aecc06f4753a85e40fc98a1487dc5126d27d'
sha=lambda b:hashlib.sha256(b).hexdigest()
def archive(source):
 raw=subprocess.check_output(['git','archive','--format=tar',source,'roblox_port/src','roblox_port/tests','.github/workflows/roblox-port.yml'],cwd=ROOT)
 with tarfile.open(fileobj=io.BytesIO(raw)) as bundle:
  return {m.name:bundle.extractfile(m).read() for m in bundle if m.isfile()}
current=archive(SOURCE);base=archive(BASE)
assert current.keys()==base.keys()
assert [name for name in current if current[name]!=base[name]]==['roblox_port/src/Client/SelfTest.luau']
for name,data in current.items():assert (ROOT/name).read_bytes()==data,name
assert subprocess.check_output(['git','log','-1','--format=%H','--','roblox_port/src','roblox_port/tests'],cwd=ROOT,text=True).strip()==SOURCE
# Earlier stage still checks immutable original/corrected focused cohorts and
# the exact old native fingerprints. It does not claim native proof on SOURCE.
runpy.run_path(str(HERE.parent/'local-return/verify.py'))
ci=json.loads((HERE/'ci-final.json').read_text(encoding='utf8'))
assert ci['id']==39852128734 and ci['head_sha']==SOURCE and ci['status']=='completed' and ci['conclusion']=='success'
assert ci['modules_compiled']==222 and ci['suites']==75 and ci['passed']==444664 and ci['failed']==0 and ci['runner_regressions']==5
assert sha(current['.github/workflows/roblox-port.yml'])==ci['workflow_sha256']
for name,digest in ci['logs_sha256'].items():assert sha((HERE/name).read_bytes())==digest,name
for job in ci['jobs_evidence']['jobs']:
 assert job['status']=='completed' and job['conclusion']=='success'
 for step in job['steps']:assert step['status']=='completed' and step['conclusion']=='success',step['name']
text=(HERE/'ci-suites.txt').read_text(encoding='utf8')
clean='\n'.join(re.sub(r'^\d{4}-\d\d-\d\dT\S+\s+','',line) for line in text.splitlines())
rows=re.findall(r'^([A-Z_0-9 ]+) passed=(\d+) failed=(\d+)',clean,re.M)
assert len(rows)==75 and sum(int(r[1]) for r in rows)==444664 and all(int(r[2])==0 for r in rows)
assert '[SELFTEST] END pass=41 fail=0 skip=0' in clean
assert '[SELFTEST] END pass=274 fail=0 skip=0' in clean
assert not re.search(r'\[SELFTEST\] FAIL|^FAIL|##\[error\]',clean,re.M)
receipt=dict(source=SOURCE,current_workspace_inputs_verified=True,linux_run=ci['id'],linux_suites=75,linux_passed=444664,failed=0,
 modules_compiled=222,strict_clean=True,runner_regressions=5,shim_selftest_checks=[41,274],
 native_historical_source='07234cae75b5a62b820dc6dda830dce7e503c36b',native_historical_assertions=22,
 current_source_native_verified=False,current_source_windows_full_verified=False,save_cost_measurements_pending=True,
 rig_candidate_adopted=False,hard_frame_budget_proven=False,goal_complete=False,published=False)
(HERE/'verification.json').write_text(json.dumps(receipt,indent=2)+'\n',encoding='utf8',newline='\n')
print(json.dumps(receipt,indent=2))
