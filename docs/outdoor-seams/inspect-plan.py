"""Bounded pure-plan diagnosis; does not launch a client or change sources."""
from pathlib import Path
import importlib.util,subprocess,tempfile
H=Path(__file__).resolve().parent;ROOT=H.parents[1];PORT=ROOT/'roblox_port'
T=Path('C:/Users/natha/.codex/.chatgpt-projects/g-p-6ac2f32f82a48191b0c7151a11eab0fd/roblox_tools')
spec=importlib.util.spec_from_file_location('plan_runner',PORT/'tests/run.py');r=importlib.util.module_from_spec(spec);spec.loader.exec_module(r)
body=r.requires((PORT/'tests/compact_layout.luau').read_text());program=r.bundle('compact_layout.luau');assert program.endswith(body+'\n');program=program[:-len(body+'\n')]
old=subprocess.check_output(['git','show','8ce079f0:roblox_port/src/Shared/World/Verge.luau'],cwd=ROOT).decode()
current=r.chunk(PORT/'src/Shared/World/Verge.luau');previous='(function()\n'+r.requires(r.strict(old))+'\nend)()'
observe='''
__mods.WorldMap.use("preserve")
for _,at in {Vector3.new(-25.5,.31,6),Vector3.new(-5,.31,-9)}do
 local fresh,total=__mods.LookPlan.plan(at,"full",__mods.WorldMap.region("sill"))
 local held={}
 for _,region in __mods.WorldMap.regions()do held=__mods.LookPlan.plan(region.spawn.pos+Vector3.yAxis*.31,"full",region,held)end
 local returned,parts=__mods.LookPlan.plan(at,"full",__mods.WorldMap.region("sill"),held)
 print("PLAN",at,"fresh",total,fresh.hut,"after_tour",parts,returned.hut)
 if returned.hut~="full"then for _,region in __mods.WorldMap.regions()do
  if returned[region.id]~=fresh[region.id]then print(region.id,"fresh",fresh[region.id],"returned",returned[region.id])end
 end end
end
'''
with tempfile.TemporaryDirectory(prefix='hut-plan-inspect-')as temp:
 for name,source in [('before',program.replace(current,previous)),('after',program)]:
  f=Path(temp)/(name+'.luau');f.write_bytes((source+observe).encode())
  run=subprocess.run([str(T/'luau/luau.exe'),str(f)],capture_output=True,text=True)
  print(name,run.returncode,run.stdout,run.stderr)
