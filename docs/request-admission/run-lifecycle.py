"""Private typed New/departure qualification over the complete saving cohort."""
from pathlib import Path
import hashlib,importlib.util,json,re,subprocess,sys,tempfile,time
H=Path(__file__).resolve().parent;ROOT=H.parents[1]
def load(name,path):
 spec=importlib.util.spec_from_file_location(name,path);m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m);return m
def build(focused=False):
 base=load('lifecycle_saving',H/'run-saving.py');r=load('lifecycle_runner',ROOT/'roblox_port/tests/run.py');bundle,inputs=base.build()
 facade='(function()\n'+(H/'worker-facade.luau').read_text(encoding='utf8')+'\nend)()'
 operation='(function()\n'+(H/'operation.luau').read_text(encoding='utf8').replace('require("./worker-facade")',facade)+'\nend)()'
 def code(text):
  for name,var in {'RecoverySessionFencePrototype':'__sessionFence','RecoveryControllerPrototype':'__archiveControllerPrototype','RecoveryArchiveStorePrototype':'__archiveStorePrototype',
   'RecoveryOfferReaderPrototype':'__offerReaderPrototype','RecoveryReadLeasePrototype':'__readLeasePrototype','RecoveryRoutineProgressPrototype':'__routineProgressPrototype',
   'RecoveryProgressReconcilePrototype':'__progressReconcilePrototype','RecoveryPacketPrototype':'__packetPrototype','RecoveryProgressBaselinePrototype':'__progressBaselinePrototype',
   'RecoveryPipelinePrototype':'__pipelinePrototype','RecoveryIdlePrototype':'__idlePrototype','RecoveryDeparturePrototype':'__departurePrototype'}.items():
   text=text.replace('require(Shared.Persistence.'+name+')',var).replace('require(script.Parent.'+name+')',var)
  return r.requires(r.strict(text.replace('require(Shared.Persistence.RecoveryOperationAdmission)',operation)))
 for old,new in [(ROOT/'docs/new-life-policy/new-life-policy-prototype.luau',H/'new-policy.luau'),(ROOT/'docs/save-slot-isolation/recovery-departure-prototype.luau',H/'departure.luau'),
  (ROOT/'docs/save-slot-isolation/recovery-runtime-prototype.luau',H/'runtime-lifecycle.luau')]:
  before=code(old.read_text(encoding='utf8'));assert bundle.count(before)==1,old.name
  bundle=bundle.replace(before,code(new.read_text(encoding='utf8')));inputs.append(new)
 start=bundle.index('local function runProtectedNewChecks()');end=bundle.index('local function originals(f)',start)
 prefix='do\n'+bundle[start:end].replace('runProtectedNewChecks','runLifecycleNewChecks',1)
 marker='check(#recent<=Rules.REQUESTS_PER_MINUTE or t and t.stage=='
 assert prefix.count(marker)==1;prefix=prefix.replace(marker,'check(f.g~=nil or #recent<=Rules.REQUESTS_PER_MINUTE or t and t.stage==')
 utilities=(ROOT/'docs/new-life-policy/tests.luau').read_text(encoding='utf8').split('for _,mode in Rules.MODES do',1)[0]
 gate='(function()\n'+(H/'worker-admission.luau').read_text(encoding='utf8')+'\nend)()'
 newTests=(H/'lifecycle-new-tests.luau').read_text(encoding='utf8').replace('__lifecycleGate',gate)
 ds=ROOT/'docs/save-slot-isolation/recovery-departure-tests.luau';departure=ds.read_text(encoding='utf8').split('-- Retained counterexample:',1)[0]
 assert departure.endswith('end\n');departure=departure.replace('do\nlocal Memory=', 'do\nlocal function runLifecycleDepartureChecks()\nlocal Memory=',1)
 departure+=(H/'lifecycle-departure-tests.luau').read_text(encoding='utf8').replace('__lifecycleGate',gate)
 source=ROOT/'docs/save-slot-isolation/recovery-save-loop-tests.luau'
 recovered=source.read_text(encoding='utf8').split('for _,mode in Rules.MODES do',1)[0].replace('runSaveLoopChecks','runLifecycleRecoveredChecks',1)
 recovered+=(H/'lifecycle-recovered-tests.luau').read_text(encoding='utf8').replace('__lifecycleGate',gate)
 assert bundle.endswith('end\n');bundle=bundle[:-4]+'\n'+prefix+r.requires(utilities+newTests)+'\n'+r.requires(departure)+'\n'+r.requires(recovered)+'\nend\n'
 if focused:
  bundle=re.sub(r'\n(run\w+Checks)\(\)\nend',lambda m:'\n-- focused: skip '+m[1]+'\nend' if m[1] not in {'runLifecycleNewChecks','runLifecycleDepartureChecks','runLifecycleRecoveredChecks'} else m[0],bundle)
 return bundle,list(dict.fromkeys(inputs+[ds,source,ROOT/'docs/new-life-policy/tests.luau',H/'lifecycle-new-tests.luau',H/'lifecycle-departure-tests.luau',H/'lifecycle-recovered-tests.luau']))
def main():
 prefix=sys.argv[1];assert re.fullmatch('[a-z][a-z0-9-]*',prefix);out=H/(prefix+'-output.txt');assert not out.exists()
 focused='--focused' in sys.argv;bundle,paths=build(focused);sha=lambda b:hashlib.sha256(b).hexdigest()
 inputs={p.relative_to(ROOT).as_posix():sha(p.read_bytes()) for p in paths};started=time.time()
 tool=Path(r'C:/Users/natha/.codex/.chatgpt-projects/g-p-6ac2f32f82a48191b0c7151a11eab0fd/roblox_tools/luau/luau.exe')
 with tempfile.TemporaryDirectory(prefix='windowsill-lifecycle-admission-') as tmp:
  path=Path(tmp)/'run.luau';path.write_text(bundle,encoding='utf8',newline='\n');result=subprocess.run([str(tool),str(path)],cwd=ROOT,capture_output=True,text=True)
 assert inputs=={p.relative_to(ROOT).as_posix():sha(p.read_bytes()) for p in paths}
 output=result.stdout+result.stderr;out.write_text(output,encoding='utf8',newline='\n')
 if result.returncode:(H/(prefix+'-bundle.luau')).write_text(bundle,encoding='utf8',newline='\n')
 receipt=dict(source=subprocess.check_output(['git','log','-1','--format=%H','--','roblox_port/src','roblox_port/tests'],cwd=ROOT,text=True).strip(),inputs=inputs,
  bundle_sha256=sha(bundle.encode()),output_sha256=sha(output.encode()),exit_code=result.returncode,elapsed_seconds=time.time()-started,focused=focused,
  typed_new_and_departure=True,all_workers_typed=False,service_lanes_installed=False,provider='memory',clock='synthetic',normal_startup_installed=False,native_verified=False,online_verified=False,published=False)
 (H/(prefix+'-receipt.json')).write_text(json.dumps(receipt,indent=2)+'\n',encoding='utf8',newline='\n');print(output);raise SystemExit(result.returncode)
if __name__=='__main__':main()
