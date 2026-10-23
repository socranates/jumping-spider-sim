"""Actual entry/read-lease overrides plus the qualified discovery/application cohort."""
from pathlib import Path
import hashlib,importlib.util,json,re,subprocess,sys,tempfile,time
H=Path(__file__).resolve().parent;ROOT=H.parents[1]
def load(name,path):
 spec=importlib.util.spec_from_file_location(name,path);m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m);return m
def build(workerPath=None):
 base=load('entry_worker_base',H/'run-workers.py');r=load('entry_worker_runner',ROOT/'roblox_port/tests/run.py')
 workerPath=workerPath or H/'worker-v2.luau'
 bundle,inputs=base.build(workerPath)
 facade='(function()\n'+(H/'worker-facade.luau').read_text()+'\nend)()'
 worker='(function()\n'+workerPath.read_text().replace('require("./worker-facade")',facade)+'\nend)()'
 def code(text):
  for name,var in {'RecoveryProgressPrototype':'__progressPrototype','RecoveryArchivePrototype':'__packetArchive','RecoveryArchiveStorePrototype':'__archiveStorePrototype','RecoveryPacketPrototype':'__packetPrototype','RecoveryRestFormatPrototype':'__restFormatPrototype'}.items():
   text=text.replace('require(Shared.Persistence.'+name+')',var).replace('require(script.Parent.'+name+')',var)
  return r.requires(r.strict(text.replace('require(script.Parent.RecoveryRequestAdmission)',worker)))
 for name,target in [('recovery-entry-prototype.luau','entry.luau'),('recovery-read-lease-prototype.luau','lease.luau')]:
  old=ROOT/'docs/save-slot-isolation'/name;new=H/target
  before,after=code(old.read_text()),code(new.read_text());assert bundle.count(before)==1,name
  bundle=bundle.replace(before,after);inputs.append(new)
 source=ROOT/'docs/save-slot-isolation/recovery-entry-tests.luau'
 prefix=source.read_text().split('local function tick(f)',1)[0];assert prefix.endswith('end\n')
 prefix=prefix.replace('runEntryChecks','runEntryAdmissionChecks',1)
 gate='(function()\n'+(H/'worker-admission.luau').read_text()+'\nend)()'
 tests=(H/'entry-tests.luau').read_text().replace('__workerAdmission',gate)
 marker='print("ENTRY_ADMISSION passed="..count.." failed=0 groups="..groups)'
 assert tests.count(marker)==1
 tests=tests.replace(marker,(H/'entry-lease-wait-tests.luau').read_text()+'\n'+marker)
 dispatch=';(function()\nlocal Admission='+gate+'\nlocal Worker='+worker+'\nlocal Memory=require("../src/Shared/Persistence/MemoryBackend")\nlocal Scheduler=require("../src/Shared/Persistence/SaveScheduler")\n'+(H/'dispatch-guard-tests.luau').read_text()+'\nend)()\n'
 assert bundle.endswith('end\n');bundle=bundle[:-4]+r.requires(prefix+tests)+r.requires(dispatch)+'\nend\n'
 return bundle,list(dict.fromkeys(inputs+[source,H/'entry-tests.luau',H/'entry-lease-wait-tests.luau',H/'dispatch-guard-tests.luau']))
def main():
 prefix=sys.argv[1];assert re.fullmatch('[a-z][a-z0-9-]*',prefix)
 out=H/(prefix+'-output.txt');assert not out.exists(),'Preserve previous runs'
 bundle,paths=build();sha=lambda b:hashlib.sha256(b).hexdigest()
 inputs={p.relative_to(ROOT).as_posix():sha(p.read_bytes()) for p in paths};started=time.time()
 tool=Path(r'C:/Users/natha/.codex/.chatgpt-projects/g-p-6ac2f32f82a48191b0c7151a11eab0fd/roblox_tools/luau/luau.exe')
 with tempfile.TemporaryDirectory(prefix='windowsill-entry-admission-') as tmp:
  path=Path(tmp)/'run.luau';path.write_text(bundle,encoding='utf8',newline='\n')
  result=subprocess.run([str(tool),str(path)],cwd=ROOT,capture_output=True,text=True)
 assert inputs=={p.relative_to(ROOT).as_posix():sha(p.read_bytes()) for p in paths}
 output=result.stdout+result.stderr;out.write_text(output,encoding='utf8',newline='\n')
 if result.returncode:(H/(prefix+'-bundle.luau')).write_text(bundle,encoding='utf8',newline='\n')
 receipt=dict(source=subprocess.check_output(['git','log','-1','--format=%H','--','roblox_port/src','roblox_port/tests'],cwd=ROOT,text=True).strip(),
  inputs=inputs,bundle_sha256=sha(bundle.encode()),output_sha256=sha(output.encode()),exit_code=result.returncode,elapsed_seconds=time.time()-started,
  typed_worker_overrides=['discovery','entry','read_lease'],all_workers_typed=False,service_lanes_installed=False,normal_startup_installed=False,
  provider='memory',clock='synthetic',native_verified=False,online_verified=False,published=False)
 (H/(prefix+'-receipt.json')).write_text(json.dumps(receipt,indent=2)+'\n',encoding='utf8',newline='\n');print(output);raise SystemExit(result.returncode)
if __name__=='__main__':main()
