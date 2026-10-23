"""Bind full actual-menu/application evidence to committed source and adapter bytes."""
from pathlib import Path
import hashlib,importlib.util,io,json,re,subprocess,tarfile
H=Path(__file__).resolve().parent;ROOT=H.parents[1];P=ROOT/'docs/save-slot-isolation'
SOURCE='216b83c7f2b5136230d8bda58653717433eccc51'
sha=lambda b:hashlib.sha256(b).hexdigest()
spec=importlib.util.spec_from_file_location('application_qualification',H/'run.py');m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
bundle,_=m.build()
r=json.loads((H/'qualified-full-2-receipt.json').read_text(encoding='utf8'));output=(H/'qualified-full-2-output.txt').read_bytes()
assert r['source']==SOURCE and r['exit_code']==0 and not r['focused'] and not r['source_uncommitted']
assert sha(bundle.encode())==r['bundle_sha256'] and sha(output)==r['output_sha256']
for name,digest in {**r['inputs'],**r['production_inputs']}.items():assert sha((ROOT/name).read_bytes())==digest,name
raw=subprocess.check_output(['git','archive','--format=tar',SOURCE,'roblox_port/src','roblox_port/tests'],cwd=ROOT)
with tarfile.open(fileobj=io.BytesIO(raw)) as archive:
 committed={item.name:sha(archive.extractfile(item).read()) for item in archive if item.isfile()}
assert committed==r['production_inputs']
baseline=subprocess.check_output(['git','show','2423d4230b2153d23853ac5e804b077b44c43f9e:docs/server-recovery-templates/qualified-full-2-output.txt'],cwd=ROOT).decode()
pattern=r'^(RECOVERY_\w+|SESSION_REPLACEMENT|SERVER_TEMPLATE_RECOVERY) passed=(\d+) failed=(\d+)'
old=re.findall(pattern,baseline,re.M);assert len(old)==30 and sum(int(p) for _,p,_ in old)==204788 and all(int(f)==0 for _,_,f in old)
expected={name:(int(p),0) for name,p,_ in old}
assert expected['SESSION_REPLACEMENT']==(2688,0)
expected.update(SESSION_REPLACEMENT=(2735,0),RECOVERY_APPLICATION_GAME=(65,0))
rows=re.findall(pattern,output.decode(),re.M)
assert len(rows)==31 and {name:(int(p),int(f)) for name,p,f in rows}==expected and sum(int(p) for _,p,_ in rows)==204900
assert re.search(r'^RECOVERY_APPLICATION_GAME read_invariants=[1-9]\d* every_read_checked=true$',output.decode(),re.M)
for mode in ['main','free','easy']:
 assert f'RECOVERY_APPLICATION_GAME mode={mode} actual_menu=true actual_callbacks=true held_until_grant_or_exit=true closed_owner_before_fresh_menu=true' in output.decode()
types=json.loads((P/'application-types-1-types.json').read_text(encoding='utf8'))
assert types['source']==SOURCE and len(types['candidates'])==40 and len(types['steps'])==3
for name,digest in types['candidates'].items():assert sha((P/name).read_bytes())==digest,name
for name,digest in types['production_inputs'].items():assert sha((ROOT/name).read_bytes())==digest,name
for step in types['steps']:assert step['exit_code']==0 and sha((P/('application-types-1-'+step['name']+'.txt')).read_bytes())==step['output_sha256']
strict=(P/'application-types-1-strict.txt').read_text(encoding='utf8')
assert not [line for line in strict.splitlines() if line and not line.startswith('[INFO]') and 'didChangeWatchedFiles' not in line]
assert 'ownerFactory' not in (ROOT/'roblox_port/src/Server/Persistence.server.luau').read_text(encoding='utf8')
negative=json.loads((H/'focused-dev-4-receipt.json').read_text(encoding='utf8'));negative_output=(H/'focused-dev-4-output.txt').read_bytes()
assert negative['exit_code']==1 and negative['source_uncommitted'] and sha(negative_output)==negative['output_sha256']
assert b'server could not verify old departure owner=offered' in negative_output
for snapshot,name in [('before-preaccept-replacement-owner.luau','docs/save-slot-isolation/replacement-owner-prototype.luau'),('before-preaccept-application-tests.luau','docs/recovery-application/application-tests.luau')]:
 assert sha((H/snapshot).read_bytes())==negative['inputs'][name]
result=dict(source=SOURCE,total_checks=204900,named_groups=31,failed=0,application_game_checks=65,all_storage_reads_also_check_invariants=True,
 timing_dependent_read_invariants_reported_separately=True,session_replacement_checks=2735,private_candidates=40,
 compile_and_full_strict_clean=True,actual_game_menu_and_pause_ready_error_callbacks=True,preaccept_exit_and_drain_before_offer_verified=True,
 partial_adoption_error_stays_held_with_visible_exit=True,hidden_menu_cannot_resume_old_world=True,originals_retained=True,
 explicit_new_choice_only_current_epoch=True,protected_new_life_reports_session_only=True,protected_new_life_retirement_policy_installed=False,
 ordinary_startup_recovery_enabled=False,native_application_recovery_verified=False,real_datastore_verified=False,published=False,goal_complete=False)
(H/'private-verification.json').write_text(json.dumps(result,indent=2)+'\n',encoding='utf8',newline='\n');print(json.dumps(result,indent=2))
