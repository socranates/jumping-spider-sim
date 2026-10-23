"""Reconstruct current worker bundles and bind real backend/source and type evidence."""
from pathlib import Path
import ast,hashlib,importlib.util,io,json,re,subprocess,tarfile,zipfile
H=Path(__file__).resolve().parent;ROOT=H.parents[1]
SOURCE='bd67582b5d53473f067244fc1e2e1f94adde173b';sha=lambda b:hashlib.sha256(b).hexdigest()
def load(name,file):
 spec=importlib.util.spec_from_file_location(name,H/file);m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m);return m
def check(prefix,bundle,paths):
 receipt=json.loads((H/(prefix+'-receipt.json')).read_text());output=(H/(prefix+'-output.txt')).read_bytes()
 assert receipt['source']==SOURCE and receipt['exit_code']==0
 assert receipt['inputs']=={p.relative_to(ROOT).as_posix():sha(p.read_bytes()) for p in paths}
 assert receipt['bundle_sha256']==sha(bundle.encode()) and receipt['output_sha256']==sha(output)
 assert not re.search(r'\b(?:fail|failed)=[1-9]\d*\b|stacktrace:',output.decode())
 return receipt,output.decode()
def main():
 fullRunner=load('qualified_workers','run-workers.py');fullBundle,fullPaths=fullRunner.build()
 full,text=check('workers-qualified-2',fullBundle,fullPaths)
 prior=(ROOT/'docs/new-life-application/qualified-full-1-output.txt').read_text()
 pattern=r'^([A-Z_0-9]+) passed=(\d+) failed=(\d+)'
 expected={name:(int(p),int(f)) for name,p,f in re.findall(pattern,prior,re.M)}
 assert len(expected)==34 and sum(p for p,f in expected.values())==211717 and all(f==0 for p,f in expected.values())
 expected.update(WORKER_ADMISSION=(127,0),ADMISSION_BRIDGE=(20,0))
 rows=re.findall(pattern,text,re.M);assert len(rows)==36 and {name:(int(p),int(f)) for name,p,f in rows}==expected
 assert len(re.findall(r'^WORKER_ADMISSION_CASE\s',text,re.M))==8 and len(re.findall(r'^BRIDGE_CASE\s',text,re.M))==6
 assert sum(int(n) for n in re.findall(r'^WORKER_ADMISSION_CASE\s[^\n]+\s(\d+)$',text,re.M))==127
 assert sum(int(n) for n in re.findall(r'^BRIDGE_CASE\s[^\n]+\s(\d+)$',text,re.M))==20
 for mode in ['main','free','easy']:assert f'NEW_APPLICATION mode={mode} actual_menu=true original_retained=true old_closed=true explicit_fresh_choice=true writable=true normal_rest_stored=true' in text
 assert re.search(r'^RECOVERY_APPLICATION_GAME read_invariants=[1-9]\d* every_read_checked=true$',text,re.M)
 bridgeRunner=load('qualified_bridge','run-bridge.py');bridgeBundle,_,bridgePaths=bridgeRunner.build()
 bridge,bridgeText=check('bridge-qualified-2',bridgeBundle,bridgePaths)
 assert 'REQUEST_ADMISSION passed=4771 failed=0 groups=22' in bridgeText and 'ADMISSION_BACKEND passed=82 failed=0 groups=8 options=5' in bridgeText and 'ADMISSION_BRIDGE passed=20 failed=0 groups=6' in bridgeText
 oldWorker=subprocess.check_output(['git','show','6aa8d72:docs/request-admission/worker.luau'],cwd=ROOT).decode()
 currentWorker=(H/'worker.luau').read_text()
 beforeBundle=bridgeBundle.replace(currentWorker.replace('require("./worker-facade")','Facade'),oldWorker.replace('require("./worker-facade")','Facade'))
 assert beforeBundle!=bridgeBundle
 before=json.loads((H/'bridge-before-throw-fix-receipt.json').read_text());beforeText=(H/'bridge-before-throw-fix-output.txt').read_bytes()
 beforeInputs={p.relative_to(ROOT).as_posix():sha(p.read_bytes()) for p in bridgePaths};beforeInputs['docs/request-admission/worker.luau']=sha(oldWorker.encode())
 assert before['inputs']==beforeInputs and before['exit_code']!=0 and before['bundle_sha256']==sha(beforeBundle.encode()) and before['output_sha256']==sha(beforeText)
 assert (H/'bridge-before-throw-fix-bundle.luau').read_bytes()==beforeBundle.encode() and b'provider exception lost the backend failure/backoff path' in beforeText
 differential=load('ledger_equivalence','run-ledger.py');ledgerBundle,ledgerPaths=differential.build()
 lr=json.loads((H/'ledger-qualified-1-receipt.json').read_text());lt=(H/'ledger-qualified-1-output.txt').read_bytes()
 assert lr['exit_code']==0 and lr['bundle_sha256']==sha(ledgerBundle.encode()) and lr['output_sha256']==sha(lt)
 assert lr['inputs']=={p.relative_to(ROOT).as_posix():sha(p.read_bytes()) for p in ledgerPaths}
 assert 'ADMISSION_LEDGER_EQUIVALENCE passed=12215 failed=0 steps=1200 provider_starts=13' in lt.decode()
 # Bind the CPU fixture as source, without executing new benchmarks here.
 tree=ast.parse((H/'benchmark-workers.py').read_text())
 fixture=next(ast.literal_eval(n.value) for n in ast.walk(tree) if isinstance(n,ast.Assign) and any(isinstance(t,ast.Name) and t.id=='fixture' for t in n.targets))
 def cpu(prefix,path):
  r=json.loads((H/(prefix+'-receipt.json')).read_text());output=(H/(prefix+'-output.txt')).read_bytes();source=path.read_text()
  bundle='local Gate=(function()\n'+source+'\nend)()\n'+fixture
  assert r['input_path']==path.relative_to(ROOT).as_posix() and r['input_sha256']==sha(source.encode()) and r['bundle_sha256']==sha(bundle.encode()) and r['output_sha256']==sha(output)
  assert r['exit_code']==0 and r['samples_per_case']==20 and not r['native_verified'] and not r['frame_rate_claim']
  rows=re.findall(r'^ADMISSION_CPU actors=(\d+) debt=(\d+) pending=(\d+) median_ms=([\d.]+) p95_ms=([\d.]+) max_ms=([\d.]+)$',output.decode(),re.M)
  assert len(rows)==2 and [r[:3] for r in rows]==[('16','6','32'),('64','150','256')]
  return [dict(actors=int(a),debt=int(d),pending=int(p),median_ms=float(m),p95_ms=float(q),max_ms=float(x)) for a,d,p,m,q,x in rows]
 cpuBefore=cpu('workers-cpu-before-2',H/'workers-before-ledger-admission.luau');cpuAfter=cpu('workers-cpu-after-2',H/'worker-admission.luau')
 assert cpuAfter[1]['median_ms']<cpuBefore[1]['median_ms']
 with zipfile.ZipFile(H/'workers-development-1-bundle.zip') as archive:
  assert archive.namelist()==['workers-development-1-bundle.luau']
  assert sha(archive.read(archive.namelist()[0]))==json.loads((H/'workers-development-1-receipt.json').read_text())['bundle_sha256']
 checker=load('worker_types','check-workers.py');sources=checker.paths();types=json.loads((H/'workers-types-qualified-2-types.json').read_text())
 assert len(sources)==44 and types['candidates']=={p.relative_to(ROOT).as_posix():sha(p.read_bytes()) for p in sources.values()}
 for name,digest in types['production_inputs'].items():assert sha((ROOT/name).read_bytes())==digest
 mounted={}
 for target,p in sources.items():
  code=p.read_text()
  if p==H/'worker.luau':code=code.replace('require("./worker-facade")','require(script.Parent.RequestAdmissionFacade)')
  mounted[target]=sha(code.encode())
 assert mounted==types['mounted'] and len(types['steps'])==3
 for step in types['steps']:assert step['exit_code']==0 and sha((H/('workers-types-qualified-2-'+step['name']+'.txt')).read_bytes())==step['sha256']
 assert (H/'workers-types-qualified-2-compile.txt').read_text()=='compile 44/44\n'
 strict=(H/'workers-types-qualified-2-strict.txt').read_text()
 assert not [line for line in strict.splitlines() if line and not line.startswith('[INFO]') and 'didChangeWatchedFiles' not in line]
 archive=subprocess.check_output(['git','archive','--format=tar',SOURCE,'roblox_port/src','roblox_port/tests'],cwd=ROOT)
 with tarfile.open(fileobj=io.BytesIO(archive)) as a:
  production={m.name:sha(a.extractfile(m).read()) for m in a if m.isfile()}
 assert all(sha((ROOT/name).read_bytes())==digest for name,digest in production.items())
 assert full['reader_override'] and not full['other_workers_typed'] and not full['normal_startup_installed'] and not full['native_verified'] and not full['online_verified'] and not full['published']
 private={p.relative_to(ROOT).as_posix():sha(p.read_bytes()) for p in [H/'reader.luau',H/'worker.luau',H/'worker-admission.luau',H/'worker-facade.luau',H/'workers-tests.luau',H/'bridge-tests.luau']}
 committed=all(subprocess.run(['git','cat-file','-e','HEAD:'+p],cwd=ROOT,capture_output=True).returncode==0 and sha(subprocess.check_output(['git','show','HEAD:'+p],cwd=ROOT))==digest for p,digest in private.items())
 privateCommit=subprocess.check_output(['git','log','-1','--format=%H','--',*private],cwd=ROOT,text=True).strip() if committed else None
 result=dict(source=SOURCE,private_inputs_committed=committed,private_commit=privateCommit,full_checks=211864,full_named_groups=48,full_failed=0,baseline_checks=211717,typed_reader_checks=127,typed_reader_groups=8,bridge_checks=20,bridge_groups=6,
  portable_gate_backend_bridge_checks=4873,ledger_equivalence_checks=12215,ledger_equivalence_steps=1200,before_fix_provider_throw_bound=True,
  cli_cpu_before=cpuBefore,cli_cpu_after=cpuAfter,roblox_frame_rate_improvement_proved=False,
  overlay_candidates=44,strict_clean=True,provider='memory',clock='synthetic',typed_reader_override_qualified=True,other_workers_typed=False,service_epoch_lanes_installed=False,
  cooperative_driver_installed=False,normal_startup_installed=False,native_verified=False,online_verified=False,loading_speedup_proved=False,published=False,goal_complete=False)
 (H/'worker-verification.json').write_text(json.dumps(result,indent=2)+'\n',encoding='utf8',newline='\n');print(json.dumps(result,indent=2))
if __name__=='__main__':main()
