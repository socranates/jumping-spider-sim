from pathlib import Path
import hashlib,importlib.util,json,subprocess,tempfile
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[1]
spec=importlib.util.spec_from_file_location('runner',ROOT/'roblox_port/tests/run.py');r=importlib.util.module_from_spec(spec);spec.loader.exec_module(r)
name='../../docs/save-slot-isolation/recovery-archive-store-tests.luau';body=(HERE/'recovery-archive-store-tests.luau').read_text(encoding='utf8')
text=r.bundle(name);suffix=r.requires(body)+'\n';assert text.endswith(suffix)
archive=HERE/'recovery-archive-prototype.luau';candidate=HERE/'recovery-archive-store-prototype.luau'
store=candidate.read_text(encoding='utf8').replace('require(script.Parent.RecoveryArchivePrototype)','__archivePrototype')
text=text[:-len(suffix)]+'local __archivePrototype='+r.chunk(archive)+'\nlocal __archiveStorePrototype=(function()\n'+r.requires(r.strict(store))+'\nend)()\n'+suffix
cli=Path(r'C:/Users/natha/.codex/.chatgpt-projects/g-p-6ac2f32f82a48191b0c7151a11eab0fd/roblox_tools/luau/luau.exe')
with tempfile.NamedTemporaryFile('w',suffix='.luau',encoding='utf8',delete=False) as f:f.write(text);path=Path(f.name)
try:result=subprocess.run([str(cli),str(path)],capture_output=True,text=True)
finally:path.unlink(missing_ok=True)
output=result.stdout+result.stderr
(HERE/'recovery-archive-store-output.txt').write_text(output,encoding='utf8',newline='\n')
receipt=dict(source=subprocess.check_output(['git','log','-1','--format=%H','--','roblox_port/src','roblox_port/tests'],cwd=ROOT,text=True).strip(),exit_code=result.returncode,candidate_sha256=hashlib.sha256(candidate.read_bytes()).hexdigest(),archive_sha256=hashlib.sha256(archive.read_bytes()).hexdigest(),test_sha256=hashlib.sha256(body.encode()).hexdigest(),output_sha256=hashlib.sha256(output.encode()).hexdigest(),production_changed=False,backend='MemoryBackend fault simulation',real_datastore_verified=False,progress_import_implemented=False)
(HERE/'recovery-archive-store-receipt.json').write_text(json.dumps(receipt,indent=2)+'\n',encoding='utf8',newline='\n');print(output);raise SystemExit(result.returncode)
