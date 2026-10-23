from pathlib import Path
import argparse,hashlib,importlib.util,json,subprocess,tempfile
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[1]
spec=importlib.util.spec_from_file_location('runner',ROOT/'roblox_port/tests/run.py');r=importlib.util.module_from_spec(spec);spec.loader.exec_module(r)
p=argparse.ArgumentParser();p.add_argument('--integration',action='store_true');p.add_argument('--aggregate-probe',action='store_true');p.add_argument('--bounded',action='store_true');a=p.parse_args()
stem='recovery-source-aggregate-'+('candidate' if a.bounded else 'baseline') if a.aggregate_probe else 'recovery-source-integration' if a.integration else 'recovery-source-collector'
test='recovery-source-aggregate-probe.luau' if a.aggregate_probe else stem+'-tests.luau'
name='../../docs/save-slot-isolation/'+test;body=(HERE/test).read_text(encoding='utf8')
text=r.bundle(name);suffix=r.requires(body)+'\n';assert text.endswith(suffix)
archive=HERE/'recovery-archive-prototype.luau';candidate=HERE/'recovery-source-collector-prototype.luau'
code=candidate.read_text(encoding='utf8').replace('require(script.Parent.RecoveryArchivePrototype)','__archivePrototype')
prelude='local EXPECTED_BOUNDED='+str(a.bounded).lower()+'\nlocal __archivePrototype='+r.chunk(archive)+'\nlocal __collectorPrototype=(function()\n'+r.requires(r.strict(code))+'\nend)()\n'
store=HERE/'recovery-archive-store-prototype.luau'
if a.integration:prelude+='local __archiveStorePrototype=(function()\n'+r.requires(r.strict(store.read_text().replace('require(script.Parent.RecoveryArchivePrototype)','__archivePrototype')))+'\nend)()\n'
text=text[:-len(suffix)]+prelude+suffix
assert not (HERE/(stem+'-output.txt')).exists(),'Retain prior run'
with tempfile.NamedTemporaryFile('w',suffix='.luau',encoding='utf8',delete=False) as f:f.write(text);path=Path(f.name)
try:result=subprocess.run([r'C:/Users/natha/.codex/.chatgpt-projects/g-p-6ac2f32f82a48191b0c7151a11eab0fd/roblox_tools/luau/luau.exe',str(path)],capture_output=True,text=True)
finally:path.unlink(missing_ok=True)
output=result.stdout+result.stderr;(HERE/(stem+'-output.txt')).write_text(output,encoding='utf8',newline='\n')
receipt=dict(source=subprocess.check_output(['git','log','-1','--format=%H','--','roblox_port/src','roblox_port/tests'],cwd=ROOT,text=True).strip(),exit_code=result.returncode,candidate_sha256=hashlib.sha256(candidate.read_bytes()).hexdigest(),archive_sha256=hashlib.sha256(archive.read_bytes()).hexdigest(),test_sha256=hashlib.sha256(body.encode()).hexdigest(),bundle_sha256=hashlib.sha256(text.encode()).hexdigest(),output_sha256=hashlib.sha256(output.encode()).hexdigest(),production_changed=False,real_datastore_verified=False,progress_import_implemented=False)
if a.integration:receipt['store_sha256']=hashlib.sha256(store.read_bytes()).hexdigest();receipt['backend_sha256']=hashlib.sha256((ROOT/'roblox_port/src/Server/DataStoreBackend.luau').read_bytes()).hexdigest()
(HERE/(stem+'-receipt.json')).write_text(json.dumps(receipt,indent=2)+'\n',encoding='utf8',newline='\n');print(output);raise SystemExit(result.returncode)
