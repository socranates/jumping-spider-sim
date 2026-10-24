local Map=require("../src/Shared/World/WorldMap")
local Region=require("../src/Shared/World/Region")
local Pond=require("../src/Shared/World/Pond")
local Meadow=require("../src/Shared/World/Meadow")
local Hut=require("../src/Shared/World/Hut")
local Verge=require("../src/Shared/World/Verge")
local LookPlan=require("../src/Shared/World/LookPlan")
local Build=require("../src/Shared/World/WorldBuild")
local Motor=require("../src/Shared/Movement/SpiderMotor")
local Species=require("../src/Shared/Data/Species")
local Surfaces=require("../src/Shared/Data/Surfaces")
local Director=require("../src/Shared/Prey/PreyDirector")
local Memory=require("../src/Shared/Perception/ObservationMemory")
local Sensor=require("../src/Shared/Perception/Sensor")
local Needs=require("../src/Shared/Life/NeedsModel")
local Life=require("../src/Shared/Life/LifeLoop")
local Checkpoint=require("../src/Shared/Persistence/Checkpoint")
local ObjectRecord=require("../src/Shared/Persistence/ObjectRecord")
local Json=require("../src/Shared/Persistence/Json")
local fixtures=require("./compact_legacy_fixture")
local passed,failed=0,0
local function check(ok,msg) if ok then passed+=1 else failed+=1;print("FAIL COMPACT "..msg) end end
Map.use("preserve")
check(Map.revision()=="preserve-3","layout revision changes")
check(math.abs(Pond.PATH_E.x1-Pond.PATH_E.x0+Pond.PATH_N.z1-Pond.PATH_N.z0-286)<1e-8,"pond approach is 286 cm, formerly 2911 cm")
check(Meadow.PAD.z1==-516 and Meadow.CORE.z1==Meadow.PAD.z0,"meadow moves nearer without separating the habitat")
local path=0
for _,r in Hut.WALK do if string.match(r.id,"^path_m") then path+=r.z1-r.z0 end end
check(path==100,"garden-to-meadow path shrinks from four metres to one")
for _,r in Map.regions() do
 check(Map.at(r.spawn.pos+Vector3.new(0,.31,0))==r,"region owns its spawn: "..r.id)
end
-- The player's reported fall spot is supported and has nearby startup life,
-- rather than all five animals being clustered at the far end of the cell.
local shoulderPoint=Vector3.new(100,-84.29,-550)
local shoulder=assert(Map.at(shoulderPoint))
local closeStarts=0
for _,kind in Verge.bestiary(shoulder) do
 for _,perch in kind.perches do
  if perch.start and (perch.position-shoulderPoint).Magnitude<30 then closeStarts+=1 end
 end
end
check(closeStarts>0,"reported path shoulder has nearby startup life")
local chain={"garden_d2","path_m1","path_m2","path_m3","path_m4","pad_a2","pad_b2","pad_b3","mown_e1","mown_e2","mown_n1","walk_s1","walk_s2","walk_s3","walk_s4","deck_s1"}
for i=1,#chain-1 do
 local r=assert(Map.region(chain[i]));local found=false
 for _,n in r.neighbors do if n.id==chain[i+1] then found=true end end
 check(found,"continuous route "..chain[i].." -> "..chain[i+1])
end
-- The grass just outside the hut's outer path must be real ground. Without
-- support here the motor can wrap onto the gravel slab's underside, even
-- though the backdrop still looks like level grass.
for _,probe in {
 {"south_near",236.5,348},{"south_far",236.5,372},
 {"east_near",591,69.5},{"east_far",615,69.5},
 {"east_inner_near",529,69.5},{"east_inner_far",505,69.5},
 {"north_near",247.5,-197},{"north_far",247.5,-221},
}do
 local x,z=probe[2],probe[3]
 local owner=Map.at(Vector3.new(x,Hut.GROUND+.31,z));local supported=false
 for _,r in Map.regions()do
  for _,p in Region.pieces(r)do
   if x>=p.lo.X and x<=p.hi.X and z>=p.lo.Z and z<=p.hi.Z and math.abs(p.hi.Y-Hut.GROUND)<1e-6 then supported=true;break end
  end
  if supported then break end
 end
 check(owner~=nil and supported,`hut path shoulder {probe[1]}: region={owner~=nil}, support={supported}`)
end
-- Additive ground must not grow through the building or change old surfaces.
for _,r in Map.regions()do
 if r.kind=="verge"then
  for _,p in Region.pieces(r)do
   if string.find(p.id,"_soil_",1,true)then
    local inside=p.lo.X<Hut.BUILDING.x1 and p.hi.X>Hut.BUILDING.x0 and p.lo.Z<284 and p.hi.Z> -16
    check(not inside,"soil stays outside the hut footprint: "..p.id)
   end
  end
 end
end
local root=Build.world(workspace)
-- A tour must not let retained distant-room details displace the hut at home.
for _,tier in {"full","low"}do
 local held={}
 for _,r in Map.regions()do held=LookPlan.plan(r.spawn.pos+Vector3.yAxis*.31,tier,r,held)end
 local plan,total=LookPlan.plan(Vector3.new(-5,.31,-9),tier,Map.region("sill"),held)
 check(plan.hut==tier,tier.." returning from all ground regions retains the hut's detail")
 check(total<=LookPlan.BUDGET[tier],tier.." return still fits the render budget")
end
local lo,hi=Map.bounds()
local casts=Director.casts(root)
local motor=Motor.new({world=root,surfaces=Surfaces,profile=Species.phidippus_audax_prototype,
 spawn=Vector3.new(-25.5,.31,6),heading=Vector3.xAxis,boundsMin=lo,boundsMax=hi})
local prey=Director.engine(root,Species.fly_like_prototype,914,4,false,nil,casts)
local memory=Memory.new();local sensor=Sensor.new(memory);sensor:configureFrom(Species.phidippus_audax_prototype.perception)
local needs=Needs.new(true,false);prey.feeding.needs=needs
local life=Life.new(needs)
local world={motor=motor,prey=prey,memory=memory,sensor=sensor,needs=needs,life=life,garden={}}
local function vector(p) return Vector3.new(p[1],p[2],p[3]) end
for _,id in {"bench_slats","pond_stone","sill_crevice"} do
 local record=fixtures[id]
 local old=assert(ObjectRecord.decode(record.world,Checkpoint.CLASSES,Checkpoint.refs(world)))
 local ant=old.roots.garden.meadow_b4.ambient.ant.items[1]
 local oldAnt,oldHeading=ant.position,ant.heading
 local oldPerch=old.roots.garden.bin.kinds.housefly.graph.perches[1].position
 local unchanged=assert(Json.canonical(record))
 local ok,errors=Checkpoint.restore(record,world)
 check(ok,id.." restores: "..table.concat(errors," | "))
 if ok then
  local offset=if id=="bench_slats" then Vector3.new(0,0,300) elseif id=="pond_stone" then Vector3.new(-1300,0,1625) else Vector3.zero
  check((motor.pos-vector(record.player.position)-offset).Magnitude<1e-6,id.." preserves exact pose on relocated support")
  check(Map.inRetreat(motor.pos)==id,id.." remains in the same refuge")
  check(math.abs(needs.energy-.57)<1e-8 and life.clock.day==4 and life.clock.hour==12,"reserves and clock survive")
  check(life.growth.stage==1 and life.growth.fedSinceMoult==1.2,"growth and eaten meals survive")
  check(life.growth:canRun() and not life.growth:canLock(),"migration retains earned run without granting the second-moult lock")
  check(world.garden.meadow_b4.ambient.ant.items[1].position==oldAnt+Vector3.new(0,0,300),"ants relocate with their hill")
  check(world.garden.meadow_b4.ambient.ant.items[1].heading==oldHeading,"directions are not translated")
  check(world.garden.bin.kinds.housefly.graph.perches[1].position==oldPerch+Vector3.new(0,0,300),"perches relocate with their furniture")
  check(world.garden.mown_e15==nil,"retired long-path population is reauthored on demand")
  check(world.garden.bin.kinds.housefly.feeding==prey.feeding and prey.feeding.needs==needs,"one shared feeding ledger after migration")
  local newRecord=assert(Checkpoint.capture(world,0))
  check(newRecord.world_map.revision=="preserve-3" and #Checkpoint.check(newRecord,world)==0,"new save validates without reapplying migration")
 end
 check(Json.canonical(record)==unchanged,"checking/restoring does not mutate the old record")
end
-- Migration must validate an old route's objects before retiring its cache.
local broken=Json.copy(fixtures.bench_slats)
local damaged=false
for _,object in broken.world.objects do
 if object.c=="Fly" then
  local isRoute=false
  for _,entry in object.e do if entry[1]=="id" and string.find(entry[2],"mown_e15",1,true) then isRoute=true end end
  if isRoute then for _,entry in object.e do if entry[1]=="state" then entry[2]="INVALID";damaged=true;break end end;break end
 end
end
check(damaged,"fixture includes a retired route's living fly")
local before=assert(Json.canonical(assert(Checkpoint.capture(world,0))))
local restored=Checkpoint.restore(broken,world)
check(not restored,"damaged old ecology is refused, not repaired by pruning")
check(Json.canonical(assert(Checkpoint.capture(world,0)))==before,"refused migration leaves the live world untouched")
print(`COMPACT passed={passed} failed={failed} regions={#Map.regions()}`)
if failed>0 then error("compact layout checks failed") end
