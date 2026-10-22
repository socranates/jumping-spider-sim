"""Read-only diagnostic; immutable bundled input, no production/test edits."""
from pathlib import Path
import hashlib, importlib.util, json, subprocess, tempfile
ROOT=Path(__file__).resolve().parents[3]
HERE=Path(__file__).resolve().parent
TOOL=Path(r'C:/Users/natha/.codex/.chatgpt-projects/g-p-6ac2f32f82a48191b0c7151a11eab0fd/roblox_tools/luau/luau.exe')
assert not (HERE/'output.txt').exists(), 'preserve previous evidence'
# Do not contaminate current full-run CPU measurement or overlap heavy CLI jobs.
assert (HERE.parent/'local-return/windows-full-process.json').exists(), 'wait for full Windows run to terminate'
spec=importlib.util.spec_from_file_location('runner',ROOT/'roblox_port/tests/run.py')
runner=importlib.util.module_from_spec(spec);spec.loader.exec_module(runner)
source=runner.bundle('local_rest_client.luau')
marker='-- Real client loop on shim services; not native rendering/network evidence.'
assert source.count(marker)==1
source=source.split(marker)[0]+runner.requires((HERE/'profile.luau').read_text(encoding='utf8'))
inputs={p.relative_to(ROOT).as_posix():hashlib.sha256(p.read_bytes()).hexdigest()
        for p in (ROOT/'roblox_port/src').rglob('*.luau')}
with tempfile.TemporaryDirectory() as folder:
 path=Path(folder)/'profile.luau';path.write_text(source,encoding='utf8',newline='\n')
 with (HERE/'output.txt').open('w',encoding='utf8',newline='\n') as log:
  result=subprocess.run([str(TOOL),str(path)],stdout=log,stderr=subprocess.STDOUT)
(HERE/'receipt.json').write_text(json.dumps(dict(exit_code=result.returncode,inputs=inputs,
 source=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),
 bundle_sha256=hashlib.sha256(source.encode()).hexdigest(),
 output_sha256=hashlib.sha256((HERE/'output.txt').read_bytes()).hexdigest(),
 scope='CLI shim; inclusive rows overlap; no native FPS or hard frame budget proof'),indent=2)+'\n',encoding='utf8',newline='\n')
raise SystemExit(result.returncode)
