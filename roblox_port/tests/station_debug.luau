-- Focused regression for the station: a real motor through the new exit,
-- floor prey on actual support and a mouse that stays on traversable floor.
local Map=require("../src/Shared/World/WorldMap")
local Region=require("../src/Shared/World/Region")
local Hut=require("../src/Shared/World/Hut")
local Build=require("../src/Shared/World/WorldBuild")
local Station=require("../src/Shared/World/StationTerritory")
local Motor=require("../src/Shared/Movement/SpiderMotor")
local Species=require("../src/Shared/Data/Species")
local Surfaces=require("../src/Shared/Data/Surfaces")
local Mouse=require("../src/Shared/Prey/StationMouse")
local Body=require("../src/Client/StationMouseBody")
local Director=require("../src/Shared/Prey/PreyDirector")
local passed,failed=0,0
local function check(ok,msg) if ok then passed+=1 else failed+=1;print("FAIL STATION DEBUG "..msg) end end
Map.use("preserve")
local root=Instance.new("Folder");root.Parent=workspace
for _,id in {"room_window","room_exit","room_floor_f","path_e2","path_e3"} do Build.region(assert(Map.region(id)),root) end
local lo,hi=Map.bounds()
local motor=Motor.new({world=root,surfaces=Surfaces,profile=Species.phidippus_audax_prototype,
 spawn=Vector3.new(450,.31,134),heading=Vector3.xAxis,boundsMin=lo,boundsMax=hi})
motor:place(Vector3.new(450,.31,134),Vector3.yAxis,Vector3.xAxis)
local input=Motor.idleInput();input.wish=Vector3.xAxis
local detached=0
for _=1,60*24 do motor:tick(input);if motor.mode~="attached" then detached+=1 end end
check(motor.pos.X>470 and detached==0,"walk through five-cm crack and onto exterior sill without dropping")
-- Explicitly follow the logs downward; no invisible reset or floor trap.
motor:place(Vector3.new(473.81,-10,134),Vector3.xAxis,-Vector3.yAxis)
input.wish=-Vector3.yAxis
for _=1,60*32 do motor:tick(input);if motor.mode~="attached" then detached+=1 end end
check(motor.pos.Y< -80 and detached==0,"rough exterior logs meet real ground")
motor:place(Vector3.new(477,Hut.GROUND+.31,134),Vector3.yAxis,Vector3.xAxis)
input.wish=Vector3.xAxis
for _=1,60*24 do motor:tick(input);if motor.mode~="attached" then detached+=1 end end
check(motor.pos.X>530 and detached==0,"ground connects all the way to existing stone path")
check(not Station.contains("room_exit"),"resident rival cannot follow onto exterior exit")
local floorRoot=Instance.new("Folder");floorRoot.Parent=workspace
for _,r in Map.regions() do if Station.contains(r.id) then Build.region(r,floorRoot) end end
local params=RaycastParams.new();params.FilterType=Enum.RaycastFilterType.Include;params.FilterDescendantsInstances={floorRoot}
for id,quantity in Hut.LIFE.floorflies do
 local region=assert(Map.region(id));local spec
 for _,s in Hut.bestiary(region) do if s.profile=="fly_like_prototype" then spec=s end end
 check(spec~=nil and spec.target==quantity.full and spec.low==1,"one floor fly at both tiers: "..id)
 if spec then
  local supported=true
  for _,p in spec.perches do
   local hit=workspace:Raycast(p.position+Vector3.new(0,.1,0),Vector3.new(0,-.2,0),params)
   if not hit or hit.Normal.Y<.99 then supported=false end
  end
  check(supported,"random floor perches have actual support: "..id)
  local d=Director.engine(floorRoot,Species.fly_like_prototype,spec.seed,spec.target,false,spec)
  check(#d.flies==1,"floor fly director starts populated: "..id)
 end
end
local mouse=Mouse.new(914);local twin=Mouse.new(914)
local maxStep=0;local supported=true;local rooms={};local travelled=0
for _=1,60*120 do
 local before=mouse.pos
 mouse:step(1/60,nil,nil);twin:step(1/60,nil,nil)
 maxStep=math.max(maxStep,(mouse.pos-before).Magnitude)
 travelled+= (mouse.pos-before).Magnitude
 rooms[if mouse.pos.X<146.5 then "hut" elseif mouse.pos.X>175 then "back" else "doorway"]=true
 local hit=workspace:Raycast(mouse.pos+Vector3.new(0,1,0),Vector3.new(0,-2,0),params)
 if not hit then supported=false end
end
check(mouse.pos==twin.pos and mouse.seed==twin.seed,"mouse pauses and routes reproduce from seed")
check(travelled>400 and rooms.hut and rooms.back and rooms.doorway,"mouse actually visits both rooms")
check(maxStep<=Mouse.SPEED/60+.001 and supported,"mouse never teleports or leaves supported floor")
local drawn=Body.new(workspace);drawn:draw(mouse,false)
check(#drawn.parts<=16,"bounded mouse part budget")
for _,p in drawn.parts do check(not p.CanCollide and not p.CanQuery,"mouse cannot obstruct movement or perception") end
Map.use("test_garden")
print(`STATION DEBUG passed={passed} failed={failed}`)
if failed>0 then error("station debugging regressions failed") end
