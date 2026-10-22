from pathlib import Path
import hashlib,io,json,re,subprocess,tarfile,xml.etree.ElementTree as ET
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[1]
read=lambda n:json.loads((HERE/n).read_text(encoding='utf8'))
sha=lambda b:hashlib.sha256(b).hexdigest()
BASE='8e02b5ee5f443ab332cf7e70f5951a304cb89eea'
SOURCE=subprocess.check_output(['git','log','-1','--format=%H','--','roblox_port/src'],cwd=ROOT,text=True).strip()
def archive(commit):
 b=subprocess.check_output(['git','archive','--format=tar',commit,'roblox_port/src'],cwd=ROOT)
 with tarfile.open(fileobj=io.BytesIO(b)) as tree:return {t.name:tree.extractfile(t).read() for t in tree if t.isfile()}
base,new=archive(BASE),archive(SOURCE);assert len(base)==216 and len(new)==217
changed={p for p in set(base)|set(new) if base.get(p)!=new.get(p)}
assert changed=={'roblox_port/src/Client/SpiderClient.client.luau','roblox_port/src/Shared/Predator/RivalDrive.luau','roblox_port/src/Shared/World/StationAir.luau','roblox_port/src/Shared/World/NavigationPreparation.luau'}
for p,b in new.items():assert (ROOT/p).read_bytes()==b,p
old=read('baseline-process.json');target=read('target-process.json');assert old['exit_code']!=0 and target['exit_code']==0
for p,b in base.items():assert old['inputs'][p]==sha(b)
helper='roblox_port/src/Shared/World/NavigationPreparation.luau';assert old['test_only_added_module']==helper and old['inputs'][helper]==sha(new[helper])
assert 'NAVIGATION_STARTUP passed=10 failed=5' in (HERE/'baseline.txt').read_text(encoding='utf8')
for p,h in target['inputs'].items():assert sha((ROOT/p).read_bytes())==h,p
fixture='roblox_port/tests/navigation_startup.luau';assert old['inputs'][fixture]==target['inputs'][fixture]
rows=re.findall(r'^([A-Z_0-9 ]+) passed=(\d+) failed=(\d+)',(HERE/'target.txt').read_text(encoding='utf8'),re.M)
assert rows==[('NAVIGATION_STARTUP','15','0'),('OUTDOOR_RESET','45','0'),('MINIMAL','63','0'),('SAVE_NOTICE','53','0'),('CLIENT','27','0'),('TITLE','21','0')]
c=read('compile.json');assert c['total']==c['passed']==217
for r in c['files']:assert r['exit_code']==0 and r['sha256']==sha(new[r['path']])
for name in ['build','sourcemap','strict','runner']:assert read(name+'-process.json')['exit_code']==0
assert not re.search(r'TypeError|SyntaxError|Error:',(HERE/'strict.txt').read_text(encoding='utf8'))
assert 'Ran 5 tests' in (HERE/'runner.txt').read_text(encoding='utf8')
expected={}
for path,b in new.items():
 parts=list(Path(path).relative_to('roblox_port/src').parts);prefix={'First':'ReplicatedFirst','Client':'StarterPlayer.StarterPlayerScripts.Client','Server':'ServerScriptService.Server','Shared':'ReplicatedStorage.Shared'}[parts.pop(0)]
 parts[-1]=parts[-1].removesuffix('.luau').removesuffix('.client').removesuffix('.server');expected[prefix+'.'+'.'.join(parts)]=sha(b.replace(b'\r\n',b'\n'))
def release(path):
 found={}
 def walk(it,parent=''):
  name=it.findtext("./Properties/*[@name='Name']");full=parent+'.'+name if parent else name
  if it.attrib['class'] in {'Script','LocalScript','ModuleScript'}:
   assert full not in found;found[full]=sha(it.findtext("./Properties/*[@name='Source']").replace('\r\n','\n').encode())
  for c in it.findall('Item'):walk(c,full)
 for it in ET.parse(path).getroot().findall('Item'):walk(it)
 assert found==expected
 return sha(path.read_bytes())
h=release(ROOT/'roblox_port/TheWindowsill.rbxlx')
try:release(ROOT/'roblox_port/TheWindowsillTests.rbxlx')
except AssertionError:pass
else:raise AssertionError('test artifact accepted as production')
full=False
if (HERE/'windows-full-process.json').exists():
 assert read('windows-full-process.json')['exit_code']==0
 rows=re.findall(r'^([A-Z_0-9 ]+) passed=(\d+) failed=(\d+)',(HERE/'windows-full.txt').read_text(encoding='utf8'),re.M)
 assert len(rows)==65 and sum(int(r[1]) for r in rows)==443884 and all(int(r[2])==0 for r in rows);full=True
ci=read('ci-final.json') if (HERE/'ci-final.json').exists() else None
if ci:
 assert ci['head_sha']==SOURCE and ci['conclusion']=='success' and ci['passed']==443884 and ci['suites']==65
 for name,hsh in ci['logs_sha256'].items():assert sha((HERE/name).read_bytes())==hsh
receipt=dict(source=SOURCE,base=BASE,evidence_id='845ef13d49a92f88',production_modules=217,changed_modules=sorted(changed),
 paired_regression_baseline_pass=10,paired_regression_baseline_fail=5,startup_cases_passed=15,targeted_suites=6,targeted_passed=224,
 compile_passed=217,strict_clean=True,runner_regressions=5,production_sha256=h,test_artifact_rejected=True,
 windows_full_complete=full,linux_ci_verified=bool(ci),native_verified=False,full_controller_moving_input_replay_verified=False,published=False,publication_ready=False)
(HERE/'receipt.json').write_text(json.dumps(receipt,indent=2)+'\n',encoding='utf8',newline='\n');print(json.dumps(receipt,indent=2))
