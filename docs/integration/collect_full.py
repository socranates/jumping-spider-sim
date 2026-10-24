"""Qualify completed normal-command output against the exact expected suites."""
from pathlib import Path
import argparse,ast,hashlib,json,re
H=Path(__file__).resolve().parent;ROOT=H.parents[1];PORT=ROOT/'roblox_port'
p=argparse.ArgumentParser();p.add_argument('--exit-code',type=int,required=True);p.add_argument('--check',action='store_true');a=p.parse_args()
assert a.exit_code==0,'Require the authoritative completed exec exit code'
sha=lambda data:hashlib.sha256(data).hexdigest()
baseline=json.loads((ROOT/'docs/integrated-release/menu-full2-receipt.json').read_text())
menu=json.loads((ROOT/'docs/integrated-release/menu1-receipt.json').read_text())
tree=ast.parse((PORT/'tests/run.py').read_text());main=next(n for n in tree.body if isinstance(n,ast.FunctionDef)and n.name=='main')
loop=next(n for n in main.body if isinstance(n,ast.For));defaults=ast.literal_eval(loop.iter.values[1])
assert defaults==baseline['requested']+['menu_overflow.luau']and len(defaults)==79
def summaries(text):
 return [(m.group(1).strip(),int(m.group(2)),int(m.group(3)))for m in re.finditer(r'^([^\r\n]*?)passed=(\d+) failed=(\d+)[^\r\n]*$',text.replace('\r\n','\n'),re.M)]
expected=[]
for row in baseline['results']+[next(r for r in menu['results']if r['suite']=='menu_overflow.luau')]:
 path=ROOT/'docs/integrated-release'/row['output'];data=path.read_bytes()
 assert sha(data)==row['output_sha256']and row['exit_code']==0
 values=summaries(data.decode());assert values
 expected.extend(values)
log=H/'full-cli.txt';data=log.read_bytes();actual=summaries(data.decode('utf8'))
assert actual==expected,(len(actual),len(expected))
assert all(failed==0 for _,_,failed in actual)
total=sum(passed for _,passed,_ in actual);assert total==468979
equivalence=json.loads((H/'runner-equivalence.json').read_text())
sources={f.relative_to(PORT/'src').as_posix():sha(f.read_bytes())for f in (PORT/'src').rglob('*.luau')}
tests={f.relative_to(PORT/'tests').as_posix():sha(f.read_bytes())for f in (PORT/'tests').rglob('*')if f.is_file()and '__pycache__'not in f.parts}
assert sources==equivalence['inputs']and tests==equivalence['test_inputs']
receipt=json.loads((PORT/'build-receipt.json').read_text());promotion=json.loads((H/'promotion.json').read_text())
assert receipt['sources']==promotion['sources']and receipt['source_count']==273
for output in receipt['outputs']:assert sha((PORT/output['file']).read_bytes())==output['sha256']
record=dict(exit_code=0,suites=79,passed=total,failed=0,source_count=273,
 command='python tests/run.py <luau>',log_sha256=sha(data),sources=sources,test_inputs=tests,
 suite_summaries=[list(row) for row in actual],build_evidence=receipt['evidence_id'],build_receipt_sha256=sha((PORT/'build-receipt.json').read_bytes()),
 limits='Executed Windows CLI and build identity; not native rendering, all-mode lives, phone or real storage proof.')
target=H/'full-cli-receipt.json'
if a.check:assert json.loads(target.read_text())==record
else:assert not target.exists();target.write_bytes((json.dumps(record,indent=2)+'\n').encode())
print(json.dumps(dict(suites=79,passed=total,failed=0,evidence=receipt['evidence_id'])))
