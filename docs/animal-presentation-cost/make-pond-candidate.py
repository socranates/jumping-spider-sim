"""Create a source-bound presentation candidate without touching production."""
from pathlib import Path
import hashlib,json,subprocess
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[1]
SOURCE='59146e1005c083330455379766ab8c9dd2de2705'
path='roblox_port/src/Client/PondBodies.luau'
raw=subprocess.check_output(['git','show',SOURCE+':'+path],cwd=ROOT)
assert (ROOT/path).read_bytes()==raw,'production no longer matches the measured reference'
reference=HERE/'pond-reference.luau';candidate=HERE/'pond-candidate.luau'
assert not reference.exists() and not candidate.exists(),'preserve existing prototype inputs'
text=raw.decode('utf8')
changes=[
 ('return { model = model, parts = parts, count = #specs }','return { model = model, parts = parts, count = #specs, moved = {}, frames = {} }'),
 ('local AWAY = CFrame.new(0, -600, 0)','local AWAY = CFrame.new(0, -600, 0)\nlocal HIDDEN: { Spec } = table.freeze({})'),
 ('local moved: { BasePart } = {}\n\tlocal frames: { CFrame } = {}','local moved: { BasePart } = rig.moved\n\tlocal frames: { CFrame } = rig.frames\n\ttable.clear(moved)\n\ttable.clear(frames)'),
 ('place(self.frog, {}, CFrame.identity)','place(self.frog, HIDDEN, CFrame.identity)'),
 ('local specs = PondBodies.darnerParts(true)\n\t\tif self.darner == nil then self.darner = build(self, "GreenDarner", specs) end',
  'if self.darner == nil then\n\t\t\tlocal specs = PondBodies.darnerParts(true)\n\t\t\tself.darner = build(self, "GreenDarner", specs)\n\t\t\tself.darner.recipe = specs\n\t\tend\n\t\tlocal specs = self.darner.recipe'),
 ('place(self.darner, {}, CFrame.identity)','place(self.darner, HIDDEN, CFrame.identity)'),
]
for old,new in changes:
 assert text.count(old)==1,old
 text=text.replace(old,new)
reference.write_bytes(raw);candidate.write_text(text,encoding='utf8',newline='\n')
metadata=dict(source=SOURCE,path=path,reference_sha256=hashlib.sha256(raw).hexdigest(),candidate_sha256=hashlib.sha256(text.encode()).hexdigest(),
 changes='Owned per-rig bulk-move buffers, one darner recipe per presentation instance, immutable empty hidden recipe',
 production_changed=False,simulation_changed=False,animation_rates_changed=False,adopted=False)
(HERE/'pond-candidate.json').write_text(json.dumps(metadata,indent=2)+'\n',encoding='utf8',newline='\n')
print(json.dumps(metadata,indent=2))
