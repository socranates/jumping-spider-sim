local Map=require("../src/Shared/World/WorldMap")
local Pond=require("../src/Shared/World/Pond")
Map.use("preserve")
for _,id in {"sill","hut_desk","garden_b2","meadow_b2","pond_a2","hut_doorway","lamp_1"} do
 local r=assert(Map.region(id));local p=r.spawn.pos+Vector3.yAxis*.31
 if id=="pond_a2" then local site=Pond.FROG_SITES[1];p=assert(Pond.frogSeat(site,Map.regions()))-site.facing*4+Vector3.yAxis*.31 end
 local actual=assert(Map.at(p));assert(actual.id==id,id.." resolves to "..actual.id)
 print("MEMORY_FIXTURE",id,p.X,p.Y,p.Z)
end
print("MEMORY_FIXTURES passed=7 failed=0")
