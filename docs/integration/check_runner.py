"""Compare the normal runner with every qualified staged CLI program.

Only the independently qualified touch-font assignment is normalized away.
This checks runner equivalence; it does not substitute for native gameplay.
"""
from pathlib import Path
import argparse,ast,hashlib,importlib.util,json,time
H=Path(__file__).resolve().parent;ROOT=H.parents[1];PORT=ROOT/'roblox_port'
p=argparse.ArgumentParser();p.add_argument('--check',action='store_true');a=p.parse_args()
sha=lambda b:hashlib.sha256(b).hexdigest()
path=PORT/'tests/run.py';spec=importlib.util.spec_from_file_location('normal_runner_equivalence',path)
r=importlib.util.module_from_spec(spec);spec.loader.exec_module(r)
baseline=json.loads((ROOT/'docs/integrated-release/menu-full2-receipt.json').read_text())
menu=json.loads((ROOT/'docs/integrated-release/menu1-receipt.json').read_text())
assert baseline['all_passed']and menu['all_passed']
tree=ast.parse(path.read_text());main=next(n for n in tree.body if isinstance(n,ast.FunctionDef)and n.name=='main')
loop=next(n for n in main.body if isinstance(n,ast.For));defaults=ast.literal_eval(loop.iter.values[1])
assert defaults==baseline['requested']+['menu_overflow.luau']and len(defaults)==79
expected={row['suite']:row['bundle_sha256']for row in baseline['results']}
expected['menu_overflow.luau']=next(row['bundle_sha256']for row in menu['results']if row['suite']=='menu_overflow.luau')
added='\t\tb.TextSize = textSize or 18\n\t\tb.Font = Enum.Font.GothamMedium\n'
original='\t\tb.TextSize = textSize or 18\n'
began=time.perf_counter();rows=[]
for suite in defaults:
 code=r.bundle(suite);assert code.count(added)==1,suite
 normalized=code.replace(added,original,1)
 actual=sha(normalized.encode());assert actual==expected[suite],(suite,actual,expected[suite])
 rows.append(dict(suite=suite,normal_bundle_sha256=sha(code.encode()),qualified_without_font_sha256=actual))
elapsed=time.perf_counter()-began
inputs={f.relative_to(PORT/'src').as_posix():sha(f.read_bytes())for f in (PORT/'src').rglob('*.luau')}
tests={f.relative_to(PORT/'tests').as_posix():sha(f.read_bytes())for f in (PORT/'tests').rglob('*')if f.is_file()and '__pycache__'not in f.parts}
result=dict(source_count=len(inputs),runner_sha256=sha(path.read_bytes()),programs=rows,inputs=inputs,test_inputs=tests,
 only_program_difference='Qualified one-line touch-button font assignment',same_qualified_programs=79,
 limits='Program equivalence, not a new native or full executed run. Current font has its own targeted/native proof.')
target=H/'runner-equivalence.json'
if a.check:assert json.loads(target.read_text())==result
else:assert not target.exists();target.write_bytes((json.dumps(result,indent=2)+'\n').encode())
print(json.dumps(dict(equivalent_programs=79,modules=len(r.MODULES),source_count=len(inputs),bundle_seconds=round(elapsed,3))))
