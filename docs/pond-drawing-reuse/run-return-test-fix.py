from pathlib import Path
import hashlib,importlib.util,json,subprocess,tempfile,sys
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[1]
spec=importlib.util.spec_from_file_location('runner',ROOT/'roblox_port/tests/run.py')
r=importlib.util.module_from_spec(spec);spec.loader.exec_module(r)
name='client_smoke.luau';original=(ROOT/'roblox_port/tests'/name).read_bytes()
candidate=(HERE/'client-smoke-snapshot-candidate.luau').read_text(encoding='utf8')
m=json.loads((HERE/'return-test-candidate.json').read_text())
assert hashlib.sha256(original).hexdigest()==m['original_sha256']
assert hashlib.sha256(candidate.encode()).hexdigest()==m['candidate_sha256']
text=r.bundle(name);body=r.requires(original.decode())+'\n';assert text.endswith(body)
text=text[:-len(body)]+r.requires(candidate)+'\n'
cli=Path(r'C:/Users/natha/.codex/.chatgpt-projects/g-p-6ac2f32f82a48191b0c7151a11eab0fd/roblox_tools/luau/luau.exe')
with tempfile.NamedTemporaryFile('w',suffix='.luau',encoding='utf8',delete=False) as f:f.write(text);path=Path(f.name)
try:result=subprocess.run([str(cli),str(path)],capture_output=True,text=True)
finally:path.unlink(missing_ok=True)
output=result.stdout+result.stderr
stem='return-test-'+next((x.split('=',1)[1] for x in sys.argv if x.startswith('--revision=')),'candidate')
assert not (HERE/(stem+'-output.txt')).exists(),'Retain previous attempt'
(HERE/(stem+'-output.txt')).write_text(output,encoding='utf8',newline='\n')
receipt=dict(source=subprocess.check_output(['git','log','-1','--format=%H','--','roblox_port/src','roblox_port/tests'],cwd=ROOT,text=True).strip(),exit_code=result.returncode,candidate_sha256=m['candidate_sha256'],output_sha256=hashlib.sha256(output.encode()).hexdigest(),runtime_changed=False,adopted=False)
(HERE/(stem+'-receipt.json')).write_text(json.dumps(receipt,indent=2)+'\n',encoding='utf8',newline='\n')
assert (ROOT/'roblox_port/tests'/name).read_bytes()==original
print(output);raise SystemExit(result.returncode)
