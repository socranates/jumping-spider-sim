"""Private recovered save coordinator and preceding regression cohort."""
from pathlib import Path
import hashlib,importlib.util,json,subprocess,tempfile,sys
H=Path(__file__).resolve().parent;ROOT=H.parents[1]
def build():
 spec=importlib.util.spec_from_file_location('runtime_runner',H/'run-recovery-entry.py');m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m);text,inputs=m.build()
 spec=importlib.util.spec_from_file_location('runner',ROOT/'roblox_port/tests/run.py');r=importlib.util.module_from_spec(spec);spec.loader.exec_module(r)
 assert text.endswith('end\n');text=text[:-4]
 modules=[('recovery-routine-progress-prototype.luau','__routineProgressPrototype'),('recovery-save-loop-prototype.luau','__saveLoopPrototype')]
 for name,var in modules:
  code=(H/name).read_text(encoding='utf8')
  for module,target in {'RecoveryProgressPrototype':'__progressPrototype','RecoveryArchivePrototype':'__packetArchive','RecoveryArchiveStorePrototype':'__archiveStorePrototype','RecoveryPacketPrototype':'__packetPrototype','RecoveryRestFormatPrototype':'__restFormatPrototype','RecoveryProgressReconcilePrototype':'__progressReconcilePrototype','RecoveryReadLeasePrototype':'__readLeasePrototype','RecoveryRoutineProgressPrototype':'__routineProgressPrototype','RecoveryCurrentWriterPrototype':'__currentWriterPrototype'}.items():
   code=code.replace('require(Shared.Persistence.'+module+')',target).replace('require(script.Parent.'+module+')',target)
  text+='local '+var+'=(function()\n'+r.requires(r.strict(code))+'\nend)()\n'
 test=H/'recovery-save-loop-tests.luau';text+=r.requires(test.read_text(encoding='utf8'))+'\nend\n'

 return text,inputs+[H/name for name,var in modules]+[test]
def main():
 prefix=sys.argv[1] if len(sys.argv)>1 else 'recovery-save-loop';assert prefix.replace('-','').isalnum()
 text,inputs=build();out=H/(prefix+'-output.txt');assert not out.exists(),'Preserve previous evidence'
 sha=lambda b:hashlib.sha256(b).hexdigest();hashes={p.name:sha(p.read_bytes()) for p in inputs}
 with tempfile.NamedTemporaryFile('w',suffix='.luau',encoding='utf8',delete=False) as f:f.write(text);path=Path(f.name)
 try:result=subprocess.run([r'C:/Users/natha/.codex/.chatgpt-projects/g-p-6ac2f32f82a48191b0c7151a11eab0fd/roblox_tools/luau/luau.exe',str(path)],capture_output=True,text=True)
 finally:path.unlink(missing_ok=True)
 assert hashes=={p.name:sha(p.read_bytes()) for p in inputs},'Inputs changed during execution'
 output=result.stdout+result.stderr;out.write_text(output,encoding='utf8',newline='\n')
 receipt=dict(source=subprocess.check_output(['git','log','-1','--format=%H','--','roblox_port/src','roblox_port/tests'],cwd=ROOT,text=True).strip(),exit_code=result.returncode,inputs=hashes,bundle_sha256=sha(text.encode()),output_sha256=sha(output.encode()),production_connected=False,real_datastore_verified=False,native_verified=False,destination_commit_authorized=False)
 (H/(prefix+'-receipt.json')).write_text(json.dumps(receipt,indent=2)+'\n',encoding='utf8',newline='\n');print(output);raise SystemExit(result.returncode)
if __name__=='__main__':main()
