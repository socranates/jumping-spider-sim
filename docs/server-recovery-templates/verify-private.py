"""Qualify the server-authored catalog through current private adapters."""
from pathlib import Path
import hashlib, importlib.util, io, json, re, subprocess, tarfile
H=Path(__file__).resolve().parent;ROOT=H.parents[1];PRIVATE=ROOT/'docs/save-slot-isolation'
SOURCE='46c299f5e36038d06f164c968e5fda78bb4407e8'
sha=lambda b:hashlib.sha256(b).hexdigest()
spec=importlib.util.spec_from_file_location('current_templates_runner',H/'run-private.py')
m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
bundle,_,test=m.build()
r=json.loads((H/'qualified-full-2-receipt.json').read_text(encoding='utf8'));output=(H/'qualified-full-2-output.txt').read_bytes()
assert r['source']==SOURCE and r['exit_code']==0 and not r['focused'] and not r['source_uncommitted']
assert sha(bundle.encode())==r['bundle_sha256'] and sha(output)==r['output_sha256'] and sha(test.encode())==r['generated_test_sha256']
assert (H/'qualified-full-2-test.luau').read_bytes()==test.encode()
for name,digest in {**r['inputs'],**r['production_inputs']}.items():assert sha((ROOT/name).read_bytes())==digest,name
# Retain the negative test as a failure, then bind the focused fixed cohort to
# exactly the same current adapter/test bytes as the full qualification.
negative=json.loads((PRIVATE/'initial-scope-before-1-receipt.json').read_text(encoding='utf8'))
negative_output=(PRIVATE/'initial-scope-before-1-output.txt').read_bytes()
assert negative['source']==SOURCE and negative['focused'] and negative['exit_code']==1
assert sha(negative_output)==negative['output_sha256']
assert b'late initial factory revived a removed player or acquired a lease' in negative_output
for name,snapshot in [('replacement-service-prototype.luau','before-initial-scope-replacement-service.luau'),('replacement-tests.luau','before-initial-scope-replacement-tests.luau')]:
 assert sha((H/snapshot).read_bytes())==negative['inputs']['docs/save-slot-isolation/'+name]
fixed=json.loads((PRIVATE/'initial-scope-after-1-receipt.json').read_text(encoding='utf8'))
focused_bundle,_=m.load('focused_replacement',PRIVATE/'run-replacement.py').build(True)
fixed_output=(PRIVATE/'initial-scope-after-1-output.txt').read_bytes()
assert fixed['source']==SOURCE and fixed['focused'] and fixed['exit_code']==0
assert sha(focused_bundle.encode())==fixed['bundle_sha256'] and sha(fixed_output)==fixed['output_sha256']
assert b'SESSION_REPLACEMENT passed=2688 failed=0' in fixed_output
for name,digest in {**fixed['inputs'],**fixed['production_inputs']}.items():assert sha((ROOT/name).read_bytes())==digest,name
raw=subprocess.check_output(['git','archive','--format=tar',SOURCE,'roblox_port/src','roblox_port/tests'],cwd=ROOT)
with tarfile.open(fileobj=io.BytesIO(raw)) as archive:
 committed={item.name:sha(archive.extractfile(item).read()) for item in archive if item.isfile()}
assert committed==r['production_inputs']
pattern=r'^(RECOVERY_\w+|SESSION_REPLACEMENT|SERVER_TEMPLATE_RECOVERY) passed=(\d+) failed=(\d+)'
baseline=re.findall(pattern,(PRIVATE/'replacement-full-1-output.txt').read_text(encoding='utf8'),re.M)
assert len(baseline)==29 and sum(int(p) for _,p,_ in baseline)==204254 and all(int(f)==0 for _,_,f in baseline)
expected={name:(int(p),0) for name,p,_ in baseline}
assert expected['SESSION_REPLACEMENT']==(2667,0)
expected['SESSION_REPLACEMENT']=(2688,0) # includes initial constructor lifetime cases
expected['SERVER_TEMPLATE_RECOVERY']=(513,0)
rows=re.findall(pattern,output.decode(),re.M)
assert len(rows)==30 and {name:(int(p),int(f)) for name,p,f in rows}==expected
for mode in ['main','free','easy']:
 assert f'SERVER_TEMPLATE_RECOVERY mode={mode} authored_geometry=true actual_entry=true stored_rest=true replacement=true cache_unchanged=true' in output.decode()
types=json.loads((PRIVATE/'initial-scope-types-1-types.json').read_text(encoding='utf8'))
assert types['source']==SOURCE and len(types['candidates'])==40 and len(types['steps'])==3
assert (PRIVATE/'initial-scope-types-1-compile.txt').read_text(encoding='utf8')=='compile 40/40\n'
for name,digest in types['candidates'].items():assert sha((PRIVATE/name).read_bytes())==digest,name
for name,digest in types['production_inputs'].items():assert sha((ROOT/name).read_bytes())==digest,name
for step in types['steps']:
 assert step['exit_code']==0 and sha((PRIVATE/('initial-scope-types-1-'+step['name']+'.txt')).read_bytes())==step['output_sha256']
strict=(PRIVATE/'initial-scope-types-1-strict.txt').read_text(encoding='utf8')
assert not [line for line in strict.splitlines() if line and not line.startswith('[INFO]') and 'didChangeWatchedFiles' not in line]
assert subprocess.run(['git','diff','--quiet','HEAD','--','roblox_port/src','roblox_port/tests'],cwd=ROOT).returncode==0
result=dict(source=SOURCE,preceding_checks=204275,authored_catalog_entry_rest_and_replacement_checks=513,total_checks=204788,failed=0,
 private_candidates=40,compile_and_full_strict_clean=True,authored_production_builder_used_in_server_factory=True,
 all_three_modes_receive_actual_entry_and_next_rest_stored_ack=True,replacement_reuses_unchanged_cached_templates=True,
 no_client_played_template_input=True,initial_constructor_disconnect_shutdown_rejoin_and_failure_fenced=True,
 ordinary_engine_recovery_installed=False,native_full_recovery_verified=False,real_datastore_verified=False,published=False,goal_complete=False)
(H/'private-verification.json').write_text(json.dumps(result,indent=2)+'\n',encoding='utf8',newline='\n');print(json.dumps(result,indent=2))
