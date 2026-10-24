"""Run actual scenery equivalence plus existing geometry/controller regressions."""
from pathlib import Path
import argparse,gzip,hashlib,importlib.util,json,subprocess,tempfile
H=Path(__file__).resolve().parent;ROOT=H.parents[1]
TOOLS=Path('C:/Users/natha/.codex/.chatgpt-projects/g-p-6ac2f32f82a48191b0c7151a11eab0fd/roblox_tools')
p=argparse.ArgumentParser();p.add_argument('prefix');p.add_argument('--focused',action='store_true');a=p.parse_args()
assert a.prefix.replace('-','').isalnum() and not (H/(a.prefix+'-checks.json')).exists()
s=importlib.util.spec_from_file_location('scenery_cli',ROOT/'roblox_port/tests/run.py');r=importlib.util.module_from_spec(s);s.loader.exec_module(r)
old=r.chunk(ROOT/'roblox_port/src/Shared/World/LookPlan.luau');new=r.chunk(H/'look-plan.luau')
inputs={};sha=lambda b:hashlib.sha256(b).hexdigest()
for path in [Path(__file__),H/'cache-checks.luau',H/'phone-checks.luau',H/'look-plan.luau',ROOT/'roblox_port/tests/run.py',ROOT/'roblox_port/tests/shim.luau',*list((ROOT/'roblox_port/src').rglob('*.luau')),*list((ROOT/'roblox_port/tests').glob('*.luau'))]:inputs[path.relative_to(ROOT).as_posix()]=sha(path.read_bytes())
results=[]
with tempfile.TemporaryDirectory(prefix='windowsill-scenery-cache-')as temp:
 for suite in (['equivalence']if a.focused else ['equivalence','worldmap.luau','world_client.luau','preserve.luau','compact_layout.luau']):
  if suite=='equivalence':
   bundle=r.bundle('worldmap.luau');body=r.requires((ROOT/'roblox_port/tests/worldmap.luau').read_text(encoding='utf8'))
   assert bundle.endswith(body+'\n');bundle=bundle[:-len(body+'\n')]
   bundle+='local __countedRegion=table.clone(__mods.Region)\nlocal __baselineLookPlan='+old.replace('__mods.Region','__countedRegion')+'\nlocal __optimizedLookPlan='+new.replace('__mods.Region','__countedRegion')+'\nlocal __phoneLookPlan='+new.replace('__mods.Region','__countedRegion')+'\n'+(H/'cache-checks.luau').read_text(encoding='utf8')+'\n'+(H/'phone-checks.luau').read_text(encoding='utf8')
  else:
   bundle=r.bundle(suite);marker='__mods.LookPlan = '+old;assert bundle.count(marker)==1
   bundle=bundle.replace(marker,'__mods.LookPlan = '+new)
  path=Path(temp)/'run.luau';path.write_bytes(bundle.encode())
  result=subprocess.run([str(TOOLS/'luau/luau.exe'),str(path)],capture_output=True,text=True)
  output=result.stdout+result.stderr;filename=a.prefix+'-'+suite.replace('.luau','')+'-output.txt';(H/filename).write_bytes(output.encode())
  if result.returncode:(H/(a.prefix+'-'+suite.replace('.luau','')+'-bundle.luau.gz')).write_bytes(gzip.compress(bundle.encode(),mtime=0))
  results.append(dict(suite=suite,exit_code=result.returncode,bundle_sha256=sha(bundle.encode()),output=filename,output_sha256=sha(output.encode())))
  print(suite,result.returncode,output[-1600:],flush=True)
  if result.returncode:break
assert all(sha((ROOT/path).read_bytes())==value for path,value in inputs.items())
(H/(a.prefix+'-checks.json')).write_bytes((json.dumps(dict(inputs=inputs,suites=results,all_passed=all(x['exit_code']==0 for x in results)),indent=2)+'\n').encode())
raise SystemExit(0 if all(x['exit_code']==0 for x in results)else 1)
