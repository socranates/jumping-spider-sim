"""Evaluate a rig optimization in a private bundle; never edit production source."""
from pathlib import Path
import hashlib,importlib.util,json,subprocess,tempfile,sys
ROOT=Path(__file__).resolve().parents[3];HERE=Path(__file__).resolve().parent
assert not (HERE/'rig-output.txt').exists(),'preserve prior result'
tool=Path(r'C:/Users/natha/.codex/.chatgpt-projects/g-p-6ac2f32f82a48191b0c7151a11eab0fd/roblox_tools/luau/luau.exe')
spec=importlib.util.spec_from_file_location('runner',ROOT/'roblox_port/tests/run.py')
runner=importlib.util.module_from_spec(spec);spec.loader.exec_module(runner)
path=ROOT/'roblox_port/src/Shared/Rig/SpiderRig.luau';original=path.read_text(encoding='utf8');candidate=original
inputs={p.relative_to(ROOT).as_posix():hashlib.sha256(p.read_bytes()).hexdigest()
 for base in ['roblox_port/src','roblox_port/tests'] for p in (ROOT/base).rglob('*') if p.is_file() and '__pycache__' not in p.parts}
def replace(old,new,count=1):
 global candidate
 assert candidate.count(old)==count,(old,candidate.count(old))
 candidate=candidate.replace(old,new)
replace('k: number, dir: Vector3 }','k: number, dir: Vector3, rotation: CFrame }')
first='if lie then Vector3.new(math.cos(lie), math.sin(lie) * c, math.sin(lie) * sn) else Vector3.new(1.3, c, sn).Unit'
second='Vector3.new(math.cos(lie), math.sin(lie) * c, math.sin(lie) * sn)'
assert candidate.count('local entry: LegHair = {')==2
replace('local c, sn, lie = math.cos(spec.theta), math.sin(spec.theta), spec.lift\n',
 'local c, sn, lie = math.cos(spec.theta), math.sin(spec.theta), spec.lift\n\t\t\t\tlocal direction = '+first+'\n')
replace('local width = spec.width or fuzz.legWidth\n','local width = spec.width or fuzz.legWidth\n\t\t\t\tlocal direction = '+second+'\n')
replace('dir = '+first+',','dir = direction, rotation = CFrame.lookAt(Vector3.zero, direction, Vector3.xAxis),')
replace('dir = '+second+',','dir = direction, rotation = CFrame.lookAt(Vector3.zero, direction, Vector3.xAxis),')
replace('rc * CFrame.lookAt(base + dir * (spec.length * g * 0.5), base + dir * spec.length*g, Vector3.xAxis)',
 'rc * (hair.rotation + (base + dir * (spec.length * g * 0.5)))')
source=runner.bundle('look.luau');marker="-- Look checks: the daughter's pattern is pinned literally"
assert source.count(marker)==1
source=source.split(marker)[0]+'\n__mods.RigCandidate=(function()\n'+runner.requires(runner.strict(candidate))+'\nend)()\n'+(HERE/'rig-candidate.luau').read_text(encoding='utf8')
with tempfile.TemporaryDirectory() as folder:
 bundle=Path(folder)/'paired.luau';bundle.write_text(source,encoding='utf8',newline='\n')
 if '--compile-only' in sys.argv:
  raise SystemExit(subprocess.call([str(tool.with_name('luau-compile.exe')),'-O0','--null',str(bundle)]))
 assert (HERE/'receipt.json').exists(),'finish serial save profiling first'
 with (HERE/'rig-output.txt').open('w',encoding='utf8',newline='\n') as log:
  result=subprocess.run([str(tool),str(bundle)],stdout=log,stderr=subprocess.STDOUT)
(HERE/'rig-candidate-source.luau').write_text(candidate,encoding='utf8',newline='\n')
(HERE/'rig-receipt.json').write_text(json.dumps(dict(exit_code=result.returncode,
 inputs=inputs,probe_sha256=hashlib.sha256((HERE/'rig-candidate.luau').read_bytes()).hexdigest(),
 original_sha256=hashlib.sha256(path.read_bytes()).hexdigest(),candidate_sha256=hashlib.sha256(candidate.encode()).hexdigest(),
 bundle_sha256=hashlib.sha256(source.encode()).hexdigest(),output_sha256=hashlib.sha256((HERE/'rig-output.txt').read_bytes()).hexdigest(),
 production_changed=False,native_verified=False),indent=2)+'\n',encoding='utf8',newline='\n')
raise SystemExit(result.returncode)
