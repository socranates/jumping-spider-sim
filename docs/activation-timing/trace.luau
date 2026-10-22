local Map=require("../src/Shared/World/WorldMap")
local Station=require("../src/Shared/World/StationTerritory")
local Route=require("../src/Shared/Predator/RivalRoute")
local Drive=require("../src/Shared/Predator/RivalDrive")
local Motor=require("../src/Shared/Movement/SpiderMotor")
local Species=require("../src/Shared/Data/Species")
local Surfaces=require("../src/Shared/Data/Surfaces")
local Build=require("../src/Shared/World/WorldBuild")
local FPS=__FPS__
local BARRIER=__BARRIER__
Map.use("preserve")
local root=Build.world(workspace)
local lo,hi=Map.bounds()
Drive.prepare(Station.roam(),Station.REGION)
local drive=Drive.new(Motor.new({world=root,surfaces=Surfaces,profile=Species.phidippus_audax_prototype,
 spawn=Station.ARRIVE,heading=Vector3.xAxis,boundsMin=lo,boundsMax=hi}),function() return false end,Station.REGION,Station.roam(),true)
local rival={state="patrol",position=Station.ARRIVE,heading=Vector3.xAxis,up=Vector3.yAxis,region=Station.REGION,origin=Station.ARRIVE,leg=0}
local spider={position=Vector3.new(-25.5,.31,6),up=Vector3.yAxis,safe=true,resting=true,seed=914}
-- Experimental gate only; this is not connected to the playable controller.
-- Prepare all resident routes before simulation tick zero, keeping per-slice production budgets.
local warmStarted=os.clock();local warmSlices=0
if BARRIER then
 while Route.preparationStats().pending>0 do
  local ok,why=Drive.advance();assert(ok,why);warmSlices+=1
  assert(warmSlices<100000,"warmup did not converge")
 end
end
print("[ACTIVATION_WARMUP]",FPS,BARRIER,warmSlices,os.clock()-warmStarted)
local accumulator,tick=0,0
local preparedAt,movedAt=nil,nil
local checks=0
for frame=1,FPS*90 do
 local ok,why=Drive.advance();assert(ok,why)
 accumulator+=1/FPS
 while accumulator+1e-10>=1/60 do
  accumulator-=1/60;tick+=1
  if preparedAt==nil and Route.prepared(Station.REGION)~=nil then preparedAt=tick end
  drive:update(rival,1/60,spider)
  if movedAt==nil and (rival.position-Station.ARRIVE).Magnitude>.2 then movedAt=tick end
  if tick%600==0 then
   print("[ACTIVATION_SAMPLE]",FPS,tick,if drive.g then "ready" else "pending",string.format("%.6f",rival.position.X),string.format("%.6f",rival.position.Y),string.format("%.6f",rival.position.Z),rival.leg,Route.preparationStats().pending)
  end
 end
 local stats=Route.preparationStats();assert(stats.lastUnits<=2048);checks+=1
end
assert(tick==5400 and preparedAt and movedAt,"trace did not exercise completed navigation and movement")
print("[ACTIVATION_DONE]",FPS,tick,preparedAt,movedAt,checks)
