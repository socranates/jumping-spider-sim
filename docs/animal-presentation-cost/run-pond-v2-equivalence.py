from pathlib import Path
import hashlib,importlib.util,json,subprocess,tempfile
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[1]
spec=importlib.util.spec_from_file_location('runner',ROOT/'roblox_port/tests/run.py')
r=importlib.util.module_from_spec(spec);spec.loader.exec_module(r)
name='../../docs/animal-presentation-cost/pond-v2-equivalence.luau';r.CLIENT_TESTS.add(name)
metadata=json.loads((HERE/'pond-candidate-v2.json').read_text(encoding='utf8'))
reference=HERE/'pond-reference.luau';candidate=HERE/'pond-candidate-v2.luau'
assert hashlib.sha256(reference.read_bytes()).hexdigest()==metadata['reference_sha256']
assert hashlib.sha256(candidate.read_bytes()).hexdigest()==metadata['candidate_sha256']
body=(HERE/'pond-v2-equivalence.luau').read_text(encoding='utf8')
text=r.bundle(name);assert text.endswith(r.requires(body)+'\n')
text=text[:-len(r.requires(body)+'\n')]
text+='local __pondReference='+r.chunk(reference)+'\nlocal __pondCandidate='+r.chunk(candidate)+'\n'+r.requires(body)+'\n'
cli=Path(r'C:/Users/natha/.codex/.chatgpt-projects/g-p-6ac2f32f82a48191b0c7151a11eab0fd/roblox_tools/luau/luau.exe')
with tempfile.NamedTemporaryFile('w',suffix='.luau',encoding='utf8',delete=False) as f:f.write(text);test=Path(f.name)
try:result=subprocess.run([str(cli),str(test)],capture_output=True,text=True)
finally:test.unlink(missing_ok=True)
output=result.stdout+result.stderr
(HERE/'pond-v2-equivalence.txt').write_text(output,encoding='utf8',newline='\n')
receipt=dict(source=metadata['source'],reference_sha256=metadata['reference_sha256'],candidate_sha256=metadata['candidate_sha256'],
 test_sha256=hashlib.sha256(body.encode()).hexdigest(),output_sha256=hashlib.sha256(output.encode()).hexdigest(),exit_code=result.returncode,
 scope='Exact part properties/transforms and ownership under CLI emulation, full/low tiers; no native rendering/performance proof',adopted=False)
(HERE/'pond-v2-equivalence.json').write_text(json.dumps(receipt,indent=2)+'\n',encoding='utf8',newline='\n')
print(output);raise SystemExit(result.returncode)
