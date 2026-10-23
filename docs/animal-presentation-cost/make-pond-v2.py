"""Extend the unchanged first candidate with owned invariant frog data."""
from pathlib import Path
import hashlib,json
HERE=Path(__file__).resolve().parent
m=json.loads((HERE/'pond-candidate.json').read_text(encoding='utf8'))
raw=(HERE/'pond-candidate.luau').read_bytes();assert hashlib.sha256(raw).hexdigest()==m['candidate_sha256']
output=HERE/'pond-candidate-v2.luau';assert not output.exists()
text=raw.decode('utf8')
helpers='''local function frogSizes(throat: number, swell: number?): (Vector3, Vector3)
 local sw = 1 + 0.05 * (swell or 0)
 return v(4.6 * sw, 2.3 * sw, 5.6), v(2.7, 0.7 + 0.45 * throat, 2.3)
end
local function frogTongue(out: { Spec }, tongue: number)
 if tongue > 0.05 then rod(out, "Tongue", v(0, 0.9, -4.4), v(0, 0.9, -4.4 - tongue), 0.45, PondBodies.FROG.tongue) end
end

'''
changes=[
 ('function PondBodies.frogParts(',helpers+'function PondBodies.frogParts('),
 ('local sw = 1 + 0.05 * (swell or 0)','local bodySize, throatSize = frogSizes(throat, swell)'),
 ('v(4.6 * sw, 2.3 * sw, 5.6), C.back','bodySize, C.back'),
 ('v(2.7, 0.7 + 0.45 * throat, 2.3), C.throat','throatSize, C.throat'),
 ('if tongue > 0.05 then rod(out, "Tongue", v(0, 0.9, -4.4), v(0, 0.9, -4.4 - tongue), 0.45, C.tongue) end','frogTongue(out, tongue)'),
 ('local specs = PondBodies.frogParts(throat, tongue, breath)\n\t\tif self.frog == nil then self.frog = build(self, "GreenFrog", PondBodies.frogParts(0.5, 1)) end',
 '''if self.frog == nil then
   local recipe = PondBodies.frogParts(0.5, 1)
   self.frog = build(self, "GreenFrog", recipe)
   self.frog.recipe = recipe
   for _, spec in recipe do
    if spec.name == "Body" then self.frog.bodySpec = spec elseif spec.name == "Throat" then self.frog.throatSpec = spec end
   end
   assert(self.frog.bodySpec and self.frog.throatSpec and recipe[self.frog.count].name == "Tongue", "frog recipe layout")
  end
  local specs = self.frog.recipe
  self.frog.bodySpec.size, self.frog.throatSpec.size = frogSizes(throat, breath)
  specs[self.frog.count] = nil
  frogTongue(specs, tongue)'''),
]
# Replace old factory expressions before inserting helpers with matching text.
for old,new in changes[1:]:
 assert text.count(old)==1,old
 text=text.replace(old,new)
old,new=changes[0];assert text.count(old)==1;text=text.replace(old,new)
output.write_text(text,encoding='utf8',newline='\n')
meta=dict(source=m['source'],path=m['path'],reference_sha256=m['reference_sha256'],candidate_sha256=hashlib.sha256(text.encode()).hexdigest(),
 revision='v2',previous_candidate_sha256=m['candidate_sha256'],changes='Owned invariant frog/darner recipes and bulk buffers; shared size/tongue helpers preserve pure factory and exact dynamic poses',
 production_changed=False,simulation_changed=False,animation_rates_changed=False,adopted=False)
(HERE/'pond-candidate-v2.json').write_text(json.dumps(meta,indent=2)+'\n',encoding='utf8',newline='\n');print(json.dumps(meta,indent=2))
