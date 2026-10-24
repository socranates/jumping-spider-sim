"""Bind the completed native test to the unmodified candidate and fixture."""
from pathlib import Path
import argparse,hashlib,json,re,subprocess,sys
H=Path(__file__).resolve().parent;ROOT=H.parents[1];sha=lambda b:hashlib.sha256(b).hexdigest()
p=argparse.ArgumentParser();p.add_argument('--check',action='store_true');a=p.parse_args()
subprocess.run([sys.executable,str(H/'prepare.py'),'--check'],check=True)
fixture=json.loads((H/'fixture.json').read_text());model=Path(fixture['source_model'])
assert sha((model/'manifest.json').read_bytes())==fixture['manifest_sha256']
assert sha((model/'guard.luau').read_bytes())==fixture['guard_sha256']
manifest=json.loads((model/'manifest.json').read_text())
assert sha(Path(manifest['place']).read_bytes())==manifest['place_sha256']
assert manifest['source_count']==fixture['source_count']==274
assert manifest['universe']==10771634917 and manifest['place_id']==109879630247781
assert fixture['never_publish']and fixture['only_fixture_change']=='Workspace.SelfTest=true'
run=json.loads((H/'attempt1-receipt.json').read_text())
assert run['complete']and run['all_passed']and run['counts']=={'pass':274,'fail':0,'skip':0}
assert run['fixture_sha256']==sha((H/'fixture.json').read_bytes())
assert len(run['names']['PASS'])==274 and not run['names']['FAIL']and not run['names']['SKIP']
assert sha((H/'attempt1-output.txt').read_bytes())==run['output_sha256']
assert not any('shim:'in s for s in run['info'])
sill=next(s for s in run['info']if s.startswith('INFO frame time on the sill:'))
assert re.search(r'301 frames, mean 16.7 ms',sill)
assert 'INFO took 591 s'in run['info']
path=Path('C:/Users/natha/claude-xfer/Windowsill-integrated-native-attempt1/NativeSelfTest.rbxl')
assert path.is_file()
inputs={f.relative_to(ROOT).as_posix():sha(f.read_bytes())for f in H.iterdir()if f.is_file()and f.name!='qualification.json'}
result=dict(inputs=inputs,fixture_file=str(path),fixture_file_sha256=sha(path.read_bytes()),candidate_model_sha256=manifest['place_sha256'],
 native_checks=274,failed=0,skipped=0,seconds=591,game_sources_unchanged=273,warning_records=len(run['warnings']),
 studio_only=True,published=False,standalone_player=False,goal_complete=False)
target=H/'qualification.json'
if a.check:assert json.loads(target.read_text())==result
else:
 assert not target.exists();target.write_bytes((json.dumps(result,indent=2)+'\n').encode())
print('Exact-source native Studio self-test verified: 274 passed / 0 failed / 0 skipped; warnings retained')
