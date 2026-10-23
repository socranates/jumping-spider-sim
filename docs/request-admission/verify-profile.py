"""Bind all-slot Profile propagation, actual factory flow and negative proofs."""
from pathlib import Path
import hashlib,importlib.util,json,re,subprocess,zipfile
H=Path(__file__).resolve().parent;ROOT=H.parents[1]
SOURCE='bd67582b5d53473f067244fc1e2e1f94adde173b';sha=lambda b:hashlib.sha256(b).hexdigest()
def load(name,file):
 s=importlib.util.spec_from_file_location(name,H/file);m=importlib.util.module_from_spec(s);s.loader.exec_module(m);return m
def bind(prefix,bundle,paths):
 r=json.loads((H/(prefix+'-receipt.json')).read_text(encoding='utf8'));raw=(H/(prefix+'-output.txt')).read_bytes()
 assert r['inputs']=={p.relative_to(ROOT).as_posix():sha(p.read_bytes()) for p in paths}
 assert r['bundle_sha256']==sha(bundle.encode()) and r['output_sha256']==sha(raw)
 return r,raw.decode('utf8')
def main():
 # Reconstruct the earlier cohort and byte-exact production evidence, too.
 load('profile_prior_verifier','verify-ordinary.py').main()
 runner=load('profile_proof_runner','run-profile.py');bundle,paths=runner.build()
 r,text=bind('profile-qualified-1',bundle,paths)
 assert r['source']==SOURCE and r['exit_code']==0 and not r['focused'] and r['profile_lane_from_constructor']
 assert not any(r[k] for k in ['service_lanes_installed','normal_startup_installed','native_verified','online_verified','published'])
 pattern=r'^([A-Z_0-9]+) passed=(\d+) failed=(\d+)'
 prior=(H/'ordinary-qualified-2-output.txt').read_text(encoding='utf8')
 expected={name:(int(p),int(f)) for name,p,f in re.findall(pattern,prior,re.M)}
 assert len(expected)==51 and sum(p for p,f in expected.values())==284075 and all(f==0 for p,f in expected.values())
 counts={'profile-discovery-waits-and-keeps-caller-options':153,'fresh-selection-entry-and-saving-main':673,
  'fresh-selection-entry-and-saving-free':673,'fresh-selection-entry-and-saving-easy':673,
  'post-accept-switch-hold-uses-the-shared-lane':1017,'profile-bind-drains-an-ordinary-admission-suspension':133,
  'suspended-profile-read-drains-before-a-new-choice':118,'protected-new-factory-inherits-lane-after-rebind':430,
  'a-factory-without-admission-refuses-before-begin':84,'conflicting-profile-dependencies-refuse-before-storage':2}
 cases=re.findall(r'^PROFILE_ADMISSION_CASE\s([^\t\n]+)\s(\d+)$',text,re.M)
 assert len(cases)==10 and {name:int(n) for name,n in cases}==counts and sum(counts.values())==3956
 expected['PROFILE_ADMISSION']=(3956,0);rows=re.findall(pattern,text,re.M)
 assert len(rows)==52 and {name:(int(p),int(f)) for name,p,f in rows}==expected
 groups=re.findall(r'^[A-Z_0-9]+ passed=\d+ failed=0 groups=(\d+)$',text,re.M)
 assert len(rows)-len(groups)==34 and sum(map(int,groups))+len(rows)-len(groups)==148
 assert not re.search(r'\b(?:fail|failed)=[1-9]\d*\b|stacktrace:',text)
 focused,small=bind('profile-development-3',*runner.build(True))
 assert focused['exit_code']==0 and focused['focused'] and 'PROFILE_ADMISSION passed=3956 failed=0 groups=10' in small
 checker=load('profile_proof_types','check-profile.py').checker();sources=checker.paths()
 types=json.loads((H/'profile-types-development-2-types.json').read_text(encoding='utf8'))
 assert len(sources)==49 and len(types['candidates'])==48
 assert types['candidates']=={p.relative_to(ROOT).as_posix():sha(p.read_bytes()) for p in sources.values()}
 mounted={}
 for target,path in sources.items():
  code=path.read_text()
  if path in [H/'worker-v3.luau',H/'operation.luau']:code=code.replace('require("./worker-facade")','require(script.Parent.RequestAdmissionFacade)')
  mounted[target]=sha(code.encode())
 assert types['mounted']==mounted and len(types['steps'])==3
 for step in types['steps']:
  assert step['exit_code']==0 and sha((H/('profile-types-development-2-'+step['name']+'.txt')).read_bytes())==step['sha256']
 assert (H/'profile-types-development-2-compile.txt').read_text(encoding='utf8')=='compile 49/49\n'
 strict=(H/'profile-types-development-2-strict.txt').read_text(encoding='utf8')
 assert not [line for line in strict.splitlines() if line and not line.startswith('[INFO]') and 'didChangeWatchedFiles' not in line]
 for name,digest in types['production_inputs'].items():assert sha((ROOT/name).read_bytes())==digest
 negative=load('profile_proof_negative','run-profile-negative.py')
 for case,prefix in [('profile','profile-before-bind-fix-1'),('new','profile-before-new-fix-1')]:
  nr,no=bind(prefix,*negative.build(case))
  assert nr['case']==case and nr['exit_code']!=0 and nr['expected_failure'] in no
 # The first short lease counterexample hit its missing-lane check before
 # actual dispatch, because the old aggregate limiter temporarily masked it.
 # Preserve that observation without crediting it as the expected leak proof.
 short,short_text=bind('profile-before-lease-fix-1',*negative.build('lease'))
 assert short['exit_code']!=0 and short['expected_failure'] not in short_text
 assert 'profile switch lease lost retained typed wait' in short_text
 probe=load('profile_proof_long_lease','probe-profile-lease.py')
 for before,prefix in [(True,'profile-lease-visibility-before-1'),(False,'profile-lease-visibility-fixed-1')]:
  nr,no=bind(prefix,*probe.build(before))
  assert nr['before_fix']==before and nr['observation_seconds']==70
  if before:assert nr['exit_code']!=0 and nr['expected_failure'] in no
  else:assert nr['exit_code']==0 and 'PROFILE_ADMISSION passed=4280 failed=0 groups=10' in no
 for n in [1,2]:
  prefix=f'profile-development-{n}';dr=json.loads((H/(prefix+'-receipt.json')).read_text(encoding='utf8'))
  assert dr['exit_code']!=0 and dr['output_sha256']==sha((H/(prefix+'-output.txt')).read_bytes())
  with zipfile.ZipFile(H/(prefix+'-bundle.zip')) as z:
   assert z.namelist()==[prefix+'-bundle.luau'] and sha(z.read(z.namelist()[0]))==dr['bundle_sha256']
 private=[H/x for x in ['profile-options.luau','profile-owner.luau','new-policy-profile.luau','profile-tests.luau',
  'run-profile.py','run-profile-negative.py','probe-profile-lease.py','check-profile.py','verify-profile.py','PROFILE-WORKERS.md']]
 committed=all(subprocess.run(['git','cat-file','-e','HEAD:'+p.relative_to(ROOT).as_posix()],cwd=ROOT,capture_output=True).returncode==0
  and subprocess.check_output(['git','show','HEAD:'+p.relative_to(ROOT).as_posix()],cwd=ROOT)==p.read_bytes() for p in private)
 commit=subprocess.check_output(['git','log','-1','--format=%H','--',*[p.relative_to(ROOT).as_posix() for p in private]],cwd=ROOT,text=True).strip() if committed else None
 result=dict(source=SOURCE,private_inputs_committed=committed,private_commit=commit,preceding_checks=284075,
  Profile_checks=3956,Profile_groups=10,full_checks=288031,full_named_groups=148,full_failed=0,
  overlay_targets=49,distinct_private_sources=48,strict_clean=True,profile_lane_from_constructor=True,
  profile_rebinding_and_switch_hold_typed=True,actual_factory_New_inherits_lane=True,
  before_fix_counterexamples_bound=3,separate_long_lease_probe_checks=4280,old_aggregate_masking_observed=True,
  ordinary_Session_typed=True,provider='memory',clock='synthetic',
  service_lanes_installed=False,initial_cancellation_cleanup_qualified=False,replacement_account_epochs_qualified=False,
  cooperative_service_driver_installed=False,normal_startup_installed=False,native_verified=False,online_verified=False,
  loading_speedup_proved=False,published=False,goal_complete=False)
 (H/'profile-verification.json').write_text(json.dumps(result,indent=2)+'\n',encoding='utf8',newline='\n');print(json.dumps(result,indent=2))
if __name__=='__main__':main()
