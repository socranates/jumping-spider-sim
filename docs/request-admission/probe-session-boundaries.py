"""Bounded actual-Session counterexamples; no recovery overlay and no real store."""
from pathlib import Path
import hashlib,importlib.util,json,re,subprocess,sys,tempfile
H=Path(__file__).resolve().parent;ROOT=H.parents[1];sha=lambda b:hashlib.sha256(b).hexdigest()
def build(case):
 path=ROOT/'roblox_port/tests/run.py';spec=importlib.util.spec_from_file_location('session_boundary_runner',path);r=importlib.util.module_from_spec(spec);spec.loader.exec_module(r)
 test=H/'session-boundary-tests.luau';base=ROOT/'docs/save-slot-isolation/recovery-progress-baseline-prototype.luau'
 bundle=r.bundle(str(test))
 assert bundle.count('__boundaryBaseline')==1 and bundle.count('__boundaryCase')==1
 bundle=bundle.replace('__boundaryBaseline','(function()\n'+r.requires(r.strict(base.read_text(encoding='utf8')))+'\nend)()').replace('__boundaryCase',json.dumps(case))
 paths=[path,test,base,r.HERE/'shim.luau']+[r.SRC/rel for _,rel in r.MODULES]
 paths += [r.HERE/(ref+'.luau') for ref in r.REFERENCES if str(test) in r.REFERENCE_ONLY.get(ref,{str(test)})]
 return bundle,list(dict.fromkeys(paths))
def main():
 prefix=sys.argv[1];assert re.fullmatch('[a-z][a-z0-9-]*',prefix)
 for case,problem in [('late-lock','initial load reported active with an already expired stored lease'),('read-account','in-flight initial rest read is absent from request accounting')]:
  out=H/(prefix+'-'+case+'-output.txt');assert not out.exists()
  bundle,paths=build(case);inputs={p.relative_to(ROOT).as_posix():sha(p.read_bytes()) for p in paths}
  with tempfile.TemporaryDirectory(prefix='windowsill-session-boundary-') as tmp:
   p=Path(tmp)/'run.luau';p.write_text(bundle,encoding='utf8',newline='\n')
   r=subprocess.run([r'C:/Users/natha/.codex/.chatgpt-projects/g-p-6ac2f32f82a48191b0c7151a11eab0fd/roblox_tools/luau/luau.exe',str(p)],cwd=ROOT,capture_output=True,text=True)
  assert inputs=={p.relative_to(ROOT).as_posix():sha(p.read_bytes()) for p in paths}
  output=r.stdout+r.stderr;out.write_text(output,encoding='utf8',newline='\n')
  assert r.returncode!=0 and problem in output and 'fixed=true' not in output
  receipt=dict(case=case,inputs=inputs,bundle_sha256=sha(bundle.encode()),output_sha256=sha(output.encode()),exit_code=r.returncode,expected_failure=problem,
   factory_baseline_bound=True,issue_fixed=False,provider='memory',clock='synthetic',native_verified=False,published=False)
  (H/(prefix+'-'+case+'-receipt.json')).write_text(json.dumps(receipt,indent=2)+'\n',encoding='utf8',newline='\n')
  print(output[-1700:]);print('EXPECTED UNFIXED BOUNDARY REPRODUCED',case)
if __name__=='__main__':main()
