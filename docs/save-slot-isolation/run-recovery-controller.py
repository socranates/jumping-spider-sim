from pathlib import Path
import argparse,hashlib,importlib.util,json,subprocess,tempfile
H=Path(__file__).resolve().parent;ROOT=H.parents[1]
spec=importlib.util.spec_from_file_location('runner',ROOT/'roblox_port/tests/run.py');r=importlib.util.module_from_spec(spec);spec.loader.exec_module(r)
def build(baseline=False):
 state=(ROOT/'roblox_port/tests/state.luau').read_text();suffix=r.requires(state)+'\n';text=r.bundle('state.luau');assert text.endswith(suffix)
 prefix=state.split('-- ---------------------------------------------------------------------------------------------- sizes, measured')[0]
 modules=[('recovery-archive-prototype.luau','__archivePrototype','RecoveryArchivePrototype'),('recovery-source-collector-prototype.luau','__collectorPrototype','RecoverySourceCollectorPrototype'),('recovery-archive-store-prototype.luau','__archiveStorePrototype','RecoveryArchiveStorePrototype'),('recovery-session-fence-prototype.luau','__sessionFence','RecoverySessionFencePrototype'),('recovery-controller-prototype.luau','__controllerPrototype','RecoveryControllerPrototype')]
 if baseline:modules[-1]=('before-heartbeat-recovery-controller-prototype.luau','__controllerPrototype','RecoveryControllerPrototype')
 prelude=''
 for name,var,_ in modules:
  code=(H/name).read_text()
  for _,other,module in modules:code=code.replace('require(script.Parent.'+module+')',other)
  prelude+='local '+var+'=(function()\n'+r.requires(r.strict(code))+'\nend)()\n'
 test=H/('recovery-controller-negative-tests.luau' if baseline else 'recovery-controller-tests.luau')
 return text[:-len(suffix)]+r.requires(prefix)+'\n'+prelude+test.read_text(),[H/name for name,_,_ in modules]+[test]
def main():
 p=argparse.ArgumentParser();p.add_argument('--baseline',action='store_true');a=p.parse_args();stem='recovery-controller-negative' if a.baseline else 'recovery-controller'
 text,inputs=build(a.baseline);assert not (H/(stem+'-output.txt')).exists(),'Preserve previous evidence'
 with tempfile.NamedTemporaryFile('w',suffix='.luau',encoding='utf8',delete=False) as f:f.write(text);path=Path(f.name)
 try:result=subprocess.run([r'C:/Users/natha/.codex/.chatgpt-projects/g-p-6ac2f32f82a48191b0c7151a11eab0fd/roblox_tools/luau/luau.exe',str(path)],capture_output=True,text=True)
 finally:path.unlink(missing_ok=True)
 output=result.stdout+result.stderr;sha=lambda b:hashlib.sha256(b).hexdigest()
 (H/(stem+'-output.txt')).write_text(output,encoding='utf8',newline='\n')
 receipt=dict(source=subprocess.check_output(['git','log','-1','--format=%H','--','roblox_port/src','roblox_port/tests'],cwd=ROOT,text=True).strip(),exit_code=result.returncode,inputs={p.name:sha(p.read_bytes()) for p in inputs},bundle_sha256=sha(text.encode()),output_sha256=sha(output.encode()),production_connected=False,real_datastore_verified=False,native_verified=False,destination_commit_authorized=False)
 (H/(stem+'-receipt.json')).write_text(json.dumps(receipt,indent=2)+'\n',encoding='utf8',newline='\n');print(output);raise SystemExit(result.returncode)
if __name__=='__main__':main()
