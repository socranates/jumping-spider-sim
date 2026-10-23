"""Qualify the private actual-game adapter, not production engine activation."""
from pathlib import Path
import ast,hashlib,importlib.util,io,json,re,subprocess,tarfile
H=Path(__file__).resolve().parent;ROOT=H.parents[1]
sha=lambda b:hashlib.sha256(b).hexdigest()
source=subprocess.check_output(['git','log','-1','--format=%H','--','roblox_port/src','roblox_port/tests'],cwd=ROOT,text=True).strip()
spec=importlib.util.spec_from_file_location('current_game_runner',H/'run-recovery-game-entry.py');m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
bundle,_=m.build();r=json.loads((H/'actual-game-attempt-2-receipt.json').read_text(encoding='utf8'));output=(H/'actual-game-attempt-2-output.txt').read_bytes()
assert r['source']==source and r['exit_code']==0 and not r['focused'] and not r['baseline'] and not r['deadline_only']
assert sha(bundle.encode())==r['bundle_sha256'] and sha(output)==r['output_sha256']
for name,digest in {**r['inputs'],**r['production_inputs']}.items():assert sha((ROOT/name).read_bytes())==digest,name
raw=subprocess.check_output(['git','archive','--format=tar',source,'roblox_port/src','roblox_port/tests'],cwd=ROOT)
with tarfile.open(fileobj=io.BytesIO(raw)) as archive:
 committed={item.name:sha(archive.extractfile(item).read()) for item in archive if item.isfile()}
assert committed==r['production_inputs']
tree=ast.parse((H/'verify-recovery-capability.py').read_text(encoding='utf8'))
node=next(n.value for n in tree.body if isinstance(n,ast.Assign) and any(isinstance(t,ast.Name) and t.id=='expected' for t in n.targets))
expected={k.arg:ast.literal_eval(k.value) for k in node.keywords};assert sum(expected.values())==187257
expected['RECOVERY_ACTUAL_GAME']=949
rows=re.findall(r'^(RECOVERY_\w+) passed=(\d+) failed=(\d+)',output.decode(),re.M)
assert len(rows)==26 and {name:(int(p),int(f)) for name,p,f in rows}=={name:(n,0) for name,n in expected.items()}
cases=re.findall(r'^RECOVERY_ACTUAL_GAME mode=(main|free|easy) scene=(rest|courted|hatched) real_adoption=true generation_delta=1 applied_once=true menu_hidden_hold=true actual_server_grant=true$',output.decode(),re.M)
assert set(cases)=={(mode,stage) for mode in ['main','free','easy'] for stage in ['rest','courted','hatched']} and len(cases)==9
assert 'RECOVERY_ACTUAL_GAME deadline_callback_before_update_refused=true' in output.decode()
types=json.loads((H/'actual-game-types-5-types.json').read_text(encoding='utf8'));assert len(types['candidates'])==35 and len(types['steps'])==3
for name,digest in types['candidates'].items():assert sha((H/name).read_bytes())==digest,name
for step in types['steps']:
 assert step['exit_code']==0 and sha((H/('actual-game-types-5-'+step['name']+'.txt')).read_bytes())==step['output_sha256']
strict=(H/'actual-game-types-5-strict.txt').read_text(encoding='utf8')
assert not [s for s in strict.splitlines() if s and not s.startswith('[INFO]') and 'didChangeWatchedFiles' not in s]
# Reconstruct the actually executed pre-fix negative, including its exact older
# fixture. Its snapshot hash was matched before preserving it under this name.
negative=json.loads((H/'actual-game-deadline-negative-1-receipt.json').read_text(encoding='utf8'))
old_fixture=H/'before-deadline-game-tests.luau';old_bundle,_=m.build(True,True,True,test_path=old_fixture)
assert negative['exit_code']!=0 and negative['baseline'] and negative['deadline_only'] and negative['focused']
assert sha(old_bundle.encode())==negative['bundle_sha256']
for name,digest in negative['inputs'].items():
 p=old_fixture if name=='docs/save-slot-isolation/recovery-game-entry-tests.luau' else ROOT/name
 assert sha(p.read_bytes())==digest,name
bad=(H/'actual-game-deadline-negative-1-output.txt').read_bytes();assert sha(bad)==negative['output_sha256']
assert 'late grant callback released before deadline update' in bad.decode()
pspec=importlib.util.spec_from_file_location('profile_probe',H/'run-recovery-game-profile-probe.py');pm=importlib.util.module_from_spec(pspec);pspec.loader.exec_module(pm)
pbundle,_=pm.build();profile=json.loads((H/'actual-game-profile-alias-1-receipt.json').read_text(encoding='utf8'))
assert profile['source']==source and profile['exit_code']==0 and profile['expected_integration_counterexample'] and not profile['legacy_profile_supported']
assert sha(pbundle.encode())==profile['bundle_sha256']
for name,digest in profile['inputs'].items():assert sha((ROOT/name).read_bytes())==digest,name
pout=(H/'actual-game-profile-alias-1-output.txt').read_bytes();assert sha(pout)==profile['output_sha256']
assert 'RECOVERY_PROFILE_COUNTEREXAMPLE source_slot=main rules=gentle adopted_active_slot=easy acknowledged=false held=true supported=false' in pout.decode()
assert 'RECOVERY_PROFILE_GUARD passed=53 failed=0' in pout.decode()
assert subprocess.run(['git','diff','--quiet','HEAD','--','roblox_port/src','roblox_port/tests'],cwd=ROOT).returncode==0
result=dict(source=source,actual_game_assertions=949,preceding_private_assertions=187257,total_assertions=188206,private_candidates=35,
 actual_game_store_rules_controls_camera_adoption_called=True,same_game_and_adapter_transport_view=True,all_nine_mode_scene_pairs=True,
 real_saveservice_saveclient_memory_transport_grant=True,hidden_menu_clocks_energy_held=True,entry_resends_apply_once=True,
 cooperative_cancellation_refuses_apply=True,newer_choice_and_unexpected_generation_fenced=True,reentrant_grant_and_lost_send_result=True,
 late_actual_grant_after_new_choice_refused=True,deadline_callback_counterexample_reproduced_and_fixed=True,
 original_archives_proposals_preserved=True,compile_and_full_strict_clean=True,production_unchanged=True,
 profile_alias_counterexample_checks=53,legacy_main_gentle_profile_alias_supported=False,menu_callbacks_installed_in_engine=False,
 server_profiles_or_replacement_epochs_implemented=False,ordinary_engine_recovery_installed=False,native_recovery_verified=False,
 real_datastore_verified=False,published=False,goal_complete=False)
(H/'recovery-game-entry-verification.json').write_text(json.dumps(result,indent=2)+'\n',encoding='utf8',newline='\n');print(json.dumps(result,indent=2))
