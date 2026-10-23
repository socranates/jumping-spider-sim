"""Replay unchanged correctness assertions against the ordinary Session candidate."""
from pathlib import Path
import hashlib,importlib.util,json,subprocess,tempfile,sys
H=Path(__file__).resolve().parent;ROOT=H.parents[1];sha=lambda b:hashlib.sha256(b).hexdigest()
def load(name,path):
 s=importlib.util.spec_from_file_location(name,path);m=importlib.util.module_from_spec(s);s.loader.exec_module(m);return m
def build(case):
 old=load('ordinary_boundary_prior',H/'probe-session-boundaries.py');bundle,paths=old.build(case)
 new=load('ordinary_boundary_override',H/'run-ordinary.py');_,before,after=new.replacement();assert bundle.count(before)==1
 return bundle.replace(before,after),list(dict.fromkeys(paths+[H/'ordinary-session.luau',H/'ordinary-io.luau',H/'operation.luau',H/'worker-facade.luau']))
def main():
 prefix=sys.argv[1]
 for case in ['late-lock','read-account']:
  out=H/(prefix+'-'+case+'-output.txt');assert not out.exists();bundle,paths=build(case);inputs={p.relative_to(ROOT).as_posix():sha(p.read_bytes()) for p in paths}
  with tempfile.TemporaryDirectory(prefix='windowsill-ordinary-boundary-') as tmp:
   p=Path(tmp)/'run.luau';p.write_text(bundle,encoding='utf8',newline='\n')
   r=subprocess.run([r'C:/Users/natha/.codex/.chatgpt-projects/g-p-6ac2f32f82a48191b0c7151a11eab0fd/roblox_tools/luau/luau.exe',str(p)],cwd=ROOT,capture_output=True,text=True)
  assert inputs=={p.relative_to(ROOT).as_posix():sha(p.read_bytes()) for p in paths}
  output=r.stdout+r.stderr;out.write_text(output,encoding='utf8',newline='\n')
  receipt=dict(inputs=inputs,bundle_sha256=sha(bundle.encode()),output_sha256=sha(output.encode()),exit_code=r.returncode,case=case,issue_fixed=r.returncode==0,native_verified=False,published=False)
  (H/(prefix+'-'+case+'-receipt.json')).write_text(json.dumps(receipt,indent=2)+'\n',encoding='utf8',newline='\n');print(output);assert r.returncode==0 and 'fixed=true' in output
if __name__=='__main__':main()
