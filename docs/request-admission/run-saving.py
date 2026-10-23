"""Qualify optional recovered saving over the preceding full typed cohort."""
from pathlib import Path
import hashlib,importlib.util,json,re,subprocess,sys,tempfile,time
H=Path(__file__).resolve().parent;ROOT=H.parents[1]
def load(name,path):
 spec=importlib.util.spec_from_file_location(name,path);m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m);return m
def build(focused=False):
 base=load('saving_commit',H/'run-commit.py');r=load('saving_runner',ROOT/'roblox_port/tests/run.py');bundle,inputs=base.build()
 facade='(function()\n'+(H/'worker-facade.luau').read_text()+'\nend)()'
 operation='(function()\n'+(H/'operation.luau').read_text().replace('require("./worker-facade")',facade)+'\nend)()'
 def code(text):
  for name,var in {'RecoveryProgressPrototype':'__progressPrototype','RecoveryArchivePrototype':'__packetArchive','RecoveryArchiveStorePrototype':'__archiveStorePrototype',
   'RecoveryPacketPrototype':'__packetPrototype','RecoveryRestFormatPrototype':'__restFormatPrototype','RecoveryProgressReconcilePrototype':'__progressReconcilePrototype',
   'RecoveryReadLeasePrototype':'__readLeasePrototype','RecoveryRoutineProgressPrototype':'__routineProgressPrototype','RecoveryCurrentWriterPrototype':'__currentWriterPrototype'}.items():
   text=text.replace('require(Shared.Persistence.'+name+')',var).replace('require(script.Parent.'+name+')',var)
  return r.requires(r.strict(text.replace('require(Shared.Persistence.RecoveryOperationAdmission)',operation)))
 for oldName,newName in [('recovery-routine-progress-prototype.luau','routine-progress.luau'),('recovery-current-writer-prototype.luau','current-writer.luau'),('recovery-save-loop-prototype.luau','save-loop.luau')]:
  before=code((ROOT/'docs/save-slot-isolation'/oldName).read_text());new=H/newName
  assert bundle.count(before)==1,(oldName,bundle.count(before));bundle=bundle.replace(before,code(new.read_text()));inputs.append(new)
 source=ROOT/'docs/save-slot-isolation/recovery-save-loop-tests.luau';prefix=source.read_text().split('for _,mode in Rules.MODES do',1)[0]
 assert prefix.endswith('end\n');prefix=prefix.replace('runSaveLoopChecks','runSavingAdmissionChecks',1)
 gate='(function()\n'+(H/'worker-admission.luau').read_text()+'\nend)()'
 tests=(H/'saving-tests.luau').read_text().replace('__savingGate',gate)
 marker='print("SAVING_ADMISSION passed="..count.." failed=0 groups="..groups)'
 assert tests.count(marker)==1
 tests=tests.replace(marker,(H/'saving-lifetime-tests.luau').read_text().replace('__savingOperation',operation)+'\n'+marker)
 assert bundle.endswith('end\n');bundle=bundle[:-4]+'\n'+r.requires(prefix+tests)+'\nend\n'
 if focused:
  bundle=re.sub(r'\n(run\w+Checks)\(\)\nend',lambda m:'\n-- focused: skip '+m[1]+'\nend' if m[1]!='runSavingAdmissionChecks' else m[0],bundle)
  # Older portable admission checks are top-level closures, so their small
  # comparisons still run. The full qualification is the authoritative run.
 return bundle,list(dict.fromkeys(inputs+[source,H/'saving-tests.luau',H/'saving-lifetime-tests.luau']))
def main():
 prefix=sys.argv[1];assert re.fullmatch('[a-z][a-z0-9-]*',prefix);out=H/(prefix+'-output.txt');assert not out.exists()
 focused='--focused' in sys.argv;bundle,paths=build(focused);sha=lambda b:hashlib.sha256(b).hexdigest()
 inputs={p.relative_to(ROOT).as_posix():sha(p.read_bytes()) for p in paths};started=time.time()
 tool=Path(r'C:/Users/natha/.codex/.chatgpt-projects/g-p-6ac2f32f82a48191b0c7151a11eab0fd/roblox_tools/luau/luau.exe')
 with tempfile.TemporaryDirectory(prefix='windowsill-saving-admission-') as tmp:
  path=Path(tmp)/'run.luau';path.write_text(bundle,encoding='utf8',newline='\n');result=subprocess.run([str(tool),str(path)],cwd=ROOT,capture_output=True,text=True)
 assert inputs=={p.relative_to(ROOT).as_posix():sha(p.read_bytes()) for p in paths}
 output=result.stdout+result.stderr;out.write_text(output,encoding='utf8',newline='\n')
 if result.returncode:(H/(prefix+'-bundle.luau')).write_text(bundle,encoding='utf8',newline='\n')
 receipt=dict(source=subprocess.check_output(['git','log','-1','--format=%H','--','roblox_port/src','roblox_port/tests'],cwd=ROOT,text=True).strip(),inputs=inputs,
  bundle_sha256=sha(bundle.encode()),output_sha256=sha(output.encode()),exit_code=result.returncode,elapsed_seconds=time.time()-started,focused=focused,
  typed_recovered_saving=True,all_workers_typed=False,service_lanes_installed=False,provider='memory',clock='synthetic',normal_startup_installed=False,native_verified=False,online_verified=False,published=False)
 (H/(prefix+'-receipt.json')).write_text(json.dumps(receipt,indent=2)+'\n',encoding='utf8',newline='\n');print(output);raise SystemExit(result.returncode)
if __name__=='__main__':main()
