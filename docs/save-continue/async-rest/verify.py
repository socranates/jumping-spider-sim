from pathlib import Path
import hashlib,io,json,re,subprocess,tarfile
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[2]
sha=lambda b:hashlib.sha256(b).hexdigest()
source=subprocess.check_output(['git','log','-1','--format=%H','--','roblox_port/src','roblox_port/tests'],cwd=ROOT,text=True).strip()
raw=subprocess.check_output(['git','archive','--format=tar',source,'roblox_port/src','roblox_port/tests'],cwd=ROOT)
with tarfile.open(fileobj=io.BytesIO(raw)) as archive:files={m.name:archive.extractfile(m).read() for m in archive if m.isfile()}
meta=json.loads((HERE/'target-process.json').read_text(encoding='utf8'))
assert meta['exit_code']==1 # Retained original title fixture failure; corrected below.
originalTitle=subprocess.check_output(['git','show','133aa60342d03b534f9dbbf5f6399244714b9fc7:roblox_port/tests/title.luau'],cwd=ROOT)
assert sha(originalTitle)==meta['inputs']['roblox_port/tests/title.luau']
for name,digest in meta['inputs'].items():
 if name!='roblox_port/tests/title.luau': assert sha(files[name])==digest and sha((ROOT/name).read_bytes())==digest,name
rows=re.findall(r'^([A-Z_0-9 ]+) passed=(\d+) failed=(\d+)',(HERE/'target.txt').read_text(encoding='utf8'),re.M)
assert len(rows)==23 and sum(int(r[1]) for r in rows)==25186 and sum(int(r[2]) for r in rows)==1,rows
assert [(r[0].strip(),int(r[2])) for r in rows if int(r[2])]!=[]
assert [(r[0].strip(),int(r[2])) for r in rows if int(r[2])]==[('TITLE',1)]
fixed=json.loads((HERE/'title-fix/target-process.json').read_text(encoding='utf8'))
assert fixed['exit_code']==0 and fixed['suites']==['title.luau']
for name,digest in fixed['inputs'].items(): assert sha(files[name])==digest and sha((ROOT/name).read_bytes())==digest,name
fixedRows=re.findall(r'^([A-Z_0-9 ]+) passed=(\d+) failed=(\d+)',(HERE/'title-fix/target.txt').read_text(encoding='utf8'),re.M)
assert fixedRows==[('TITLE','21','0')],fixedRows
assert sum(int(r[1]) for r in rows if r[0].strip()!='TITLE')+21==25187
compiled=json.loads((HERE/'release-check/compile.json').read_text(encoding='utf8'))
assert compiled['total']==compiled['passed']==222
assert len(compiled['files'])==len([name for name in files if name.startswith('roblox_port/src/')])
for r in compiled['files']:assert r['exit_code']==0 and sha(files[r['path']])==r['sha256']
for name in ['strict','runner','sourcemap']:assert json.loads((HERE/'release-check'/(name+'-process.json')).read_text(encoding='utf8'))['exit_code']==0
assert not re.search(r'TypeError|SyntaxError|Error:',(HERE/'release-check/strict.txt').read_text(encoding='utf8'))
assert 'Ran 5 tests' in (HERE/'release-check/runner.txt').read_text(encoding='utf8')
native=json.loads((HERE/'native-receipt.json').read_text(encoding='utf8'))
manifest=json.loads((HERE/'manifest.json').read_text(encoding='utf8'))
runtimeSource=subprocess.check_output(['git','log','-1','--format=%H','--','roblox_port/src'],cwd=ROOT,text=True).strip()
assert native['source']==manifest['source']==runtimeSource and native['assertions']==15 and native['creator_errors']==0
assert native['persistence_disabled'] and not native['online_save_accessed']
assert sha((HERE/'native-output.txt').read_bytes())==native['output_sha256']
assert sha((HERE/'native-probe.luau').read_bytes())==native['probe_sha256']
nativeText=(HERE/'native-output.txt').read_text(encoding='utf8')
assert '[NATIVE_ASYNC_REST_FAIL]' not in nativeText
assert re.search(r'\[NATIVE_ASYNC_REST_PASS\]\s+1792699532277\s+15\s*$',nativeText,re.M)
assert f'[NATIVE_ASYNC_REST_GUARD] {runtimeSource} 223 persistence_disabled' in nativeText
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
receipt=dict(source=source,runtime_source=runtimeSource,original_title_fixture_failure_retained=True,title_fixture_corrected_and_retested=True,modules_compiled=222,targeted_suites=23,targeted_passed=25187,failed=0,strict_clean=True,runner_regressions=5,inputs_verified=True,continue_worker_enabled=True,all_save_stalls_resolved=False,native_current_worker_verified=True,owned_offer_worker_enabled=True,local_rest_worker_enabled=True,native_assertions=15,hard_frame_budget_proven=False,release_artifact_rebuilt=False,published=False)
(HERE/'receipt.json').write_text(json.dumps(receipt,indent=2)+'\n',encoding='utf8',newline='\n')
print(json.dumps(receipt,indent=2))
