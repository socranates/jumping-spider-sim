"""Actual-game recovery adoption plus the entire preceding private cohort."""
from pathlib import Path
import hashlib,importlib.util,json,subprocess,tempfile,sys,re
H=Path(__file__).resolve().parent;ROOT=H.parents[1]
def build(focused=False,baseline=False,deadline_only=False,test_path=None):
 spec=importlib.util.spec_from_file_location('runtime_runner',H/'run-recovery-service-owner.py');m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m);text,inputs=m.build()
 spec=importlib.util.spec_from_file_location('runner',ROOT/'roblox_port/tests/run.py');r=importlib.util.module_from_spec(spec);spec.loader.exec_module(r)
 assert text.endswith('end\n');text=text[:-4]
 module=H/('before-deadline-recovery-game-entry-prototype.luau' if baseline else 'recovery-game-entry-prototype.luau');code=module.read_text(encoding='utf8').replace('require(Shared.Persistence.RecoveryEntryClientPrototype)','__entryClientPrototype')
 text+='local __gameEntryPrototype=(function()\n'+r.requires(r.strict(code))+'\nend)()\n'
 for name,relative in r.CLIENT_MODULES:
  text+='__mods.'+name+' = '+r.chunk(r.SRC/relative)+'\n'
 test=test_path or H/'recovery-game-entry-tests.luau';body=test.read_text(encoding='utf8')
 if deadline_only:
  body=body.split('for _,mode in Rules.MODES do for _,stage',1)[0]+body[body.index('-- Deadline callback race:'):]
 text+=r.requires(body)+'\nend\n'
 if focused:
  text=re.sub(r'\n(run\w+Checks)\(\)\nend',lambda m:'\n-- focused: skip '+m.group(1)+'\nend' if m.group(1)!='runActualGameEntryChecks' else m.group(0),text)
 return text,inputs+[module,test]+[r.SRC/relative for _,relative in r.CLIENT_MODULES]+[ROOT/"roblox_port/src/Client/SpiderClient.client.luau"]

def main():
 prefix=sys.argv[1] if len(sys.argv)>1 else 'recovery-game-entry';assert prefix.replace('-','').isalnum()
 focused="--focused" in sys.argv[2:];baseline="--baseline-deadline" in sys.argv[2:];deadline_only="--deadline-only" in sys.argv[2:]
 text,inputs=build(focused,baseline,deadline_only);out=H/(prefix+'-output.txt');assert not out.exists(),'Preserve previous evidence'
 sha=lambda b:hashlib.sha256(b).hexdigest();hashes={p.relative_to(ROOT).as_posix():sha(p.read_bytes()) for p in inputs}
 production={p.relative_to(ROOT).as_posix():sha(p.read_bytes()) for folder in ['roblox_port/src','roblox_port/tests'] for p in (ROOT/folder).rglob('*') if p.is_file() and '__pycache__' not in p.parts}
 with tempfile.NamedTemporaryFile('w',suffix='.luau',encoding='utf8',delete=False) as f:f.write(text);path=Path(f.name)
 try:result=subprocess.run([r'C:/Users/natha/.codex/.chatgpt-projects/g-p-6ac2f32f82a48191b0c7151a11eab0fd/roblox_tools/luau/luau.exe',str(path)],capture_output=True,text=True)
 finally:path.unlink(missing_ok=True)
 assert hashes=={p.relative_to(ROOT).as_posix():sha(p.read_bytes()) for p in inputs},'Inputs changed during execution'
 assert production=={p.relative_to(ROOT).as_posix():sha(p.read_bytes()) for folder in ['roblox_port/src','roblox_port/tests'] for p in (ROOT/folder).rglob('*') if p.is_file() and '__pycache__' not in p.parts},'Production changed during execution'
 output=result.stdout+result.stderr;out.write_text(output,encoding='utf8',newline='\n')
 receipt=dict(source=subprocess.check_output(['git','log','-1','--format=%H','--','roblox_port/src','roblox_port/tests'],cwd=ROOT,text=True).strip(),exit_code=result.returncode,focused=focused,baseline=baseline,deadline_only=deadline_only,inputs=hashes,production_inputs=production,bundle_sha256=sha(text.encode()),output_sha256=sha(output.encode()),production_connected=False,real_datastore_verified=False,native_verified=False,destination_commit_authorized=False)
 (H/(prefix+'-receipt.json')).write_text(json.dumps(receipt,indent=2)+'\n',encoding='utf8',newline='\n');print(output);raise SystemExit(result.returncode)
if __name__=='__main__':main()
