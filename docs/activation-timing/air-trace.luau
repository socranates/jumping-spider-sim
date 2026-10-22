local Map=require("../src/Shared/World/WorldMap")
local Air=require("../src/Shared/World/StationAir")
local FPS=__FPS__
local BARRIER=__BARRIER__
Map.use("preserve")
local a,b=Air.entry,Air.points[9].hover
assert(not Air.clear(a,b),"fixture must need graph navigation")
local pauses=0
local thread=coroutine.create(function() Air.prepare(function() pauses+=1;coroutine.yield() end) end)
local function advance()
 if coroutine.status(thread)~="dead" then local ok,why=coroutine.resume(thread);assert(ok,why) end
end
-- Model the existing task.wait callback as one warmup resumption per render frame.
-- This is a controlled scheduling model, not Roblox scheduler/network proof.
if BARRIER then repeat advance() until coroutine.status(thread)=="dead" end
local tick,accumulator,readyAt=0,0,nil
for frame=1,FPS*30 do
 advance();accumulator+=1/FPS
 while accumulator+1e-10>=1/60 do
  accumulator-=1/60;tick+=1
  local route=Air.route(a,b)
  if #route>1 and readyAt==nil then readyAt=tick end
  if tick%300==0 then print("[AIR_SAMPLE]",FPS,tick,#route,coroutine.status(thread),pauses) end
 end
end
assert(tick==1800 and readyAt and coroutine.status(thread)=="dead" and pauses==625,"air trace incomplete")
local route=Air.route(a,b)
for i=2,#route do assert(Air.clear(route[i-1],route[i]),"final route crosses collision") end
print("[AIR_DONE]",FPS,tick,readyAt,pauses,#route)
