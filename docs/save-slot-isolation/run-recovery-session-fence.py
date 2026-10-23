from pathlib import Path
import argparse,hashlib,importlib.util,json,subprocess,tempfile
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[1]
spec=importlib.util.spec_from_file_location('runner',ROOT/'roblox_port/tests/run.py');r=importlib.util.module_from_spec(spec);spec.loader.exec_module(r)
state=(ROOT/'roblox_port/tests/state.luau').read_text();suffix=r.requires(state)+'\n';text=r.bundle('state.luau');assert text.endswith(suffix)
prefix=state.split('-- ---------------------------------------------------------------------------------------------- sizes, measured')[0]
p=argparse.ArgumentParser();p.add_argument('--baseline',action='store_true');a=p.parse_args()
stem='recovery-session-fence-negative' if a.baseline else 'recovery-session-fence'
archive=HERE/'recovery-archive-prototype.luau';collector=HERE/'recovery-source-collector-prototype.luau';fence=HERE/('initial-recovery-session-fence-prototype.luau' if a.baseline else 'recovery-session-fence-prototype.luau');test=HERE/'recovery-session-fence-tests.luau'
prelude='local __archivePrototype='+r.chunk(archive)+'\nlocal __collectorPrototype=(function()\n'+r.requires(r.strict(collector.read_text().replace('require(script.Parent.RecoveryArchivePrototype)','__archivePrototype')))+'\nend)()\nlocal __sessionFence='+r.chunk(fence)+'\n'
text=text[:-len(suffix)]+r.requires(prefix)+'\n'+prelude+test.read_text()
assert not (HERE/(stem+'-output.txt')).exists(),'Preserve prior evidence'
with tempfile.NamedTemporaryFile('w',suffix='.luau',encoding='utf8',delete=False) as f:f.write(text);path=Path(f.name)
try:result=subprocess.run([r'C:/Users/natha/.codex/.chatgpt-projects/g-p-6ac2f32f82a48191b0c7151a11eab0fd/roblox_tools/luau/luau.exe',str(path)],capture_output=True,text=True)
finally:path.unlink(missing_ok=True)
output=result.stdout+result.stderr;sha=lambda b:hashlib.sha256(b).hexdigest()
(HERE/(stem+'-output.txt')).write_text(output,encoding='utf8',newline='\n')
receipt=dict(source=subprocess.check_output(['git','log','-1','--format=%H','--','roblox_port/src','roblox_port/tests'],cwd=ROOT,text=True).strip(),exit_code=result.returncode,inputs={p.name:sha(p.read_bytes()) for p in [archive,collector,fence,test]},bundle_sha256=sha(text.encode()),output_sha256=sha(output.encode()),production_changed=False,real_datastore_verified=False,native_verified=False,destination_commit_authorized=False)
(HERE/(stem+'-receipt.json')).write_text(json.dumps(receipt,indent=2)+'\n',encoding='utf8',newline='\n');print(output);raise SystemExit(result.returncode)
