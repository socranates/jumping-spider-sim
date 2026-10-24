"""Qualify two complete default runs of the exact current candidate.

The focused new menu regression is qualified separately, without double counting.
"""
from pathlib import Path
import argparse, ast, hashlib, json, re
H=Path(__file__).resolve().parent;ROOT=H.parents[1];CLI=ROOT/'docs/integrated-release'
STAGE=Path('C:/Users/natha/claude-xfer/Windowsill-menu-overflow-attempt1')
sha=lambda b:hashlib.sha256(b).hexdigest()
p=argparse.ArgumentParser();p.add_argument('--check',action='store_true');a=p.parse_args()
manifest=json.loads((STAGE/'manifest.json').read_text());model=Path(manifest['place'])
assert sha(model.read_bytes())==manifest['place_sha256']and manifest['source_count']==273
game={f.relative_to(STAGE/'roblox_port/src').as_posix():sha(f.read_bytes())for f in (STAGE/'roblox_port/src').rglob('*.luau')}
tests={f.relative_to(STAGE/'roblox_port/tests').as_posix():sha(f.read_bytes())for f in (STAGE/'roblox_port/tests').rglob('*')if f.is_file()and '__pycache__'not in f.parts}
prefix={'First':'ReplicatedFirst','Shared':'ReplicatedStorage.Shared','Server':'ServerScriptService.Server','Client':'StarterPlayer.StarterPlayerScripts.Client'}
def model_name(rel):
 parts=Path(rel).parts
 return '.'.join([prefix[parts[0]],*parts[1:-1],parts[-1][:-5].removesuffix('.server').removesuffix('.client')])
assert {model_name(k):sha((STAGE/'roblox_port/src'/k).read_bytes().replace(b'\r\n',b'\n'))for k in game}==manifest['sources']
tree=ast.parse((STAGE/'roblox_port/tests/run.py').read_text())
main=next(n for n in tree.body if isinstance(n,ast.FunctionDef)and n.name=='main')
loop=next(n for n in main.body if isinstance(n,ast.For));default=ast.literal_eval(loop.iter.values[1])
assert len(default)==78 and len(set(default))==78
inputs={};summaries=[]
def bind(path):inputs[path.relative_to(ROOT).as_posix()]=sha(path.read_bytes())
def read_run(name):
 path=CLI/(name+'-receipt.json');bind(path);run=json.loads(path.read_text())
 assert run['all_passed']and run['inputs']==game and run['test_inputs']==tests
 assert run['runner_sha256']==sha((CLI/'run-cli.py').read_bytes())
 return run
def counts(row):
 path=CLI/row['output'];bind(path);data=path.read_bytes()
 assert row['exit_code']==0 and sha(data)==row['output_sha256']
 found=re.findall(r'passed=(\d+) failed=(\d+)',data.decode());assert found,row['suite']
 assert all(int(failed)==0 for _,failed in found),row['suite']
 return sum(int(passed)for passed,_ in found)
runs=[]
for name in ['menu-full1','menu-full2']:
 run=read_run(name);assert run['full']and run['requested']==default and [r['suite']for r in run['results']]==default
 per_suite={r['suite']:counts(r)for r in run['results']};assert all(n>0 for n in per_suite.values())
 runs.append(run);summaries.append(dict(prefix=name,suites=78,passed=sum(per_suite.values()),failed=0,per_suite=per_suite))
assert summaries[0]['per_suite']==summaries[1]['per_suite']
assert runs[0]['module_aliases']==runs[1]['module_aliases']
assert [r['bundle_sha256']for r in runs[0]['results']]==[r['bundle_sha256']for r in runs[1]['results']]
# Refuse silent lost assertions compared with the earlier complete candidate.
baseline=json.loads((CLI/'full2-receipt.json').read_text());bind(CLI/'full2-receipt.json')
assert baseline['all_passed']and baseline['requested']==default
assert summaries[0]['per_suite']=={r['suite']:counts(r)for r in baseline['results']}
menu=read_run('menu1');row=next(r for r in menu['results']if r['suite']=='menu_overflow.luau')
assert counts(row)==12 and 'menu_overflow.luau'not in default
bind(CLI/'run-cli.py');bind(Path(__file__))
result=dict(model_sha256=manifest['place_sha256'],manifest_sha256=sha((STAGE/'manifest.json').read_bytes()),
 source_count=273,test_input_count=len(tests),runs=summaries,new_menu_regressions_separate=12,
 same_assertion_counts=True,same_bundles=True,observed_outcome_differences=[],
 limits='Two complete CLI runs, not native rendering, general flake probability, natural lifecycle or published-player proof.',inputs=inputs)
out=H/'current-cli-qualification.json'
if a.check:assert json.loads(out.read_text())==result
else:assert not out.exists();out.write_bytes((json.dumps(result,indent=2)+'\n').encode())
print(json.dumps(dict(runs=[{k:v for k,v in r.items()if k!='per_suite'}for r in summaries],new_menu_regressions_separate=12)))
