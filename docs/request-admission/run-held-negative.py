"""Replace only held maintenance with its preceding untyped implementation."""
from pathlib import Path
import hashlib,importlib.util,json,subprocess,tempfile
H=Path(__file__).resolve().parent;ROOT=H.parents[1]
def load(name,path):
 s=importlib.util.spec_from_file_location(name,path);m=importlib.util.module_from_spec(s);s.loader.exec_module(m);return m
def build():
 m=load('held_negative_current',H/'run-held.py');r=load('held_negative_runner',ROOT/'roblox_port/tests/run.py');bundle,paths=m.build(True)
 facade='(function()\n'+(H/'worker-facade.luau').read_text(encoding='utf8')+'\nend)()'
 operation='(function()\n'+(H/'operation.luau').read_text(encoding='utf8').replace('require("./worker-facade")',facade)+'\nend)()'
 current=r.requires(r.strict((H/'idle.luau').read_text(encoding='utf8').replace('require(Shared.Persistence.RecoveryOperationAdmission)',operation)))
 old=r.requires(r.strict((ROOT/'docs/save-slot-isolation/recovery-idle-prototype.luau').read_text(encoding='utf8')))
 assert bundle.count(current)==1;return bundle.replace(current,old),paths
def main():
 prefix='held-before-admission-negative-1';out=H/(prefix+'-output.txt');assert not out.exists()
 bundle,paths=build();sha=lambda b:hashlib.sha256(b).hexdigest();inputs={p.relative_to(ROOT).as_posix():sha(p.read_bytes()) for p in paths}
 with tempfile.TemporaryDirectory(prefix='windowsill-held-negative-') as tmp:
  p=Path(tmp)/'run.luau';p.write_text(bundle,encoding='utf8',newline='\n')
  r=subprocess.run([r'C:/Users/natha/.codex/.chatgpt-projects/g-p-6ac2f32f82a48191b0c7151a11eab0fd/roblox_tools/luau/luau.exe',str(p)],cwd=ROOT,capture_output=True,text=True)
 assert inputs=={p.relative_to(ROOT).as_posix():sha(p.read_bytes()) for p in paths}
 output=r.stdout+r.stderr;out.write_text(output,encoding='utf8',newline='\n');assert r.returncode!=0 and 'zero capacity held worker started provider' in output
 receipt=dict(inputs=inputs,bundle_sha256=sha(bundle.encode()),output_sha256=sha(output.encode()),exit_code=r.returncode,
  expected_failure='zero capacity held worker started provider',only_mutation='Restore preceding untyped held worker while Runtime supplies a typed lane',native_verified=False,published=False)
 (H/(prefix+'-receipt.json')).write_text(json.dumps(receipt,indent=2)+'\n',encoding='utf8',newline='\n');print(output[-1400:]);print('EXPECTED HELD ADMISSION FAILURE CONFIRMED')
if __name__=='__main__':main()
