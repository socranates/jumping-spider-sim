"""Bind the corrected snapshot test, full gates and unchanged renderer evidence."""
from pathlib import Path
import hashlib,io,json,re,subprocess,tarfile
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[1];TRIAL=HERE.parent/'animal-presentation-cost'
sha=lambda b:hashlib.sha256(b).hexdigest()
for name in ['windows-full-process.json','ci-final.json']:
 assert (HERE/name).exists(),'Current pond adoption full gate pending: '+name
source=subprocess.check_output(['git','log','-1','--format=%H','--','roblox_port/src','roblox_port/tests'],cwd=ROOT,text=True).strip()
raw=subprocess.check_output(['git','archive','--format=tar',source,'roblox_port/src','roblox_port/tests','.github/workflows/roblox-port.yml'],cwd=ROOT)
with tarfile.open(fileobj=io.BytesIO(raw)) as archive:files={m.name:archive.extractfile(m).read() for m in archive if m.isfile()}
for name,data in files.items():assert (ROOT/name).read_bytes()==data,name
m=json.loads((TRIAL/'pond-candidate-v2.json').read_text())
assert sha(files[m['path']])==m['candidate_sha256']
assert sha(files['roblox_port/tests/studio/LegacyPondBodies.luau'])==m['reference_sha256']
changed=subprocess.check_output(['git','diff','--name-only',m['source'],source,'--','roblox_port/src'],cwd=ROOT,text=True).splitlines()
assert changed==[m['path']],changed
windows=json.loads((HERE/'windows-full-process.json').read_text())
assert windows['source']==source and windows['exit_code']==0
for name,digest in windows['inputs'].items():assert sha(files[name])==digest,name
text=(HERE/'windows-full.txt').read_text();rows=re.findall(r'^([A-Z_0-9 ]+) passed=(\d+) failed=(\d+)',text,re.M)
assert len(rows)==76 and sum(int(r[1]) for r in rows)==468114 and all(int(r[2])==0 for r in rows)
assert ('BODIES','3610','0') in rows and '[SELFTEST] FAIL' not in text
ci=json.loads((HERE/'ci-final.json').read_text())
assert ci['head_sha']==source and ci['conclusion']=='success' and ci['status']=='completed'
assert ci['suites']==76 and ci['passed']==468114 and ci['failed']==0 and ci['modules_compiled']==222 and ci['runner_regressions']==5
for job in ci['jobs_evidence']['jobs']:
 assert job['status']=='completed' and job['conclusion']=='success'
 for step in job['steps']:assert step['status']=='completed' and step['conclusion']=='success'
for name,digest in ci['logs_sha256'].items():assert sha((HERE/name).read_bytes())==digest,name
assert sha(files['.github/workflows/roblox-port.yml'])==ci['workflow_sha256']
compiled=json.loads((HERE.parent/'pond-drawing-reuse/final-check/compile.json').read_text());assert compiled['total']==compiled['passed']==222
for row in compiled['files']:assert row['exit_code']==0 and sha(files[row['path']])==row['sha256']
for name in ['sourcemap','strict','runner']:assert json.loads((HERE.parent/'pond-drawing-reuse/final-check'/(name+'-process.json')).read_text())['exit_code']==0
prefix={'First':'ReplicatedFirst','Shared':'ReplicatedStorage.Shared','Server':'ServerScriptService.Server','Client':'StarterPlayer.StarterPlayerScripts.Client'}
expected={}
for name,data in files.items():
 if not name.startswith('roblox_port/src/'):continue
 parts=list(Path(name).parts[2:]);stem=parts[-1][:-5]
 for suffix in ['.client','.server']:
  if stem.endswith(suffix):stem=stem[:-len(suffix)]
 expected['.'.join([prefix[parts[0]],*parts[1:-1],stem])]=sha(data.replace(b'\r\n',b'\n'))
body='StarterPlayer.StarterPlayerScripts.Client.PondBodies'
expected[body]=m['reference_sha256']
expected['StarterPlayer.StarterPlayerScripts.Client.PondCandidate']=m['candidate_sha256']
for kind,count in [('native',985),('batch',41)]:
 manifest=json.loads((TRIAL/('prepared-pond-v2'+('-batch' if kind=='batch' else '')+'-manifest.json')).read_text())
 native=json.loads((TRIAL/f'pond-v2-{kind}-receipt.json').read_text());closed=json.loads((TRIAL/f'pond-v2-{kind}-close.json').read_text())
 expected['StarterPlayer.StarterPlayerScripts.Client.SilkPlayback']=sha((TRIAL/f'pond-v2-{kind}-probe.luau').read_bytes())
 assert {r['path']:r['sha256'] for r in manifest['scripts']}==expected
 assert native['source']==manifest['source']==m['source'] and native['assertions']==count and native['creator_errors']==0
 assert native['scripts']==224 and native['persistence_disabled'] and manifest['persistence_disabled']
 assert sha((TRIAL/f'pond-v2-{kind}-output.txt').read_bytes())==native['output_sha256']
 assert closed['playback_stopped'] and closed['place_closed'] and closed['diagnostic_window_closed']
 assert closed['original_restored_sha256']==manifest['place_sha256']==native['place_sha256']
 if kind=='batch':assert native['adoption_criteria_met']
r=dict(source=source,current_workspace_inputs_verified=True,windows_suites=76,windows_passed=468114,linux_suites=76,linux_passed=468114,failed=0,modules_compiled=222,strict_clean=True,runner_regressions=5,native_geometry_assertions=985,native_batch_assertions=41,native_scope='private component comparison, exact adopted body bytes; all other production sources unchanged',whole_game_fps_gain_proven=False,legacy_world_migration_implemented=False,goal_complete=False,published=False)
(HERE/'verification.json').write_text(json.dumps(r,indent=2)+'\n',encoding='utf8',newline='\n');print(json.dumps(r,indent=2))
