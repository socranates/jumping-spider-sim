from pathlib import Path
import hashlib,importlib.util,json,re,subprocess,tempfile
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[1]
spec=importlib.util.spec_from_file_location('runner',ROOT/'roblox_port/tests/run.py')
r=importlib.util.module_from_spec(spec);spec.loader.exec_module(r)
module=ROOT/'roblox_port/src/Shared/Persistence/Checkpoint.luau';original=module.read_bytes()
helper=(HERE/'spatial-validator-candidate.luau').read_text(encoding='utf8')
marker='local function checkWorld('
old='if typeof(f.position) ~= "Vector3" and type(f.position) ~= "table" then bad(`{label}: {f.id} has no position`) end'
new='if not finiteVector(f.position) then bad(`{label}: {f.id} has no finite vector position`) end'
text=original.decode('utf8');assert text.count(marker)==text.count(old)==1
text=text.replace(marker,helper+'\n'+marker).replace(old,new)
base_chunk=r.chunk
def chunk(path):
 if path.resolve()!=module.resolve():return base_chunk(path)
 return '(function()\n'+r.requires(r.strict(text))+'\nend)()'
r.chunk=chunk
name='../../docs/save-slot-isolation/spatial-validation-probe.luau'
cli=Path(r'C:/Users/natha/.codex/.chatgpt-projects/g-p-6ac2f32f82a48191b0c7151a11eab0fd/roblox_tools/luau/luau.exe')
with tempfile.NamedTemporaryFile('w',suffix='.luau',encoding='utf8',delete=False) as f:
 f.write(r.bundle(name));test=Path(f.name)
try:result=subprocess.run([str(cli),str(test)],capture_output=True,text=True)
finally:test.unlink(missing_ok=True)
output=result.stdout+result.stderr;assert module.read_bytes()==original
cases=re.findall(r'^SPATIAL_CASE\s+(\w+)\s+(ACCEPTED|REFUSED)',output,re.M)
assert result.returncode==0 and len(cases)==5 and all(c[1]=='REFUSED' for c in cases),output
(HERE/'spatial-candidate.txt').write_text(output,encoding='utf8',newline='\n')
receipt=dict(source_sha256=hashlib.sha256(original).hexdigest(),candidate_module_sha256=hashlib.sha256(text.encode()).hexdigest(),
 helper_sha256=hashlib.sha256(helper.encode()).hexdigest(),probe_sha256=hashlib.sha256((HERE/'spatial-validation-probe.luau').read_bytes()).hexdigest(),
 output_sha256=hashlib.sha256(output.encode()).hexdigest(),exit_code=result.returncode,invalid_positions_refused=5,valid_controls=2,
 integrated=False,production_changed=False,scope='Private Checkpoint fly-position validator; no generic graph-format or live-save changes')
(HERE/'spatial-candidate.json').write_text(json.dumps(receipt,indent=2)+'\n',encoding='utf8',newline='\n')
print(output)
