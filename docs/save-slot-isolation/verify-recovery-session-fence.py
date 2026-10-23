from pathlib import Path
import hashlib,importlib.util,json,subprocess
H=Path(__file__).resolve().parent;ROOT=H.parents[1];sha=lambda b:hashlib.sha256(b).hexdigest()
source=subprocess.check_output(['git','log','-1','--format=%H','--','roblox_port/src','roblox_port/tests'],cwd=ROOT,text=True).strip()
spec=importlib.util.spec_from_file_location('runner',ROOT/'roblox_port/tests/run.py');r=importlib.util.module_from_spec(spec);spec.loader.exec_module(r)
state=(ROOT/'roblox_port/tests/state.luau').read_text();suffix=r.requires(state)+'\n';base=r.bundle('state.luau');assert base.endswith(suffix)
prefix=state.split('-- ---------------------------------------------------------------------------------------------- sizes, measured')[0]
for stem,fenceName,expected in [('recovery-session-fence','recovery-session-fence-prototype.luau',0),('recovery-session-fence-negative','initial-recovery-session-fence-prototype.luau',1)]:
 receipt=json.loads((H/(stem+'-receipt.json')).read_text());output=(H/(stem+'-output.txt')).read_bytes()
 assert receipt['source']==source and receipt['exit_code']==expected and receipt['output_sha256']==sha(output)
 for name,digest in receipt['inputs'].items():assert sha((H/name).read_bytes())==digest
 archive=H/'recovery-archive-prototype.luau';collector=H/'recovery-source-collector-prototype.luau';fence=H/fenceName;test=H/'recovery-session-fence-tests.luau'
 prelude='local __archivePrototype='+r.chunk(archive)+'\nlocal __collectorPrototype=(function()\n'+r.requires(r.strict(collector.read_text().replace('require(script.Parent.RecoveryArchivePrototype)','__archivePrototype')))+'\nend)()\nlocal __sessionFence='+r.chunk(fence)+'\n'
 bundle=base[:-len(suffix)]+r.requires(prefix)+'\n'+prelude+test.read_text()
 assert sha(bundle.encode())==receipt['bundle_sha256'],'current runtime/dependencies differ from executed bundle'
 assert ('RECOVERY_SESSION_FENCE passed=129 failed=0' if expected==0 else 'expired ticket resurrected after a later heartbeat') in output.decode()
types=json.loads((H/'recovery-session-fence-types.json').read_text());assert len(types['candidates'])==4 and len(types['steps'])==3
for name,digest in types['candidates'].items():assert sha((H/name).read_bytes())==digest
for step in types['steps']:assert step['exit_code']==0 and step['output_sha256']==sha((H/('recovery-session-fence-'+step['name']+'.txt')).read_bytes())
assert subprocess.run(['git','diff','--quiet','HEAD','--','roblox_port/src','roblox_port/tests'],cwd=ROOT).returncode==0
result=dict(source=source,assertions=129,expired_ticket_resurrection_counterexample_reproduced=True,current_runtime_bundle_verified=True,strict_clean=True,actual_session_objects=True,backend='MemoryBackend',production_connected=False,native_verified=False,real_datastore_verified=False,destination_commit_authorized=False,progress_import_implemented=False,published=False)
(H/'recovery-session-fence-verification.json').write_text(json.dumps(result,indent=2)+'\n',encoding='utf8',newline='\n');print(json.dumps(result,indent=2))
