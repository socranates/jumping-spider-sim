-- Real authored boot/book solids, motor and camera: a fallback must not start inside props.
local Map=require("../src/Shared/World/WorldMap")
local Build=require("../src/Shared/World/WorldBuild")
local Motor=require("../src/Shared/Movement/SpiderMotor")
local Camera=require("../src/Client/SpiderCamera")
local Species=require("../src/Shared/Data/Species")
local Surfaces=require("../src/Shared/Data/Surfaces")
local passed,failed=0,0
local function check(ok,msg) if ok then passed+=1 else failed+=1;print("FAIL SPAWN "..msg) end end
Map.use("preserve")
local root=Instance.new("Folder");root.Parent=workspace
for _,id in {"hut_shelf","hut_floor_a"} do Build.region(assert(Map.region(id)),root) end
local function interior(p)
 for _,part in root:GetDescendants() do if part:IsA("BasePart") and part.CanQuery and part.CanCollide then
  local lo,hi=part.Position-part.Size/2,part.Position+part.Size/2
  if p.X>lo.X+.001 and p.X<hi.X-.001 and p.Y>lo.Y+.001 and p.Y<hi.Y-.001 and p.Z>lo.Z+.001 and p.Z<hi.Z-.001 then return part.Name end
 end end
 return nil
end
check(interior(Vector3.new(-132,10.31,160))=="hut_shelf_book_top_1","old shelf fallback reproduced inside book")
check(interior(Vector3.new(-97.5,-69.69,53))=="station_boot_1_sole","old floor fallback reproduced inside boot")
local lo,hi=Map.bounds()
for _,id in {"hut_shelf","hut_floor_a"} do
 local r=assert(Map.region(id));local at=r.spawn.pos+Vector3.yAxis*.31
 local m=Motor.new({world=root,surfaces=Surfaces,profile=Species.phidippus_audax_prototype,spawn=at,heading=r.spawn.heading,boundsMin=lo,boundsMax=hi})
 m:place(at,Vector3.yAxis,r.spawn.heading)
 check(interior(at)==nil,"new fallback body clears props: "..id)
 local camera=Instance.new("Camera")
 local cam=Camera.new(camera,m.params,function() return {pos=m.pos,drawnUp=m.up,heading=m.heading} end,function() end)
 cam:snap()
 local input=Motor.idleInput()
 for tick=1,90 do
  input.wish=if tick>30 then m.heading else Vector3.zero
  m:tick(input);cam:tick(1/60);cam:render(1/60,0,0)
  if tick%15==0 then check(interior(camera.CFrame.Position)==nil,"camera clears props after stand/walk: "..id.." "..tick) end
 end
 check(m.mode=="attached" and interior(m.pos)==nil,"fallback can walk without burial: "..id)
 local floor=workspace:Raycast(m.pos+Vector3.yAxis*.1,-Vector3.yAxis*1,m.params)
 check(floor~=nil,"fallback remains physically supported: "..id)
end
print(`SPAWN passed={passed} failed={failed}`)
if failed>0 then error("spawn clearance failed") end
