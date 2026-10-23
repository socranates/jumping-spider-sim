"""Archive collector/publication/controller overrides through the full entry cohort."""
from pathlib import Path
import hashlib,importlib.util,json,re,subprocess,sys,tempfile,time
H=Path(__file__).resolve().parent;ROOT=H.parents[1]
def load(name,path):
 spec=importlib.util.spec_from_file_location(name,path);m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m);return m
def build():
 base=load('archive_prior',H/'run-entry.py');r=load('archive_runner',ROOT/'roblox_port/tests/run.py')
 bundle,inputs=base.build(H/'worker-v3.luau');facade='(function()\n'+(H/'worker-facade.luau').read_text()+'\nend)()'
 operation='(function()\n'+(H/'operation.luau').read_text().replace('require("./worker-facade")',facade)+'\nend)()'
 def code(text):
  for name,var in [('RecoveryArchivePrototype','__packetArchive'),('RecoverySourceCollectorPrototype','__collectorPrototype'),('RecoveryArchiveStorePrototype','__archiveStorePrototype'),('RecoverySessionFencePrototype','__sessionFence')]:text=text.replace('require(script.Parent.'+name+')',var)
  text=text.replace('require(script.Parent.RecoveryOperationAdmission)',operation)
  return r.requires(r.strict(text))
 for oldName,newName in [('recovery-source-collector-prototype.luau','collector.luau'),('recovery-archive-store-prototype.luau','repository.luau'),('recovery-controller-prototype.luau','controller.luau')]:
  old=ROOT/'docs/save-slot-isolation'/oldName;new=H/newName;before,after=code(old.read_text()),code(new.read_text())
  assert bundle.count(before)==1,(oldName,bundle.count(before));bundle=bundle.replace(before,after);inputs.append(new)
 gate='(function()\n'+(H/'worker-admission.luau').read_text()+'\nend)()'
 tests=(H/'archive-tests.luau').read_text().replace('__operationAdmission',operation).replace('__typedGate',gate)
 marker='print("ARCHIVE_ADMISSION passed="..checks.." failed=0 groups="..groups)';assert tests.count(marker)==1
 tests=tests.replace(marker,(H/'archive-lease-tests.luau').read_text()+'\n'+marker)
 worker='(function()\n'+(H/'worker-v3.luau').read_text().replace('require("./worker-facade")',facade)+'\nend)()'
 portable=';(function()\nlocal Admission='+gate+'\nlocal Operation='+operation+'\nlocal Worker='+worker+'\nlocal Memory=require("../src/Shared/Persistence/MemoryBackend")\nlocal Scheduler=require("../src/Shared/Persistence/SaveScheduler")\n'+(H/'operation-tests.luau').read_text()+'\n'+(H/'history-tests.luau').read_text()+'\nend)()\n'
 assert bundle.endswith('end\n');bundle=bundle[:-4]+';(function()\n'+r.requires(tests)+'\nend)()\n'+r.requires(portable)+'\nend\n'
 return bundle,list(dict.fromkeys(inputs+[H/'operation.luau',H/'archive-tests.luau',H/'archive-lease-tests.luau',H/'operation-tests.luau',H/'history-tests.luau']))
def main():
 prefix=sys.argv[1];assert re.fullmatch('[a-z][a-z0-9-]*',prefix)
 out=H/(prefix+'-output.txt');assert not out.exists()
 bundle,paths=build();sha=lambda b:hashlib.sha256(b).hexdigest();inputs={p.relative_to(ROOT).as_posix():sha(p.read_bytes()) for p in paths};started=time.time()
 tool=Path(r'C:/Users/natha/.codex/.chatgpt-projects/g-p-6ac2f32f82a48191b0c7151a11eab0fd/roblox_tools/luau/luau.exe')
 with tempfile.TemporaryDirectory(prefix='windowsill-archive-admission-') as tmp:
  path=Path(tmp)/'run.luau';path.write_text(bundle,encoding='utf8',newline='\n');result=subprocess.run([str(tool),str(path)],cwd=ROOT,capture_output=True,text=True)
 assert inputs=={p.relative_to(ROOT).as_posix():sha(p.read_bytes()) for p in paths}
 output=result.stdout+result.stderr;out.write_text(output,encoding='utf8',newline='\n')
 if result.returncode:(H/(prefix+'-bundle.luau')).write_text(bundle,encoding='utf8',newline='\n')
 receipt=dict(source=subprocess.check_output(['git','log','-1','--format=%H','--','roblox_port/src','roblox_port/tests'],cwd=ROOT,text=True).strip(),inputs=inputs,
  bundle_sha256=sha(bundle.encode()),output_sha256=sha(output.encode()),exit_code=result.returncode,elapsed_seconds=time.time()-started,
  typed_overrides=['discovery','entry','read_lease','source_collector','archive_repository','archive_controller'],all_workers_typed=False,service_lanes_installed=False,
  provider='memory',clock='synthetic',normal_startup_installed=False,native_verified=False,online_verified=False,published=False)
 (H/(prefix+'-receipt.json')).write_text(json.dumps(receipt,indent=2)+'\n',encoding='utf8',newline='\n');print(output);raise SystemExit(result.returncode)
if __name__=='__main__':main()
