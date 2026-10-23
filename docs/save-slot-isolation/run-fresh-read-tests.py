from pathlib import Path
import hashlib,importlib.util,json,subprocess,tempfile
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[1]
spec=importlib.util.spec_from_file_location('runner',ROOT/'roblox_port/tests/run.py');r=importlib.util.module_from_spec(spec);spec.loader.exec_module(r)
m=json.loads((HERE/'fresh-read-manifest.json').read_text())
original=ROOT/'roblox_port/src/Server/DataStoreBackend.luau'
assert hashlib.sha256(original.read_bytes()).hexdigest()==m['original_sha256']
candidate=HERE/'fresh-read-backend-candidate.luau';assert hashlib.sha256(candidate.read_bytes()).hexdigest()==m['candidate_sha256']
name='../../docs/save-slot-isolation/fresh-read-tests.luau';body=(HERE/'fresh-read-tests.luau').read_text(encoding='utf8')
text=r.bundle(name);suffix=r.requires(body)+'\n';assert text.endswith(suffix)
archive=HERE/'recovery-archive-prototype.luau';store=HERE/'recovery-archive-store-prototype.luau'
storeText=store.read_text(encoding='utf8').replace('require(script.Parent.RecoveryArchivePrototype)','__archivePrototype')
text=text[:-len(suffix)]+'local __freshBackend='+r.chunk(candidate)+'\nlocal __archivePrototype='+r.chunk(archive)+'\nlocal __archiveStorePrototype=(function()\n'+r.requires(r.strict(storeText))+'\nend)()\n'+suffix
cli=Path(r'C:/Users/natha/.codex/.chatgpt-projects/g-p-6ac2f32f82a48191b0c7151a11eab0fd/roblox_tools/luau/luau.exe')
with tempfile.NamedTemporaryFile('w',suffix='.luau',encoding='utf8',delete=False) as f:f.write(text);path=Path(f.name)
try:result=subprocess.run([str(cli),str(path)],capture_output=True,text=True)
finally:path.unlink(missing_ok=True)
output=result.stdout+result.stderr
(HERE/'fresh-read-output.txt').write_text(output,encoding='utf8',newline='\n')
receipt=dict(source=m['source'],exit_code=result.returncode,candidate_sha256=m['candidate_sha256'],archive_sha256=hashlib.sha256(archive.read_bytes()).hexdigest(),store_sha256=hashlib.sha256(store.read_bytes()).hexdigest(),test_sha256=hashlib.sha256(body.encode()).hexdigest(),output_sha256=hashlib.sha256(output.encode()).hexdigest(),production_changed=False,real_datastore_verified=False)
(HERE/'fresh-read-receipt.json').write_text(json.dumps(receipt,indent=2)+'\n',encoding='utf8',newline='\n');print(output);raise SystemExit(result.returncode)
