"""Typed terminal-held maintenance and Runtime route over the full lifecycle cohort."""
from pathlib import Path
import hashlib,importlib.util,json,re,subprocess,sys,tempfile,time
H=Path(__file__).resolve().parent;ROOT=H.parents[1]
def load(name,path):
 spec=importlib.util.spec_from_file_location(name,path);m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m);return m
def build(focused=False):
 base=load('held_lifecycle',H/'run-lifecycle.py');r=load('held_runner',ROOT/'roblox_port/tests/run.py');bundle,inputs=base.build()
 facade='(function()\n'+(H/'worker-facade.luau').read_text(encoding='utf8')+'\nend)()'
 operation='(function()\n'+(H/'operation.luau').read_text(encoding='utf8').replace('require("./worker-facade")',facade)+'\nend)()'
 def idle(text):return r.requires(r.strict(text.replace('require(Shared.Persistence.RecoveryOperationAdmission)',operation)))
 before=idle((ROOT/'docs/save-slot-isolation/recovery-idle-prototype.luau').read_text(encoding='utf8'))
 assert bundle.count(before)==1;bundle=bundle.replace(before,idle((H/'idle.luau').read_text(encoding='utf8')));inputs.append(H/'idle.luau')
 def runtime(text):
  for name,var in {'RecoveryProgressBaselinePrototype':'__progressBaselinePrototype','RecoveryOfferReaderPrototype':'__offerReaderPrototype','RecoveryPipelinePrototype':'__pipelinePrototype',
   'RecoveryIdlePrototype':'__idlePrototype','RecoveryDeparturePrototype':'__departurePrototype','RecoveryReadLeasePrototype':'__readLeasePrototype'}.items():text=text.replace('require(script.Parent.'+name+')',var)
  return r.requires(r.strict(text))
 before=runtime((H/'runtime-lifecycle.luau').read_text(encoding='utf8'));assert bundle.count(before)==1
 bundle=bundle.replace(before,runtime((H/'runtime-held.luau').read_text(encoding='utf8')));inputs.append(H/'runtime-held.luau')
 src=ROOT/'docs/save-slot-isolation/recovery-idle-tests.luau';prefix=src.read_text(encoding='utf8').split('-- The old terminal owner',1)[0]
 assert prefix.endswith('end\n');prefix=prefix.replace('do\nlocal Memory=', 'do\nlocal function runHeldAdmissionChecks()\nlocal Memory=',1)
 gate='(function()\n'+(H/'worker-admission.luau').read_text(encoding='utf8')+'\nend)()'
 tests=(H/'held-tests.luau').read_text(encoding='utf8').replace('__heldGate',gate)
 source=ROOT/'docs/save-slot-isolation/recovery-runtime-tests.luau';rt=source.read_text(encoding='utf8').split('local function tick(',1)[0]
 assert rt.endswith('end\n');rt=rt.replace('do\nlocal Memory=', 'do\nlocal function runHeldRuntimeChecks()\nlocal Memory=',1)
 rt+=(H/'held-runtime-tests.luau').read_text(encoding='utf8').replace('__heldGate',gate)
 assert bundle.endswith('end\n');bundle=bundle[:-4]+'\n'+r.requires(prefix+tests)+'\n'+r.requires(rt)+'\nend\n'
 if focused:
  bundle=re.sub(r'\n(run\w+Checks)\(\)\nend',lambda m:'\n-- focused: skip '+m[1]+'\nend' if m[1] not in {'runHeldAdmissionChecks','runHeldRuntimeChecks'} else m[0],bundle)
 return bundle,list(dict.fromkeys(inputs+[src,source,H/'held-tests.luau',H/'held-runtime-tests.luau']))
def main():
 prefix=sys.argv[1];assert re.fullmatch('[a-z][a-z0-9-]*',prefix);out=H/(prefix+'-output.txt');assert not out.exists()
 focused='--focused' in sys.argv;bundle,paths=build(focused);sha=lambda b:hashlib.sha256(b).hexdigest()
 inputs={p.relative_to(ROOT).as_posix():sha(p.read_bytes()) for p in paths};started=time.time()
 tool=Path(r'C:/Users/natha/.codex/.chatgpt-projects/g-p-6ac2f32f82a48191b0c7151a11eab0fd/roblox_tools/luau/luau.exe')
 with tempfile.TemporaryDirectory(prefix='windowsill-held-admission-') as tmp:
  path=Path(tmp)/'run.luau';path.write_text(bundle,encoding='utf8',newline='\n');result=subprocess.run([str(tool),str(path)],cwd=ROOT,capture_output=True,text=True)
 assert inputs=={p.relative_to(ROOT).as_posix():sha(p.read_bytes()) for p in paths}
 output=result.stdout+result.stderr;out.write_text(output,encoding='utf8',newline='\n')
 if result.returncode:(H/(prefix+'-bundle.luau')).write_text(bundle,encoding='utf8',newline='\n')
 receipt=dict(source=subprocess.check_output(['git','log','-1','--format=%H','--','roblox_port/src','roblox_port/tests'],cwd=ROOT,text=True).strip(),inputs=inputs,
  bundle_sha256=sha(bundle.encode()),output_sha256=sha(output.encode()),exit_code=result.returncode,elapsed_seconds=time.time()-started,focused=focused,
  terminal_held_idle_typed=True,all_workers_typed=False,service_lanes_installed=False,provider='memory',clock='synthetic',normal_startup_installed=False,native_verified=False,online_verified=False,published=False)
 (H/(prefix+'-receipt.json')).write_text(json.dumps(receipt,indent=2)+'\n',encoding='utf8',newline='\n');print(output);raise SystemExit(result.returncode)
if __name__=='__main__':main()
