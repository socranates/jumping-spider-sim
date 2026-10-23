"""Private coordinator plus all preceding private recovery regressions."""
from pathlib import Path
import hashlib,importlib.util,json,subprocess,tempfile,sys
H=Path(__file__).resolve().parent;ROOT=H.parents[1]
def build():
 spec=importlib.util.spec_from_file_location('idle_runner',H/'run-recovery-idle.py');m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m);text,inputs=m.build()
 spec=importlib.util.spec_from_file_location('runner',ROOT/'roblox_port/tests/run.py');r=importlib.util.module_from_spec(spec);spec.loader.exec_module(r)
 assert text.endswith('end\n');text=text[:-4]
 lease=H/'recovery-read-lease-prototype.luau';module=H/'recovery-runtime-prototype.luau';test=H/'recovery-runtime-tests.luau'
 text+='local __readLeasePrototype='+r.chunk(lease)+'\n'
 code=module.read_text(encoding='utf8')
 for name,var in [('RecoveryProgressBaselinePrototype','__progressBaselinePrototype'),('RecoveryOfferReaderPrototype','__offerReaderPrototype'),('RecoveryPipelinePrototype','__pipelinePrototype'),('RecoveryIdlePrototype','__idlePrototype'),('RecoveryDeparturePrototype','__departurePrototype'),('RecoveryReadLeasePrototype','__readLeasePrototype')]:code=code.replace('require(script.Parent.'+name+')',var)
 text+='local __runtimePrototype=(function()\n'+r.requires(r.strict(code))+'\nend)()\n'+r.requires(test.read_text(encoding='utf8'))+'\nend\n'
 return text,inputs+[lease,module,test]
def main():
 prefix=sys.argv[1] if len(sys.argv)>1 else 'recovery-runtime';assert prefix.replace('-','').isalnum()
 text,inputs=build();out=H/(prefix+'-output.txt');assert not out.exists(),'Preserve previous evidence'
 hashes={p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in inputs}
 with tempfile.NamedTemporaryFile('w',suffix='.luau',encoding='utf8',delete=False) as f:f.write(text);path=Path(f.name)
 try:result=subprocess.run([r'C:/Users/natha/.codex/.chatgpt-projects/g-p-6ac2f32f82a48191b0c7151a11eab0fd/roblox_tools/luau/luau.exe',str(path)],capture_output=True,text=True)
 finally:path.unlink(missing_ok=True)
 output=result.stdout+result.stderr;sha=lambda b:hashlib.sha256(b).hexdigest()
 assert hashes=={p.name:sha(p.read_bytes()) for p in inputs},'Inputs changed during execution'
 out.write_text(output,encoding='utf8',newline='\n')
 receipt=dict(source=subprocess.check_output(['git','log','-1','--format=%H','--','roblox_port/src','roblox_port/tests'],cwd=ROOT,text=True).strip(),exit_code=result.returncode,inputs=hashes,bundle_sha256=sha(text.encode()),output_sha256=sha(output.encode()),production_connected=False,real_datastore_verified=False,native_verified=False,destination_commit_authorized=False)
 (H/(prefix+'-receipt.json')).write_text(json.dumps(receipt,indent=2)+'\n',encoding='utf8',newline='\n');print(output);raise SystemExit(result.returncode)
if __name__=='__main__':main()
