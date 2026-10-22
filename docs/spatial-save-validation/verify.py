"""Bind current source to full Windows/Linux, strict/compile and native refusal gates."""
from pathlib import Path
import hashlib,io,json,re,subprocess,tarfile
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[1]
sha=lambda b:hashlib.sha256(b).hexdigest()
for name in ['windows-full-process.json','ci-final.json','native-receipt.json','native-close.json']:
 assert (HERE/name).exists(),'Current spatial validation gate remains pending: '+name
source=subprocess.check_output(['git','log','-1','--format=%H','--','roblox_port/src','roblox_port/tests'],cwd=ROOT,text=True).strip()
raw=subprocess.check_output(['git','archive','--format=tar',source,'roblox_port/src','roblox_port/tests','.github/workflows/roblox-port.yml'],cwd=ROOT)
with tarfile.open(fileobj=io.BytesIO(raw)) as archive:files={m.name:archive.extractfile(m).read() for m in archive if m.isfile()}
for name,data in files.items():assert (ROOT/name).read_bytes()==data,name
windows=json.loads((HERE/'windows-full-process.json').read_text(encoding='utf8'))
assert windows['source']==source and windows['exit_code']==0
for name,digest in windows['inputs'].items():assert sha(files[name])==digest,name
text=(HERE/'windows-full.txt').read_text(encoding='utf8')
rows=re.findall(r'^([A-Z_0-9 ]+) passed=(\d+) failed=(\d+)',text,re.M)
assert len(rows)==76 and sum(int(r[1]) for r in rows)==465412 and all(int(r[2])==0 for r in rows)
assert ('CHECKPOINT','594','0') in rows and ('JSON_ENCODING','20716','0') in rows and '[SELFTEST] FAIL' not in text
ci=json.loads((HERE/'ci-final.json').read_text(encoding='utf8'))
assert ci['head_sha']==source and ci['conclusion']=='success' and ci['status']=='completed'
assert ci['suites']==76 and ci['passed']==465412 and ci['failed']==0 and ci['modules_compiled']==222 and ci['runner_regressions']==5
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
assert native['source']==manifest['source']==source and native['assertions']==20 and native['scripts']==223
assert native['creator_errors']==0 and native['persistence_disabled'] and manifest['persistence_disabled']
text=(HERE/'native-output.txt').read_text(encoding='utf8');assert sha(text.encode())==native['output_sha256']
assert '[NATIVE_SPATIAL_GUARD] '+source+' 223 persistence_disabled' in text
assert '[NATIVE_SPATIAL_PASS] '+native['run']+' 20' in text and '[NATIVE_SPATIAL_FAIL]' not in text
for case in ['nan','positive_inf','negative_inf','plain_xyz','empty_table']:
 assert '[NATIVE_SPATIAL_CASE] '+native['run']+' '+case+' refused_unchanged' in text
prefix={'First':'ReplicatedFirst','Shared':'ReplicatedStorage.Shared','Server':'ServerScriptService.Server','Client':'StarterPlayer.StarterPlayerScripts.Client'}
expected={}
for name,data in files.items():
 if not name.startswith('roblox_port/src/'):continue
 parts=list(Path(name).parts[2:]);stem=parts[-1][:-5]
 for suffix in ['.client','.server']:
  if stem.endswith(suffix):stem=stem[:-len(suffix)]
 expected['.'.join([prefix[parts[0]],*parts[1:-1],stem])]=sha(data.replace(b'\r\n',b'\n'))
expected['StarterPlayer.StarterPlayerScripts.Client.SilkPlayback']=sha((HERE/'native-probe.luau').read_bytes())
assert len(expected)==223 and {r['path']:r['sha256'] for r in manifest['scripts']}==expected
closed=json.loads((HERE/'native-close.json').read_text(encoding='utf8'))
assert closed['playback_stopped'] and closed['place_closed'] and closed['diagnostic_window_closed']
assert closed['original_restored_sha256']==native['place_sha256']==manifest['place_sha256']
receipt=dict(source=source,current_workspace_inputs_verified=True,windows_suites=76,windows_passed=465412,
 linux_suites=76,linux_passed=465412,failed=0,modules_compiled=222,strict_clean=True,runner_regressions=5,
 native_assertions=20,native_scripts=223,all_spatial_fields_audited=False,legacy_world_migration_implemented=False,
 whole_game_fps_gain_proven=False,goal_complete=False,published=False)
(HERE/'verification.json').write_text(json.dumps(receipt,indent=2)+'\n',encoding='utf8',newline='\n');print(json.dumps(receipt,indent=2))
