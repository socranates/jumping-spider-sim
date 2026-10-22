from pathlib import Path
import hashlib,io,json,re,subprocess,tarfile,tempfile,shutil,runpy,contextlib,xml.etree.ElementTree as ET
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[1]
read=lambda n:json.loads((HERE/n).read_text(encoding='utf8'))
sha=lambda b:hashlib.sha256(b).hexdigest()
BASE='8e02b5ee5f443ab332cf7e70f5951a304cb89eea'
SOURCE=subprocess.check_output(['git','log','-1','--format=%H','--','roblox_port/src','roblox_port/tests'],cwd=ROOT,text=True).strip()
def archive(commit):
 b=subprocess.check_output(['git','archive','--format=tar',commit,'roblox_port/src'],cwd=ROOT)
 with tarfile.open(fileobj=io.BytesIO(b)) as tree:return {t.name:tree.extractfile(t).read() for t in tree if t.isfile()}
base,new=archive(BASE),archive(SOURCE);assert len(base)==216 and len(new)==217
changed={p for p in set(base)|set(new) if base.get(p)!=new.get(p)}
assert changed=={'roblox_port/src/Client/SpiderClient.client.luau','roblox_port/src/Shared/Predator/RivalDrive.luau','roblox_port/src/Shared/World/StationAir.luau','roblox_port/src/Shared/World/NavigationPreparation.luau'}
for p,b in new.items():assert (ROOT/p).read_bytes()==b,p
# Recompute the authored build ID rather than trusting a stale build log/stamp.
evidence_hash=hashlib.sha256()
paths=sorted([*(ROOT/'roblox_port').glob('src/**/*.luau'),*(ROOT/'roblox_port').glob('tests/**/*.luau'),*(ROOT/'roblox_port').glob('*.project.json')])
for p in paths:
 if p.name=='BuildInfo.luau':continue
 evidence_hash.update(p.relative_to(ROOT/'roblox_port').as_posix().encode()+b'\0'+p.read_bytes()+b'\0')
assert evidence_hash.hexdigest()[:16]=='ab5a28c0ff450435'
assert 'ab5a28c0ff450435' in (ROOT/'roblox_port/tests/studio/BuildInfo.luau').read_text(encoding='utf8')
old=read('baseline-process.json');target=read('target-process.json');assert old['exit_code']!=0 and target['exit_code']==0
for p,b in base.items():assert old['inputs'][p]==sha(b)
helper='roblox_port/src/Shared/World/NavigationPreparation.luau';assert old['test_only_added_module']==helper and old['inputs'][helper]==sha(new[helper])
assert 'NAVIGATION_STARTUP passed=10 failed=5' in (HERE/'baseline.txt').read_text(encoding='utf8')
for p,h in target['inputs'].items():assert sha((ROOT/p).read_bytes())==h,p
fixture='roblox_port/tests/navigation_startup.luau';assert old['inputs'][fixture]==target['inputs'][fixture]
rows=re.findall(r'^([A-Z_0-9 ]+) passed=(\d+) failed=(\d+)',(HERE/'target.txt').read_text(encoding='utf8'),re.M)
assert rows==[('NAVIGATION_STARTUP','15','0'),('OUTDOOR_RESET','45','0'),('MINIMAL','63','0'),('SAVE_NOTICE','53','0'),('CLIENT','27','0'),('TITLE','21','0'),('RARE','265','0')]
c=read('compile.json');assert c['total']==c['passed']==217
for r in c['files']:assert r['exit_code']==0 and r['sha256']==sha(new[r['path']])
for name in ['build','sourcemap','strict','runner']:assert read(name+'-process.json')['exit_code']==0
assert not re.search(r'TypeError|SyntaxError|Error:',(HERE/'strict.txt').read_text(encoding='utf8'))
assert 'Ran 5 tests' in (HERE/'runner.txt').read_text(encoding='utf8')
expected={}
for path,b in new.items():
 parts=list(Path(path).relative_to('roblox_port/src').parts);prefix={'First':'ReplicatedFirst','Client':'StarterPlayer.StarterPlayerScripts.Client','Server':'ServerScriptService.Server','Shared':'ReplicatedStorage.Shared'}[parts.pop(0)]
 parts[-1]=parts[-1].removesuffix('.luau').removesuffix('.client').removesuffix('.server');expected[prefix+'.'+'.'.join(parts)]=sha(b.replace(b'\r\n',b'\n'))
def release(path):
 found={}
 def walk(it,parent=''):
  name=it.findtext("./Properties/*[@name='Name']");full=parent+'.'+name if parent else name
  if it.attrib['class'] in {'Script','LocalScript','ModuleScript'}:
   assert full not in found;found[full]=sha(it.findtext("./Properties/*[@name='Source']").replace('\r\n','\n').encode())
  for c in it.findall('Item'):walk(c,full)
 for it in ET.parse(path).getroot().findall('Item'):walk(it)
 assert found==expected
 return sha(path.read_bytes())
h=release(ROOT/'roblox_port/TheWindowsill.rbxlx')
try:release(ROOT/'roblox_port/TheWindowsillTests.rbxlx')
except AssertionError:pass
else:raise AssertionError('test artifact accepted as production')
prepared=[]
native_modes=[]
for mode in ['success','failure']:
 path=HERE/('prepared-'+mode+'-manifest.json')
 if path.exists():
  m=json.loads(path.read_text(encoding='utf8'));assert archive(m['source'])==new and m['case']==mode and m['persistence_disabled']
  scripts={r['path']:r['sha256'] for r in m['scripts']};assert len(scripts)==len(m['scripts'])==218
  assert {p:scripts[p] for p in expected}==expected
  assert scripts['StarterPlayer.StarterPlayerScripts.Client.SilkPlayback']==sha((HERE/'native-probe.luau').read_bytes())
  prepared.append(mode)
  receipt_path=HERE/('native-'+mode+'-receipt.json')
  if receipt_path.exists():
   n=json.loads(receipt_path.read_text(encoding='utf8'))
   assert n['release_snapshot']==SOURCE and n['guarded_runtime_snapshot']==m['source'] and n['production_bytes_identical']
   assert n['assertions']==(10 if mode=='success' else 8) and n['scripts']==218 and n['persistence_disabled'] and n['creator_errors']==0
   assert n['place_sha256']==m['place_sha256']
   output=HERE/('native-'+mode+'-output.txt');assert sha(output.read_bytes())==n['output_sha256']
   text=output.read_text(encoding='utf8');assert '[NAVIGATION_NATIVE_FAIL]' not in text and '[FLog::CreatorError]' not in text
   assert '[NAVIGATION_NATIVE_DONE] '+n['run_id']+' '+mode+' '+str(n['assertions'])+' ' in text
   native_modes.append(mode)
full=False
if (HERE/'windows-full-process.json').exists():
 assert read('windows-full-process.json')['exit_code']==0
 rows=re.findall(r'^([A-Z_0-9 ]+) passed=(\d+) failed=(\d+)',(HERE/'windows-full.txt').read_text(encoding='utf8'),re.M)
 assert len(rows)==65 and sum(int(r[1]) for r in rows)==443884 and all(int(r[2])==0 for r in rows);full=True
ci=read('ci-final.json') if (HERE/'ci-final.json').exists() else None
if ci:
 assert ci['head_sha']==SOURCE and ci['conclusion']=='success' and ci['passed']==443884 and ci['suites']==65
 for name,hsh in ci['logs_sha256'].items():assert sha((HERE/name).read_bytes())==hsh
replay=False
if (HERE/'replay-v2/comparison.json').exists():
 prior_comparison=(HERE/'replay-v2/comparison.json').read_bytes()
 with contextlib.redirect_stdout(io.StringIO()):runpy.run_path(str(HERE/'analyze-replay.py'))
 assert (HERE/'replay-v2/comparison.json').read_bytes()==prior_comparison,'replay comparison was not reproducible'
 meta=read('replay-v2/process.json');comparison=read('replay-v2/comparison.json')
 assert len(meta['inputs'])==217 and len(meta['trials'])==3
 for path,hsh in meta['inputs'].items():assert sha(new[path])==hsh
 assert comparison['all_gameplay_projection_samples_match'] and comparison['all_class_dispatched_rng_calls_match']
 assert comparison['excluded_telemetry_fields']=={'PreyDirector':['beforeCost'],'Sensor':['cpuUsMax','cpuUsTotal']}
 assert comparison['projection_regression_guards']==4
 with tempfile.TemporaryDirectory() as folder:
  snap=Path(folder);shutil.copytree(ROOT/'roblox_port/src',snap/'roblox_port/src');shutil.copytree(ROOT/'roblox_port/tests',snap/'roblox_port/tests')
  runner=runpy.run_path(str(snap/'roblox_port/tests/run.py'));runner['CLIENT_TESTS'].add('controller_replay.luau')
  for row in meta['trials']:
   assert row['exit_code']==0
   assert sha((HERE/'replay-v2'/f'{row["fps"]}.txt').read_bytes())==row['log_sha256']
   fixture=(HERE/'replay.luau').read_text(encoding='utf8').replace('__FPS__',str(row['fps']))
   (snap/'roblox_port/tests/controller_replay.luau').write_text(fixture,encoding='utf8',newline='\n')
   assert sha(runner['bundle']('controller_replay.luau').encode())==row['bundle_sha256']
 replay=True
receipt=dict(source=SOURCE,base=BASE,evidence_id='ab5a28c0ff450435',production_modules=217,changed_modules=sorted(changed),
 paired_regression_baseline_pass=10,paired_regression_baseline_fail=5,startup_cases_passed=15,targeted_suites=7,targeted_passed=489,
 compile_passed=217,strict_clean=True,runner_regressions=5,production_sha256=h,test_artifact_rejected=True,
 windows_full_complete=full,linux_ci_verified=bool(ci),native_prepared_cases=prepared,native_startup_paths_verified=len(native_modes)==2,native_startup_assertions=18 if len(native_modes)==2 else 0,native_verified=False,bounded_controller_replay_verified=replay,full_controller_moving_input_replay_verified=False,published=False,publication_ready=False)
(HERE/'receipt.json').write_text(json.dumps(receipt,indent=2)+'\n',encoding='utf8',newline='\n');print(json.dumps(receipt,indent=2))
