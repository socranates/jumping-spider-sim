from pathlib import Path
import hashlib,io,json,re,subprocess,tarfile
H=Path(__file__).resolve().parent;ROOT=H.parents[1]
SOURCE='695e772d9d1ece490dd32132c655ac60c226c7b8'
sha=lambda b:hashlib.sha256(b).hexdigest()
assert (H/'windows-full-process.json').exists(),'Windows gate is still live or incomplete'
win=json.loads((H/'windows-full-process.json').read_text(encoding='utf8'));start=json.loads((H/'windows-full-start.json').read_text(encoding='utf8'))
assert win['source']==start['source']==SOURCE and win['exit_code']==0 and win['inputs']==start['inputs']
raw=subprocess.check_output(['git','archive','--format=tar',SOURCE,'roblox_port/src','roblox_port/tests'],cwd=ROOT)
with tarfile.open(fileobj=io.BytesIO(raw)) as archive:
 inputs={m.name:sha(archive.extractfile(m).read()) for m in archive if m.isfile()}
assert inputs==win['inputs']
text=(H/'windows-full.txt').read_text(encoding='utf8');rows=re.findall(r'^([A-Z_0-9 ]+) passed=(\d+) failed=(\d+)',text,re.M)
assert len(rows)==76 and sum(int(p) for _,p,_ in rows)==468866 and all(int(f)==0 for _,_,f in rows),rows
assert dict((name,(int(p),int(f))) for name,p,f in rows)['STATE']==(1488,0)
assert dict((name,(int(p),int(f))) for name,p,f in rows)['SAVE_CONTINUATION']==(260,0)
assert dict((name,(int(p),int(f))) for name,p,f in rows)['WORLD_CLIENT']==(43,0)
assert 'PLAYER_STREAM_HOLD disappeared_pose_retained=true clocks_frozen=true partial_refused=true resumed_same_objects=true second_stream_out_held=true' in text
assert 'PLAYER_STREAM_NEXT_TICK refused=true velocity_retained=true clocks_frozen=true' in text
assert 'PLAYER_STREAM_RENDER_WAIT sub_tick_frames=12 waiting_stable=true clocks_frozen=true' in text
assert not re.search(r'\b(?:fail|failed)=[1-9]\d*\b|\[SELFTEST\] FAIL',text)
checks=json.loads((H/'checks.json').read_text(encoding='utf8'));assert checks['source']==SOURCE and checks['compile_passed']==222
assert checks['compile_sha256']==sha((H/'compile.txt').read_bytes()) and (H/'compile.txt').read_text(encoding='utf8')=='compile 222/222\n'
for step in checks['steps']:assert step['exit_code']==0 and step['output_sha256']==sha((H/(step['name']+'.txt')).read_bytes())
strict=(H/'strict.txt').read_text(encoding='utf8')
assert not [s for s in strict.splitlines() if s and not s.startswith('[INFO]') and 'didChangeWatchedFiles' not in s],strict
runner=(H/'runner.txt').read_text(encoding='utf8');assert 'Ran 5 tests' in runner and re.search(r'\bOK\s*$',runner)
ci=json.loads((H/'ci-final.json').read_text(encoding='utf8'))
assert ci['head_sha']==SOURCE and ci['status']=='completed' and ci['conclusion']=='success'
assert ci['suites']==76 and ci['passed']==468866 and ci['failed']==0 and ci['modules_compiled']==222 and ci['runner_regressions']==5
for name,digest in ci['logs_sha256'].items():assert sha((H/name).read_bytes())==digest
assert 'PLAYER_STREAM_RENDER_WAIT sub_tick_frames=12 waiting_stable=true clocks_frozen=true' in (H/'ci-suites.txt').read_text(encoding='utf8')
native=json.loads((H/'native-full-receipt.json').read_text(encoding='utf8'))
assert native['source']==SOURCE and native['test_passed'] and native['checks']==60 and native['guard_verified_scripts']==223
assert native['creator_errors_during_fixture']==0 and native['original_model_unchanged'] and native['studio_closed']
assert sha((H/'native-full-output.txt').read_bytes())==native['filtered_output_sha256']
if Path(native['path']).exists():assert sha(Path(native['path']).read_bytes())==native['model_sha256']
component=json.loads((H/'private-unchanged.json').read_text(encoding='utf8'))
assert component['current_production_source']==SOURCE and component['executable_bundle_unchanged'] and component['all_explicit_inputs_unchanged']
assert component['private_component_checks']==187257 and component['private_component_failures']==0 and component['current_overlay_candidates']==34
assert subprocess.run(['git','diff','--quiet','HEAD','--','roblox_port/src','roblox_port/tests'],cwd=ROOT).returncode==0
assert subprocess.check_output(['git','log','-1','--format=%H','--','roblox_port/src','roblox_port/tests'],cwd=ROOT,text=True).strip()==SOURCE
assert 'ownerFactory' not in (ROOT/'roblox_port/src/Server/Persistence.server.luau').read_text(encoding='utf8')
assert not re.search(r'\brecovery\s*=',(ROOT/'roblox_port/src/Client/SpiderClient.client.luau').read_text(encoding='utf8'))
result=dict(source=SOURCE,windows_suites=76,windows_passed=468866,windows_failed=0,windows_output_sha256=sha((H/'windows-full.txt').read_bytes()),
 linux_run=ci['id'],linux_suites=76,linux_passed=468866,linux_failed=0,compile=222,strict_clean=True,runner_regressions=5,
 immutable_windows_snapshot_verified=True,owner_factory_default_not_installed_in_engine=True,client_recovery_default_not_configured=True,
 player_collision_hold_and_projected_tick_cli_verified=True,player_sub_tick_render_wait_verified=True,explicit_recovery_handshake_and_transport_verified=True,protected_selection_skips_two_legacy_copies=True,
 native_actual_client_scripted_checks=60,native_actual_client_scripted_fixture_verified=True,native_real_network_pressure_verified=False,
 unchanged_private_component_checks=187257,current_overlay_candidates=34,
 native_full_game_verified=False,real_service_rejoin_verified=False,goal_complete=False,published=False)
(H/'full-verification.json').write_text(json.dumps(result,indent=2)+'\n',encoding='utf8',newline='\n');print(json.dumps(result,indent=2))
