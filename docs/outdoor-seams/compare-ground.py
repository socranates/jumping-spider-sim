"""Compare generated existing map/physics/look records with pre-repair Verge.

Runs actual authoring under the current CLI shim twice. Only the second
module loader differs. This is generated-data equivalence, not engine proof.
"""
from pathlib import Path
import hashlib,importlib.util,json,subprocess,tempfile
H=Path(__file__).resolve().parent;ROOT=H.parents[1];PORT=ROOT/'roblox_port'
T=Path('C:/Users/natha/.codex/.chatgpt-projects/g-p-6ac2f32f82a48191b0c7151a11eab0fd/roblox_tools')
spec=importlib.util.spec_from_file_location('ground_runner',PORT/'tests/run.py')
r=importlib.util.module_from_spec(spec);spec.loader.exec_module(r)
sha=lambda b:hashlib.sha256(b).hexdigest()
baseline='8ce079f0'
old=subprocess.check_output(['git','show',baseline+':roblox_port/src/Shared/World/Verge.luau'],cwd=ROOT).decode()
path=PORT/'src/Shared/World/Verge.luau'
old_chunk='(function()\n'+r.requires(r.strict(old))+'\nend)()'
new_chunk=r.chunk(path)
body=r.requires((PORT/'tests/compact_layout.luau').read_text())
program=r.bundle('compact_layout.luau');assert program.endswith(body+'\n')
program=program[:-len(body+'\n')]
assert program.count(new_chunk)==1
observe='''
local function plain(value)
 if type(value)~="table"then assert(type(value)~="function");return value end
 local out={};for k,v in value do out[k]=plain(v)end;return out
end
__mods.WorldMap.use("preserve")
for _,region in __mods.WorldMap.regions()do
 local text=assert(__mods.Json.canonical({region=plain(region),pieces=plain(__mods.Region.pieces(region)),decor=plain(__mods.Region.decor(region))}));print(text)
end
'''
records={};outputs={};bundles={}
with tempfile.TemporaryDirectory(prefix='hut-ground-compare-')as temp:
 for label,source in [('before',program.replace(new_chunk,old_chunk)+observe),('after',program+observe)]:
  f=Path(temp)/(label+'.luau');f.write_bytes(source.encode());bundles[label]=sha(source.encode())
  run=subprocess.run([str(T/'luau/luau.exe'),str(f)],capture_output=True,text=True)
  assert run.returncode==0,run.stdout[-1000:]+run.stderr[-1000:]
  try:rows=[json.loads(line)for line in run.stdout.splitlines()]
  except json.JSONDecodeError as e:
   raise AssertionError((label,e.pos,e.doc[max(0,e.pos-90):e.pos+90],e.doc[:90],len(e.doc)))from e
  records[label]={row['region']['id']:row for row in rows};assert len(records[label])==len(rows)
  outputs[label]=sha(run.stdout.encode())
before,after=records['before'],records['after']
assert len(before)==233 and len(after)==266
assert all(key in after and value==after[key]for key,value in before.items()),'Existing record changed'
added=sorted(set(after)-set(before));assert len(added)==33 and all(after[key]['region']['kind']=='verge'for key in added)
fingerprint=lambda row:sha(json.dumps(row,sort_keys=True,separators=(',',':')).encode())
record=dict(baseline=baseline,baseline_verge_sha256=sha(old.encode()),current_verge_sha256=sha(path.read_bytes()),
 unchanged_regions=len(before),added_regions=added,added_physical_pieces=sum(len(after[key]['pieces'])for key in added),
 bundles=bundles,normalized_output_sha256=outputs,existing_fingerprints={key:fingerprint(value)for key,value in before.items()},
 limits='Exact generated map, physics-piece and decor records under the CLI shim; not native rendering, memory, save-store or FPS proof.')
target=H/'ground-equivalence.json';assert not target.exists();target.write_bytes((json.dumps(record,indent=2)+'\n').encode())
print(json.dumps({k:record[k]for k in ['unchanged_regions','added_regions','added_physical_pieces']}))
