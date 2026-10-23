"""Run the existing presentation suite with only the private pond candidate substituted."""
from pathlib import Path
import hashlib,importlib.util,json,subprocess,tempfile
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[1]
spec=importlib.util.spec_from_file_location('runner',ROOT/'roblox_port/tests/run.py')
r=importlib.util.module_from_spec(spec);spec.loader.exec_module(r)
m=json.loads((HERE/'pond-candidate.json').read_text(encoding='utf8'))
original=ROOT/m['path'];candidate=HERE/'pond-candidate.luau'
assert hashlib.sha256(original.read_bytes()).hexdigest()==m['reference_sha256']
assert hashlib.sha256(candidate.read_bytes()).hexdigest()==m['candidate_sha256']
base_chunk=r.chunk
def chunk(path):return base_chunk(candidate if path.resolve()==original.resolve() else path)
r.chunk=chunk
cli=Path(r'C:/Users/natha/.codex/.chatgpt-projects/g-p-6ac2f32f82a48191b0c7151a11eab0fd/roblox_tools/luau/luau.exe')
with tempfile.NamedTemporaryFile('w',suffix='.luau',encoding='utf8',delete=False) as f:f.write(r.bundle('bodies.luau'));test=Path(f.name)
try:result=subprocess.run([str(cli),str(test)],capture_output=True,text=True)
finally:test.unlink(missing_ok=True)
output=result.stdout+result.stderr
(HERE/'pond-existing.txt').write_text(output,encoding='utf8',newline='\n')
receipt=dict(source=m['source'],reference_sha256=m['reference_sha256'],candidate_sha256=m['candidate_sha256'],
 exit_code=result.returncode,output_sha256=hashlib.sha256(output.encode()).hexdigest(),
 scope='Existing bodies.luau suite under CLI, with only private candidate substitution; production files untouched',adopted=False)
(HERE/'pond-existing.json').write_text(json.dumps(receipt,indent=2)+'\n',encoding='utf8',newline='\n')
assert hashlib.sha256(original.read_bytes()).hexdigest()==m['reference_sha256']
print(output);raise SystemExit(result.returncode)
