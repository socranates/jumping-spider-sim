"""Verify retained receipts against current Git source, raw logs and built scripts."""
from pathlib import Path
import contextlib,hashlib,io,json,re,runpy,shutil,subprocess,tarfile,tempfile,xml.etree.ElementTree as ET
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[1]
BASE='4ed6375d3fb05166739b7757fecffb8d0cb90cad'
SOURCE=subprocess.check_output(['git','log','-1','--format=%H','--','roblox_port/src','roblox_port/tests'],cwd=ROOT,text=True).strip()
sha=lambda b:hashlib.sha256(b).hexdigest()
read=lambda p:json.loads((HERE/p).read_text(encoding='utf8'))
def archive(commit):
 b=subprocess.check_output(['git','archive','--format=tar',commit,'roblox_port/src'],cwd=ROOT)
 with tarfile.open(fileobj=io.BytesIO(b)) as tree:return {t.name:tree.extractfile(t).read() for t in tree if t.isfile()}
base,current=archive(BASE),archive(SOURCE);assert len(base)==len(current)==217
changed=[p for p in set(base)|set(current) if base.get(p)!=current.get(p)]
assert changed==['roblox_port/src/Shared/Persistence/SaveSession.luau']
for p,b in current.items():assert (ROOT/p).read_bytes()==b,p
fixture=(HERE/'cases.luau').read_bytes();state=(ROOT/'roblox_port/tests/state.luau').read_bytes();assert state.count(fixture)==1
pair={}
for label,code in [('baseline',base),('candidate',current)]:
 m=read(label+'-process.json');pair[label]=m
 assert m['base']==BASE and m['fixture_sha256']==sha(fixture) and m['expanded_test_sha256']==sha(state)
 for p,b in code.items():assert m['inputs'][p]==sha(b),p
 for p,h in m['inputs'].items():
  if p.startswith('roblox_port/tests/') and not p.endswith('/BuildInfo.luau'):assert sha((ROOT/p).read_bytes())==h,p
 log=(HERE/(label+'.txt')).read_bytes();assert sha(log)==m['log_sha256']
 expected='STATE passed=805 failed=26' if label=='baseline' else 'STATE passed=831 failed=0'
 assert expected in log.decode() and (m['exit_code']!=0 if label=='baseline' else m['exit_code']==0)
 with tempfile.TemporaryDirectory() as folder:
  snap=Path(folder);shutil.copytree(ROOT/'roblox_port/src',snap/'roblox_port/src');shutil.copytree(ROOT/'roblox_port/tests',snap/'roblox_port/tests')
  for p,b in code.items():(snap/p).write_bytes(b)
  runner=runpy.run_path(str(snap/'roblox_port/tests/run.py'))
  assert sha(runner['bundle']('state.luau').encode())==m['bundle_sha256']
target=read('target-process.json');assert target['exit_code']==0
for p,h in target['inputs'].items():assert sha((ROOT/p).read_bytes())==h,p
rows=re.findall(r'^([A-Z_0-9 ]+) passed=(\d+) failed=(\d+)',(HERE/'target.txt').read_text(),re.M)
assert rows==[('STATE','831','0'),('STATE_CLIENT','162','0'),('STATE_OFFLINE','8','0'),('REST_STORAGE','14','0'),('REST_COMPRESSION','57','0')]
c=read('compile.json');assert c['total']==c['passed']==217
for r in c['files']:assert r['exit_code']==0 and r['sha256']==sha(current[r['path']])
for name in ['build','sourcemap','strict','runner']:assert read(name+'-process.json')['exit_code']==0
assert not re.search(r'TypeError|SyntaxError|Error:',(HERE/'strict.txt').read_text())
assert 'Ran 5 tests' in (HERE/'runner.txt').read_text()
h=hashlib.sha256();port=ROOT/'roblox_port'
for p in sorted([*port.glob('src/**/*.luau'),*port.glob('tests/**/*.luau'),*port.glob('*.project.json')]):
 if p.name!='BuildInfo.luau':h.update(p.relative_to(port).as_posix().encode()+b'\0'+p.read_bytes()+b'\0')
evidence=h.hexdigest()[:16];assert evidence=='b425324a7f0a8007'
assert evidence in (port/'tests/studio/BuildInfo.luau').read_text()
expected={}
for path,b in current.items():
 parts=list(Path(path).relative_to('roblox_port/src').parts);prefix={'First':'ReplicatedFirst','Client':'StarterPlayer.StarterPlayerScripts.Client','Server':'ServerScriptService.Server','Shared':'ReplicatedStorage.Shared'}[parts.pop(0)]
 parts[-1]=parts[-1].removesuffix('.luau').removesuffix('.client').removesuffix('.server');expected[prefix+'.'+'.'.join(parts)]=sha(b.replace(b'\r\n',b'\n'))
def release(path):
 found={}
 def walk(it,parent=''):
  name=it.findtext("./Properties/*[@name='Name']");full=parent+'.'+name if parent else name
  if it.attrib['class'] in {'Script','LocalScript','ModuleScript'}:
   assert full not in found;found[full]=sha(it.findtext("./Properties/*[@name='Source']").replace('\r\n','\n').encode())
  for child in it.findall('Item'):walk(child,full)
 for it in ET.parse(path).getroot().findall('Item'):walk(it)
 assert found==expected
 return sha(path.read_bytes())
production=release(port/'TheWindowsill.rbxlx')
try:release(port/'TheWindowsillTests.rbxlx')
except AssertionError:pass
else:raise AssertionError('test artifact accepted as release')
windows=False;windows_hash=None
if (HERE/'windows-full-process.json').exists():
 assert read('windows-full-process.json')['exit_code']==0
 b=(HERE/'windows-full.txt').read_bytes();windows_hash=sha(b)
 rows=re.findall(r'^([A-Z_0-9 ]+) passed=(\d+) failed=(\d+)',b.decode(),re.M)
 assert len(rows)==65 and sum(int(r[1]) for r in rows)==443946 and all(int(r[2])==0 for r in rows);windows=True
receipt=dict(source=SOURCE,base=BASE,evidence_id=evidence,production_modules=217,changed_modules=changed,
 baseline_passed=805,baseline_failed=26,candidate_state_passed=831,new_state_checks=62,new_cases=9,targeted_suites=5,targeted_passed=1072,
 compile_passed=217,strict_clean=True,runner_regressions=5,production_sha256=production,test_artifact_rejected=True,
 windows_full_complete=windows,windows_log_sha256=windows_hash,linux_ci_verified=False,native_verified=False,online_rejoin_verified=False,
 foreign_lease_continue_implemented=False,legacy_world_restoration_implemented=False,published=False,publication_ready=False)
(HERE/'receipt.json').write_text(json.dumps(receipt,indent=2)+'\n',encoding='utf8',newline='\n');print(json.dumps(receipt,indent=2))
