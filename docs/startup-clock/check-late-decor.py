"""Run the three small late-visual regressions, optionally against old source.

The complete world_client suite remains authoritative for its normal checks.
This bounded selection makes the new visual-state regressions quick to repeat.
"""
from pathlib import Path
import argparse, importlib.util, subprocess, tempfile

ROOT=Path(__file__).resolve().parents[2]
p=argparse.ArgumentParser();p.add_argument('--luau',required=True);p.add_argument('--baseline');a=p.parse_args()
spec=importlib.util.spec_from_file_location('windowsill_runner',ROOT/'roblox_port/tests/run.py')
runner=importlib.util.module_from_spec(spec);spec.loader.exec_module(runner)
original_chunk=runner.chunk
changed={'Client/WorldClient.luau','Client/HutLife.luau','Client/SpiderClient.client.luau','Shared/Habitat/Breakaway.luau'}
def chunk(path):
 path=Path(path).resolve()
 if a.baseline and path.is_relative_to(ROOT/'roblox_port/src') and path.relative_to(ROOT/'roblox_port/src').as_posix() in changed:
  rel=path.relative_to(ROOT).as_posix()
  old=subprocess.check_output(['git','show',a.baseline+':'+rel],cwd=ROOT,text=True)
  return '(function()\n'+runner.requires(runner.strict(old))+'\nend)()'
 return original_chunk(path)
runner.chunk=chunk
body=(runner.HERE/'world_client.luau').read_text(encoding='utf8')
all_body=runner.requires(body)
program=runner.bundle('world_client.luau')
assert program.endswith(all_body+'\n')
selected=body[body.index('-- Optional streamed visuals arrive independently'):]
preamble=body[body.index('local passed, failed'):body.index('-- ---------------------------------------------------------------- stand-ins')]
program=program[:-len(all_body+'\n')]+preamble+runner.requires(selected)+'\n'
with tempfile.NamedTemporaryFile('w',suffix='.luau',encoding='utf8',delete=False) as f:
 f.write(program);name=Path(f.name)
try:result=subprocess.run([a.luau,str(name)])
finally:name.unlink(missing_ok=True)
raise SystemExit(result.returncode)
