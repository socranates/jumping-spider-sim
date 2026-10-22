"""Inject a private candidate into a CLI bundle; leave all production files intact."""
from pathlib import Path
import hashlib,importlib.util,json,subprocess,tempfile
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[1]
spec=importlib.util.spec_from_file_location('runner',ROOT/'roblox_port/tests/run.py')
r=importlib.util.module_from_spec(spec);spec.loader.exec_module(r)
runtime=ROOT/'roblox_port/src/Shared/World/WorldMap.luau'
original=runtime.read_bytes();candidate=(HERE/'map-view-prototype.luau').read_text(encoding='utf8')
base_chunk=r.chunk
def chunk(path):
 if path.resolve()!=runtime.resolve():return base_chunk(path)
 text=path.read_text(encoding='utf8');marker='return table.freeze(WorldMap)'
 assert text.count(marker)==1
 return '(function()\n'+r.requires(r.strict(text.replace(marker,candidate+'\n'+marker)))+'\nend)()'
r.chunk=chunk
name='../../docs/save-slot-isolation/map-view-tests.luau'
cli=Path(r'C:/Users/natha/.codex/.chatgpt-projects/g-p-6ac2f32f82a48191b0c7151a11eab0fd/roblox_tools/luau/luau.exe')
with tempfile.NamedTemporaryFile('w',suffix='.luau',encoding='utf8',delete=False) as f:
 f.write(r.bundle(name));test=Path(f.name)
try:result=subprocess.run([str(cli),str(test)],capture_output=True,text=True)
finally:test.unlink(missing_ok=True)
assert runtime.read_bytes()==original,'production file changed'
text=result.stdout+result.stderr
(HERE/'map-view-output.txt').write_text(text,encoding='utf8',newline='\n')
receipt=dict(source_sha256=hashlib.sha256(original).hexdigest(),candidate_sha256=hashlib.sha256(candidate.encode()).hexdigest(),
 exit_code=result.returncode,production_changed=False,integrated=False,migration_implemented=False,
 scope='Private map-view CLI prototype only; no Checkpoint or save schema changes')
(HERE/'map-view-receipt.json').write_text(json.dumps(receipt,indent=2)+'\n',encoding='utf8',newline='\n')
print(text);raise SystemExit(result.returncode)
