"""Bind optional actual-menu New integration to exact committed source and tests."""
from pathlib import Path
import hashlib,importlib.util,io,json,posixpath,re,subprocess,tarfile
H=Path(__file__).resolve().parent;ROOT=H.parents[1];P=ROOT/'docs/new-life-policy'
SOURCE='bd67582b5d53473f067244fc1e2e1f94adde173b';sha=lambda b:hashlib.sha256(b).hexdigest()
spec=importlib.util.spec_from_file_location('new_application_qualified',H/'run.py');m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
bundle,paths=m.build();r=json.loads((H/'qualified-full-1-receipt.json').read_text(encoding='utf8'));output=(H/'qualified-full-1-output.txt').read_bytes()
assert r['source']==SOURCE and r['exit_code']==0 and not r['focused'] and not r['source_uncommitted']
assert r['bundle_sha256']==sha(bundle.encode()) and r['output_sha256']==sha(output)
assert r['inputs']=={p.relative_to(ROOT).as_posix():sha(p.read_bytes()) for p in paths}
raw=subprocess.check_output(['git','archive','--format=tar',SOURCE,'roblox_port/src','roblox_port/tests'],cwd=ROOT)
with tarfile.open(fileobj=io.BytesIO(raw)) as archive:committed={p.name:sha(archive.extractfile(p).read()) for p in archive if p.isfile()}
assert r['production_inputs']==committed
for name,digest in committed.items():assert sha((ROOT/name).read_bytes())==digest,name
normalized={}
for name,digest in r['inputs'].items():
 key=posixpath.normpath(name);assert not key.startswith('../') and not key.startswith('/')
 assert key not in normalized or normalized[key]==digest,'Aliased input paths must name identical bytes'
 normalized[key]=digest
raw_inputs=subprocess.check_output(['git','archive','--format=tar',SOURCE,*normalized],cwd=ROOT)
with tarfile.open(fileobj=io.BytesIO(raw_inputs)) as archive:private_committed={p.name:sha(archive.extractfile(p).read()) for p in archive if p.isfile()}
assert normalized==private_committed,'Every qualified adapter/test input must also be committed at the reviewed source'
pattern=r'^(RECOVERY_\w+|SESSION_REPLACEMENT|SERVER_TEMPLATE_RECOVERY|PROTECTED_NEW|NEW_APPLICATION(?:_FAILURE)?) passed=(\d+) failed=(\d+)'
old=subprocess.check_output(['git','show','3fa1be5abbdc25470af47b727e04589b5a40e736:docs/new-life-policy/qualified-full-2-output.txt'],cwd=ROOT).decode()
prior=re.findall(pattern,old,re.M);assert len(prior)==32 and sum(int(p) for _,p,_ in prior)==211595
expected={name:(int(p),int(f)) for name,p,f in prior};expected.update(NEW_APPLICATION=(82,0),NEW_APPLICATION_FAILURE=(40,0))
rows=re.findall(pattern,output.decode(),re.M)
assert len(rows)==34 and {name:(int(p),int(f)) for name,p,f in rows}==expected
assert sum(int(p) for _,p,_ in rows)==211717 and not re.search(r'\b(?:fail|failed)=[1-9]\d*\b|stacktrace:',output.decode())
for mode in ['main','free','easy']:
 assert f'NEW_APPLICATION mode={mode} actual_menu=true original_retained=true old_closed=true explicit_fresh_choice=true writable=true normal_rest_stored=true' in output.decode()
assert re.search(r'^RECOVERY_APPLICATION_GAME read_invariants=[1-9]\d* every_read_checked=true$',output.decode(),re.M)
types=json.loads((P/'new-application-types-1-types.json').read_text(encoding='utf8'))
assert types['source']==SOURCE and len(types['candidates'])==41 and len(types['steps'])==3
for name,digest in {**types['candidates'],**types['production_inputs']}.items():assert sha((ROOT/name).read_bytes())==digest,name
assert types['candidates']=={name:digest for name,digest in r['inputs'].items() if name in types['candidates']}
for step in types['steps']:assert step['exit_code']==0 and sha((P/('new-application-types-1-'+step['name']+'.txt')).read_bytes())==step['output_sha256']
assert (P/'new-application-types-1-compile.txt').read_text(encoding='utf8')=='compile 41/41\n'
strict=(P/'new-application-types-1-strict.txt').read_text(encoding='utf8')
assert not [line for line in strict.splitlines() if line and not line.startswith('[INFO]') and 'didChangeWatchedFiles' not in line]
checks=json.loads((H/'checks.json').read_text(encoding='utf8'));assert checks['source']==SOURCE and checks['compile_passed']==224
assert checks['compile_sha256']==sha((H/'compile.txt').read_bytes()) and (H/'compile.txt').read_text()=='compile 224/224\n'
for step in checks['steps']:assert step['exit_code']==0 and sha((H/(step['name']+'.txt')).read_bytes())==step['output_sha256']
assert 'Ran 5 tests' in (H/'runner.txt').read_text() and re.search(r'\bOK\s*$',(H/'runner.txt').read_text())
assert 'ownerFactory' not in (ROOT/'roblox_port/src/Server/Persistence.server.luau').read_text()
source=(ROOT/'roblox_port/src/Client/SpiderClient.client.luau').read_text(encoding='utf8')
assert source.count('saveState.installRecovery(')==1 and 'function saveState.installRecovery(' in source
result=dict(source=SOURCE,named_groups=34,total_checks=211717,failed=0,actual_new_menu_checks=82,actual_failure_menu_checks=40,
 previous_32_groups_fixed_totals_unchanged=True,exact_committed_private_inputs=True,private_candidates=41,production_compile=224,full_strict_clean=True,runner_regressions=5,
 actual_game_new_policy_connected_with_optional_factory=True,all_three_modes_normal_stored_ack=True,
 recovered_playing_choice_closes_owner_before_fresh_menu=True,ordinary_rest_during_background_refresh_stored=True,
 lost_new_requests_and_verified_reply_recovered=True,conflicting_raw_rest_retained_with_held_exit=True,
 persisted_retirement_new_only=True,no_silent_choice_after_replacement=True,original_archives_and_proposals_retained=True,
 normal_engine_startup_installs_recovery=False,native_application_recovery_verified=False,real_datastore_verified=False,published=False,goal_complete=False)
(H/'private-verification.json').write_text(json.dumps(result,indent=2)+'\n',encoding='utf8',newline='\n');print(json.dumps(result,indent=2))
