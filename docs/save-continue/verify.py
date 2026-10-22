"""Verify only the current partial feature's focused/compile/type/runner evidence."""
from pathlib import Path
import hashlib,json,re,subprocess
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[1]
sha=lambda b:hashlib.sha256(b).hexdigest()
read=lambda name:json.loads((HERE/name).read_text(encoding='utf8'))
target=read('target-process.json');assert target['exit_code']==0
for path,h in target['inputs'].items():assert sha((ROOT/path).read_bytes())==h,path
rows=re.findall(r'^([A-Z_0-9 ]+) passed=(\d+) failed=(\d+)',(HERE/'target.txt').read_text(),re.M)
assert rows==[('SAVE_OBSERVATION','50','0'),('STATE','866','0')]
compiled=read('compile.json');assert compiled['total']==compiled['passed']==218
for row in compiled['files']:assert row['exit_code']==0 and sha((ROOT/row['path']).read_bytes())==row['sha256']
for name in ['strict','runner']:assert read(name+'-process.json')['exit_code']==0
assert not re.search(r'TypeError|SyntaxError|Error:',(HERE/'strict.txt').read_text())
assert 'Ran 5 tests' in (HERE/'runner.txt').read_text()
prior=json.loads((ROOT/'docs/save-lease-cleanup/receipt.json').read_text());assert sha((ROOT/'roblox_port/TheWindowsill.rbxlx').read_bytes())==prior['production_sha256']
source=subprocess.check_output(['git','log','-1','--format=%H','--','roblox_port/src','roblox_port/tests'],cwd=ROOT,text=True).strip()
entries=subprocess.check_output(['git','ls-tree','-rz',source,'roblox_port/src'],cwd=ROOT).split(b'\0');count=0
for entry in entries:
 if not entry:continue
 header,path=entry.split(b'\t',1);data=(ROOT/path.decode()).read_bytes()
 assert hashlib.sha1(b'blob '+str(len(data)).encode()+b'\0'+data).hexdigest()==header.split()[2].decode(),path
 count+=1
assert count==218
receipt=dict(source=source,scope='Unfinished A06 private observations and opt-in preview reads only',modules=218,targeted_passed=916,targeted_suites=2,compile_passed=218,strict_clean=True,runner_regressions=5,
 transport_integrated=False,write_authority_integrated=False,menu_integrated=False,feature_complete=False,release_artifact_rebuilt=False,native_verified=False,online_verified=False,full_current_gates_verified=False,published=False,publication_ready=False)
(HERE/'receipt.json').write_text(json.dumps(receipt,indent=2)+'\n',encoding='utf8',newline='\n');print(json.dumps(receipt,indent=2))
