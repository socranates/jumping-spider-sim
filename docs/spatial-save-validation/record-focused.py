from pathlib import Path
import hashlib,json,re,subprocess
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[1]
source=subprocess.check_output(['git','log','-1','--format=%H','--','roblox_port/src','roblox_port/tests'],cwd=ROOT,text=True).strip()
assert source=='59146e1005c083330455379766ab8c9dd2de2705'
assert subprocess.run(['git','diff','--quiet','HEAD','--','roblox_port/src','roblox_port/tests'],cwd=ROOT).returncode==0
text=(ROOT/'docs/save-slot-isolation/spatial-focused.txt').read_text(encoding='utf8')
rows=re.findall(r'^([A-Z_0-9 ]+) passed=(\d+) failed=(\d+)',text,re.M)
assert len(rows)==6 and sum(int(r[1]) for r in rows)==1783 and all(int(r[2])==0 for r in rows)
compiled=json.loads((HERE/'final-check/compile.json').read_text(encoding='utf8'))
assert compiled['total']==compiled['passed']==222
for row in compiled['files']:assert hashlib.sha256((ROOT/row['path']).read_bytes()).hexdigest()==row['sha256'] and row['exit_code']==0
receipt=dict(source=source,suites=6,passed=1783,failed=0,exit_code=0,
 output_path='docs/save-slot-isolation/spatial-focused.txt',output_sha256=hashlib.sha256(text.encode()).hexdigest(),
 modules_compiled=222,strict_clean=True,runner_regressions=5,native_verified=False,full_gates_verified=False,published=False)
for name in ['sourcemap','strict','runner']:assert json.loads((HERE/'final-check'/(name+'-process.json')).read_text(encoding='utf8'))['exit_code']==0
(HERE/'focused-receipt.json').write_text(json.dumps(receipt,indent=2)+'\n',encoding='utf8',newline='\n');print(json.dumps(receipt,indent=2))
