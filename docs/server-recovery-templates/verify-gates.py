"""Require terminal exact-source platform, native and private qualification."""
from pathlib import Path
import hashlib,io,json,re,subprocess,sys,tarfile
H=Path(__file__).resolve().parent;ROOT=H.parents[1]
SOURCE='46c299f5e36038d06f164c968e5fda78bb4407e8'
sha=lambda b:hashlib.sha256(b).hexdigest()
assert subprocess.check_output(['git','log','-1','--format=%H','--','roblox_port/src','roblox_port/tests'],cwd=ROOT,text=True).strip()==SOURCE
assert subprocess.run(['git','diff','--quiet','HEAD','--','roblox_port/src','roblox_port/tests'],cwd=ROOT).returncode==0
raw=subprocess.check_output(['git','archive','--format=tar',SOURCE,'roblox_port/src','roblox_port/tests'],cwd=ROOT)
with tarfile.open(fileobj=io.BytesIO(raw)) as archive:
 inputs={m.name:sha(archive.extractfile(m).read()) for m in archive if m.isfile()}
win=json.loads((H/'windows-full-process.json').read_text(encoding='utf8'))
assert win['source']==SOURCE and win['exit_code']==0 and win['inputs']==inputs
text=(H/'windows-full.txt').read_text(encoding='utf8')
rows=re.findall(r'^([A-Z_0-9 ]+) passed=(\d+) failed=(\d+)',text,re.M)
assert len(rows)==77 and sum(int(p) for _,p,_ in rows)==468936 and all(int(f)==0 for _,_,f in rows)
counts={name:int(p) for name,p,_ in rows}
assert counts['RECOVERY_TEMPLATES']==56 and counts['LOCAL_RETURN']==41 and counts['SAVE_CONTINUATION']==260 and counts['WORLD_CLIENT']==43
assert 'LEGACY_MAIN_GENTLE selected_slot_kept=true next_rest_same_slot=true easy_bytes_retained=true ending_offer_same_slot=true new_lives_select_own_slots=true' in text
assert 'RECOVERY_ENTRY_HOLD actual_adoption=true generation_increment=1 menu_hidden=true stale_release_refused=true explicit_current_release_resumes=true' in text
assert not re.search(r'\b(?:fail|failed)=[1-9]\d*\b|\[SELFTEST\] FAIL',text)
checks=json.loads((H/'checks.json').read_text(encoding='utf8'))
assert checks['source']==SOURCE and checks['compile_passed']==223 and (H/'compile.txt').read_text(encoding='utf8')=='compile 223/223\n'
assert checks['compile_sha256']==sha((H/'compile.txt').read_bytes())
for step in checks['steps']:assert step['exit_code']==0 and sha((H/(step['name']+'.txt')).read_bytes())==step['output_sha256']
strict=(H/'strict.txt').read_text(encoding='utf8')
assert not [line for line in strict.splitlines() if line and not line.startswith('[INFO]') and 'didChangeWatchedFiles' not in line]
runner=(H/'runner.txt').read_text(encoding='utf8');assert 'Ran 5 tests' in runner and re.search(r'\bOK\s*$',runner)
ci=json.loads((H/'ci-final.json').read_text(encoding='utf8'))
assert ci['head_sha']==SOURCE and ci['status']=='completed' and ci['conclusion']=='success' and ci['suites']==77 and ci['passed']==468936 and ci['failed']==0 and ci['modules_compiled']==223
for name,digest in ci['logs_sha256'].items():assert sha((H/name).read_bytes())==digest,name
native=json.loads((H/'native-receipt.json').read_text(encoding='utf8'))
assert native['source']==SOURCE and native['test_passed'] and native['studio_closed'] and native['original_model_unchanged']
assert native['total_native_checks']==109 and native['guard_verified_scripts']==225 and native['creator_errors_during_fixture']==0
assert sha((H/'native-output.txt').read_bytes())==native['filtered_output_sha256']
for path,digest in [(native['path'],native['model_sha256']),(native['editor_copy_path'],native['editor_copy_sha256'])]:
 if Path(path).exists():assert sha(Path(path).read_bytes())==digest,path
subprocess.run([sys.executable,str(H/'verify-private.py')],cwd=ROOT,check=True)
private=json.loads((H/'private-verification.json').read_text(encoding='utf8'));assert private['source']==SOURCE and private['total_checks']==204788 and private['failed']==0
assert 'ownerFactory' not in (ROOT/'roblox_port/src/Server/Persistence.server.luau').read_text(encoding='utf8')
result=dict(source=SOURCE,windows_suites=77,windows_passed=468936,windows_failed=0,windows_output_sha256=sha((H/'windows-full.txt').read_bytes()),
 linux_run=ci['id'],linux_suites=77,linux_passed=468936,linux_failed=0,compile=223,strict_clean=True,runner_regressions=5,
 immutable_windows_snapshot_verified=True,native_actual_client_scripted_fixture_verified=True,native_actual_client_checks=82,
 native_server_template_checks=27,native_total_checks=109,native_verified_script_fingerprints=225,native_creator_errors=0,
 native_authored_callback_recapture_verified=True,native_full_recovery_verified=False,private_checks=204788,private_candidates=40,
 owner_factory_default_not_installed_in_engine=True,ordinary_engine_recovery_installed=False,real_service_rejoin_verified=False,
 whole_game_verified=False,published=False,goal_complete=False)
(H/'full-verification.json').write_text(json.dumps(result,indent=2)+'\n',encoding='utf8',newline='\n');print(json.dumps(result,indent=2))
