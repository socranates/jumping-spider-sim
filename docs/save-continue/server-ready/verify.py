"""Source-bound server milestone only; client/menu/native/release remain open."""
from pathlib import Path
import hashlib,io,json,re,subprocess,tarfile
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[2]
BASE='0f5a00b'
SOURCE=subprocess.check_output(['git','log','-1','--format=%H','--','roblox_port/src','roblox_port/tests'],cwd=ROOT,text=True).strip()
sha=lambda b:hashlib.sha256(b).hexdigest()
read=lambda name:json.loads((HERE/name).read_text(encoding='utf8'))
def archive(commit):
 b=subprocess.check_output(['git','archive','--format=tar',commit,'roblox_port/src'],cwd=ROOT)
 with tarfile.open(fileobj=io.BytesIO(b)) as tree:return {t.name:tree.extractfile(t).read() for t in tree if t.isfile()}
base,current=archive(BASE),archive(SOURCE);assert len(base)==218 and len(current)==219
changed=sorted(p for p in set(base)|set(current) if base.get(p)!=current.get(p))
assert set(changed)=={'roblox_port/src/Server/SaveService.luau','roblox_port/src/Shared/Data/SaveRules.luau','roblox_port/src/Shared/Persistence/SaveIntent.luau','roblox_port/src/Shared/Persistence/SaveObservation.luau','roblox_port/src/Shared/Persistence/SaveSession.luau'}
for path,b in current.items():assert (ROOT/path).read_bytes()==b,path
target=read('target-process.json');assert target['exit_code']==0
for path,h in target['inputs'].items():assert sha((ROOT/path).read_bytes())==h,path
rows=re.findall(r'^([A-Z_0-9 ]+) passed=(\d+) failed=(\d+)',(HERE/'target.txt').read_text(),re.M)
assert rows==[('SAVE_INTENT','57','0'),('SAVE_OBSERVATION','50','0'),('STATE','971','0'),('STATE_CLIENT','162','0'),('STATE_OFFLINE','8','0'),('REST_STORAGE','14','0'),('REST_COMPRESSION','57','0')]
compiled=read('compile.json');assert compiled['total']==compiled['passed']==219
assert len(compiled['files'])==219 and {r['path'] for r in compiled['files']}==set(current)
for r in compiled['files']:assert r['exit_code']==0 and r['sha256']==sha(current[r['path']])
for name in ['sourcemap','strict','runner']:assert read(name+'-process.json')['exit_code']==0
assert not re.search(r'TypeError|SyntaxError|Error:',(HERE/'strict.txt').read_text())
assert 'Ran 5 tests' in (HERE/'runner.txt').read_text()
prior=json.loads((ROOT/'docs/save-lease-cleanup/receipt.json').read_text());assert sha((ROOT/'roblox_port/TheWindowsill.rbxlx').read_bytes())==prior['production_sha256']
receipt=dict(source=SOURCE,base=subprocess.check_output(['git','rev-parse',BASE],cwd=ROOT,text=True).strip(),scope='A06 server authority, negotiated protocol and checkpoint receipts; unfinished client/game feature',
 production_modules=219,changed_modules=changed,targeted_suites=7,targeted_passed=1319,state_passed=971,intent_passed=57,observation_passed=50,compile_passed=219,strict_clean=True,runner_regressions=5,
 server_authority_integrated=True,server_protocol_integrated=True,checkpoint_receipts_integrated=True,client_protocol_integrated=False,menu_integrated=False,feature_complete=False,
 release_artifact_rebuilt=False,native_verified=False,online_verified=False,full_current_gates_verified=False,published=False,publication_ready=False)
(HERE/'receipt.json').write_text(json.dumps(receipt,indent=2)+'\n',encoding='utf8',newline='\n');print(json.dumps(receipt,indent=2))
