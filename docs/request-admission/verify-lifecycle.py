"""Bind typed New/departure/Runtime lifecycle and its exact preceding cohort."""
from pathlib import Path
import hashlib,importlib.util,io,json,re,subprocess,tarfile,zipfile
H=Path(__file__).resolve().parent;ROOT=H.parents[1]
SOURCE='bd67582b5d53473f067244fc1e2e1f94adde173b';sha=lambda b:hashlib.sha256(b).hexdigest()
def load(name,file):
 spec=importlib.util.spec_from_file_location(name,H/file);m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m);return m
def main():
 runner=load('lifecycle_qualified','run-lifecycle.py');bundle,paths=runner.build()
 r=json.loads((H/'lifecycle-qualified-1-receipt.json').read_text());raw=(H/'lifecycle-qualified-1-output.txt').read_bytes();text=raw.decode()
 assert r['source']==SOURCE and r['exit_code']==0 and not r['focused']
 assert r['inputs']=={p.relative_to(ROOT).as_posix():sha(p.read_bytes()) for p in paths}
 assert r['bundle_sha256']==sha(bundle.encode()) and r['output_sha256']==sha(raw)
 pattern=r'^([A-Z_0-9]+) passed=(\d+) failed=(\d+)'
 prior=(H/'saving-qualified-1-output.txt').read_text(encoding='utf8');expected={name:(int(p),int(f)) for name,p,f in re.findall(pattern,prior,re.M)}
 assert len(expected)==44 and sum(p for p,f in expected.values())==254680 and all(f==0 for p,f in expected.values())
 caseExpected={
 'NEW':{'all-modes-preserve-original-before-retirement':898,'continued-new-reuses-exact-originals-and-proposal':284,
  'queued-retirement-and-readback-keep-exact-cas':561,'lost-retirement-ack-probes-before-retry':540,'queued-new-cancel-selection-change-and-cap':84,
  'cancel-suspended-committed-retirement-withholds-result-and-drains':234,'verified-new-departure-cancels-queued-maintenance-first':245},
 'DEPARTURE':{'closed-departure-merges-and-releases-all-source-variants':838,'unlocked-readback-waits-without-another-write':356,
  'ambiguous-departure-read-failure-and-callback-retry':1288,'foreign-ownership-expiry-and-provider-cap-refuse-closed':54,'suspended-committed-departure-expires-and-drains':316},
 'RECOVERED':{'all-modes-retire-fresh-marker-and-closed-departure':5331,'unresolved-aba-progress-is-reconciled-by-typed-departure':3464,
  'Runtime-flush-deadline-cancels-queued-departure':1721,'returning-retired-offer-binds-fresh-writer-and-lease':1757}}
 for category,counts in caseExpected.items():
  cases=re.findall(r'^LIFECYCLE_'+category+r'_CASE\s([^\t\n]+)\s(\d+)$',text,re.M)
  assert len(cases)==len(counts) and {name:int(p) for name,p in cases}==counts
  expected['LIFECYCLE_'+category]=(sum(counts.values()),0)
 rows=re.findall(pattern,text,re.M);assert len(rows)==47 and {name:(int(p),int(f)) for name,p,f in rows}==expected
 assert sum(p for p,f in expected.values())==272651 and not re.search(r'\b(?:fail|failed)=[1-9]\d*\b|stacktrace:',text)
 assert r['typed_new_and_departure'] and not any(r[k] for k in ['all_workers_typed','service_lanes_installed','normal_startup_installed','native_verified','online_verified','published'])
 checker=load('lifecycle_type_qualification','check-lifecycle.py').checker();sources=checker.paths()
 types=json.loads((H/'lifecycle-types-qualified-1-types.json').read_text());assert len(sources)==46 and len(types['candidates'])==45
 assert types['candidates']=={p.relative_to(ROOT).as_posix():sha(p.read_bytes()) for p in sources.values()}
 mounted={}
 for target,p in sources.items():
  code=p.read_text()
  if p in [H/'worker-v3.luau',H/'operation.luau']:code=code.replace('require("./worker-facade")','require(script.Parent.RequestAdmissionFacade)')
  mounted[target]=sha(code.encode())
 assert types['mounted']==mounted and len(types['steps'])==3
 for step in types['steps']:assert step['exit_code']==0 and sha((H/('lifecycle-types-qualified-1-'+step['name']+'.txt')).read_bytes())==step['sha256']
 assert (H/'lifecycle-types-qualified-1-compile.txt').read_text()=='compile 46/46\n'
 strict=(H/'lifecycle-types-qualified-1-strict.txt').read_text();assert not [line for line in strict.splitlines() if line and not line.startswith('[INFO]') and 'didChangeWatchedFiles' not in line]
 for name,digest in types['production_inputs'].items():assert sha((ROOT/name).read_bytes())==digest
 negative=json.loads((H/'lifecycle-timeout-negative-1-receipt.json').read_text());nb,np=runner.build(True)
 old='''j.scope.owner:finishDeparture(j.scope,false);j.state,j.problem="refused","routing departure deadline reached"
   j.result={progressPreserved=false,leaseReleased=false,sessionClosed=true,gameplayAuthorized=false}'''
 assert nb.count('self.departure:expire(j)')==1;nb=nb.replace('self.departure:expire(j)',old)
 nr=(H/'lifecycle-timeout-negative-1-output.txt').read_bytes()
 assert negative['inputs']=={p.relative_to(ROOT).as_posix():sha(p.read_bytes()) for p in np}
 assert negative['bundle_sha256']==sha(nb.encode()) and negative['output_sha256']==sha(nr) and negative['exit_code']!=0
 assert 'Runtime timeout stranded queued departure' in nr.decode() and 'LIFECYCLE_RECOVERED passed=' not in nr.decode()
 development=json.loads((H/'lifecycle-development-1-receipt.json').read_text())
 with zipfile.ZipFile(H/'lifecycle-development-1-bundle.zip') as z:assert sha(z.read('run.luau'))==development['bundle_sha256']
 assert development['exit_code']!=0 and sha((H/'lifecycle-development-1-output.txt').read_bytes())==development['output_sha256']
 archive=subprocess.check_output(['git','archive','--format=tar',SOURCE,'roblox_port/src','roblox_port/tests','roblox_port/default.project.json'],cwd=ROOT)
 with tarfile.open(fileobj=io.BytesIO(archive)) as a:production={m.name:sha(a.extractfile(m).read()) for m in a if m.isfile()}
 assert all(sha((ROOT/name).read_bytes())==digest for name,digest in production.items())
 private=[H/x for x in ['new-policy.luau','departure.luau','runtime-lifecycle.luau','lifecycle-new-tests.luau','lifecycle-departure-tests.luau','lifecycle-recovered-tests.luau',
  'run-lifecycle.py','check-lifecycle.py','run-lifecycle-negative.py','verify-lifecycle.py']]
 committed=all(subprocess.run(['git','cat-file','-e','HEAD:'+p.relative_to(ROOT).as_posix()],cwd=ROOT,capture_output=True).returncode==0 and subprocess.check_output(['git','show','HEAD:'+p.relative_to(ROOT).as_posix()],cwd=ROOT)==p.read_bytes() for p in private)
 commit=subprocess.check_output(['git','log','-1','--format=%H','--',*[p.relative_to(ROOT).as_posix() for p in private]],cwd=ROOT,text=True).strip() if committed else None
 result=dict(source=SOURCE,private_inputs_committed=committed,private_commit=commit,baseline_checks=254680,new_policy_checks=2846,departure_checks=2852,recovered_lifecycle_checks=12273,
  lifecycle_checks=17971,lifecycle_groups=16,full_checks=272651,full_named_groups=111,full_failed=0,overlay_targets=46,distinct_private_sources=45,strict_clean=True,
  Runtime_timeout_counterexample_reproduced=True,main_free_easy_retirement_and_departure_verified=True,queued_owner_maintenance_cancelled=True,
  provider='memory',clock='synthetic',typed_new_and_departure=True,all_workers_typed=False,terminal_held_idle_typed=False,service_lanes_installed=False,cooperative_driver_installed=False,
  normal_startup_installed=False,native_verified=False,online_verified=False,loading_speedup_proved=False,published=False,goal_complete=False)
 (H/'lifecycle-verification.json').write_text(json.dumps(result,indent=2)+'\n',encoding='utf8',newline='\n');print(json.dumps(result,indent=2))
if __name__=='__main__':main()
