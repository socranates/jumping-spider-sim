"""Require exact-current source and both full CLI gates after encoder adoption."""
from pathlib import Path
import hashlib,io,json,re,runpy,subprocess,tarfile
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[1]
sha=lambda b:hashlib.sha256(b).hexdigest()
assert (HERE/'windows-full-process.json').exists(),'Current streaming-readiness full Windows gate remains pending'
assert (HERE/'ci-final.json').exists(),'Current streaming-readiness full Linux gate remains pending'
assert (HERE/'native-receipt.json').exists(),'Current readiness engine probe remains pending'
runpy.run_path(str(ROOT/'docs/save-continue/json-encoding/verify-prototype.py'))
# Historical full-game and save/return runs retain their original source; they are not current-game evidence.
source='032926fd6e02c68c3f257189d397cbdf2a116bba'
raw=subprocess.check_output(['git','archive','--format=tar',source,'roblox_port/src','roblox_port/tests','.github/workflows/roblox-port.yml'],cwd=ROOT)
with tarfile.open(fileobj=io.BytesIO(raw)) as archive:files={m.name:archive.extractfile(m).read() for m in archive if m.isfile()}
workspace_matches=all((ROOT/name).read_bytes()==data for name,data in files.items())
windows=json.loads((HERE/'windows-full-process.json').read_text(encoding='utf8'))
assert windows['source']==source and windows['exit_code']==0
for name,digest in windows['inputs'].items():assert sha(files[name])==digest,name
win_text=(HERE/'windows-full.txt').read_text(encoding='utf8')
rows=re.findall(r'^([A-Z_0-9 ]+) passed=(\d+) failed=(\d+)',win_text,re.M)
assert len(rows)==76 and sum(int(r[1]) for r in rows)==465388 and all(int(r[2])==0 for r in rows)
assert ('JSON_ENCODING','20716','0') in rows and '[SELFTEST] FAIL' not in win_text
ci=json.loads((HERE/'ci-final.json').read_text(encoding='utf8'))
assert ci['head_sha']==source and ci['conclusion']=='success' and ci['status']=='completed'
assert ci['suites']==76 and ci['passed']==465388 and ci['failed']==0 and ci['modules_compiled']==222 and ci['runner_regressions']==5
for name,digest in ci['logs_sha256'].items():assert sha((HERE/name).read_bytes())==digest,name
assert sha(files['.github/workflows/roblox-port.yml'])==ci['workflow_sha256']
for job in ci['jobs_evidence']['jobs']:
 assert job['status']=='completed' and job['conclusion']=='success'
 for step in job['steps']:assert step['status']=='completed' and step['conclusion']=='success'
compiled=json.loads((HERE/'final-check/compile.json').read_text(encoding='utf8'))
assert compiled['total']==compiled['passed']==222
for row in compiled['files']:assert row['exit_code']==0 and sha(files[row['path']])==row['sha256']
for name in ['sourcemap','strict','runner']:assert json.loads((HERE/'final-check'/(name+'-process.json')).read_text(encoding='utf8'))['exit_code']==0
manifest=json.loads((HERE/'prepared-native-manifest.json').read_text(encoding='utf8'))
native=json.loads((HERE/'native-receipt.json').read_text(encoding='utf8'))
assert native['source']==manifest['source']==source and native['assertions']==22 and native['scripts']==225
assert native['creator_errors']==0 and native['persistence_disabled'] and manifest['persistence_disabled']
text=(HERE/'native-output.txt').read_text(encoding='utf8');assert sha(text.encode())==native['output_sha256']
assert '[NATIVE_PREY_READY_GUARD] '+source+' 225 persistence_disabled' in text
assert '[NATIVE_READINESS_PASS] '+native['creature_run']+' 11' in text
assert '[NATIVE_PREY_READY_PASS] '+native['prey_run']+' 11' in text
assert '[NATIVE_READY_SEQUENCE_END] '+native['sequence'] in text
assert '[NATIVE_READINESS_FAIL]' not in text and '[NATIVE_PREY_READY_FAIL]' not in text
prefix={'First':'ReplicatedFirst','Shared':'ReplicatedStorage.Shared','Server':'ServerScriptService.Server','Client':'StarterPlayer.StarterPlayerScripts.Client'}
expected={}
for name,data in files.items():
 if not name.startswith('roblox_port/src/'):continue
 parts=list(Path(name).parts[2:]);stem=parts[-1][:-5]
 for suffix in ['.client','.server']:
  if stem.endswith(suffix):stem=stem[:-len(suffix)]
 expected['.'.join([prefix[parts[0]],*parts[1:-1],stem])]=sha(data.replace(b'\r\n',b'\n'))
for name,path in [('SilkPlayback',HERE/'sequence.luau'),('CreatureReadinessMeasurement',HERE.parent/'stream-readiness/native-probe.luau'),('PreyReadinessMeasurement',HERE/'native-probe.luau')]:
 expected['StarterPlayer.StarterPlayerScripts.Client.'+name]=sha(path.read_bytes())
assert len(expected)==225 and {r['path']:r['sha256'] for r in manifest['scripts']}==expected
closed=json.loads((HERE/'native-close.json').read_text(encoding='utf8'))
assert closed['playback_stopped'] and closed['place_closed'] and closed['diagnostic_window_closed']
assert closed['original_restored_sha256']==native['place_sha256']==manifest['place_sha256']
receipt=dict(source=source,current_workspace_inputs_verified=workspace_matches,historical_snapshot_verified=True,windows_suites=76,windows_passed=465388,
 linux_suites=76,linux_passed=465388,failed=0,modules_compiled=222,strict_clean=True,runner_regressions=5,
 native_assertions=22,native_scripts=225,natural_network_stream_out_verified=False,
 current_full_native_walkthrough_verified=False,whole_game_fps_gain_proven=False,goal_complete=False,published=False)
(HERE/'verification.json').write_text(json.dumps(receipt,indent=2)+'\n',encoding='utf8',newline='\n');print(json.dumps(receipt,indent=2))
