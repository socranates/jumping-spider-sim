"""Unmodified STATE/STATE_CLIENT against private Session and service candidates."""
from pathlib import Path
import hashlib,importlib.util,json,subprocess,sys,tempfile,time
H=Path(__file__).resolve().parent;ROOT=H.parents[1];sha=lambda b:hashlib.sha256(b).hexdigest()
def build(test):
 s=importlib.util.spec_from_file_location('service_state_base',H/'run-ordinary-state.py');m=importlib.util.module_from_spec(s);s.loader.exec_module(m)
 bundle,paths=m.build(test)
 t=importlib.util.spec_from_file_location('service_state_core',ROOT/'roblox_port/tests/run.py');r=importlib.util.module_from_spec(t);t.loader.exec_module(r)
 facade='(function()\n'+(H/'worker-facade.luau').read_text(encoding='utf8')+'\nend)()'
 operation='(function()\n'+(H/'operation.luau').read_text(encoding='utf8').replace('require("./worker-facade")',facade)+'\nend)()'
 def io(path):return r.requires(r.strict(path.read_text(encoding='utf8').replace('require(script.Parent.RecoveryOperationAdmission)',operation)))
 before=io(H/'ordinary-io.luau');assert bundle.count(before)==1;bundle=bundle.replace(before,io(H/'ordinary-io-service.luau'))
 before=r.requires(r.strict((ROOT/'roblox_port/src/Server/SaveService.luau').read_text(encoding='utf8')));assert bundle.count(before)==1
 bundle=bundle.replace(before,r.requires(r.strict((H/'save-service.luau').read_text(encoding='utf8'))))
 return bundle,list(dict.fromkeys(paths+[H/'ordinary-io-service.luau',H/'save-service.luau']))
def main():
 prefix=sys.argv[1]
 for test in ['state.luau','state_client.luau']:
  case=Path(test).stem.replace('_','-');out=H/(prefix+'-'+case+'-output.txt');assert not out.exists()
  bundle,paths=build(test);inputs={p.relative_to(ROOT).as_posix():sha(p.read_bytes()) for p in paths};started=time.time()
  with tempfile.TemporaryDirectory(prefix='windowsill-service-state-') as tmp:
   p=Path(tmp)/'run.luau';p.write_text(bundle,encoding='utf8',newline='\n')
   r=subprocess.run([r'C:/Users/natha/.codex/.chatgpt-projects/g-p-6ac2f32f82a48191b0c7151a11eab0fd/roblox_tools/luau/luau.exe',str(p)],cwd=ROOT,capture_output=True,text=True)
  assert inputs=={p.relative_to(ROOT).as_posix():sha(p.read_bytes()) for p in paths}
  output=r.stdout+r.stderr;out.write_text(output,encoding='utf8',newline='\n')
  if r.returncode:(H/(prefix+'-'+case+'-bundle.luau')).write_text(bundle,encoding='utf8',newline='\n')
  receipt=dict(test=test,inputs=inputs,bundle_sha256=sha(bundle.encode()),output_sha256=sha(output.encode()),exit_code=r.returncode,
   elapsed_seconds=time.time()-started,private_service_and_Session=True,account_gate_installed_in_this_legacy_test=False,native_verified=False,published=False)
  (H/(prefix+'-'+case+'-receipt.json')).write_text(json.dumps(receipt,indent=2)+'\n',encoding='utf8',newline='\n');print(output);assert r.returncode==0
if __name__=='__main__':main()
