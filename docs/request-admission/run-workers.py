"""Qualify the actual reader override through the full private application cohort."""
from pathlib import Path
import hashlib,importlib.util,json,re,subprocess,sys,tempfile,time
H=Path(__file__).resolve().parent;ROOT=H.parents[1]
TOOLS=Path(r'C:/Users/natha/.codex/.chatgpt-projects/g-p-6ac2f32f82a48191b0c7151a11eab0fd/roblox_tools')
def load(name,path):
 spec=importlib.util.spec_from_file_location(name,path);m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m);return m
def build(workerPath=None):
 prior=load('prior_application',ROOT/'docs/new-life-application/run.py');r=load('runner_workers',ROOT/'roblox_port/tests/run.py')
 bundle,inputs=prior.build()
 old=ROOT/'docs/save-slot-isolation/recovery-offer-reader-prototype.luau'
 facade='(function()\n'+(H/'worker-facade.luau').read_text()+'\nend)()'
 workerPath=workerPath or H/'worker.luau'
 worker='(function()\n'+workerPath.read_text().replace('require("./worker-facade")',facade)+'\nend)()'
 def reader(text):
  for name,var in [('RecoveryArchivePrototype','__packetArchive'),('RecoveryArchiveStorePrototype','__archiveStorePrototype'),('RecoveryLifePrototype','__lifePrototype')]:text=text.replace('require(Shared.Persistence.'+name+')',var)
  text=text.replace('require(script.Parent.RecoveryPacketPrototype)','__packetPrototype').replace('require(script.Parent.RecoveryRequestAdmission)',worker)
  return r.requires(r.strict(text))
 before=reader(old.read_text());after=reader((H/'reader.luau').read_text());assert bundle.count(before)==1
 bundle=bundle.replace(before,after)
 gate='(function()\n'+(H/'worker-admission.luau').read_text()+'\nend)()'
 tests=(H/'workers-tests.luau').read_text().replace('__workerAdmission',gate)
 tests+='\n'+(H/'bridge-tests.luau').read_text().replace('__workerAdmission',gate).replace('__workerBridge',worker)
 assert bundle.endswith('end\n');bundle=bundle[:-4]+';(function()\n'+r.requires(tests)+'\nend)()\nend\n'
 return bundle,list(dict.fromkeys(inputs+[workerPath]+[H/x for x in ['worker-admission.luau','worker-facade.luau','reader.luau','workers-tests.luau','bridge-tests.luau']]))
def main():
 prefix=sys.argv[1];assert re.fullmatch('[a-z][a-z0-9-]*',prefix)
 out=H/(prefix+'-output.txt');assert not out.exists(),'Preserve earlier runs'
 bundle,inputs=build();sha=lambda b:hashlib.sha256(b).hexdigest()
 hashes={p.relative_to(ROOT).as_posix():sha(p.read_bytes()) for p in inputs}
 started=time.time()
 with tempfile.TemporaryDirectory(prefix='windowsill-workers-') as folder:
  path=Path(folder)/'run.luau';path.write_text(bundle,encoding='utf8',newline='\n')
  result=subprocess.run([str(TOOLS/'luau/luau.exe'),str(path)],capture_output=True,text=True,cwd=ROOT)
 output=result.stdout+result.stderr;out.write_text(output,encoding='utf8',newline='\n')
 if result.returncode:(H/(prefix+'-bundle.luau')).write_text(bundle,encoding='utf8',newline='\n')
 assert hashes=={p.relative_to(ROOT).as_posix():sha(p.read_bytes()) for p in inputs}
 receipt=dict(source=subprocess.check_output(['git','log','-1','--format=%H','--','roblox_port/src','roblox_port/tests'],cwd=ROOT,text=True).strip(),
  inputs=hashes,bundle_sha256=sha(bundle.encode()),output_sha256=sha(output.encode()),exit_code=result.returncode,elapsed_seconds=time.time()-started,
  provider='memory',clock='synthetic',reader_override=True,other_workers_typed=False,normal_startup_installed=False,native_verified=False,online_verified=False,published=False)
 (H/(prefix+'-receipt.json')).write_text(json.dumps(receipt,indent=2)+'\n',encoding='utf8',newline='\n')
 print(output,flush=True);raise SystemExit(result.returncode)
if __name__=='__main__':main()
