"""Serial follow-up: retain old full-run failures, then check the diagnostic fix."""
from pathlib import Path
import hashlib,json,re,subprocess,sys,time
ROOT=Path(__file__).resolve().parents[3];HERE=Path(__file__).resolve().parent
assert not (HERE/'follow-up.json').exists()
while not (HERE.parent/'local-return/windows-full-process.json').exists():time.sleep(2)
old=json.loads((HERE.parent/'local-return/windows-full-process.json').read_text(encoding='utf8'))
text=(HERE.parent/'local-return/windows-full.txt').read_text(encoding='utf8')
rows=re.findall(r'^([A-Z_0-9 ]+) passed=(\d+) failed=(\d+)',text,re.M)
(HERE/'prior-windows-full.json').write_text(json.dumps(dict(source=old['source'],exit_code=old['exit_code'],
 suites=len(rows),passed=sum(int(r[1]) for r in rows),failed=sum(int(r[2]) for r in rows),
 failed_suites=[r for r in rows if int(r[2])],
 log_sha256=hashlib.sha256(text.encode()).hexdigest()),indent=2)+'\n',encoding='utf8',newline='\n')
tool=Path(r'C:/Users/natha/.codex/.chatgpt-projects/g-p-6ac2f32f82a48191b0c7151a11eab0fd/roblox_tools/luau/luau.exe')
inputs={p.relative_to(ROOT).as_posix():hashlib.sha256(p.read_bytes()).hexdigest()
 for base in ['roblox_port/src','roblox_port/tests'] for p in (ROOT/base).rglob('*') if p.is_file() and '__pycache__' not in p.parts}
with (HERE/'selftest.txt').open('w',encoding='utf8',newline='\n') as log:
 result=subprocess.run([sys.executable,str(ROOT/'roblox_port/tests/run.py'),str(tool),'selftest.luau','selftest_preserve.luau'],stdout=log,stderr=subprocess.STDOUT)
(HERE/'follow-up.json').write_text(json.dumps(dict(exit_code=result.returncode,inputs=inputs),indent=2)+'\n',encoding='utf8',newline='\n')
print('selftest follow-up exit',result.returncode,flush=True)
if result.returncode:raise SystemExit(result.returncode)
raise SystemExit(subprocess.call([sys.executable,str(HERE/'profile.py')]))
