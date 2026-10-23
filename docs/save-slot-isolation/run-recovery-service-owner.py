"""Actual save-service owner transport and preceding recovery regression cohort."""
from pathlib import Path
import hashlib,importlib.util,json,subprocess,tempfile,sys,re
H=Path(__file__).resolve().parent;ROOT=H.parents[1]
def build(focused=False):
 spec=importlib.util.spec_from_file_location('runtime_runner',H/'run-recovery-archive-reuse.py');m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m);text,inputs=m.build()
 spec=importlib.util.spec_from_file_location('runner',ROOT/'roblox_port/tests/run.py');r=importlib.util.module_from_spec(spec);spec.loader.exec_module(r)
 assert text.endswith('end\n');text=text[:-4]
 module=H/'recovery-service-owner-prototype.luau';code=module.read_text(encoding='utf8').replace('require(script.Parent.RecoveryRuntimePrototype)','__runtimePrototype')
 text+='local __serviceOwnerPrototype=(function()\n'+r.requires(r.strict(code))+'\nend)()\n'
 test=H/'recovery-service-owner-tests.luau';text+=r.requires(test.read_text(encoding='utf8'))+'\nend\n'
 if focused:
  text=re.sub(r'\n(run\w+Checks)\(\)\nend',lambda m:'\n-- focused: skip '+m.group(1)+'\nend' if m.group(1)!='runServiceOwnerChecks' else m.group(0),text)
 return text,inputs+[module,test]

def main():
 prefix=sys.argv[1] if len(sys.argv)>1 else 'recovery-service-owner';assert prefix.replace('-','').isalnum()
 focused="--focused" in sys.argv[2:];text,inputs=build(focused);out=H/(prefix+'-output.txt');assert not out.exists(),'Preserve previous evidence'
 sha=lambda b:hashlib.sha256(b).hexdigest();hashes={p.name:sha(p.read_bytes()) for p in inputs}
 with tempfile.NamedTemporaryFile('w',suffix='.luau',encoding='utf8',delete=False) as f:f.write(text);path=Path(f.name)
 try:result=subprocess.run([r'C:/Users/natha/.codex/.chatgpt-projects/g-p-6ac2f32f82a48191b0c7151a11eab0fd/roblox_tools/luau/luau.exe',str(path)],capture_output=True,text=True)
 finally:path.unlink(missing_ok=True)
 assert hashes=={p.name:sha(p.read_bytes()) for p in inputs},'Inputs changed during execution'
 output=result.stdout+result.stderr;out.write_text(output,encoding='utf8',newline='\n')
 receipt=dict(source=subprocess.check_output(['git','log','-1','--format=%H','--','roblox_port/src','roblox_port/tests'],cwd=ROOT,text=True).strip(),exit_code=result.returncode,focused=focused,inputs=hashes,bundle_sha256=sha(text.encode()),output_sha256=sha(output.encode()),production_connected=False,real_datastore_verified=False,native_verified=False,destination_commit_authorized=False)
 (H/(prefix+'-receipt.json')).write_text(json.dumps(receipt,indent=2)+'\n',encoding='utf8',newline='\n');print(output);raise SystemExit(result.returncode)
if __name__=='__main__':main()
