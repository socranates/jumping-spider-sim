from pathlib import Path
import hashlib,io,json,re,subprocess,tarfile
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[2]
sha=lambda b:hashlib.sha256(b).hexdigest()
source='4ee6aecc06f4753a85e40fc98a1487dc5126d27d' # Historical immutable evidence
raw=subprocess.check_output(['git','archive','--format=tar',source,'roblox_port/src','roblox_port/tests'],cwd=ROOT)
with tarfile.open(fileobj=io.BytesIO(raw)) as archive:files={m.name:archive.extractfile(m).read() for m in archive if m.isfile()}
meta=json.loads((HERE/'target-process.json').read_text(encoding='utf8'))
assert meta['exit_code']==1 # Retained original world replay fixture failure; corrected below.
originalWorld=subprocess.check_output(['git','show','6970459:roblox_port/tests/world_client.luau'],cwd=ROOT)
assert sha(originalWorld)==meta['inputs']['roblox_port/tests/world_client.luau']
for name,digest in meta['inputs'].items():
 if name!='roblox_port/tests/world_client.luau': assert sha(files[name])==digest,name
rows=re.findall(r'^([A-Z_0-9 ]+) passed=(\d+) failed=(\d+)',(HERE/'target.txt').read_text(encoding='utf8'),re.M)
assert len(rows)==27 and sum(int(r[1]) for r in rows)==25293 and sum(int(r[2]) for r in rows)==1,rows
assert [(r[0].strip(),int(r[2])) for r in rows if int(r[2])]==[('WORLD_CLIENT',1)]
fixed=json.loads((HERE/'world-fix/target-process.json').read_text(encoding='utf8'))
assert fixed['exit_code']==0 and fixed['suites']==['world_client.luau']
for name,digest in fixed['inputs'].items(): assert sha(files[name])==digest,name
fixedRows=re.findall(r'^([A-Z_0-9 ]+) passed=(\d+) failed=(\d+)',(HERE/'world-fix/target.txt').read_text(encoding='utf8'),re.M)
assert fixedRows==[('WORLD_CLIENT','33','0')],fixedRows
assert sum(int(r[1]) for r in rows if r[0].strip()!='WORLD_CLIENT')+33==25294
compiled=json.loads((HERE/'final-check/compile.json').read_text(encoding='utf8'))
assert compiled['total']==compiled['passed']==222
assert len(compiled['files'])==len([name for name in files if name.startswith('roblox_port/src/')])
for r in compiled['files']:assert r['exit_code']==0 and sha(files[r['path']])==r['sha256']
for name in ['strict','runner','sourcemap']:assert json.loads((HERE/'final-check'/(name+'-process.json')).read_text(encoding='utf8'))['exit_code']==0
assert not re.search(r'TypeError|SyntaxError|Error:',(HERE/'final-check/strict.txt').read_text(encoding='utf8'))
assert 'Ran 5 tests' in (HERE/'final-check/runner.txt').read_text(encoding='utf8')
native=json.loads((HERE/'native-receipt.json').read_text(encoding='utf8'))
manifest=json.loads((HERE/'manifest.json').read_text(encoding='utf8'))
runtimeSource='07234cae75b5a62b820dc6dda830dce7e503c36b' # Native historical source
assert native['source']==manifest['source']==runtimeSource and native['assertions']==22 and native['creator_errors']==0
assert native['persistence_disabled'] and not native['online_save_accessed']
assert sha((HERE/'native-output.txt').read_bytes())==native['output_sha256']
assert sha((HERE/'native-probe.luau').read_bytes())==native['probe_sha256']
nativeText=(HERE/'native-output.txt').read_text(encoding='utf8')
assert '[NATIVE_LOCAL_RETURN_FAIL]' not in nativeText
assert re.search(r'\[NATIVE_LOCAL_RETURN_PASS\]\s+1792701458910\s+22\s*$',nativeText,re.M)
assert f'[NATIVE_LOCAL_RETURN_GUARD] {runtimeSource} 223 persistence_disabled' in nativeText
prefix={'First':'ReplicatedFirst','Shared':'ReplicatedStorage.Shared','Server':'ServerScriptService.Server','Client':'StarterPlayer.StarterPlayerScripts.Client'}
expected={}
for name in meta['inputs']:
 if not name.startswith('roblox_port/src/'):continue
 parts=list(Path(name).parts[2:]);stem=parts[-1][:-5]
 for suffix in ['.client','.server']:
  if stem.endswith(suffix):stem=stem[:-len(suffix)]
 expected['.'.join([prefix[parts[0]],*parts[1:-1],stem])]=sha(files[name].replace(b'\r\n',b'\n'))
assert len(expected)==222
assert {r['path']:r['sha256'] for r in manifest['scripts'] if not r['path'].endswith('.SilkPlayback')}==expected
closed=json.loads((HERE/'close.json').read_text(encoding='utf8'))
assert closed['playback_stopped'] and closed['place_closed'] and closed['studio_closed']
assert closed['original_restored_sha256']==manifest['place_sha256']==native['place_sha256']
receipt=dict(source=source,runtime_source=runtimeSource,original_world_fixture_failure_retained=True,world_fixture_corrected_and_retested=True,modules_compiled=222,targeted_suites=27,targeted_passed=25294,failed=0,strict_clean=True,runner_regressions=5,inputs_verified=True,continue_worker_enabled=True,all_save_stalls_resolved=False,native_current_worker_verified=True,owned_offer_worker_enabled=True,local_rest_worker_enabled=True,local_return_worker_enabled=True,native_assertions=22,hard_frame_budget_proven=False,release_artifact_rebuilt=False,published=False)
(HERE/'receipt.json').write_text(json.dumps(receipt,indent=2)+'\n',encoding='utf8',newline='\n')
print(json.dumps(receipt,indent=2))
