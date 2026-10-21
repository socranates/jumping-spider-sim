local Map=require("../src/Shared/World/WorldMap")
local Station=require("../src/Shared/World/StationTerritory")
local Region=require("../src/Shared/World/Region")
local Rival=require("../src/Shared/Predator/RivalSpider")
local Route=require("../src/Shared/Predator/RivalRoute")
local Drive=require("../src/Shared/Predator/RivalDrive")
local Motor=require("../src/Shared/Movement/SpiderMotor")
local Species=require("../src/Shared/Data/Species")
local Surfaces=require("../src/Shared/Data/Surfaces")
local Build=require("../src/Shared/World/WorldBuild")
local passed,failed=0,0
local function check(ok,msg) if ok then passed+=1 else failed+=1;print("FAIL STATION "..msg) end end
Map.use("preserve")
local ids=Station.roam()
for _,id in {"sill","hut_floor_a","hut_floor_i","room_floor_a","room_floor_i","hut_desk","hut_doorway","hut_up_i","room_up_i"} do
 check(Station.contains(id) and ids[id],"resident territory includes "..id)
end
for _,id in {"garden_a3","garden_d2","path_m1","meadow_a3","hut_wall_w","hut_eave_mid"} do
 check(not Station.contains(id) and not ids[id],"resident territory excludes "..id)
end
local all,regions={},{}
for id in ids do
 local region=assert(Map.region(id));table.insert(regions,region)
 for _,p in Region.pieces(region) do table.insert(all,p) end
 local built=Build.region(region,Instance.new("Folder"))
 if region.kind~="sill" then check(built.ModelStreamingMode==Enum.ModelStreamingMode.Persistent,"resident collision persists: "..id) end
end
print(`STATION physical parts={#all} regions={#regions}`)
check(#all<2500,"station persistent collider budget")
local world=BoxWorld.folder("Station",all)
local lo,hi=Map.unionOf(regions)
local r=Rival.new()
local s={day=1,hour=0,meals=0,born=0,position=Vector3.new(0,.31,6),previous=Vector3.new(0,.31,6),
 heading=Vector3.zAxis,up=Vector3.yAxis,safe=true,resting=true,grounded=true,moving=false,seed=914}
Rival.step(r,1/60,s,function() return true end)
check(r.state=="patrol" and r.notice==0,"resident patrol starts on first day without meals, while player rests")
check(Rival.valid(r) and not Rival.misplaced(r),"resident record is valid")
-- Audit the surface graph, including corners between region planes. A mere
-- list of permitted region names would not prove a way through both rooms.
local startFace=Route.graph(r.region):faceAt(r.position,Vector3.yAxis)
local queue={{region=r.region,face=assert(startFace)}};local seen={};local reachable={};local head=1
while head<=#queue do
 local here=queue[head];head+=1
 local key=here.region..":"..here.face
 if seen[key] then continue end
 seen[key]=true;reachable[here.region]=true
 local graph=Route.graph(here.region)
 for _,edge in graph.faces[here.face].edges do table.insert(queue,{region=here.region,face=edge.to}) end
 for _,edge in graph:seamsOf(here.face) do
  if ids[edge.region] then table.insert(queue,{region=edge.region,face=edge.to}) end
 end
end
for id in ids do check(reachable[id],"surface routes reach "..id) end
local old=Rival.new();old.region="garden_d2"
check(Rival.misplaced(old),"old outdoor rival is migrated to the station")
local motor=Motor.new({world=world,surfaces=Surfaces,profile=Species.phidippus_audax_prototype,
 spawn=Vector3.new(47,-69.69,85),heading=Vector3.xAxis,boundsMin=lo,boundsMax=hi,probeParent=world})
motor:place(Vector3.new(47,-69.69,85),Vector3.yAxis,Vector3.xAxis)
r.position=motor.pos;r.previous=r.position;r.origin=r.position;r.target=r.position
local d=Drive.new(motor,function() return nil end,r.region,ids)
d.prevState="patrol"
local crossing=d:crossTo(Vector3.new(50,-70,85),"hut_floor_c")
check(crossing~=nil,"actual floor graph has a cross-cell route")
if crossing then
 d:_setGoal(crossing,"patrol")
 local crossed=false
 for _=1,60*8 do
  s.drive=d;Rival.step(r,1/60,s,function() return nil end);d:update(r,1/60,s)
  check(Map.inRetreat(motor.pos)==nil,"resident never enters retreat")
  if r.region=="hut_floor_c" then crossed=true;break end
 end
 check(crossed,"resident continues walking across floor cells while player shelters")
 check(not d.sees and r.notice==0,"sheltering player supplies no hidden sight information")
end
local asleep=Rival.new();asleep.state="consumed";asleep.food=0;asleep.elapsed=0;asleep.day=1
for _=1,60*61 do Rival.step(asleep,1/60,s,function() return nil end) end
check(asleep.state=="consumed","defeated rival cannot reappear in clear view")
Rival.step(asleep,1/60,s,function() return true end)
check(asleep.state=="patrol","replacement arrives only after delay and out of sight")
Map.use("test_garden")
-- Air routes are built from the preserve's real collision boxes, including the
-- wall between its rooms. Their swept segments must all remain clear.
Map.use("preserve")
local Air=require("../src/Shared/World/StationAir")
local warm=coroutine.create(function() Air.prepare(function() coroutine.yield() end) end)
assert(coroutine.resume(warm))
local from=Vector3.new(-110,16,160);local to=Vector3.new(400,40,70)
check(not Air.clear(from,to) and #Air.route(from,to)==1,"partially warmed navigation cannot expose an unsafe incomplete route")
local batches=1
while coroutine.status(warm)~="dead" do assert(coroutine.resume(warm));batches+=1 end
check(batches>100 and batches<800,"navigation warm-up yields in bounded batches instead of blocking a render frame")
for i,point in Air.points do
 check(Air.clear(point.hover,point.hover),"patrol point fits: "..point.id)
 local destination=Air.points[i%#Air.points+1]
 local route=Air.route(point.hover,destination.hover)
 check(#route>1,"patrol circuit reaches "..destination.id)
 for n=2,#route do check(Air.clear(route[n-1],route[n]),"swept route avoids solid geometry") end
end
local Wasp=require("../src/Shared/Predator/WaspDirector")
local wasp=Wasp.new({seed=914,world={ray=function() return false end,clear=function(a,b) return Air.clear(a,b) end,inRetreat=function() return true end}})
wasp:useGameRules();wasp:useStationRules()
local block={day=1,hour=0,meals=0,resting=true,moulting=false}
local spider={position=Vector3.new(0,.31,6),velocity=Vector3.zero,walkSpeed=3,airborne=false,falling=false}
wasp:step(1/60,spider,block)
check(wasp:isVisiting() and wasp.wasp.visible,"wasp resident exists from day one without a meal")
local visited={};local previous=wasp.wasp.position
for _=1,60*180 do
 wasp:step(1/60,spider,block)
 visited[wasp.point]=true
 check(wasp.wasp.visible and wasp.phase~="away" and wasp.phase~="leaving","resident does not fly away while player shelters")
 check(Air.clear(previous,wasp.wasp.position),"resident movement never crosses a wall")
 check(wasp.notice==0,"safe retreat gives no notice")
 previous=wasp.wasp.position
end
local count=0;for _ in visited do count+=1 end
print(`STATION wasp circuit visited={count}/{#Air.points}`)
check(count>=8,"resident searches widely instead of remaining on the sill")
Map.use("test_garden")
check(not Station.contains("sill") and Rival.roam()==nil,"legacy sill is not a resident station")
print(`STATION passed={passed} failed={failed}`)
if failed>0 then error("station checks failed") end
