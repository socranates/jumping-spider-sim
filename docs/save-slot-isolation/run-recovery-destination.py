from pathlib import Path
import hashlib,importlib.util,json,subprocess,tempfile
H=Path(__file__).resolve().parent;ROOT=H.parents[1]
def build():
 spec=importlib.util.spec_from_file_location('life_runner',H/'run-recovery-life.py');m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m);text,inputs=m.build()
 spec=importlib.util.spec_from_file_location('runner',ROOT/'roblox_port/tests/run.py');r=importlib.util.module_from_spec(spec);spec.loader.exec_module(r)
 productionCheckpoint=ROOT/'roblox_port/src/Shared/Persistence/Checkpoint.luau';productionRest=ROOT/'roblox_port/src/Shared/Persistence/SaveRest.luau'
 text+='\nlocal __productionCheckpoint='+r.chunk(productionCheckpoint)+'\n'
 restCode=productionRest.read_text(encoding='utf8').replace('require(script.Parent.Checkpoint)','__productionCheckpoint')
 text+='local __productionRest=(function()\n'+r.requires(r.strict(restCode))+'\nend)()\n'
 module=H/'recovery-destination-prototype.luau';test=H/'recovery-destination-tests.luau'
 code=module.read_text(encoding='utf8').replace('require(script.Parent.RecoveryLifePrototype)','__lifePrototype')
 text+='\nlocal __destinationPrototype=(function()\n'+r.requires(r.strict(code))+'\nend)()\n'+r.requires(test.read_text(encoding='utf8'))+'\n'
 return text,inputs+[productionCheckpoint,productionRest,module,test]
def main():
 text,inputs=build();assert not (H/'recovery-destination-output.txt').exists(),'Preserve previous evidence'
 with tempfile.NamedTemporaryFile('w',suffix='.luau',encoding='utf8',delete=False) as f:f.write(text);path=Path(f.name)
 try:result=subprocess.run([r'C:/Users/natha/.codex/.chatgpt-projects/g-p-6ac2f32f82a48191b0c7151a11eab0fd/roblox_tools/luau/luau.exe',str(path)],capture_output=True,text=True)
 finally:path.unlink(missing_ok=True)
 output=result.stdout+result.stderr;sha=lambda b:hashlib.sha256(b).hexdigest()
 (H/'recovery-destination-output.txt').write_text(output,encoding='utf8',newline='\n')
 receipt=dict(source=subprocess.check_output(['git','log','-1','--format=%H','--','roblox_port/src','roblox_port/tests'],cwd=ROOT,text=True).strip(),exit_code=result.returncode,inputs={p.name:sha(p.read_bytes()) for p in inputs},bundle_sha256=sha(text.encode()),output_sha256=sha(output.encode()),production_connected=False,real_datastore_verified=False,native_verified=False,destination_commit_authorized=False)
 (H/'recovery-destination-receipt.json').write_text(json.dumps(receipt,indent=2)+'\n',encoding='utf8',newline='\n');print(output);raise SystemExit(result.returncode)
if __name__=='__main__':main()
