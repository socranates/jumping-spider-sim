"""Qualify actual game recovery menus and replacement callbacks with real adapters."""
from pathlib import Path
import hashlib,importlib.util,json,re,subprocess,sys,tempfile
H=Path(__file__).resolve().parent;ROOT=H.parents[1]
TOOLS=Path(r'C:/Users/natha/.codex/.chatgpt-projects/g-p-6ac2f32f82a48191b0c7151a11eab0fd/roblox_tools')
def load(name,path):
 spec=importlib.util.spec_from_file_location(name,path);m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m);return m
def build(focused=False):
 prior=load('templates_application_base',ROOT/'docs/server-recovery-templates/run-private.py')
 runner=load('application_game_runner',ROOT/'roblox_port/tests/run.py')
 bundle,inputs,_=prior.build();assert bundle.endswith('end\n')
 test=H/'application-tests.luau'
 bundle=bundle[:-4]+runner.requires(test.read_text(encoding='utf8'))+'\nend\n'
 if focused:
  bundle=re.sub(r'\n(run\w+Checks)\(\)\nend',lambda m:'\n-- focused: skip '+m[1]+'\nend' if m[1]!='runApplicationGameChecks' else m[0],bundle)
 return bundle,list(dict.fromkeys(inputs+[test,ROOT/'roblox_port/src/Client/RecoveryApplication.luau']))
def main():
 prefix=sys.argv[1];assert prefix.replace('-','').isalnum();focused='--focused' in sys.argv[2:]
 out=H/(prefix+'-output.txt');assert not out.exists(),'Preserve prior evidence'
 bundle,inputs=build(focused);sha=lambda b:hashlib.sha256(b).hexdigest()
 hashes={p.relative_to(ROOT).as_posix():sha(p.read_bytes()) for p in inputs}
 production={p.relative_to(ROOT).as_posix():sha(p.read_bytes()) for folder in ['roblox_port/src','roblox_port/tests'] for p in (ROOT/folder).rglob('*') if p.is_file() and '__pycache__' not in p.parts}
 with tempfile.NamedTemporaryFile('w',suffix='.luau',encoding='utf8',delete=False) as f:f.write(bundle);path=Path(f.name)
 try:result=subprocess.run([str(TOOLS/'luau/luau.exe'),str(path)],capture_output=True,text=True)
 finally:path.unlink(missing_ok=True)
 assert hashes=={p.relative_to(ROOT).as_posix():sha(p.read_bytes()) for p in inputs}
 assert production=={p:sha((ROOT/p).read_bytes()) for p in production}
 output=result.stdout+result.stderr;out.write_text(output,encoding='utf8',newline='\n')
 dirty=subprocess.run(['git','diff','--quiet','HEAD','--','roblox_port/src','roblox_port/tests'],cwd=ROOT).returncode!=0
 r=dict(source=subprocess.check_output(['git','log','-1','--format=%H','--','roblox_port/src','roblox_port/tests'],cwd=ROOT,text=True).strip(),source_uncommitted=dirty,focused=focused,exit_code=result.returncode,inputs=hashes,production_inputs=production,bundle_sha256=sha(bundle.encode()),output_sha256=sha(output.encode()),ordinary_startup_recovery_enabled=False,actual_game_callbacks_used=True,native_verified=False,real_datastore_verified=False,published=False)
 (H/(prefix+'-receipt.json')).write_text(json.dumps(r,indent=2)+'\n',encoding='utf8',newline='\n');print(output,flush=True);raise SystemExit(result.returncode)
if __name__=='__main__':main()
