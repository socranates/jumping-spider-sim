"""Bind the actual entry/lease worker cohort; no service activation or native claim."""
from pathlib import Path
import hashlib,importlib.util,io,json,re,subprocess,tarfile
H=Path(__file__).resolve().parent;ROOT=H.parents[1]
SOURCE='bd67582b5d53473f067244fc1e2e1f94adde173b';sha=lambda b:hashlib.sha256(b).hexdigest()
def load(name,file):
 spec=importlib.util.spec_from_file_location(name,H/file);m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m);return m
def main():
 runner=load('entry_qualification','run-entry.py');bundle,paths=runner.build()
 r=json.loads((H/'entry-qualified-2-receipt.json').read_text());raw=(H/'entry-qualified-2-output.txt').read_bytes();text=raw.decode()
 assert r['source']==SOURCE and r['exit_code']==0 and r['inputs']=={p.relative_to(ROOT).as_posix():sha(p.read_bytes()) for p in paths}
 assert r['bundle_sha256']==sha(bundle.encode()) and r['output_sha256']==sha(raw)
 pattern=r'^([A-Z_0-9]+) passed=(\d+) failed=(\d+)'
 prior=(H/'workers-qualified-2-output.txt').read_text();expected={name:(int(p),int(f)) for name,p,f in re.findall(pattern,prior,re.M)}
 assert len(expected)==36 and sum(p for p,f in expected.values())==211864 and all(f==0 for p,f in expected.values())
 cases=re.findall(r'^ENTRY_ADMISSION_CASE\s([^\t\n]+)\s(\d+)$',text,re.M)
 names={'all-modes-hold-until-final-fresh-witnesses','cancelled-entry-and-expired-wait-never-read','lease-transform-and-evidence-survive-capacity-waits',
  'ambiguous-renewal-reprobes-without-payload-change','cancellation-during-committed-renewal-drains-owner','lease-expiry-or-route-change-refuses-queued-provider',
  'lease-renews-while-client-application-is-delayed','changed-final-rest-after-capacity-wait-refuses-grant'}
 assert len(cases)==8 and {name for name,p in cases}==names
 entryCount=sum(int(p) for name,p in cases);assert entryCount>=200
 expected['ENTRY_ADMISSION']=(entryCount,0);expected['DISPATCH_GUARD']=(9,0);rows=re.findall(pattern,text,re.M)
 assert entryCount==341 and len(rows)==38 and {name:(int(p),int(f)) for name,p,f in rows}==expected
 assert not re.search(r'\b(?:fail|failed)=[1-9]\d*\b|stacktrace:',text)
 for mode in ['main','free','easy']:assert f'ENTRY_ADMISSION mode={mode} actual_runtime=true client_applied=true fresh_final_reads=true granted_once=true' in text
 assert re.search(r'^RECOVERY_APPLICATION_GAME read_invariants=[1-9]\d* every_read_checked=true$',text,re.M)
 assert r['typed_worker_overrides']==['discovery','entry','read_lease'] and not any(r[k] for k in ['all_workers_typed','service_lanes_installed','normal_startup_installed','native_verified','online_verified','published'])
 checker=load('entry_types_qualification','check-entry.py').checker();sources=checker.paths()
 types=json.loads((H/'entry-types-qualified-2-types.json').read_text());assert len(sources)==44
 assert types['candidates']=={p.relative_to(ROOT).as_posix():sha(p.read_bytes()) for p in sources.values()}
 mounted={}
 for target,p in sources.items():
  code=p.read_text()
  if p==H/'worker-v2.luau':code=code.replace('require("./worker-facade")','require(script.Parent.RequestAdmissionFacade)')
  mounted[target]=sha(code.encode())
 assert types['mounted']==mounted and len(types['steps'])==3
 for step in types['steps']:assert step['exit_code']==0 and sha((H/('entry-types-qualified-2-'+step['name']+'.txt')).read_bytes())==step['sha256']
 assert (H/'entry-types-qualified-2-compile.txt').read_text()=='compile 44/44\n'
 strict=(H/'entry-types-qualified-2-strict.txt').read_text();assert not [line for line in strict.splitlines() if line and not line.startswith('[INFO]') and 'didChangeWatchedFiles' not in line]
 for name,digest in types['production_inputs'].items():assert sha((ROOT/name).read_bytes())==digest
 rawSource=subprocess.check_output(['git','archive','--format=tar',SOURCE,'roblox_port/src','roblox_port/tests'],cwd=ROOT)
 with tarfile.open(fileobj=io.BytesIO(rawSource)) as archive:
  production={m.name:sha(archive.extractfile(m).read()) for m in archive if m.isfile()}
 assert all(sha((ROOT/name).read_bytes())==digest for name,digest in production.items())
 dispatch=load('dispatch_proof','run-dispatch-guard.py')
 for label,worker,successful in [('dispatch-before-fix','worker.luau',False),('dispatch-qualified-1','worker-v2.luau',True)]:
  db,di,dp=dispatch.build(H/worker);dr=json.loads((H/(label+'-receipt.json')).read_text());dt=(H/(label+'-output.txt')).read_bytes()
  assert dr['inputs']==di and dr['bundle_sha256']==sha(db.encode()) and dr['output_sha256']==sha(dt) and (dr['exit_code']==0)==successful
  if successful:assert b'DISPATCH_GUARD passed=9 failed=0 groups=2' in dt
  else:assert (H/(label+'-bundle.luau')).read_bytes()==db.encode() and b'scheduler cancellation still started a provider' in dt
 startup=load('actual_startup_dispatch_proof','run-startup-dispatch.py')
 for label,worker,successful in [('startup-dispatch-before-fix','worker.luau',False),('startup-dispatch-qualified-1','worker-v2.luau',True)]:
  sb,si,sp=startup.build(H/worker);sr=json.loads((H/(label+'-receipt.json')).read_text());st=(H/(label+'-output.txt')).read_bytes()
  assert sr['inputs']==si and sr['bundle_sha256']==sha(sb.encode()) and sr['output_sha256']==sha(st) and (sr['exit_code']==0)==successful
  if successful:assert b'STARTUP_DISPATCH_GUARD passed=4 failed=0 groups=1 actual_startup_wrapper=true' in st
  else:assert (H/(label+'-bundle.luau')).read_bytes()==sb.encode() and b'actual startup scheduler cancellation still started a provider' in st
 private=[H/x for x in ['entry.luau','lease.luau','entry-tests.luau','entry-lease-wait-tests.luau','run-entry.py','check-entry.py','worker-v2.luau','dispatch-guard-tests.luau']]
 committed=all(subprocess.run(['git','cat-file','-e','HEAD:'+p.relative_to(ROOT).as_posix()],cwd=ROOT,capture_output=True).returncode==0 and subprocess.check_output(['git','show','HEAD:'+p.relative_to(ROOT).as_posix()],cwd=ROOT)==p.read_bytes() for p in private)
 commit=subprocess.check_output(['git','log','-1','--format=%H','--',*[p.relative_to(ROOT).as_posix() for p in private]],cwd=ROOT,text=True).strip() if committed else None
 result=dict(source=SOURCE,private_inputs_committed=committed,private_commit=commit,baseline_checks=211864,entry_lease_checks=entryCount,entry_lease_groups=8,
  full_checks=211864+entryCount+9,full_named_groups=58,full_failed=0,dispatch_guard_checks=9,dispatch_counterexample_bound=True,portable_guard_checks=4882,
  actual_startup_guard_checks=4,actual_startup_guard_counterexample_bound=True,
  overlay_candidates=44,strict_clean=True,typed_workers=['discovery','entry','read_lease'],
  provider='memory',clock='synthetic',actual_runtime_and_client_receipts=True,all_workers_typed=False,service_lanes_installed=False,cooperative_driver_installed=False,
  normal_startup_installed=False,native_verified=False,online_verified=False,loading_speedup_proved=False,published=False,goal_complete=False)
 (H/'entry-verification.json').write_text(json.dumps(result,indent=2)+'\n',encoding='utf8',newline='\n');print(json.dumps(result,indent=2))
if __name__=='__main__':main()
