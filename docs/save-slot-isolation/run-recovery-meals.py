from pathlib import Path
import argparse,hashlib,importlib.util,json,subprocess,tempfile
H=Path(__file__).resolve().parent;ROOT=H.parents[1]
def build(baseline=False):
 spec=importlib.util.spec_from_file_location('runner',ROOT/'roblox_port/tests/run.py');r=importlib.util.module_from_spec(spec);spec.loader.exec_module(r)
 manifest=json.loads((H/'recorded-inspection-manifest.json').read_text());base=r.chunk
 candidates={str((ROOT/p).resolve()):H/name for p,name in [('roblox_port/src/Shared/World/WorldMap.luau','recorded-map-candidate.luau'),('roblox_port/src/Shared/Persistence/Checkpoint.luau','recorded-checkpoint-candidate.luau')]}
 for p,digest in manifest['originals'].items():assert hashlib.sha256((ROOT/p).read_bytes()).hexdigest()==digest
 r.chunk=lambda path:base(candidates.get(str(path.resolve()),path))
 fixture=(ROOT/'roblox_port/tests/checkpoint.luau').read_text(encoding='utf8');prefix=fixture[:fixture.index('-- --------------------------------------------------------------------------------------------------------------------------')]
 garden=fixture[fixture.index('local function gardenWorld()'):fixture.index('-- Ticks the garden',fixture.index('local function gardenWorld()'))]
 deps='\nlocal WorldMap2=WorldMap\nlocal WorldBuild=require("../src/Shared/World/WorldBuild")\nlocal Garden=require("../src/Shared/World/Garden")\nlocal Woodlouse=require("../src/Shared/Prey/Woodlouse")\nlocal Region=require("../src/Shared/World/Region")\n'
 body=r.requires(fixture)+'\n';text=r.bundle('checkpoint.luau');assert text.endswith(body)
 module=H/('before-validation-recovery-meals-prototype.luau' if baseline else 'recovery-meals-prototype.luau');test=H/'recovery-meals-tests.luau'
 text=text[:-len(body)]+r.requires(prefix+deps+garden)+'\nlocal __mealsPrototype='+r.chunk(module)+'\n'+r.requires(test.read_text())+'\n'
 return text,[*candidates.values(),module,test]
def main():
 p=argparse.ArgumentParser();p.add_argument('--baseline',action='store_true');a=p.parse_args();stem='recovery-meals-negative' if a.baseline else 'recovery-meals'
 text,inputs=build(a.baseline);assert not (H/(stem+'-output.txt')).exists(),'Preserve previous evidence'
 with tempfile.NamedTemporaryFile('w',suffix='.luau',encoding='utf8',delete=False) as f:f.write(text);path=Path(f.name)
 try:result=subprocess.run([r'C:/Users/natha/.codex/.chatgpt-projects/g-p-6ac2f32f82a48191b0c7151a11eab0fd/roblox_tools/luau/luau.exe',str(path)],capture_output=True,text=True)
 finally:path.unlink(missing_ok=True)
 output=result.stdout+result.stderr;sha=lambda b:hashlib.sha256(b).hexdigest()
 (H/(stem+'-output.txt')).write_text(output,encoding='utf8',newline='\n')
 receipt=dict(source=subprocess.check_output(['git','log','-1','--format=%H','--','roblox_port/src','roblox_port/tests'],cwd=ROOT,text=True).strip(),exit_code=result.returncode,inputs={p.name:sha(p.read_bytes()) for p in inputs},bundle_sha256=sha(text.encode()),output_sha256=sha(output.encode()),production_connected=False,real_datastore_verified=False,native_verified=False,complete_projection=False)
 (H/(stem+'-receipt.json')).write_text(json.dumps(receipt,indent=2)+'\n',encoding='utf8',newline='\n');print(output);raise SystemExit(result.returncode)
if __name__=='__main__':main()
