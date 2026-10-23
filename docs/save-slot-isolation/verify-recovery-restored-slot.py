"""Qualify the private actual-game adapter, not production engine activation."""
from pathlib import Path
import ast,hashlib,importlib.util,io,json,re,subprocess,tarfile
H=Path(__file__).resolve().parent;ROOT=H.parents[1]
sha=lambda b:hashlib.sha256(b).hexdigest()
source=subprocess.check_output(['git','log','-1','--format=%H','--','roblox_port/src','roblox_port/tests'],cwd=ROOT,text=True).strip()
spec=importlib.util.spec_from_file_location('current_game_runner',H/'run-recovery-game-entry.py');m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
bundle,_=m.build();r=json.loads((H/'restored-slot-attempt-1-receipt.json').read_text(encoding='utf8'));output=(H/'restored-slot-attempt-1-output.txt').read_bytes()
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
expected['RECOVERY_ACTUAL_GAME']=1012
rows=re.findall(r'^(RECOVERY_\w+) passed=(\d+) failed=(\d+)',output.decode(),re.M)
assert len(rows)==26 and {name:(int(p),int(f)) for name,p,f in rows}=={name:(n,0) for name,n in expected.items()}
cases=re.findall(r'^RECOVERY_ACTUAL_GAME mode=(main|free|easy) scene=(rest|courted|hatched) real_adoption=true generation_delta=1 applied_once=true menu_hidden_hold=true actual_server_grant=true$',output.decode(),re.M)
assert set(cases)=={(mode,stage) for mode in ['main','free','easy'] for stage in ['rest','courted','hatched']} and len(cases)==9
assert 'RECOVERY_ACTUAL_GAME deadline_callback_before_update_refused=true' in output.decode()
types=json.loads((H/'restored-slot-types-1-types.json').read_text(encoding='utf8'));assert len(types['candidates'])==35 and len(types['steps'])==3
for name,digest in types['candidates'].items():assert sha((H/name).read_bytes())==digest,name
for step in types['steps']:
 assert step['exit_code']==0 and sha((H/('restored-slot-types-1-'+step['name']+'.txt')).read_bytes())==step['output_sha256']
strict=(H/'restored-slot-types-1-strict.txt').read_text(encoding='utf8')
assert not [s for s in strict.splitlines() if s and not s.startswith('[INFO]') and 'didChangeWatchedFiles' not in s]
assert 'RECOVERY_ACTUAL_GAME legacy_main_gentle=true same_physical_slot=true actual_rest_stored=true easy_unchanged=true' in output.decode()
context=json.loads((ROOT/'docs/restored-slot-ownership/private-type-inputs.json').read_text(encoding='utf8'));assert context['source']==source
for name,digest in context['production_inputs'].items():assert sha((ROOT/name).read_bytes().replace(b'\r\n',b'\n'))==digest,name
assert context['private_types']=='docs/save-slot-isolation/restored-slot-types-1-types.json'
assert subprocess.run(['git','diff','--quiet','HEAD','--','roblox_port/src','roblox_port/tests'],cwd=ROOT).returncode==0
result=dict(source=source,actual_game_assertions=1012,preceding_private_assertions=187257,total_assertions=188269,private_candidates=35,
 actual_game_store_rules_controls_camera_adoption_called=True,same_game_and_adapter_transport_view=True,all_nine_mode_scene_pairs=True,
 real_saveservice_saveclient_memory_transport_grant=True,hidden_menu_clocks_energy_held=True,entry_resends_apply_once=True,
 cooperative_cancellation_refuses_apply=True,newer_choice_and_unexpected_generation_fenced=True,reentrant_grant_and_lost_send_result=True,
 late_actual_grant_after_new_choice_refused=True,deadline_callback_regression_passed=True,
 original_archives_proposals_preserved=True,compile_and_full_strict_clean=True,production_unchanged=True,
 historical_profile_alias_counterexample_source="a97b0b54bfa7a49d8cec072cc4c0ebc1fd7ea8ff",legacy_main_gentle_supported_in_actual_memory_game_path=True,menu_callbacks_installed_in_engine=False,
 server_profiles_or_replacement_epochs_implemented=False,ordinary_engine_recovery_installed=False,native_recovery_verified=False,
 real_datastore_verified=False,published=False,goal_complete=False)
(H/'recovery-restored-slot-verification.json').write_text(json.dumps(result,indent=2)+'\n',encoding='utf8',newline='\n');print(json.dumps(result,indent=2))
