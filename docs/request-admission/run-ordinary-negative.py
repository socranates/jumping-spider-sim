"""Reproduce the candidate's former rejection of valid coarse-clock sleeps."""
from pathlib import Path
import hashlib,importlib.util,json,subprocess,tempfile
H=Path(__file__).resolve().parent;ROOT=H.parents[1]
def build():
 p=H/'run-ordinary.py';s=importlib.util.spec_from_file_location('ordinary_negative_current',p);m=importlib.util.module_from_spec(s);s.loader.exec_module(m)
 bundle,paths=m.build(True);r,_,_=m.replacement()
 facade='(function()\n'+(H/'worker-facade.luau').read_text(encoding='utf8')+'\nend)()'
 op='(function()\n'+(H/'operation.luau').read_text(encoding='utf8').replace('require("./worker-facade")',facade)+'\nend)()'
 def code(path):return r.requires(r.strict(path.read_text(encoding='utf8').replace('require(script.Parent.RecoveryOperationAdmission)',op)))
 before=code(H/'ordinary-io.luau');old=H/'ordinary-before-coarse-io.luau';assert bundle.count(before)==1
 return bundle.replace(before,code(old)),list(dict.fromkeys(paths+[old]))
def main():
 prefix='ordinary-coarse-before-fix-1';out=H/(prefix+'-output.txt');assert not out.exists()
 bundle,paths=build();sha=lambda b:hashlib.sha256(b).hexdigest();inputs={p.relative_to(ROOT).as_posix():sha(p.read_bytes()) for p in paths}
 with tempfile.TemporaryDirectory(prefix='windowsill-ordinary-negative-') as tmp:
  p=Path(tmp)/'run.luau';p.write_text(bundle,encoding='utf8',newline='\n')
  r=subprocess.run([r'C:/Users/natha/.codex/.chatgpt-projects/g-p-6ac2f32f82a48191b0c7151a11eab0fd/roblox_tools/luau/luau.exe',str(p)],cwd=ROOT,capture_output=True,text=True)
 assert inputs=={p.relative_to(ROOT).as_posix():sha(p.read_bytes()) for p in paths}
 output=r.stdout+r.stderr;out.write_text(output,encoding='utf8',newline='\n');assert r.returncode!=0 and 'coarse clock wait did not finish initial load' in output
 (H/(prefix+'-receipt.json')).write_text(json.dumps(dict(inputs=inputs,bundle_sha256=sha(bundle.encode()),output_sha256=sha(output.encode()),exit_code=r.returncode,
  expected_failure='coarse clock wait did not finish initial load',only_mutation='Restore previous candidate ordinary request bridge with per-sleep clock-advance rejection',native_verified=False,published=False),indent=2)+'\n',encoding='utf8')
 print(output[-1400:]);print('EXPECTED COARSE-CLOCK FAILURE CONFIRMED')
if __name__=='__main__':main()
