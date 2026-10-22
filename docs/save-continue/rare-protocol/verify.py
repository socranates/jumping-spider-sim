from pathlib import Path
import hashlib,io,json,re,subprocess,tarfile
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[2]
SOURCE=subprocess.check_output(['git','log','-1','--format=%H','--','roblox_port/src','roblox_port/tests'],cwd=ROOT,text=True).strip()
BASE='47241c994c7b2fbd4eb3fed0c4affd75ece88c10'
sha=lambda b:hashlib.sha256(b).hexdigest()
def archive(commit):
 raw=subprocess.check_output(['git','archive','--format=tar',commit,'roblox_port/src','roblox_port/tests'],cwd=ROOT)
 with tarfile.open(fileobj=io.BytesIO(raw)) as t:return {m.name:t.extractfile(m).read() for m in t if m.isfile()}
base,cur=archive(BASE),archive(SOURCE)
src={p:b for p,b in cur.items() if p.startswith('roblox_port/src/')};assert len(src)==220
assert src=={p:b for p,b in base.items() if p.startswith('roblox_port/src/')}
changed=[p for p in set(base)|set(cur) if base.get(p)!=cur.get(p)];assert changed==['roblox_port/tests/rare_sightings.luau']
assert b'v=3,epoch="rare-progress-fixture",sequence=1' in cur[changed[0]]
meta=json.loads((HERE/'target-process.json').read_text());assert meta['exit_code']==0
for p,digest in meta['inputs'].items():assert sha(cur[p])==digest and sha((ROOT/p).read_bytes())==digest,p
rows=re.findall(r'^([A-Z_0-9 ]+) passed=(\d+) failed=(\d+)',(HERE/'target.txt').read_text(),re.M)
assert rows==[('RARE','265','0'),('CONTINUATION_MENU','32','0'),('SAVE_CONTINUATION','125','0'),('SAVE_INTENT','57','0'),('SAVE_OBSERVATION','50','0'),('STATE','1013','0'),('STATE_CLIENT','161','0'),('STATE_OFFLINE','8','0'),('REST_STORAGE','14','0'),('REST_COMPRESSION','57','0'),('SAVE_NOTICE','53','0'),('TITLE','21','0')]
prior=HERE.parent/'cost-reduction'
compiled=json.loads((prior/'compile.json').read_text());assert compiled['total']==compiled['passed']==220
assert {r['path'] for r in compiled['files']}==set(src)
for r in compiled['files']:assert r['exit_code']==0 and r['sha256']==sha(src[r['path']])
for name in ['strict','runner','sourcemap']:assert json.loads((prior/(name+'-process.json')).read_text())['exit_code']==0
assert not re.search(r'TypeError|SyntaxError|Error:',(prior/'strict.txt').read_text())
assert 'Ran 5 tests' in (prior/'runner.txt').read_text()
assert base['roblox_port/tests/run.py']==cur['roblox_port/tests/run.py'] and base['roblox_port/tests/test_runner.py']==cur['roblox_port/tests/test_runner.py']
native=HERE.parent/'native-cost';manifest=json.loads((native/'manifest.json').read_text());n=json.loads((native/'native-receipt.json').read_text())
prefix={'First':'ReplicatedFirst','Shared':'ReplicatedStorage.Shared','Server':'ServerScriptService.Server','Client':'StarterPlayer.StarterPlayerScripts.Client'}
expected={}
for p,b in src.items():
 parts=list(Path(p).parts[2:]);stem=parts[-1][:-5]
 for suffix in ['.client','.server']:
  if stem.endswith(suffix):stem=stem[:-len(suffix)]
 expected['.'.join([prefix[parts[0]],*parts[1:-1],stem])]=sha(b.replace(b'\r\n',b'\n'))
actual={r['path']:r['sha256'] for r in manifest['scripts'] if not r['path'].endswith('.SilkPlayback')}
assert len(actual)==220 and actual==expected
assert n['source']==BASE and n['assertions']==13 and n['creator_errors']==0 and n['persistence_disabled']
assert sha((native/'native-output.txt').read_bytes())==n['output_sha256'] and sha((native/'native-probe.luau').read_bytes())==n['probe_sha256']
assert n['native_controller_local_transport_completed'] and not n['online_save_accessed'] and n['low_system_resources_warning_seen']
assert json.loads((native/'close.json').read_text())['original_restored_sha256']==manifest['place_sha256']==n['place_sha256']
r=dict(source=SOURCE,runtime_equivalent_to=BASE,production_modules=220,production_changes=[],test_only_changes=changed,targeted_suites=12,targeted_passed=1856,rare_passed=265,compile_passed=220,strict_clean=True,runner_regressions=5,native_controller_local_transport_assertions=13,native_runtime_matches_current=True,native_source_line_endings_normalized=True,native_region_initialization_attempts=n['region_initialization_attempts'],native_all_regions_materialized_verified=False,native_record_chars=n['record_canonical_chars'],first_offer_cost_resolved=False,full_current_gates_verified=False,native_full_feature_verified=False,online_rejoin_verified=False,remote_transfer_measured=False,physical_device_verified=False,release_artifact_rebuilt=False,published=False,publication_ready=False)
(HERE/'receipt.json').write_text(json.dumps(r,indent=2)+'\n',encoding='utf8',newline='\n');print(json.dumps(r,indent=2))
