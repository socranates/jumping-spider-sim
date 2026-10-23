"""Bind actual service account visits, bounded dispatch and cancellation proofs."""
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
 load('service_prior_verifier','verify-profile.py').main()
 runner=load('service_qualified_runner','run-service.py');r,text=bind('service-qualified-2',*runner.build())
 assert r['source']==SOURCE and r['exit_code']==0 and not r['focused'] and r['account_service_candidate']
 assert not any(r[k] for k in ['normal_startup_installed','native_verified','online_verified','published'])
 pattern=r'^([A-Z_0-9]+) passed=(\d+) failed=(\d+)'
 prior=(H/'profile-qualified-1-output.txt').read_text(encoding='utf8')
 expected={name:(int(p),int(f)) for name,p,f in re.findall(pattern,prior,re.M)}
 assert len(expected)==52 and sum(p for p,f in expected.values())==288031 and all(f==0 for p,f in expected.values())
 counts={'initial-owner-and-normal-removal-use-one-account-lane':15,'cancel-capacity-wait-before-any-storage-start':5,
  'cancel-after-initial-commit-drains-and-releases-only-the-lock':12,'cancel-before-initial-transform-cannot-create-or-change-progress':6,
  'cancel-suspended-initial-rest-discards-it-and-cleans-owned-lock':13,'closed-cleanup-waits-for-capacity-without-fake-attempts':17,
  'ambiguous-cleanup-write-probes-before-another-write':9,'foreign-lock-at-cleanup-is-never-released-or-overwritten':6,
  'cleanup-deadline-retains-uncertain-lock-and-never-fakes-release':10,'removal-cancels-queued-normal-work-and-preserves-latest-progress':13,
  'another-actors-read-can-pass-a-blocked-write':24,'loaded-multi-actor-shutdown-closes-both-scopes':22,
  'failed-constructor-retains-complete-legacy-debt-for-rejoin':15,'oversized-legacy-history-refuses-instead-of-truncating':4,
  'cancelling-history-lookup-does-not-forgive-known-debt':3,'actual-replacement-keeps-account-debt-and-originals-main':155,
  'actual-replacement-keeps-account-debt-and-originals-free':155,'actual-replacement-keeps-account-debt-and-originals-easy':155,
  'lost-replacement-control-packets-do-not-create-extra-scopes':164,'failed-replacement-factory-closes-its-new-scope-without-fallback':140,
  'late-initial-constructor-cannot-replace-a-rejoined-account':14,'shutdown-revokes-an-unreturned-constructor':3,
  'rejoin-waits-for-cancelled-native-acquisition-and-cleanup':23,'shutdown-drains-a-native-initial-load-on-its-own-engine-task':10,
  'shutdown-deadline-revokes-a-still-pending-native-provider':6,'removing-an-unstarted-load-task-does-not-start-storage':4,
  'shutdown-cancels-a-deferred-load-after-addPlayer-returned':3,'one-service-step-task-per-actor-can-be-queued':24,
  'pending-native-ordinary-work-does-not-spawn-redundant-workers':16,'initial-task-launch-failure-closes-scope-without-departure-leak':5,
  'step-launch-failure-releases-only-its-actor-dispatch-slot':13,'post-constructor-startup-wrapper-is-refused-before-registration':4,
  'actual-protected-new-and-fresh-checkpoint-main':128,'actual-protected-new-and-fresh-checkpoint-free':128,'actual-protected-new-and-fresh-checkpoint-easy':128,
  'initial-admission-expiry-is-retryable-without-fake-provider-failure':14}
 cases=re.findall(r'^ACCOUNT_SERVICE_CASE\s([^\t\n]+)\s(\d+)$',text,re.M)
 assert len(cases)==36 and {name:int(n) for name,n in cases}==counts and sum(counts.values())==1466
 expected['ACCOUNT_SERVICE']=(1466,0);rows=re.findall(pattern,text,re.M)
 assert len(rows)==53 and {name:(int(p),int(f)) for name,p,f in rows}==expected
 groups=re.findall(r'^[A-Z_0-9]+ passed=\d+ failed=0 groups=(\d+)$',text,re.M)
 assert len(rows)-len(groups)==34 and sum(map(int,groups))+len(rows)-len(groups)==184
 assert not re.search(r'\b(?:fail|failed)=[1-9]\d*\b|stacktrace:',text)
 fr,ft=bind('service-development-9',*runner.build(True));assert fr['exit_code']==0 and fr['focused'] and 'ACCOUNT_SERVICE passed=1466 failed=0 groups=36' in ft
 checker=load('service_type_qualification','check-service.py').checker();sources=checker.paths()
 types=json.loads((H/'service-types-qualified-1-types.json').read_text(encoding='utf8'));assert types['source_encoding']=='utf8'
 assert len(sources)==51 and len(types['candidates'])==50
 assert types['candidates']=={p.relative_to(ROOT).as_posix():sha(p.read_bytes()) for p in sources.values()}
 mounted={}
 for target,path in sources.items():
  code=path.read_text(encoding='utf8')
  if path in [H/'worker-v3.luau',H/'operation.luau']:code=code.replace('require("./worker-facade")','require(script.Parent.RequestAdmissionFacade)')
  mounted[target]=sha(code.encode())
 assert types['mounted']==mounted and len(types['steps'])==3
 for step in types['steps']:assert step['exit_code']==0 and sha((H/('service-types-qualified-1-'+step['name']+'.txt')).read_bytes())==step['sha256']
 assert (H/'service-types-qualified-1-compile.txt').read_text(encoding='utf8')=='compile 51/51\n'
 strict=(H/'service-types-qualified-1-strict.txt').read_text(encoding='utf8')
 assert not [line for line in strict.splitlines() if line and not line.startswith('[INFO]') and 'didChangeWatchedFiles' not in line]
 for name,digest in types['production_inputs'].items():assert sha((ROOT/name).read_bytes())==digest
 negative=load('service_negative_qualification','run-service-negative.py')
 for case in ['import','load-hook','dispatch']:
  nr,no=bind('service-before-'+case+'-2',*negative.build(case))
  assert nr['case']==case and nr['exit_code']!=0 and nr['expected_failure'] in no
 state=load('service_state_qualification','run-service-state.py')
 for test,name,count in [('state.luau','STATE',1488),('state_client.luau','STATE_CLIENT',161)]:
  prefix='service-state-qualified-2-'+Path(test).stem.replace('_','-');sr,st=bind(prefix,*state.build(test))
  assert sr['exit_code']==0 and not sr['account_gate_installed_in_this_legacy_test'] and f'{name} passed={count} failed=0' in st
 timeout=load('service_timeout_qualification','probe-service-timeout.py')
 b,p=timeout.build(True);before=json.loads((H/'service-timeout-before-1-receipt.json').read_text(encoding='utf8'));raw=(H/'service-timeout-before-1-output.txt').read_bytes()
 old_io=H/'ordinary-io-service-before-timeout.luau'
 old_inputs={path.relative_to(ROOT).as_posix():sha(old_io.read_bytes()) if path==H/'ordinary-io-service.luau' else sha(path.read_bytes()) for path in p}
 assert before['inputs']==old_inputs and before['bundle_sha256']==sha(b.encode()) and before['output_sha256']==sha(raw)
 assert before['exit_code']!=0 and not before['issue_fixed'] and before['expected_failure'] in raw.decode('utf8')
 tr,tt=bind('service-timeout-fixed-2',*timeout.build());assert tr['exit_code']==0 and tr['issue_fixed'] and 'ACCOUNT_SERVICE passed=14 failed=0 groups=1' in tt
 retry=load('service_repeated_timeout_qualification','probe-service-retry-timeout.py')
 rr,rt=bind('service-retry-timeout-before-1',*retry.build());assert rr['exit_code']==0 and 'ACCOUNT_SERVICE passed=15 failed=0 groups=1' in rt
 observation=json.loads((H/'service-retry-timeout-observation.json').read_text(encoding='utf8'))
 assert not observation['counterexample_reproduced'] and not observation['included_in_full_check_total']
 ledger=load('service_independent_ledger_qualification','probe-service-ledger.py')
 lr,lt=bind('service-ledger-qualified-1',*ledger.build());assert lr['exit_code']==0 and lr['independent_actual_SDK_trace']
 match=re.search(r'^ACCOUNT_GATE_LEDGER audits=(\d+) independent_physical_trace=true$',lt,re.M);assert match and int(match[1])>=36
 audits=int(match[1]);assert f'ACCOUNT_SERVICE passed={1466+audits} failed=0 groups=36' in lt
 # The first full pass did not include the newly reproduced expiry case.
 earlier=json.loads((H/'service-qualified-1-receipt.json').read_text(encoding='utf8'))
 earlier_raw=(H/'service-qualified-1-output.txt').read_bytes()
 assert earlier['exit_code']==0 and earlier['output_sha256']==sha(earlier_raw)
 assert earlier['inputs']['docs/request-admission/ordinary-io-service.luau']==sha(old_io.read_bytes())
 with zipfile.ZipFile(H/'service-qualified-1-before-timeout-bundle.zip') as z:
  assert z.namelist()==['service-qualified-1-bundle.luau'] and sha(z.read(z.namelist()[0]))==earlier['bundle_sha256']
 for n in [1,2,5,8]:
  prefix=f'service-development-{n}';dr=json.loads((H/(prefix+'-receipt.json')).read_text(encoding='utf8'))
  assert dr['exit_code']!=0 and dr['output_sha256']==sha((H/(prefix+'-output.txt')).read_bytes())
  with zipfile.ZipFile(H/(prefix+'-bundle.zip')) as z:assert z.namelist()==[prefix+'-bundle.luau'] and sha(z.read(z.namelist()[0]))==dr['bundle_sha256']
 private=[H/x for x in ['account-lifetimes.luau','ordinary-io-service.luau','save-service.luau','replacement-owner.luau','replacement-service.luau',
  'service-tests.luau','service-more-tests.luau','service-replacement-tests.luau','service-driver-tests.luau','service-new-tests.luau',
  'service-timeout-test.luau','service-retry-timeout-test.luau','ordinary-io-service-before-timeout.luau',
  'run-service.py','run-service-state.py','run-service-negative.py','probe-service-timeout.py','probe-service-retry-timeout.py',
  'probe-service-ledger.py','service-retry-timeout-observation.json','check-service.py','verify-service.py','SERVICE-WORKERS.md']]
 committed=all(subprocess.run(['git','cat-file','-e','HEAD:'+p.relative_to(ROOT).as_posix()],cwd=ROOT,capture_output=True).returncode==0
  and subprocess.check_output(['git','show','HEAD:'+p.relative_to(ROOT).as_posix()],cwd=ROOT)==p.read_bytes() for p in private)
 commit=subprocess.check_output(['git','log','-1','--format=%H','--',*[p.relative_to(ROOT).as_posix() for p in private]],cwd=ROOT,text=True).strip() if committed else None
 result=dict(source=SOURCE,private_inputs_committed=committed,private_commit=commit,preceding_checks=288031,account_service_checks=1466,
  account_service_groups=36,full_checks=289497,full_named_groups=184,full_failed=0,overlay_targets=51,distinct_private_sources=50,strict_clean=True,overlay_source_encoding='utf8',
  separate_STATE_checks=1488,separate_STATE_CLIENT_checks=161,service_owned_account_gate_verified=True,closed_initial_cleanup_verified=True,
  replacement_account_epochs_verified=True,bounded_service_step_dispatch_verified=True,actual_client_New_and_fresh_checkpoint_verified=True,
  controlled_before_fix_failures_bound=3,initial_admission_expiry_fixed_private=True,expiry_counterexample_bound=True,
  repeated_outage_probe_checks=15,repeated_outage_was_not_a_second_defect=True,independent_gate_ledger_audits=audits,
  independent_ledger_probe_checks=1466+audits,legacy_adoption_boundary='cold or fully quiesced complete supplied account history',
  provider='memory-injected-DataStoreBackend',clock='synthetic',normal_startup_installed=False,native_verified=False,online_verified=False,
  loading_speedup_proved=False,frame_rate_improvement_proved=False,published=False,goal_complete=False)
 (H/'service-verification.json').write_text(json.dumps(result,indent=2)+'\n',encoding='utf8',newline='\n');print(json.dumps(result,indent=2))
if __name__=='__main__':main()
