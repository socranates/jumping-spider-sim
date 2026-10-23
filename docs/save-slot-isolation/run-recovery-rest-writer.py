from pathlib import Path
import hashlib,importlib.util,json,subprocess,tempfile
H=Path(__file__).resolve().parent;ROOT=H.parents[1]
def build():
 spec=importlib.util.spec_from_file_location('proposal_runner',H/'run-recovery-proposal-store.py');m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m);text,inputs=m.build()
 spec=importlib.util.spec_from_file_location('runner',ROOT/'roblox_port/tests/run.py');r=importlib.util.module_from_spec(spec);spec.loader.exec_module(r)
 assert text.endswith('end\n');text=text[:-4]
 raw=H/'recovery-raw-backend-prototype.luau';module=H/'recovery-rest-writer-prototype.luau';test=H/'recovery-rest-writer-tests.luau'
 text+='local __rawBackendPrototype='+r.chunk(raw)+'\n'
 code=module.read_text().replace('require(Shared.Persistence.RecoveryArchivePrototype)','__packetArchive').replace('require(script.Parent.RecoveryPacketPrototype)','__packetPrototype')
 text+='local __restWriterPrototype=(function()\n'+r.requires(r.strict(code))+'\nend)()\n'+r.requires(test.read_text())+'\nend\n'
 return text,inputs+[raw,module,test]

def main():
 text,inputs=build();assert not (H/'recovery-rest-writer-output.txt').exists(),'Preserve previous evidence'
 with tempfile.NamedTemporaryFile('w',suffix='.luau',encoding='utf8',delete=False) as f:f.write(text);path=Path(f.name)
 try:result=subprocess.run([r'C:/Users/natha/.codex/.chatgpt-projects/g-p-6ac2f32f82a48191b0c7151a11eab0fd/roblox_tools/luau/luau.exe',str(path)],capture_output=True,text=True)
 finally:path.unlink(missing_ok=True)
 output=result.stdout+result.stderr;sha=lambda b:hashlib.sha256(b).hexdigest()
 (H/'recovery-rest-writer-output.txt').write_text(output,encoding='utf8',newline='\n')
 receipt=dict(source=subprocess.check_output(['git','log','-1','--format=%H','--','roblox_port/src','roblox_port/tests'],cwd=ROOT,text=True).strip(),exit_code=result.returncode,inputs={p.name:sha(p.read_bytes()) for p in inputs},bundle_sha256=sha(text.encode()),output_sha256=sha(output.encode()),production_connected=False,real_datastore_verified=False,native_verified=False,destination_commit_authorized=False)
 (H/'recovery-rest-writer-receipt.json').write_text(json.dumps(receipt,indent=2)+'\n',encoding='utf8',newline='\n');print(output);raise SystemExit(result.returncode)
if __name__=='__main__':main()
