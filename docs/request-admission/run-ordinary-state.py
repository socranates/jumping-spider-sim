"""Unmodified ordinary save/service regressions with only the candidate Session."""
from pathlib import Path
import hashlib,importlib.util,json,subprocess,sys,tempfile,time
H=Path(__file__).resolve().parent;ROOT=H.parents[1];sha=lambda b:hashlib.sha256(b).hexdigest()
def build(test):
 p=H/'run-ordinary.py';s=importlib.util.spec_from_file_location('ordinary_state_override',p);m=importlib.util.module_from_spec(s);s.loader.exec_module(m)
 r,before,after=m.replacement();bundle=r.bundle(test);assert bundle.count(before)==1;bundle=bundle.replace(before,after)
 paths=[ROOT/'roblox_port/tests/run.py',r.HERE/test,r.HERE/'shim.luau',H/'ordinary-session.luau',H/'ordinary-io.luau',H/'operation.luau',H/'worker-facade.luau']
 paths += [r.SRC/rel for _,rel in r.MODULES+(r.CLIENT_MODULES if test in r.CLIENT_TESTS else [])]
 paths += [r.HERE/(ref+'.luau') for ref in r.REFERENCES if test in r.REFERENCE_ONLY.get(ref,{test})]
 return bundle,list(dict.fromkeys(paths))
def main():
 prefix=sys.argv[1]
 for test in ['state.luau','state_client.luau']:
  case=Path(test).stem.replace('_','-');out=H/(prefix+'-'+case+'-output.txt');assert not out.exists()
  bundle,paths=build(test);inputs={p.relative_to(ROOT).as_posix():sha(p.read_bytes()) for p in paths};started=time.time()
  with tempfile.TemporaryDirectory(prefix='windowsill-ordinary-state-') as tmp:
   p=Path(tmp)/'run.luau';p.write_text(bundle,encoding='utf8',newline='\n')
   result=subprocess.run([r'C:/Users/natha/.codex/.chatgpt-projects/g-p-6ac2f32f82a48191b0c7151a11eab0fd/roblox_tools/luau/luau.exe',str(p)],cwd=ROOT,capture_output=True,text=True)
  assert inputs=={p.relative_to(ROOT).as_posix():sha(p.read_bytes()) for p in paths}
  output=result.stdout+result.stderr;out.write_text(output,encoding='utf8',newline='\n')
  if result.returncode:(H/(prefix+'-'+case+'-bundle.luau')).write_text(bundle,encoding='utf8',newline='\n')
  receipt=dict(inputs=inputs,bundle_sha256=sha(bundle.encode()),output_sha256=sha(output.encode()),exit_code=result.returncode,elapsed_seconds=time.time()-started,
   test=test,ordinary_candidate=True,admission_installed_in_service=False,native_verified=False,published=False)
  (H/(prefix+'-'+case+'-receipt.json')).write_text(json.dumps(receipt,indent=2)+'\n',encoding='utf8',newline='\n');print(output);assert result.returncode==0
if __name__=='__main__':main()
