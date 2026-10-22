"""Source-bound actual menu/controller milestone; native, network, full gates and cost follow-up remain open."""
from pathlib import Path
import hashlib,io,json,re,subprocess,tarfile
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[2]
BASE='da111f7'
SOURCE=subprocess.check_output(['git','log','-1','--format=%H','--','roblox_port/src','roblox_port/tests'],cwd=ROOT,text=True).strip()
sha=lambda b:hashlib.sha256(b).hexdigest()
read=lambda name:json.loads((HERE/name).read_text(encoding='utf8'))
def archive(commit):
 b=subprocess.check_output(['git','archive','--format=tar',commit,'roblox_port/src','roblox_port/tests'],cwd=ROOT)
 with tarfile.open(fileobj=io.BytesIO(b)) as tree:return {t.name:tree.extractfile(t).read() for t in tree if t.isfile()}
baseAll,currentAll=archive(BASE),archive(SOURCE)
base={p:b for p,b in baseAll.items() if p.startswith('roblox_port/src/')}
current={p:b for p,b in currentAll.items() if p.startswith('roblox_port/src/')}
assert len(base)==len(current)==220
changed=sorted(p for p in set(base)|set(current) if base.get(p)!=current.get(p))
assert set(changed)=={'roblox_port/src/Client/SaveClient.luau','roblox_port/src/Client/SaveContinuation.luau','roblox_port/src/Client/SpiderClient.client.luau','roblox_port/src/Shared/UI/SaveText.luau'}
for path,b in current.items():assert (ROOT/path).read_bytes()==b,path
target=read('target-process.json');assert target['exit_code']==0
for path,h in target['inputs'].items():assert sha((ROOT/path).read_bytes())==h and sha(currentAll[path])==h,path
rows=re.findall(r'^([A-Z_0-9 ]+) passed=(\d+) failed=(\d+)',(HERE/'target.txt').read_text(),re.M)
assert rows==[('CONTINUATION_MENU','32','0'),('SAVE_CONTINUATION','119','0'),('SAVE_INTENT','57','0'),('SAVE_OBSERVATION','50','0'),('STATE','995','0'),('STATE_CLIENT','161','0'),('STATE_OFFLINE','8','0'),('REST_STORAGE','14','0'),('REST_COMPRESSION','57','0'),('SAVE_NOTICE','53','0'),('TITLE','21','0')]
compiled=read('compile.json');assert compiled['total']==compiled['passed']==220
assert len(compiled['files'])==220 and {r['path'] for r in compiled['files']}==set(current)
for r in compiled['files']:assert r['exit_code']==0 and r['sha256']==sha(current[r['path']])
for name in ['sourcemap','strict','runner']:assert read(name+'-process.json')['exit_code']==0
assert not re.search(r'TypeError|SyntaxError|Error:',(HERE/'strict.txt').read_text())
assert 'Ran 5 tests' in (HERE/'runner.txt').read_text()
prior=json.loads((ROOT/'docs/save-lease-cleanup/receipt.json').read_text());assert sha((ROOT/'roblox_port/TheWindowsill.rbxlx').read_bytes())==prior['production_sha256']
cost=read('copy-cost-v2-process.json');assert cost['exit_code']==0
for path,h in cost['inputs'].items():assert sha((ROOT/path).read_bytes())==h and sha(currentAll[path])==h,path
assert cost['diagnostic_sha256']==sha((HERE/'copy-cost-v2.py').read_bytes())
assert 'COPY_COST_DONE one_full_preserve_slot metadata_reads_100_full_copies_0 restores_1' in (HERE/'copy-cost-v2.txt').read_text()
receipt=dict(source=SOURCE,base=subprocess.check_output(['git','rev-parse',BASE],cwd=ROOT,text=True).strip(),scope='A06 actual game opts into continuation, explicit controller/menu choices and safe restore failure; cost/native/network/full gates still open',
 production_modules=220,changed_modules=changed,targeted_suites=11,targeted_passed=1567,menu_passed=32,state_passed=995,continuation_passed=119,intent_passed=57,observation_passed=50,compile_passed=220,strict_clean=True,runner_regressions=5,
 server_authority_integrated=True,server_protocol_integrated=True,checkpoint_receipts_integrated=True,client_protocol_integrated=True,game_opted_in=True,menu_integrated=True,feature_complete=False,
 representative_preserve_cli_cost_measured=True,representative_preserve_copy_network_measured=False,release_artifact_rebuilt=False,native_verified=False,online_verified=False,full_current_gates_verified=False,published=False,publication_ready=False)
(HERE/'receipt.json').write_text(json.dumps(receipt,indent=2)+'\n',encoding='utf8',newline='\n');print(json.dumps(receipt,indent=2))
