"""Require exact-current source and both full CLI gates after encoder adoption."""
from pathlib import Path
import hashlib,io,json,re,runpy,subprocess,tarfile
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[2]
sha=lambda b:hashlib.sha256(b).hexdigest()
assert (HERE/'windows-full-process.json').exists(),'Current encoder full Windows gate remains pending'
assert (HERE/'ci-final.json').exists(),'Current encoder full Linux gate remains pending'
assert (HERE/'game-native-receipt.json').exists(),'Current adopted-game save/return probe remains pending'
runpy.run_path(str(HERE/'verify-prototype.py'))
runpy.run_path(str(HERE.parent/'save-cost/verify.py'))
source=subprocess.check_output(['git','log','-1','--format=%H','--','roblox_port/src','roblox_port/tests'],cwd=ROOT,text=True).strip()
raw=subprocess.check_output(['git','archive','--format=tar',source,'roblox_port/src','roblox_port/tests','.github/workflows/roblox-port.yml'],cwd=ROOT)
with tarfile.open(fileobj=io.BytesIO(raw)) as archive:files={m.name:archive.extractfile(m).read() for m in archive if m.isfile()}
for name,data in files.items():assert (ROOT/name).read_bytes()==data,name
windows=json.loads((HERE/'windows-full-process.json').read_text(encoding='utf8'))
assert windows['source']==source and windows['exit_code']==0
for name,digest in windows['inputs'].items():assert sha(files[name])==digest,name
win_text=(HERE/'windows-full.txt').read_text(encoding='utf8')
rows=re.findall(r'^([A-Z_0-9 ]+) passed=(\d+) failed=(\d+)',win_text,re.M)
assert len(rows)==76 and sum(int(r[1]) for r in rows)==465380 and all(int(r[2])==0 for r in rows)
assert ('JSON_ENCODING','20716','0') in rows and '[SELFTEST] FAIL' not in win_text
ci=json.loads((HERE/'ci-final.json').read_text(encoding='utf8'))
assert ci['head_sha']==source and ci['conclusion']=='success' and ci['status']=='completed'
assert ci['suites']==76 and ci['passed']==465380 and ci['failed']==0 and ci['modules_compiled']==222 and ci['runner_regressions']==5
for name,digest in ci['logs_sha256'].items():assert sha((HERE/name).read_bytes())==digest,name
assert sha(files['.github/workflows/roblox-port.yml'])==ci['workflow_sha256']
for job in ci['jobs_evidence']['jobs']:
 assert job['status']=='completed' and job['conclusion']=='success'
 for step in job['steps']:assert step['status']=='completed' and step['conclusion']=='success'
compiled=json.loads((HERE/'final-check/compile.json').read_text(encoding='utf8'))
assert compiled['total']==compiled['passed']==222
for row in compiled['files']:assert row['exit_code']==0 and sha(files[row['path']])==row['sha256']
for name in ['sourcemap','strict','runner']:assert json.loads((HERE/'final-check'/(name+'-process.json')).read_text(encoding='utf8'))['exit_code']==0
game=json.loads((HERE/'game-native-receipt.json').read_text(encoding='utf8'))
manifest=json.loads((HERE/'game-prepared-manifest.json').read_text(encoding='utf8'))
assert game['source']==manifest['source']==source and game['scripts']==225 and game['assertions']==32
assert game['save_assertions']==10 and game['return_assertions']==22 and game['creator_errors']==0
assert game['persistence_disabled'] and not game['online_store_accessed']
assert sha((HERE/'game-native-output.txt').read_bytes())==game['output_sha256']
game_text=(HERE/'game-native-output.txt').read_text(encoding='utf8')
assert '[NATIVE_ENCODER_GAME_GUARD] '+source+' 225 persistence_disabled' in game_text
assert '[NATIVE_SAVE_COST_PASS] '+game['save_run']+' 10 ' in game_text
assert '[NATIVE_LOCAL_RETURN_PASS] '+game['return_run']+' 22' in game_text
assert '[NATIVE_ENCODER_GAME_END] '+game['sequence'] in game_text
assert not re.search(r'\[NATIVE_(?:SAVE_COST|LOCAL_RETURN)_FAIL\]',game_text)
prefix={'First':'ReplicatedFirst','Shared':'ReplicatedStorage.Shared','Server':'ServerScriptService.Server','Client':'StarterPlayer.StarterPlayerScripts.Client'}
expected={}
for name,data in files.items():
 if not name.startswith('roblox_port/src/'):continue
 parts=list(Path(name).parts[2:]);stem=parts[-1][:-5]
 for suffix in ['.client','.server']:
  if stem.endswith(suffix):stem=stem[:-len(suffix)]
 expected['.'.join([prefix[parts[0]],*parts[1:-1],stem])]=sha(data.replace(b'\r\n',b'\n'))
for name,path in [('SilkPlayback',HERE/'game-probe.luau'),('SaveCostMeasurement',HERE.parent/'save-cost/native-probe.luau'),('LocalReturnMeasurement',HERE.parent/'local-return/native-probe.luau')]:
 expected['StarterPlayer.StarterPlayerScripts.Client.'+name]=sha(path.read_bytes().replace(b'\r\n',b'\n'))
assert len(expected)==225 and {r['path']:r['sha256'] for r in manifest['scripts']}==expected
closed=json.loads((HERE/'game-native-close.json').read_text(encoding='utf8'))
assert closed['playback_stopped'] and closed['place_closed'] and closed['diagnostic_window_closed']
assert closed['original_restored_sha256']==game['place_sha256']==manifest['place_sha256']
for name in ['first','replacement']:
 capture=re.search(r'\[NATIVE_SAVE_COST_CAPTURE\] '+game['save_run']+' '+name+r' ([\d.]+)',game_text)
 work=re.search(r'\[NATIVE_SAVE_COST_WORK\] '+game['save_run']+' '+name+r' (\d+) ([\d.]+) ([\d.]+) ([\d.]+) ([\d.]+)',game_text)
 record=re.search(r'\[NATIVE_SAVE_COST_RECORD\] '+game['save_run']+' '+name+r' (\d+) (\d+)',game_text)
 assert capture and work and record
 m=game['save_'+name];assert m['capture_ms']==float(capture[1]) and m['steps']==int(work[1])
 for value,key in zip(work.groups()[1:],['cpu_ms','max_update_ms','max_heartbeat_gap_ms','elapsed_ms']):assert float(value)==m[key]
 assert int(record[1])==m['chars'] and int(record[2])==m['initialization_attempts']==233
for name in ['local_continue','end_screen_return']:
 work=re.search(r'\[NATIVE_LOCAL_RETURN_WORK\] '+game['return_run']+' '+name+r' (\d+) ([\d.]+) ([\d.]+) ([\d.]+) ([\d.]+)',game_text)
 assert work and game[name]['steps']==int(work[1])
 for value,key in zip(work.groups()[1:],['max_update_ms','max_heartbeat_gap_ms','cpu_ms','elapsed_ms']):assert float(value)==game[name][key]
sync=re.search(r'\[NATIVE_LOCAL_RETURN_SYNC\] '+game['return_run']+r' choose ([\d.]+) (\d+)',game_text)
assert sync and float(sync[1])==game['continue_choice_ms'] and int(sync[2])==game['continue_synchronous_encodes']==0
receipt=dict(source=source,current_workspace_inputs_verified=True,windows_suites=76,windows_passed=465380,linux_suites=76,linux_passed=465380,
 failed=0,modules_compiled=222,strict_clean=True,runner_regressions=5,adopted_algorithm_native_paired_assertions=20738,
 native_paired_reference_source='ab8ca9577129e3d9583a0a8ab6824dae1a8cd014',
 native_adopted_game_save_return_verified=True,native_game_assertions=32,native_game_scripts=225,
 current_adopted_game_native_lifecycle_verified=False,whole_game_fps_gain_proven=False,hard_frame_budget_proven=False,
 goal_complete=False,release_rebuilt=False,published=False)
(HERE/'verification.json').write_text(json.dumps(receipt,indent=2)+'\n',encoding='utf8',newline='\n')
print(json.dumps(receipt,indent=2))
