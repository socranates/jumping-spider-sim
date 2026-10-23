from pathlib import Path
import hashlib,importlib.util,json,subprocess,tempfile
H=Path(__file__).resolve().parent;ROOT=H.parents[1]
def build():
 spec=importlib.util.spec_from_file_location('commit_runner',H/'run-recovery-commit-controller.py');m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m);text,inputs=m.build()
 spec=importlib.util.spec_from_file_location('runner',ROOT/'roblox_port/tests/run.py');r=importlib.util.module_from_spec(spec);spec.loader.exec_module(r)
 assert text.endswith('end\n');text=text[:-4]
 collector=H/'recovery-source-collector-prototype.luau';controller=H/'recovery-controller-prototype.luau';module=H/'recovery-offer-reader-prototype.luau';test=H/'recovery-offer-reader-tests.luau'
 code=collector.read_text().replace('require(script.Parent.RecoveryArchivePrototype)','__packetArchive')
 text+='local __collectorPrototype=(function()\n'+r.requires(r.strict(code))+'\nend)()\n'
 code=controller.read_text()
 for name,var in [('RecoverySourceCollectorPrototype','__collectorPrototype'),('RecoveryArchiveStorePrototype','__archiveStorePrototype'),('RecoverySessionFencePrototype','__sessionFence')]:code=code.replace('require(script.Parent.'+name+')',var)
 text+='local __archiveControllerPrototype=(function()\n'+r.requires(r.strict(code))+'\nend)()\n'
 code=module.read_text()
 for name,var in [('RecoveryArchivePrototype','__packetArchive'),('RecoveryArchiveStorePrototype','__archiveStorePrototype'),('RecoveryLifePrototype','__lifePrototype')]:code=code.replace('require(Shared.Persistence.'+name+')',var)
 code=code.replace('require(script.Parent.RecoveryPacketPrototype)','__packetPrototype')
 text+='local __offerReaderPrototype=(function()\n'+r.requires(r.strict(code))+'\nend)()\n'+r.requires(test.read_text())+'\nend\n'
 return text,inputs+[collector,controller,module,test]

def main():
 text,inputs=build();assert not (H/'recovery-offer-reader-output.txt').exists(),'Preserve previous evidence'
 with tempfile.NamedTemporaryFile('w',suffix='.luau',encoding='utf8',delete=False) as f:f.write(text);path=Path(f.name)
 try:result=subprocess.run([r'C:/Users/natha/.codex/.chatgpt-projects/g-p-6ac2f32f82a48191b0c7151a11eab0fd/roblox_tools/luau/luau.exe',str(path)],capture_output=True,text=True)
 finally:path.unlink(missing_ok=True)
 output=result.stdout+result.stderr;sha=lambda b:hashlib.sha256(b).hexdigest()
 (H/'recovery-offer-reader-output.txt').write_text(output,encoding='utf8',newline='\n')
 receipt=dict(source=subprocess.check_output(['git','log','-1','--format=%H','--','roblox_port/src','roblox_port/tests'],cwd=ROOT,text=True).strip(),exit_code=result.returncode,inputs={p.name:sha(p.read_bytes()) for p in inputs},bundle_sha256=sha(text.encode()),output_sha256=sha(output.encode()),production_connected=False,real_datastore_verified=False,native_verified=False,destination_commit_authorized=False)
 (H/'recovery-offer-reader-receipt.json').write_text(json.dumps(receipt,indent=2)+'\n',encoding='utf8',newline='\n');print(output);raise SystemExit(result.returncode)
if __name__=='__main__':main()
